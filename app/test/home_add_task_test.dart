import "package:drift/drift.dart" hide isNull;
import "package:drift/native.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:tapitask/data/database.dart";
import "package:tapitask/l10n/s.dart";
import "package:tapitask/state/app_state.dart";
import "package:tapitask/ui/home_screen.dart";

void main() {
  testWidgets("＋ de l'accueil : nouvelle tâche avec liste et échéance",
      (tester) async {
    S.setLocale("fr");
    final db = AppDb.forTesting(NativeDatabase.memory());
    final state = AppState(db: db);
    for (final (id, title) in [("l1", "Maison"), ("l2", "Travail")]) {
      await db.upsertList(LocalListsCompanion(
        id: Value(id),
        title: Value(title),
        ownerId: const Value(""),
        updatedAt: Value(DateTime.now().toUtc()),
        dirty: const Value(false),
        localOnly: const Value(true),
      ));
    }

    await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate],
        home: HomeScreen(state: state)));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text(S.newTask), findsOneWidget);
    expect(find.text(S.newList), findsOneWidget);

    await tester.tap(find.text(S.newTask));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.byType(TextField)),
        findsWidgets);
    expect(
        find.descendant(
            of: dialog, matching: find.byType(DropdownButtonFormField<String>)),
        findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.text(S.setDueDate)),
        findsOneWidget);

    // Échéance « Demain » via le sélecteur partagé.
    await tester.tap(find.text(S.setDueDate));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.tomorrow));
    await tester.pumpAndSettle();
    expect(find.descendant(of: dialog, matching: find.textContaining("demain")),
        findsOneWidget);

    await tester.tap(find.text(S.cancel));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
    await db.close();
  });
}
