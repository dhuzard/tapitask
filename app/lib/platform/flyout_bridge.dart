import "dart:async";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter/services.dart";

import "../l10n/s.dart";
import "../state/app_state.dart";

/// Bridge between the NATIVE Win32 tray flyout (windows/runner/flyout_window.cpp)
/// and the Dart world:
/// - pushes fresh data (pinned lists + items of the active list) through the
///   method channel whenever the drift streams emit;
/// - applies native user actions (check, add, delete, select list, pin) via
///   AppState — the drift watch then re-pushes the updated snapshot.
///
/// The flyout itself is a native window created HIDDEN at startup: showing it
/// is a plain ShowWindow, so it is instant and adds no Flutter engine.
class FlyoutBridge {
  final AppState state;
  /// Opens the main window (set by TrayController).
  void Function()? onOpenApp;
  static const _ch = MethodChannel("tapitask/win32");
  String? _activeList;
  StreamSubscription? _listsSub;
  StreamSubscription? _itemsSub;
  List<String> _lastLists = const [];

  FlyoutBridge(this.state);

  bool get isAvailable => Platform.isWindows;

  void init() {
    if (!isAvailable) return;
    _ch.setMethodCallHandler(_onNative);
    _listsSub = state.db.watchPinnedLists().listen((lists) {
      final ids = lists.map((l) => l.id).toList();
      if (ids.join(",") != _lastLists.join(",")) {
        _lastLists = ids;
        if (_activeList == null || !ids.contains(_activeList)) {
          // Liste par défaut de l'appareil si elle est épinglée.
          final dflt = state.defaultListId;
          _activeList = dflt != null && ids.contains(dflt)
              ? dflt
              : (ids.isEmpty ? null : ids.first);
          _resubscribeItems();
        }
      }
      _push();
    });
    _resubscribeItems();
  }

  void _resubscribeItems() {
    _itemsSub?.cancel();
    if (_activeList == null) {
      _push();
      return;
    }
    _itemsSub = state.db.watchItemsOf(_activeList!).listen((_) => _push());
  }

  /// Line protocol (tab-separated, UTF-8):
  ///   `L\t<id>\t<title>\t<color>`   — pinned list
  ///   `A\t<id>`                     — active list id
  ///   `I\t<id>\t<0|1>\t<label>`     — item
  Future<void> _push() async {
    if (!isAvailable) return;
    final buf = StringBuffer();
    final lists = await state.db.pinnedLists();
    for (final l in lists) {
      buf.writeln("L\t${l.id}\t${_clean(l.title)}\t${l.color ?? ""}");
    }
    if (_activeList != null) buf.writeln("A\t$_activeList");
    // Localized native labels (per-user synced language).
    buf.writeln("T\t${_clean(S.addButton)}\t${_clean(S.deleteAction)}"
        "\t${_clean(S.nothingToDo)}\t${_clean(S.pinListsHelp)}");
    // Fine-grained flyout settings: open-app button visibility.
    buf.writeln("F\t${state.settings["flyout_open_button"] == false ? 0 : 1}");
    final items = _activeList == null
        ? const []
        : await state.db.uncheckedItemsOf(_activeList!);
    for (final i in items) {
      final due = state.dueSuffix(i);
      buf.writeln("I\t${i.id}\t${i.done ? 1 : 0}\t${_clean(i.label)}"
          "\t${_clean(due ?? "")}");
    }
    try {
      await _ch.invokeMethod("updateFlyoutData", {"data": buf.toString()});
    } catch (_) {}
  }

  static String _clean(String s) => s.replaceAll("\t", " ").replaceAll("\n", " ");

  Future<dynamic> _onNative(MethodCall call) async {
    if (call.method != "flyoutEvent") return null;
    final args = Map<String, dynamic>.from(call.arguments as Map);
    final action = args["action"] as String? ?? "";
    final a = args["a"] as String? ?? "";
    final b = args["b"] as String? ?? "";
    switch (action) {
      case "check":
        await state.toggleItem(a, true);
        break;
      case "uncheck":
        await state.toggleItem(a, false);
        break;
      case "delete":
        await state.deleteItem(a);
        break;
      case "add":
        if (_activeList != null && a.trim().isNotEmpty) {
          await state.addQuickItems(_activeList!, a);
        }
        break;
      case "select":
        if (a != _activeList) {
          _activeList = a;
          _resubscribeItems();
        }
        break;
      case "pin":
        await state.setFlyoutPinned(b == "true");
        break;
      case "openApp":
        onOpenApp?.call();
        break;
      case "close":
        break;
    }
    return null;
  }

  /// Tray click: toggle the native flyout. The pinned state is read from the
  /// prefs cache so the popup applies topmost + no-dismiss immediately.
  Future<void> toggle() async {
    if (!isAvailable) return;
    try {
      final pinned = await state.flyoutPinned();
      // Guarantee: opening the flyout NEVER hides the main window — it stays
      // exactly as it was (the flyout is an independent popup).
      final appWasVisible =
          await state.isMainWindowVisible?.call() ?? false;
      final nowVisible = await _ch.invokeMethod<bool>("toggleFlyout",
          {"pinned": pinned});
      if ((nowVisible ?? false) && appWasVisible) {
        await state.restoreMainWindow?.call();
      }
      if (nowVisible ?? false) _push();
    } catch (e) {
      // Visible with `flutter run` — a silent catch here is what made the
      // flyout impossible to debug from the outside.
      debugPrint("FlyoutBridge.toggle failed: $e");
      rethrow;
    }
  }

  void dispose() {
    _listsSub?.cancel();
    _itemsSub?.cancel();
  }
}
