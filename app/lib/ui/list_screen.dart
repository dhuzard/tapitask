import "dart:io" show Platform;

import "package:material_ui/material_ui.dart";
import "package:flutter/services.dart";

import "../data/database.dart";
import "../state/app_state.dart";
import "due_picker.dart";
import "share_screen.dart";
import "../l10n/s.dart";

class ListScreen extends StatefulWidget {
  final AppState state;
  final String listId;
  const ListScreen({super.key, required this.state, required this.listId});

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  final _quickAdd = TextEditingController();
  String _recurrence = "none";

  /// Échéance choisie pour le prochain ajout (puce « Échéance » de la zone
  /// d'ajout). Null = aucune (les mots-clés « demain »… restent actifs).
  DateTime? _newDue;
  String? _parentIdForNextAdd;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  /// Switch directly to another list without going back to the home screen.
  void _switchList(String listId) {
    if (listId == widget.listId) return;
    Navigator.pushReplacementNamed(context, "/list", arguments: listId);
  }

  @override
  void dispose() {
    widget.state.removeListener(_onChanged);
    super.dispose();
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
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler")),
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

  Future<void> _pickColor(LocalList list) async {
    const palette = [
      null,
      "#00897B",
      "#43A047",
      "#1E88E5",
      "#5E35B1",
      "#D32F2F",
      "#F4511E",
      "#F6BF26",
      "#6D4C41",
      "#546E7A",
      "#37474F",
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
                    color: hex == null
                        ? null
                        : Color(int.parse(hex.replaceFirst("#", "0xFF"))),
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
                  backgroundColor:
                      Theme.of(context).colorScheme.errorContainer),
              onPressed: () => Navigator.pop(context, true),
              label: Text(S.delete)),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.state.deleteList(list.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final scheme = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () =>
            widget.state.undoLast(),
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: FutureBuilder<List<LocalList>>(
            future: state.db.visibleLists(),
            builder: (context, snapshot) {
              final lists = snapshot.data ?? [];
              final index = lists.indexWhere((l) => l.id == widget.listId);
              final list = index >= 0 ? lists[index] : null;
              // Le sélecteur ◀ ▾ ▶ n'apparaît qu'à partir de 2 listes actives.
              if (lists.length < 2) {
                return Text(list?.title ?? "Liste",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: list?.color == null
                            ? scheme.onSurface
                            : Color(int.parse(
                                list!.color!.replaceFirst("#", "0xFF"))),
                        fontWeight: FontWeight.w600));
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: S.prevList,
                    icon: const Icon(Icons.chevron_left, size: 22),
                    onPressed: index > 0
                        ? () => _switchList(lists[index - 1].id)
                        : null,
                  ),
                  Flexible(
                    child: PopupMenuButton<String>(
                      tooltip: S.switchList,
                      initialValue: widget.listId,
                      onSelected: _switchList,
                      itemBuilder: (context) => [
                        for (final l in lists)
                          PopupMenuItem(
                            value: l.id,
                            child: Row(children: [
                              if (l.id == widget.listId)
                                const Icon(Icons.check, size: 16)
                              else
                                const SizedBox(width: 16),
                              const SizedBox(width: 8),
                              Flexible(
                                  child: Text(l.title,
                                      overflow: TextOverflow.ellipsis)),
                            ]),
                          ),
                      ],
                      // Le ▾ reste visible : seul le titre est tronqué.
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              list?.title ?? "Liste",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: list?.color == null
                                      ? scheme.onSurface
                                      : Color(int.parse(list!.color!
                                          .replaceFirst("#", "0xFF"))),
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 22),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: S.nextList,
                    icon: const Icon(Icons.chevron_right, size: 22),
                    onPressed: index >= 0 && index < lists.length - 1
                        ? () => _switchList(lists[index + 1].id)
                        : null,
                  ),
                ],
              );
            },
          ),
          actions: [
            PopupMenuButton<String>(
              onSelected: (action) async {
                final list = await _list();
                if (list == null) return;
                if (action == "rename") await _renameList(list);
                if (action == "delete") await _deleteList(list);
                if (action == "sync") {
                  await widget.state.setListLocalOnly(list.id, !list.localOnly);
                }
                if (action == "color") await _pickColor(list);
                if (action == "clean") await _confirmPurgeDone();
                if (action == "share") await _openShare();
              if (action == "default") {
                await widget.state.setDefaultList(
                    widget.state.defaultListId == list.id ? null : list.id);
              }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: "default",
                  child: Row(children: [
                    Icon(widget.state.defaultListId == widget.listId
                        ? Icons.star
                        : Icons.star_border),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(widget.state.defaultListId == widget.listId
                          ? S.unsetDefaultList
                          : S.setDefaultList),
                    ),
                  ]),
                ),
                PopupMenuItem(
                  value: "share",
                  child: Row(children: [
                    const Icon(Icons.share),
                    const SizedBox(width: 12),
                    Text(S.share),
                  ]),
                ),
                PopupMenuItem(
                  value: "clean",
                  child: Row(children: [
                    const Icon(Icons.delete_sweep_outlined),
                    const SizedBox(width: 12),
                    Text(S.cleanDone),
                  ]),
                ),
                PopupMenuItem(
                  value: "color",
                  child: Row(children: [
                    Icon(Icons.palette_outlined),
                    SizedBox(width: 12),
                    Text(S.color),
                  ]),
                ),
                PopupMenuItem(
                  value: "sync",
                  child: FutureBuilder<LocalList?>(
                    future: _list(),
                    builder: (context, snap) => Row(children: [
                      Icon(snap.data?.localOnly == true
                          ? Icons.cloud_off_outlined
                          : Icons.cloud_done_outlined),
                      const SizedBox(width: 12),
                      Text(snap.data?.localOnly == true
                          ? "Activer la synchro"
                          : "Local uniquement"),
                    ]),
                  ),
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
        body: Column(
          children: [
            Card(
              elevation: 0,
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Column(
                  children: [
                    TextField(
                      controller: _quickAdd,
                      autofocus: Platform.isWindows,
                      maxLines: 3,
                      minLines: 1,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: _parentIdForNextAdd != null
                            ? S.subtaskHint
                            : "Ajouter… (collez plusieurs lignes = plusieurs items)",
                        suffixIcon: IconButton(
                          icon: Icon(Icons.add_circle, color: scheme.primary),
                          onPressed: _submit,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 40,
                      child: Row(
                        children: [
                          if (_parentIdForNextAdd != null)
                            ActionChip(
                              label: Text(S.subtask),
                              avatar: const Icon(Icons.subdirectory_arrow_right,
                                  size: 18),
                              onPressed: () =>
                                  setState(() => _parentIdForNextAdd = null),
                            ),
                          // Expanded + Align : la puce prend sa taille naturelle
                          // et ne se tronque que si la place manque.
                          Expanded(
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: InputChip(
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                avatar: Icon(
                                    _newDue == null
                                        ? Icons.event_outlined
                                        : Icons.event,
                                    size: 18,
                                    color: _newDue == null
                                        ? scheme.outline
                                        : scheme.primary),
                                label: Text(
                                  _newDue == null
                                      ? S.dueDate
                                      : dueLabel(_newDue!),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                tooltip: S.setDueDate,
                                onPressed: _pickNewDue,
                                onDeleted: _newDue == null
                                    ? null
                                    : () => setState(() => _newDue = null),
                              ),
                            ),
                          ),
                          // Flexible + isExpanded : le libellé se tronque au
                          // lieu de déborder (petits écrans, grande police).
                          Flexible(
                            child: DropdownButton<String>(
                              value: _recurrence,
                              underline: const SizedBox.shrink(),
                              isDense: true,
                              isExpanded: true,
                              alignment: AlignmentDirectional.centerEnd,
                              items: [
                                for (final r in const [
                                  "none",
                                  "daily",
                                  "weekly",
                                  "monthly",
                                ])
                                  DropdownMenuItem(
                                    value: r,
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: Text(
                                      switch (r) {
                                        "daily" => S.daily,
                                        "weekly" => S.weekly,
                                        "monthly" => S.monthly,
                                        _ => S.noRepeat,
                                      },
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _recurrence = v ?? "none"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder(
                stream: state.db.watchItemsOf(widget.listId),
                builder: (context, snapshot) {
                  final items = snapshot.data ?? [];
                  final top = items.where((i) => i.parentId == null).toList();
                  if (top.isEmpty) {
                    return Center(
                      child: Text(S.nothingToDoAdd,
                          style: TextStyle(color: scheme.outline)),
                    );
                  }
                  return ReorderableListView.builder(
                    buildDefaultDragHandles: true,
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                    itemCount: top.length,
                    onReorderItem: (oldIndex, newIndex) async {
                      // onReorderItem fournit déjà le newIndex ajusté au retrait
                      // de l'élément déplacé (plus de décrément manuel).
                      final moved = top.removeAt(oldIndex);
                      top.insert(newIndex, moved);
                      for (var pos = 0; pos < top.length; pos++) {
                        await state.reorderItem(top[pos].id, pos);
                      }
                    },
                    itemBuilder: (context, i) {
                      final item = top[i];
                      final children =
                          items.where((c) => c.parentId == item.id).toList();
                      return Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: scheme.errorContainer,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          child: Icon(Icons.delete_outline,
                              color: scheme.onErrorContainer),
                        ),
                        onDismissed: (_) async {
                          final messenger = ScaffoldMessenger.of(context);
                          final undo = await state.deleteItem(item.id);
                          if (!mounted) return;
                          {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text("« ${item.label} » supprimé"),
                                action: SnackBarAction(
                                  label: "ANNULER",
                                  onPressed: () => undo(),
                                ),
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          }
                        },
                        child: Column(
                          key: ValueKey("col-${item.id}"),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onLongPress: () => _itemActions(item),
                              child: CheckboxListTile(
                                dense: true,
                                value: item.done,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(
                                  item.label,
                                  style: TextStyle(
                                    decoration: item.done
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: item.done ? scheme.outline : null,
                                  ),
                                ),
                                subtitle: _itemSubtitle(item),
                                secondary: state.visibleActions
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: item.dueDate == null
                                                ? S.setDueDate
                                                : S.editDueDate,
                                            icon: Icon(
                                              item.dueDate == null
                                                  ? Icons.event_outlined
                                                  : Icons.event,
                                              size: 20,
                                              color: item.dueDate == null
                                                  ? scheme.outline
                                                  : scheme.primary,
                                            ),
                                            onPressed: () => _pickDueDate(item),
                                          ),
                                          IconButton(
                                            tooltip: S.itemActions,
                                            icon: Icon(Icons.more_vert,
                                                size: 20,
                                                color: scheme.outline),
                                            onPressed: () => _itemActions(item),
                                          ),
                                        ],
                                      )
                                    : null,
                                onChanged: (v) =>
                                    state.toggleItem(item.id, v ?? false),
                              ),
                            ),
                            for (final child in children)
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 32, bottom: 2),
                                child: CheckboxListTile(
                                  dense: true,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  value: child.done,
                                  title: Text(child.label,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: child.done
                                              ? scheme.outline
                                              : null)),
                                  onChanged: (v) =>
                                      state.toggleItem(child.id, v ?? false),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _itemActions(LocalItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.subdirectory_arrow_right),
            title: Text(S.addSubtask),
            onTap: () => Navigator.pop(context, "subtask"),
          ),
          ListTile(
            leading: Icon(Icons.event,
                color: item.dueDate != null
                    ? Theme.of(context).colorScheme.primary
                    : null),
            title: Text(item.dueDate == null
                ? S.setDueDate
                : "${S.dueDate} : ${dueLabel(item.dueDate!)}"),
            onTap: () => Navigator.pop(context, "due"),
          ),
          ListTile(
            leading: Icon(Icons.notes_outlined,
                color: item.notes != null
                    ? Theme.of(context).colorScheme.primary
                    : null),
            title: Text(S.note),
            onTap: () => Navigator.pop(context, "notes"),
          ),
        ]),
      ),
    );
    switch (action) {
      case "subtask":
        setState(() => _parentIdForNextAdd = item.id);
        break;
      case "due":
        await _pickDueDate(item);
        break;
      case "notes":
        await _editNotes(item);
        break;
    }
  }

  /// Échéance ergonomique : raccourcis en un tap, puis sélecteur
  /// date/heure complet si besoin. Aussi accessible via l'icône
  /// calendrier sur chaque item (pas besoin d'un appui long).
  Future<void> _openShare() async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShareScreen(state: widget.state, listId: widget.listId),
      ),
    );
  }

  /// Confirme puis supprime les items cochés de la liste (menu ⋮).
  Future<void> _confirmPurgeDone() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.cleanDoneConfirm),
        content: Text(S.cleanDoneBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Annuler")),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(S.clean)),
        ],
      ),
    );
    if (confirmed == true) await widget.state.purgeDone(widget.listId);
  }

  Future<void> _pickDueDate(LocalItem item) async {
    final choice = await chooseDueDate(context, item.label, item.dueDate);
    if (choice == null || !mounted) return;
    if (choice.date == null) {
      await widget.state.setItemDetails(item.id, clearDue: true);
    } else {
      await widget.state.setItemDetails(item.id, dueDate: choice.date);
    }
  }

  /// Échéance de la tâche en cours de saisie (zone d'ajout).
  Future<void> _pickNewDue() async {
    final title = _quickAdd.text.trim().split("\n").first;
    final choice = await chooseDueDate(
        context, title.isEmpty ? S.dueDate : title, _newDue);
    if (choice == null || !mounted) return;
    setState(() => _newDue = choice.date);
  }

  Future<void> _editNotes(LocalItem item) async {
    final controller = TextEditingController(text: item.notes ?? "");
    final notes = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.note),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler")),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(S.ok)),
        ],
      ),
    );
    if (notes != null) {
      await widget.state.setItemDetails(item.id, notes: notes);
    }
  }

  Future<LocalList?> _list() async {
    try {
      return await (widget.state.db.select(widget.state.db.localLists)
            ..where((l) => l.id.equals(widget.listId)))
          .getSingle();
    } catch (_) {
      return null;
    }
  }

  Widget? _itemSubtitle(LocalItem item) {
    final parts = <Widget>[];
    if (item.dueDate != null) {
      final overdue = item.dueDate!.isBefore(DateTime.now());
      parts.add(Text((overdue ? "⚠ " : "📅 ") + dueLabel(item.dueDate!),
          style: TextStyle(
              fontSize: 12,
              color: overdue ? Theme.of(context).colorScheme.error : null)));
    }
    if (item.recurrence != "none") {
      parts.add(Text("↻ ${_recurrenceLabel(item.recurrence)}",
          style: const TextStyle(fontSize: 12)));
    }
    if (item.notes != null && item.notes!.isNotEmpty) {
      parts.add(Text("📝 ${item.notes!}",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12)));
    }
    if (parts.length == 1) return parts.first;
    if (parts.isEmpty) return null;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: parts);
  }

  String _recurrenceLabel(String r) => switch (r) {
        "daily" => "quotidien",
        "weekly" => "hebdomadaire",
        "monthly" => "mensuel",
        _ => "",
      };

  void _submit() async {
    final text = _quickAdd.text;
    if (text.trim().isEmpty) return;
    _quickAdd.clear();
    await widget.state.addQuickItems(
      widget.listId,
      text,
      parentId: _parentIdForNextAdd,
      recurrence: _recurrence,
      dueDate: _newDue,
    );
    setState(() {
      _parentIdForNextAdd = null;
      _newDue = null;
    });
  }
}
