import "package:drift/drift.dart" hide isNull;
import "package:drift/native.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:shared_preferences/shared_preferences.dart";
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

  Future<AppDb> twoLists() async {
    final db = AppDb.forTesting(NativeDatabase.memory());
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
    return db;
  }

  test("liste cible : défaut > dernière utilisée > épinglée > première", () {
    final state = AppState(db: AppDb.forTesting(NativeDatabase.memory()));
    final lists = [(id: "a"), (id: "b"), (id: "c")];
    expect(state.addTargetAmong(lists), "a");
    expect(state.addTargetAmong(lists, pinned: [(id: "c")]), "c");
    expect(state.addTargetAmong(lists, fallback: "b", pinned: [(id: "c")]),
        "b");
    state.defaultListId = "c";
    expect(state.addTargetAmong(lists, fallback: "b"), "c");
    // Liste par défaut supprimée : on retombe sur le reste.
    state.defaultListId = "zz";
    expect(state.addTargetAmong(lists, fallback: "b"), "b");
    expect(state.addTargetAmong([]), isNull);
  });

  testWidgets("liste par défaut : présélectionnée dans « Nouvelle tâche »",
      (tester) async {
    S.setLocale("fr");
    SharedPreferences.setMockInitialValues({});
    final db = await twoLists();
    final state = AppState(db: db);
    await state.setDefaultList("l2");

    await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate],
        home: HomeScreen(state: state)));
    await tester.pumpAndSettle();
    // ★ sur la carte de la liste par défaut.
    expect(find.byIcon(Icons.star), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.newTask));
    await tester.pumpAndSettle();

    final field = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>));
    expect(field.initialValue, "l2");
    expect(
        (await SharedPreferences.getInstance()).getString("default_list_id"),
        "l2");

    await tester.tap(find.text(S.cancel));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await db.close();
  });
}
