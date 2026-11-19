import "package:material_ui/material_ui.dart";

import "../l10n/s.dart";

/// Sélecteur d'échéance partagé (calendrier d'un item, zone d'ajout d'une
/// liste, dialogue « Nouvelle tâche » de l'accueil).

/// Résultat du sélecteur d'échéance : [date] null = échéance retirée.
class DueChoice {
  final DateTime? date;
  const DueChoice(this.date);
}

/// Raccourcis en un tap puis sélecteur date/heure complet.
/// Retourne null si annulé ; `DueChoice(null)` si l'échéance est retirée.
Future<DueChoice?> chooseDueDate(
    BuildContext context, String title, DateTime? current) async {
  final now = DateTime.now();
  final choice = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title:
          Text("${S.dueDate} — $title", style: const TextStyle(fontSize: 16)),
      children: [
        SimpleDialogOption(
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.today_outlined),
            title: Text(S.today),
          ),
          onPressed: () => Navigator.pop(context, "today"),
        ),
        SimpleDialogOption(
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.arrow_outward),
            title: Text(S.tomorrow),
          ),
          onPressed: () => Navigator.pop(context, "tomorrow"),
        ),
        SimpleDialogOption(
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.date_range_outlined),
            title: Text(S.inAWeek),
          ),
          onPressed: () => Navigator.pop(context, "week"),
        ),
        SimpleDialogOption(
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.calendar_month_outlined),
            title: Text(S.chooseDate),
          ),
          onPressed: () => Navigator.pop(context, "custom"),
        ),
        if (current != null)
          SimpleDialogOption(
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.event_busy),
              title: Text(S.removeDueDate),
            ),
            onPressed: () => Navigator.pop(context, "clear"),
          ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return null;
  switch (choice) {
    case "today":
      return DueChoice(DateTime(now.year, now.month, now.day, 18));
    case "tomorrow":
      return DueChoice(DateTime(now.year, now.month, now.day + 1, 9));
    case "week":
      final d = now.add(const Duration(days: 7));
      return DueChoice(DateTime(d.year, d.month, d.day, 9));
    case "clear":
      return const DueChoice(null);
  }
  final picked = await showDatePicker(
    context: context,
    initialDate: current ?? now,
    firstDate: now.subtract(const Duration(days: 365)),
    lastDate: now.add(const Duration(days: 365 * 3)),
    helpText: S.dueDate,
  );
  if (picked == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(current ?? now),
  );
  return DueChoice(DateTime(
    picked.year,
    picked.month,
    picked.day,
    time?.hour ?? 0,
    time?.minute ?? 0,
  ));
}

/// Libellé court d'une échéance (« demain 09:00 », « 24/11 »).
String dueLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = day.difference(today).inDays;
  final hh = d.hour.toString().padLeft(2, "0");
  final mm = d.minute.toString().padLeft(2, "0");
  switch (diff) {
    case 0:
      return "aujourd'hui ${d.hour == 0 && d.minute == 0 ? "" : "$hh:$mm"}"
          .trim();
    case 1:
      return "demain ${d.hour == 0 && d.minute == 0 ? "" : "$hh:$mm"}".trim();
    case -1:
      return "hier (en retard)";
    default:
      return "${day.day}/${day.month}${d.hour == 0 && d.minute == 0 ? "" : " $hh:$mm"}";
  }
}
