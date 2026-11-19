import "dart:io";

import "dart:async";
import "dart:convert";
import "dart:math";

import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:drift/drift.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../data/api_client.dart";
import "../l10n/s.dart";
import "../data/database.dart";
import "../data/sync_service.dart";
import "package:home_widget/home_widget.dart";

import "../platform/alert_service.dart";
import "../platform/widget_service.dart";
import "widget_intent.dart";

class AppState extends ChangeNotifier {
  final AppDb db;
  AppState({AppDb? db}) : db = db ?? AppDb();
  late final ApiClient api;
  late final SyncService sync;

  bool ready = false;
  String? error;
  bool isAdmin = false;
  bool quickAddRequested = false;
  String? quickAddListId;
  StreamSubscription<Uri?>? _widgetClickSub;
  final MethodChannel _widgetChannel = MethodChannel("com.tapitask/tapitask/widget");

  /// Per-user feature toggles (server-side, synced between devices).
  Map<String, dynamic> settings = {
    "folders": false,
    "alerts": false,
    "templates": false,
    "visible_actions": true,
    "poll_interval": 30,
    "theme": "system",
    "lang": "fr",
    "notify_app": true,
    "notify_email": true,
    // Mots-clés d'échéance personnels pour l'ajout rapide :
    // {"j+1": "+1", "next week": "+7", "réunion": "lundi"}
    "due_keywords": <String, String>{},
    // Fonctions visibles dans le volet / widget
    "compact_due": true,
    "flyout_open_button": true,
    "start_hidden": false,
    "compact_delete": true,
  };
  final List<void Function()> _undoStack = [];

  bool get featureFolders => settings["folders"] == true;
  bool get featureAlerts => settings["alerts"] == true;
  bool get featureTemplates => settings["templates"] == true;

  /// Actions d'item visibles (icônes calendrier/⋯ sur chaque ligne) vs
  /// accès par appui long uniquement.
  bool get visibleActions => settings["visible_actions"] != false;

  /// Mots-clés d'échéance personnels (ajout rapide), ex. {"j+1": "+7"}.
  Map<String, String> get dueKeywords {
    final raw = settings["due_keywords"];
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return {};
  }

  /// Échéances affichées dans le volet / widget.
  bool get compactDueDates => settings["compact_due"] != false;

  /// Poubelle visible dans le volet.
  bool get compactDelete => settings["compact_delete"] != false;

  /// [lightweight] skips everything network-related (full sync, profile,
  /// alerts, widget-launch URI): used by the Windows flyout, which must be
  /// instant and only reads/writes the local database.
  Future<void> init({bool lightweight = false}) async {
    api = await ApiClient.load();
    sync = SyncService(
        api: api, db: db, onChanged: notifyListeners, onSynced: _refreshWidget);
    if (lightweight) {
      // The flyout reads the locally cached settings (written by the main
      // window on every profile reload / settings save) — no network needed.
      await _loadCachedSettings();
      ready = true;
      notifyListeners();
      return;
    }
    await _applyWidgetToggles();
    await sync.init();
    await reloadProfile();
    await _refreshWidget();
    if (featureAlerts && settings["notify_app"] != false) {
      await AlertService.ensureInitialized();
      final due = await db.dueItems();
      await AlertService.notifyDueToday(due);
    }
    if (Platform.isAndroid) {
      // Android : action privée + MethodChannel natif (pas de plugin
      // home_widget pour le lancement — vérif d'expéditeur impossible,
      // validation stricte côté Dart).
      // La spec prévoyait receiveBroadcastStream(), retirée de MethodChannel
      // dans les Flutter récents : équivalent = handler de méthode pour le
      // push natif « widgetLaunch ».
      _widgetChannel.setMethodCallHandler(_onWidgetLaunch);
      final cold = await _widgetChannel.invokeMethod<String>("getLaunchUri");
      await _applyWidgetUri(cold == null ? null : Uri.parse(cold));
    } else {
      try {
        final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
        _applyWidgetUri(uri);
      } catch (_) {}
      // Relance depuis le widget alors que l'app est DÉJÀ ouverte :
      // launchMode=singleTask route vers onNewIntent → home_widget émet ici.
      _widgetClickSub = HomeWidget.widgetClicked.listen(_applyWidgetUri);
    }
    ready = true;
    notifyListeners();
  }

