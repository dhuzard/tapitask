import "package:material_ui/material_ui.dart";
import "package:flutter/services.dart";

import "../data/database.dart";
import "../state/app_state.dart";
import "admin_screen.dart";
import "list_screen.dart";
import "search_screen.dart";
import "share_screen.dart";
import "../l10n/s.dart";

class HomeScreen extends StatefulWidget {
  final AppState state;
  const HomeScreen({super.key, required this.state});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Lists whose inline items are COLLAPSED. Items are shown by default.
  final Set<String> _collapsed = {};
  final _newList = TextEditingController();
  bool _quickAddShown = false;

  static const _templates = {
    "Courses": [
      "Fruits et légumes", "Pain", "Lait", "Viande / poisson",
      "Produits d'entretien",
    ],
    "Voyage": [
      "Réserver l'hébergement", "Billets de transport", "Assurance",
      "Papiers d'identité", "Chargeurs et adaptateurs", "Médicaments",
    ],
    "Réunion": [
      "Ordre du jour", "Compte-rendu précédent", "Points à décider",
      "Invitations envoyées",
    ],
  };

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeQuickAdd());
  }

  void _onChanged() {
    setState(() {});
    // Relance depuis le widget pendant que l'app est déjà ouverte.
    if (widget.state.quickAddRequested) _maybeQuickAdd();
  }

  @override
  void dispose() {
    widget.state.removeListener(_onChanged);
    super.dispose();
  }

  /// Opened from the 1x1 quick-add widget: preselect a list and focus add.
  Future<void> _maybeQuickAdd() async {
    if (_quickAddShown || !widget.state.quickAddRequested) return;
    _quickAddShown = true;
    widget.state.quickAddRequested = false;
    final target = widget.state.quickAddListId;
    widget.state.quickAddListId = null;
    if (target != null) {
      // Garde double : la liste doit exister encore (la validation amont
      // rend ce cas théorique, mais la défense coûte 3 lignes).
      final visible = await widget.state.db.visibleLists();
      if (!visible.any((l) => l.id == target)) return;
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ListScreen(state: widget.state, listId: target),
        ),
      );
      return;
    }
    final lists = await widget.state.db.visibleLists();
    if (!mounted) return;
    if (lists.isEmpty) {
      await _promptNewList();
    } else {
      final pinned = await widget.state.db.pinnedLists();
      final fallback = pinned.isNotEmpty ? pinned.first : lists.first;
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ListScreen(state: widget.state, listId: fallback.id),
        ),
      );
    }
  }

  Future<void> _createList(String title, {List<String>? items}) async {
    final id = await widget.state.createList(title);
    if (items != null && items.isNotEmpty) {
      await widget.state.addQuickItems(id, items.join("\n"));
    }
    if (!mounted) return;
    final share = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("« $title » créée"),
        content: const Text("Voulez-vous la partager avec d'autres membres ?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(S.later)),
          FilledButton.icon(
              icon: const Icon(Icons.share),
              onPressed: () => Navigator.pop(context, true),
              label: Text(S.share)),
        ],
      ),
    );
    if (share == true && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ShareScreen(state: widget.state, listId: id),
        ),
      );
    }
  }

  Future<void> _renameList(LocalList list) async {
    final controller = TextEditingController(text: list.title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.renameList),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(S.rename)),
        ],
      ),
    );
    if (title != null && title.trim().isNotEmpty) {
      await widget.state.renameList(list.id, title.trim());
    }
  }

  Future<void> _deleteList(LocalList list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Supprimer « ${list.title} » ?"),
        content: Text(S.deleteListBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Annuler")),
          FilledButton.tonalIcon(
              icon: const Icon(Icons.delete_outline),
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer),
              onPressed: () => Navigator.pop(context, true),
              label: Text(S.delete)),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.state.deleteList(list.id);
    }
  }

  Future<void> _pickColor(LocalList list) async {
    const palette = [
      null,
      "#00897B", "#43A047", "#1E88E5", "#5E35B1", "#D32F2F",
      "#F4511E", "#F6BF26", "#6D4C41", "#546E7A", "#37474F",
    ];
    final choice = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.listColor),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final hex in palette)
              InkWell(
                onTap: () => Navigator.pop(context, hex),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: hex == null ? null : _parseColor(hex),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outline),
                    shape: BoxShape.circle,
                  ),
                  child: hex == null
                      ? const Icon(Icons.format_color_reset, size: 20)
                      : null,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text(S.close)),
        ],
      ),
    );
    if (choice != list.color) {
      await widget.state.setListColor(list.id, choice);
    }
  }

  Future<void> _pickFolder(LocalList list) async {
    final folders = await _existingFolders();
    if (!mounted) return;
    final controller = TextEditingController(text: list.folder ?? "");
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.folder),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(hintText: S.folderName),
              onSubmitted: (v) => Navigator.pop(context, v),
            ),
            if (folders.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final f in folders)
                    ActionChip(
                      label: Text(f),
                      onPressed: () => Navigator.pop(context, f),
                    ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, ""),
              child: Text(S.none)),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(S.ok)),
        ],
      ),
    );
    if (choice != null) {
      await widget.state.setListFolder(list.id,
          choice.trim().isEmpty ? null : choice.trim());
    }
  }

  Future<Set<String>> _existingFolders() async {
    final lists = await widget.state.db.visibleLists();
    return lists
        .map((l) => l.folder)
        .whereType<String>()
        .where((f) => f.isNotEmpty)
        .toSet();
  }

  Future<void> _promptNewList() async {
    final state = widget.state;
    if (state.featureTemplates) {
      final choice = await showDialog<_TemplateChoice>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(S.newList),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(S.emptyList),
                onTap: () =>
                    Navigator.pop(context, const _TemplateChoice.empty()),
              ),
              for (final entry in _templates.entries)
                ListTile(
                  leading: const Icon(Icons.content_copy),
                  title: Text(entry.key),
                  subtitle: Text(entry.value.take(3).join(", ")),
                  onTap: () => Navigator.pop(
                      context, _TemplateChoice.template(entry.key)),
                ),
            ],
          ),
        ),
      );
      if (choice == null) return;
      if (choice.isTemplate) {
        await _createList(choice.name, items: _templates[choice.name]);
        return;
      }
    }
    final title = await _promptTitle();
    if (title != null && title.trim().isNotEmpty) {
      await _createList(title.trim());
    }
  }

  Future<String?> _promptTitle() {
    _newList.clear();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.newList),
        content: TextField(
          controller: _newList,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(context, v),
          decoration: const InputDecoration(hintText: "Nom de la liste"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          FilledButton(
              onPressed: () => Navigator.pop(context, _newList.text),
              child: Text(S.create)),
        ],
      ),
    );
  }

  Color? _parseColor(String? hex) {
    if (hex == null) return null;
    final v = int.tryParse(hex.replaceFirst("#", "0xFF"));
    return v == null ? null : Color(v);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final scheme = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            _promptNewList,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => SearchScreen(state: state))),
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            state.undoLast,
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Tapitask",
              style: TextStyle(
                  color: scheme.onSurface, fontWeight: FontWeight.w600)),
          actions: [
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: S.todoAllTooltip,
              onPressed: () => Navigator.pushNamed(context, "/todo"),
            ),
            IconButton(
              icon: const Icon(Icons.today_outlined),
              tooltip: S.today,
              onPressed: () => Navigator.pushNamed(context, "/today"),
            ),
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: S.search,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => SearchScreen(state: state)),
              ),
            ),
            if (widget.state.isAdmin)
              IconButton(
                icon: const Icon(Icons.admin_panel_settings),
                tooltip: S.administration,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AdminScreen(state: widget.state)),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: S.settings,
              onPressed: () => Navigator.pushNamed(context, "/settings"),
            ),
          ],
        ),
        body: StreamBuilder<List<LocalList>>(
          stream: state.db.watchVisibleLists(),
          initialData: const [],
          builder: (context, snapshot) {
            final lists = snapshot.data ?? [];
            if (lists.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.checklist_rounded,
                        size: 64, color: scheme.outline),
                    const SizedBox(height: 12),
                    Text("Aucune liste",
                        style: TextStyle(color: scheme.outline)),
                    const SizedBox(height: 4),
                    Text(S.createOneBelow,
                        style:
                            TextStyle(color: scheme.outline, fontSize: 12)),
                  ],
                ),
              );
            }
            if (state.featureFolders) {
              return _folderListView(lists);
            }
            return _listView("Vos listes", lists);
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: Text(S.newList),
          onPressed: _promptNewList,
        ),
      ),
    );
  }

  Widget _folderListView(List<LocalList> lists) {
    final children = <Widget>[];
    final noFolder = lists.where((l) => (l.folder ?? "").isEmpty).toList();
    children.addAll(_folderSection("Vos listes", noFolder, isDefault: true));
    for (final folder in _existingFoldersSync(lists)) {
      final inFolder = lists.where((l) => l.folder == folder).toList();
      children.addAll(_folderSection(folder, inFolder));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      children: children,
    );
  }

  /// A folder section: a drop target (drag a list card onto it) + its cards.
  List<Widget> _folderSection(String folder, List<LocalList> inFolder,
      {bool isDefault = false}) {
    final scheme = Theme.of(context).colorScheme;
    return [
      DragTarget<LocalList>(
        onWillAcceptWithDetails: (details) => details.data.folder != folder,
        onAcceptWithDetails: (details) => widget.state
            .setListFolder(details.data.id, isDefault ? null : folder),
        builder: (context, candidates, rejected) {
          final highlighted = candidates.isNotEmpty;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: highlighted
                  ? scheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Icon(isDefault ? Icons.list_rounded : Icons.folder_outlined,
                  size: 16, color: scheme.outline),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isDefault ? "Vos listes" : folder,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.outline),
                ),
              ),
              Text("${inFolder.length}",
                  style: TextStyle(fontSize: 12, color: scheme.outline)),
              if (!isDefault) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _shareFolder(folder, inFolder),
                  child: Icon(Icons.share, size: 16, color: scheme.outline),
                ),
              ],
            ]),
          );
        },
      ),
      ...inFolder.map((list) => Draggable<LocalList>(
            data: list,
            feedback: SizedBox(
              width: 220,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(list.title),
                ),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.4, child: _listCard(list)),
            child: _listCard(list),
          )),
    ];
  }

  /// Share every list of a folder with a member (roles apply per list).
  Future<void> _shareFolder(String folder, List<LocalList> lists) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Partager le dossier « $folder »"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                "La personne sera ajoutée à ${lists.length} liste(s) du dossier."),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration:
                  InputDecoration(labelText: S.memberEmail),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler")),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(S.share)),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return;
    final state = widget.state;
    var ok = 0;
    for (final list in lists) {
      try {
        await state.api
            .post("/lists/${list.id}/members", {"email": result.trim()});
        ok++;
      } catch (_) {}
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              "$ok / ${lists.length} liste(s) partagées avec ${result.trim()}")));
    }
  }

  Iterable<String> _existingFoldersSync(List<LocalList> lists) sync* {
    final seen = <String>{};
    for (final l in lists) {
      final f = l.folder ?? "";
      if (f.isNotEmpty && seen.add(f)) yield f;
    }
  }

  Widget _listView(String header, List<LocalList> lists) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
          child: Text(header,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.outline)),
        ),
        ...lists.map((list) => _listCard(list)),
      ],
    );
  }

  Widget _listCard(LocalList list) {
    final state = widget.state;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
            color: _parseColor(list.color) ?? scheme.outlineVariant,
            width: _parseColor(list.color) != null ? 1.5 : 1),
      ),
      child: Column(
        children: [
      ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: _parseColor(list.color) ?? scheme.outline,
            shape: BoxShape.circle,
          ),
        ),
        title: Row(children: [
          if (list.pinned)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.push_pin,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary),
            ),
          // Sync state at a glance: local-only lists are flagged.
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
                list.localOnly
                    ? Icons.cloud_off_outlined
                    : Icons.cloud_done_outlined,
                size: 14,
                color: list.localOnly
                    ? Theme.of(context).colorScheme.outline
                    : Theme.of(context).colorScheme.primary),
          ),
          Flexible(
              child: Text(list.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
        ]),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Collapse the inline items (shown by default).
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(
                  _collapsed.contains(list.id)
                      ? Icons.expand_more
                      : Icons.expand_less,
                  size: 20),
              onPressed: () => setState(() {
                _collapsed.contains(list.id)
                    ? _collapsed.remove(list.id)
                    : _collapsed.add(list.id);
              }),
            ),
            PopupMenuButton<String>(
          onSelected: (action) {
            switch (action) {
              case "pin":
                state.pinList(list.id, !list.pinned);
                break;
              case "rename":
                _renameList(list);
                break;
              case "color":
                _pickColor(list);
                break;
              case "folder":
                _pickFolder(list);
                break;
              case "duplicate":
                state.duplicateList(list.id);
                break;
              case "sync":
                state.setListLocalOnly(list.id, !list.localOnly);
                break;
              case "share":
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ShareScreen(state: widget.state, listId: list.id),
                  ),
                );
                break;
              case "delete":
                _deleteList(list);
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: "pin",
              child: Row(children: [
                Icon(list.pinned ? Icons.push_pin_outlined : Icons.push_pin),
                const SizedBox(width: 12),
                Text(list.pinned ? S.unpin : S.pin),
              ]),
            ),
            PopupMenuItem(
              value: "rename",
              child: Row(children: [
                Icon(Icons.drive_file_rename_outline),
                SizedBox(width: 12),
                Text(S.rename),
              ]),
            ),
            PopupMenuItem(
              value: "color",
              child: Row(children: [
                Icon(Icons.palette_outlined,
                    color: _parseColor(list.color)),
                const SizedBox(width: 12),
                Text(S.color),
              ]),
            ),
            if (state.featureFolders)
              PopupMenuItem(
                value: "folder",
                child: Row(children: [
                  Icon(Icons.folder_outlined),
                  SizedBox(width: 12),
                  Text(S.folderEllipsis),
                ]),
              ),
            PopupMenuItem(
              value: "duplicate",
              child: Row(children: [
                Icon(Icons.content_copy),
                SizedBox(width: 12),
                Text(S.duplicate),
              ]),
            ),
            PopupMenuItem(
              value: "sync",
              child: Row(children: [
                Icon(list.localOnly
                    ? Icons.cloud_off_outlined
                    : Icons.cloud_done_outlined),
                const SizedBox(width: 12),
                Text(list.localOnly
                    ? "Activer la synchro"
                    : "Local uniquement"),
              ]),
            ),
            PopupMenuItem(
              value: "share",
              child: Row(children: [
                Icon(Icons.share),
                SizedBox(width: 12),
                Text(S.share),
              ]),
            ),
            PopupMenuItem(
              value: "delete",
              child: Row(children: [
                Icon(Icons.delete_outline),
                SizedBox(width: 12),
                Text(S.delete),
              ]),
            ),
          ],
            ),
          ],
        ),
        onTap: () =>
            Navigator.pushNamed(context, "/list", arguments: list.id),
      ),
          if (!_collapsed.contains(list.id)) _itemsPreview(list),
        ],
      ),
    );
  }

  /// Inline unchecked items on the home card (checkable directly).
  Widget _itemsPreview(LocalList list) {
    final state = widget.state;
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<LocalItem>>(
      future: state.db.uncheckedItemsOf(list.id),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        if (items.isEmpty) return const SizedBox.shrink();
        final shown = items.take(3).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: scheme.outlineVariant.withValues(alpha: 0.5)),
            for (final item in shown)
              InkWell(
                onTap: () => state.toggleItem(item.id, true),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  child: Row(
                    children: [
                      Icon(Icons.check_box_outline_blank,
                          size: 17, color: scheme.outline),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13.5))),
                      if (state.dueSuffix(item)
                          case final badge? when badge.isNotEmpty)
                        Text(badge,
                            style: TextStyle(
                                fontSize: 11.5, color: scheme.outline)),
                    ],
                  ),
                ),
              ),
            if (items.length > 3)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text("+${items.length - 3}",
                    style: TextStyle(fontSize: 12, color: scheme.outline)),
              ),
          ],
        );
      },
    );
  }
}

class _TemplateChoice {
  final String name;
  final bool isTemplate;
  const _TemplateChoice.empty() : name = "", isTemplate = false;
  const _TemplateChoice.template(this.name) : isTemplate = true;
}
