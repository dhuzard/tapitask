import "package:material_ui/material_ui.dart";

import "../state/app_state.dart";
import "../l10n/s.dart";

/// Réglages : chaque utilisateur active uniquement ce qu'il veut.
/// Design compact : sections plates, une ligne par réglage, aides en info-bulle.
class SettingsScreen extends StatefulWidget {
  final AppState state;
  const SettingsScreen({super.key, required this.state});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    widget.state.removeListener(_onChanged);
    super.dispose();
  }

  Future<void> _toggle(String key, bool value) async {
    widget.state.settings[key] = value;
    await widget.state.saveSettings();
  }

  // ---- petits composants compacts (pas de cartes, pas de bordures) ----

  Widget _header(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
        child: Text(title,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: Theme.of(context).colorScheme.primary)),
      );

  Widget _switchRow(String title, bool value, void Function(bool) onChanged,
          {String? info}) =>
      SizedBox(
        height: 44,
        child: Row(
          children: [
            Expanded(
                child: Text(title,
                    style: const TextStyle(fontSize: 14.5),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (info != null)
              Tooltip(
                message: info,
                preferBelow: false,
                child: Icon(Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.outline),
              ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      );

  Widget _tapRow(String title, String value, VoidCallback onTap) => SizedBox(
        height: 44,
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              Expanded(
                  child: Text(title,
                      style: const TextStyle(fontSize: 14.5),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.outline)),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right,
                  size: 18,
                  color: Theme.of(context).colorScheme.outline),
            ],
          ),
        ),
      );

  Widget _divider() => Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5));

  // ---- mots-clés ----

  static final _keywordValues = [
    "aujourd'hui", "demain", S.dayAfterTomorrow,
    "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche",
    "+1", "+2", "+3", "+7", "+14", "+30",
  ];

  Future<void> _removeKeyword(String key) async {
    widget.state.settings["due_keywords"] = {
      ...widget.state.dueKeywords,
    }..remove(key);
    await widget.state.saveSettings();
  }

  Future<void> _addKeyword() async {
    final controller = TextEditingController();
    String value = "demain";
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.newKeyword),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(labelText: S.keywordLabel),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: value,
              decoration: InputDecoration(labelText: S.dueDate),
              items: [
                for (final v in _keywordValues)
                  DropdownMenuItem(value: v, child: Text(v)),
              ],
              onChanged: (v) => value = v!,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(S.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(S.add)),
        ],
      ),
    );
    final key = controller.text.trim().toLowerCase();
    if (ok != true || key.isEmpty) return;
    widget.state.settings["due_keywords"] = {
      ...widget.state.dueKeywords,
      key: value,
    };
    await widget.state.saveSettings();
  }

  // ---- dialogues ----

  Future<void> _pickTheme() async {
    final s = widget.state;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(S.theme),
        children: [
          for (final (label, value) in [
            (S.themeSystem, "system"),
            (S.themeLight, "light"),
            (S.themeDark, "dark"),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, value),
              child: Text(label),
            ),
        ],
      ),
    );
    if (choice != null) {
      s.settings["theme"] = choice;
      await s.saveSettings();
      setState(() {});
    }
  }

  Future<void> _pickLanguage() async {
    final s = widget.state;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Langue / Language"),
        children: [
          for (final (label, value) in [
            ("Français", "fr"),
            ("English", "en"),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, value),
              child: Text(label),
            ),
        ],
      ),
    );
    if (choice != null) {
      s.settings["lang"] = choice;
      await s.saveSettings();
      setState(() {});
    }
  }

  Future<void> _pickInterval() async {
    final s = widget.state;
    final choice = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(S.syncDelay),
        children: [
          for (final (label, value) in [
            (S.every10s, 10),
            (S.every30s, 30),
            (S.everyMinute, 60),
            (S.every5min, 300),
            (S.pollOff, 0),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, value),
              child: Text(label),
            ),
        ],
      ),
    );
    if (choice != null) {
      s.settings["poll_interval"] = choice;
      await s.saveSettings();
      s.sync.applyPollInterval(choice);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    bool flag(String key, {bool dflt = false}) =>
        (s.settings[key] as bool?) ?? dflt;

    return Scaffold(
      appBar: AppBar(title: Text(S.settings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ---- Apparence ----
          _header(S.appearance),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _tapRow(S.theme, _themeLabel(s.settings["theme"] as String?),
                    _pickTheme),
                _divider(),
                _tapRow("Langue / Language",
                    s.settings["lang"] == "en" ? "English" : "Français",
                    _pickLanguage),
              ],
            ),
          ),

          // ---- Fonctionnalités ----
          _header(S.features),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _switchRow(S.folders, flag("folders", dflt: true),
                    (v) => _toggle("folders", v)),
                _divider(),
                _switchRow(S.alerts, flag("alerts", dflt: true),
                    (v) => _toggle("alerts", v),
                    info: S.alertsHelp),
                _divider(),
                _switchRow(S.templates, flag("templates", dflt: true),
                    (v) => _toggle("templates", v),
                    info: S.templatesHelp),
                _divider(),
                _switchRow(S.visibleActions, flag("visible_actions", dflt: true),
                    (v) => _toggle("visible_actions", v),
                    info: S.visibleActionsHelp),
              ],
            ),
          ),

          // ---- Volet & widget ----
          _header(S.compact),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _switchRow(S.compactDue, flag("compact_due", dflt: true),
                    (v) => _toggle("compact_due", v),
                    info: S.compactDueHelp),
                _divider(),
                _switchRow(S.openAppBtn, flag("flyout_open_button", dflt: true),
                    (v) => _toggle("flyout_open_button", v)),
                _divider(),
                _switchRow(S.startHidden, flag("start_hidden"),
                    (v) => _toggle("start_hidden", v)),
              ],
            ),
          ),

          // ---- Notifications ----
          _header(S.notifications),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _switchRow(S.inApp, flag("notify_app", dflt: true),
                    (v) => _toggle("notify_app", v)),
                _divider(),
                _switchRow(S.byEmail, flag("notify_email", dflt: true),
                    (v) => _toggle("notify_email", v),
                    info: S.byEmailHelp),
              ],
            ),
          ),

          // ---- Mots-clés d'échéance ----
          _header(S.dueKeywords),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final entry in s.dueKeywords.entries)
                      InputChip(
                        label: Text("${entry.key} → ${entry.value}"),
                        visualDensity: VisualDensity.compact,
                        onDeleted: () => _removeKeyword(entry.key),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: _addKeyword,
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(S.addKeyword),
                  ),
                ),
              ],
            ),
          ),

          // ---- Synchronisation ----
          _header(S.syncSection),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _tapRow(
                S.syncDelay,
                _intervalLabel(
                    (s.settings["poll_interval"] as num?)?.toInt() ?? 30),
                _pickInterval),
          ),

          // ---- Compte ----
          _header(S.account),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _tapRow(
                S.accountAndServer,
                s.api.baseUrl.isEmpty ? S.notConfigured : s.api.baseUrl,
                () => Navigator.pushNamed(context, "/login")),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _themeLabel(String? theme) {
    switch (theme) {
      case "light":
        return S.themeLight;
      case "dark":
        return S.themeDark;
      default:
        return S.themeSystem;
    }
  }

  String _intervalLabel(int seconds) {
    switch (seconds) {
      case 0:
        return S.pollOff;
      case 10:
        return S.every10s;
      case 60:
        return S.everyMinute;
      case 300:
        return S.every5min;
      default:
        return S.every30sShort;
    }
  }
}