  /// Push natif « widgetLaunch » (relance depuis le widget, app déjà ouverte).
  Future<void> _onWidgetLaunch(MethodCall call) async {
    if (call.method != "widgetLaunch") return;
    final arg = call.arguments;
    await _applyWidgetUri(arg is String ? Uri.parse(arg) : null);
  }

  /// URI de lancement d'un widget : validation stricte (scheme/path/uuid)
  /// + membership via les listes visibles localement, session requise.
  Future<void> _applyWidgetUri(Uri? uri) async {
    if (uri == null || uri.scheme != "tapitask") return;
    if (api.accessToken == null) return;
    if (uri.path != "quickadd" && uri.host != "quickadd") return;
    final ids = (await db.visibleLists()).map((l) => l.id).toSet();
    final list = validateQuickAddUri(uri, ids);
    if (list == null) return;
    quickAddRequested = true;
    quickAddListId = list.isEmpty ? null : list;
    notifyListeners();
  }

  /// (Re)load the user profile: admin flag + per-user feature settings.
  /// Called at startup and after every login.
  Future<void> reloadProfile() async {
    if (api.isConfigured && api.accessToken != null) {
      try {
        final me = await api.get("/auth/me");
        isAdmin = me["is_admin"] == true;
        final remote = me["settings"];
        if (remote is Map<String, dynamic>) {
          settings = {...settings, ...remote};
        }
        S.setLocale(settings["lang"] as String?);
        await _cacheSettings();
      } catch (_) {}
    }
    // Apply the synced parameters (polling delay).
    final poll = settings["poll_interval"];
    if (poll is int && poll != sync.pollSeconds) {
      sync.applyPollInterval(poll);
    }
    notifyListeners();
  }

  /// Called after a successful login: refresh UI, widgets and badge.
  Future<void> refreshAfterLogin() async {
    await _refreshWidget();
    notifyListeners();
  }

  /// Items checked from the home-screen widget: apply them to the local DB
  /// so the next sync pushes them to the server.
  Future<void> _applyWidgetToggles() async {
    try {
      final ids = await WidgetService.pendingToggles();
      if (ids.isEmpty) return;
      final now = DateTime.now().toUtc();
      for (final id in ids) {
        try {
          await db.setDone(id, true, now);
        } catch (_) {}
      }
      await WidgetService.clearToggles();
      if (api.isConfigured && api.accessToken != null) {
        sync.syncSoon();
      }
    } catch (_) {}
  }

  Future<String> createList(String title, {bool localOnly = false}) async {
    final id = _uuid();
    final now = DateTime.now().toUtc();
    await db.upsertList(LocalListsCompanion(
      id: Value(id),
      title: Value(title),
      ownerId: const Value(""),
      updatedAt: Value(now),
      dirty: Value(!localOnly), // pushed as list.create unless local-only
      localOnly: Value(localOnly),
    ));
    notifyListeners();
    if (!localOnly && api.isConfigured && api.accessToken != null) {
      sync.syncSoon();
    }
    return id;
  }

  Future<void> pinList(String id, bool pinned) async {
    final list = await (db.select(db.localLists)..where((l) => l.id.equals(id)))
        .getSingle();
    await db.update(db.localLists).replace(list.copyWith(pinned: pinned));
    await _refreshWidget();
    notifyListeners();
  }

  Future<void> renameList(String id, String title) async {
    await db.renameList(id, title, DateTime.now().toUtc());
    notifyListeners();
    if (api.isConfigured && api.accessToken != null) {
      sync.syncSoon();
      await _refreshWidget();
      notifyListeners();
    }
  }

  Future<void> setListColor(String id, String? color) async {
    final list = await (db.select(db.localLists)..where((l) => l.id.equals(id)))
        .getSingle();
    await (db.update(db.localLists)..where((l) => l.id.equals(id)))
        .write(LocalListsCompanion(
      color: Value(color),
      updatedAt: Value(DateTime.now().toUtc()),
      dirty: Value(!list.localOnly),
    ));
    notifyListeners();
    if (!list.localOnly && api.isConfigured && api.accessToken != null) {
      sync.syncSoon();
    }
    await _refreshWidget();
    notifyListeners();
  }

  Future<void> setListLocalOnly(String id, bool localOnly) async {
    await (db.update(db.localLists)..where((l) => l.id.equals(id)))
        .write(LocalListsCompanion(
      localOnly: Value(localOnly),
      updatedAt: Value(DateTime.now().toUtc()),
      dirty: Value(localOnly ? false : true),
    ));
    if (!localOnly && api.isConfigured && api.accessToken != null) {
      sync.syncSoon();
    }
    await _refreshWidget();
    notifyListeners();
  }

  // Main-window hooks, set by main() once the TrayController exists
  // (avoids a circular import app_state <-> tray_controller).
  Future<bool> Function()? isMainWindowVisible;
  Future<void> Function()? restoreMainWindow;

  /// Localized due-date badge for compact surfaces (Windows flyout, Android
  /// widget), shown only if the user enabled it (settings["compact_due"]).
  String? dueSuffix(dynamic item) {
    if (!compactDueDates) return null;
    final due = item.dueDate;
    if (due == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(due.year, due.month, due.day);
    if (d == today) return S.t("today");
    if (d == today.add(const Duration(days: 1))) return S.t("tomorrow");
    if (d.isBefore(today)) return S.t("overdueSuffix").trim();
    return "${d.day}/${d.month}";
  }

  // ---- Flyout pin (native Win32 popup) ----

  Future<bool> flyoutPinned() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool("flyout_pinned") ?? false;
  }

  Future<void> setFlyoutPinned(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("flyout_pinned", value);
  }

  Future<void> saveSettings() async {
    S.setLocale(settings["lang"] as String?);
    try {
      await api.patch("/auth/me", {"settings": settings});
    } catch (_) {}
    await _cacheSettings();
    notifyListeners();
  }

  static const _cachedSettingsPref = "cached_settings";

  Future<void> _cacheSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedSettingsPref, jsonEncode(settings));
    } catch (_) {}
  }

  Future<void> _loadCachedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cachedSettingsPref);
      if (raw != null && raw.isNotEmpty) {
        final cached = jsonDecode(raw);
        if (cached is Map<String, dynamic>) {
          settings = {...settings, ...cached};
        }
        S.setLocale(settings["lang"] as String?);
      }
    } catch (_) {}
  }

  void pushUndo(void Function() undo) {
    _undoStack.add(undo);
    if (_undoStack.length > 50) _undoStack.removeAt(0);
    notifyListeners();
  }

  Future<void> undoLast() async {
    if (_undoStack.isEmpty) return;
    final undo = _undoStack.removeLast();
    undo();
    notifyListeners();
  }

  Future<void> setItemDetails(String id,
      {String? notes, DateTime? dueDate, bool clearDue = false}) async {
    await db.setItemDetails(id, DateTime.now().toUtc(),
        notes: notes, dueDate: dueDate, clearDue: clearDue);
    notifyListeners();
    if (api.isConfigured && api.accessToken != null) {
      sync.syncSoon();
    }
    await _refreshWidget();
  }

  /// Duplicate a list (title, color, folder, items).
  Future<String> duplicateList(String sourceId, {String? title}) async {
    final source = await (db.select(db.localLists)
          ..where((l) => l.id.equals(sourceId)))
        .getSingle();
    final newId = _uuid();
    final now = DateTime.now().toUtc();
    await db.upsertList(LocalListsCompanion(
      id: Value(newId),
      title: Value(title ?? "${source.title} (copie)"),
      ownerId: const Value(""),
      updatedAt: Value(now),
      dirty: Value(!source.localOnly),
      color: Value(source.color),
      folder: Value(source.folder),
      localOnly: Value(source.localOnly),
    ));
    var position = 0;
    for (final item in await db.itemsOf(sourceId)) {
      await db.addItem(_uuid(), newId, item.label, position++, now,
          recurrence: item.recurrence,
          notes: item.notes,
          dueDate: item.dueDate);
    }
    notifyListeners();
    if (!source.localOnly && api.isConfigured && api.accessToken != null) {
      sync.syncSoon();
    }
    return newId;
  }

  Future<void> setListFolder(String id, String? folder) async {
    await (db.update(db.localLists)..where((l) => l.id.equals(id)))
        .write(LocalListsCompanion(
      folder: Value(folder),
      updatedAt: Value(DateTime.now().toUtc()),
      dirty: const Value(true),
    ));
    notifyListeners();
    if (api.isConfigured && api.accessToken != null) {
      sync.syncSoon();
    }
    await _refreshWidget();
    notifyListeners();
  }

  Future<void> deleteList(String id) async {
    await db.deleteList(id, DateTime.now().toUtc());
    notifyListeners();
    if (api.isConfigured && api.accessToken != null) {
      sync.syncSoon();
    }
    await _refreshWidget();
    notifyListeners();
  }

  /// Quick add: one line = one item. Optional recurrence / parent (sub-task).
  /// Parser: "demain" / "aujourd'hui" / "après-demain" / "lundi".."dimanche"
  /// set a due date, "#nomdelaliste" also adds the item to that list.
  /// [dueDate] : échéance choisie explicitement (puce de la zone d'ajout).
  /// Elle s'applique à chaque ligne et désactive les mots-clés de date,
  /// pour ne pas retirer « lundi »… d'un libellé qui n'en est pas un.
  Future<void> addQuickItems(String listId, String text,
      {String? parentId, String recurrence = "none", DateTime? dueDate}) async {
    final lists = await db.visibleLists();
    for (final raw in text.split("\n")) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      await _addParsedLine(listId, line, lists,
          parentId: parentId, recurrence: recurrence, dueDate: dueDate);
    }
    // offline-first: items go through the outbox on the next sync,
    // never through a direct POST (it created server-side duplicates).
    if (api.isConfigured && api.accessToken != null) {
      sync.syncSoon();
    }
    await _refreshWidget();
    notifyListeners();
  }

  /// Résout une valeur de mot-clé d'échéance en date :
  /// "+N" / "j+N" = dans N jours ; "lundi".."dimanche" = prochain jour
  /// de la semaine ; "aujourd'hui" / "demain" / "après-demain" = built-ins.
  DateTime? _resolveDueValue(String value) {
    final now = DateTime.now();
    final v = value.trim().toLowerCase();
    final plus = RegExp(r"^(?:\+|j\+|j)(\d+)$").firstMatch(v);
    if (plus != null) {
      final n = int.parse(plus.group(1)!);
      return n == 0 ? now : now.add(Duration(days: n));
    }
    const weekdays = {
      "lundi": 1, "mardi": 2, "mercredi": 3, "jeudi": 4,
      "vendredi": 5, "samedi": 6, "dimanche": 7,
    };
    if (weekdays.containsKey(v)) {
      var delta = (weekdays[v]! - now.weekday + 7) % 7;
      if (delta == 0) delta = 7;
      return now.add(Duration(days: delta));
    }
    if (v == "aujourd'hui" || v == "aujourdhui" || v == "today") return now;
    if (v == "demain" || v == "tomorrow") {
      return now.add(const Duration(days: 1));
    }
    if (v == "après-demain" || v == "apres-demain") {
      return now.add(const Duration(days: 2));
    }
    return null;
  }

  Future<void> _addParsedLine(String listId, String line, List<dynamic> lists,
      {String? parentId, String recurrence = "none", DateTime? dueDate}) async {
    var label = line;
    final explicitDue = dueDate != null;
    String? extraListId;

    // 1) Mots-clés personnels (réglages synchronisés) — le plus long d'abord.
    // Ignorés si une échéance a été choisie explicitement.
    final custom = explicitDue
        ? <MapEntry<String, String>>[]
        : (dueKeywords.entries.toList()
          ..sort((a, b) => b.key.length.compareTo(a.key.length)));
    for (final entry in custom) {
      final word = entry.key.toLowerCase();
      final idx = label.toLowerCase().indexOf(word);
      if (idx >= 0) {
        final resolved = _resolveDueValue(entry.value);
        if (resolved != null) {
          dueDate = resolved;
          label = (label.substring(0, idx) + label.substring(idx + word.length))
              .trim();
          break;
        }
      }
    }
    // 2) Mots-clés intégrés.
    if (dueDate == null) {
      final dateWords = {
        "aujourd'hui": 0,
        "aujourdhui": 0,
        "demain": 1,
        "après-demain": 2,
        "apres-demain": 2,
        "lundi": 1,
        "mardi": 2,
        "mercredi": 3,
        "jeudi": 4,
        "vendredi": 5,
        "samedi": 6,
        "dimanche": 7,
      };
      for (final word in dateWords.keys) {
        final idx = label.toLowerCase().indexOf(word);
        if (idx >= 0) {
          final now = DateTime.now();
          if (word == "aujourd'hui" || word == "aujourdhui") {
            dueDate = now;
          } else if (word == "demain") {
            dueDate = now.add(const Duration(days: 1));
          } else if (word == "après-demain" || word == "apres-demain") {
            dueDate = now.add(const Duration(days: 2));
          } else {
            final target = dateWords[word]!;
            var delta = (target - now.weekday + 7) % 7;
            if (delta == 0) delta = 7;
            dueDate = now.add(Duration(days: delta));
          }
          label = (label.substring(0, idx) + label.substring(idx + word.length))
              .trim();
          break;
        }
      }
    }

    final hashMatch = RegExp(r"#([\p{L}0-9_-]+)", unicode: true).firstMatch(label);
    if (hashMatch != null) {
      final name = hashMatch.group(1)!.toLowerCase();
      for (final l in lists) {
        if ((l.title as String).toLowerCase() == name) {
          extraListId = l.id as String;
          break;
        }
      }
      if (extraListId != null) {
        label = label.replaceFirst(hashMatch.group(0)!, "").trim();
      }
    }

    final targets = {listId, if (extraListId != null) extraListId};
    final now = DateTime.now().toUtc();
    for (final target in targets) {
      final position = await db.nextPosition(target);
      await db.addItem(_uuid(), target, label, position, now,
          parentId: parentId,
          recurrence: recurrence,
          dueDate: dueDate);
    }
  }

  /// Toggle an item. If it is recurring, the server spawns the next
  /// occurrence on sync; locally we optimistically keep it simple.
  Future<void> toggleItem(String id, bool done) async {
    await db.setDone(id, done, DateTime.now().toUtc());
    notifyListeners();
    if (api.isConfigured && api.accessToken != null) {
      sync.syncSoon();
    }
    await _refreshWidget();
    // Undoable: an accidental check (widget, flyout, inline home row) is
    // restorable via Ctrl+Z.
    pushUndo(() async {
      await db.setDone(id, !done, DateTime.now().toUtc());
      notifyListeners();
      if (api.isConfigured && api.accessToken != null) {
        sync.syncSoon();
      }
      await _refreshWidget();
    });
  }

  /// Delete with undo support: returns a closure that restores the item
  /// and registers it in the global undo stack (Ctrl+Z).
  Future<void Function()> deleteItem(String id) async {
    await db.deleteItem(id, DateTime.now().toUtc());
    notifyListeners();
    if (api.isConfigured && api.accessToken != null) {
      sync.syncSoon();
    }
    await _refreshWidget();
    Future<void> restore() async {
      await db.restoreItem(id, DateTime.now().toUtc());
      notifyListeners();
      if (api.isConfigured && api.accessToken != null) {
        sync.syncSoon();
      }
      await _refreshWidget();
    }
    pushUndo(restore);
    return restore;
  }

  Future<void> reorderItem(String id, int position) async {
    await db.reorder(id, position, DateTime.now().toUtc());
    notifyListeners();
    if (api.isConfigured && api.accessToken != null) {
      sync.syncSoon();
    }
  }

  Future<void> purgeDone(String listId) async {
    await db.purgeDone(listId, DateTime.now().toUtc());
    notifyListeners();
    if (api.isConfigured && api.accessToken != null) {
      try {
        await api.delete("/lists/$listId/done-items");
      } catch (_) {}
      sync.syncSoon();
    }
    await _refreshWidget();
  }

  Future<void> _refreshWidget() async {
    try {
      final pinned = await db.pinnedLists();
      await WidgetService.update(this, db, pinned);
    } catch (_) {}
  }

  String _uuid() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final hex = b.map((x) => x.toRadixString(16).padLeft(2, "0")).join();
    return "${hex.substring(0, 8)}-${hex.substring(8, 12)}-"
        "${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}";
  }

  @override
  void dispose() {
    _widgetClickSub?.cancel();
    if (Platform.isAndroid) _widgetChannel.setMethodCallHandler(null);
    sync.dispose();
    db.close();
    super.dispose();
  }
}
