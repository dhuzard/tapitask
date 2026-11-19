/// Tapitask — chaînes UI centralisées.
///
/// Toutes les chaînes visibles passent par cette classe : ajouter une
/// langue = ajouter une map (ex. `_en`) et renseigner `locale`.
/// Les écrans n'utilisent JAMAIS de littéral en dur.
library;

class S {
  /// Langue courante ("fr" par défaut). Brancher sur un réglage
  /// utilisateur synchronisé le jour où une 2e langue arrive.
  static String locale = "fr";

  static const _fr = <String, String>{
    // --- générique ---
    "ok": "OK",
    "cancel": "Annuler",
    "apply": "Appliquer",
    "close": "Fermer",
    "add": "Ajouter",
    "create": "Créer",
    "delete": "Supprimer",
    "rename": "Renommer",
    "share": "Partager",
    "later": "Plus tard",
    "none": "Aucun",
    "remove": "Retirer",
    "undo": "ANNULER",
    "today": "Aujourd'hui",
    "tomorrow": "Demain",
    "todayLabel": "aujourd'hui",
    "tomorrowLabel": "demain",
    "dayAfterTomorrow": "après-demain",
    "yesterdayOverdue": "hier (en retard)",
    "inAWeek": "Dans une semaine",
    "chooseDate": "Choisir une date…",
    "overdueSuffix": "  •  en retard",
    // --- navigation / écrans ---
    "appTitle": "Tapitask",
    "settings": "Réglages",
    "account": "Compte",
    "accountAndServer": "Compte & serveur",
    "administration": "Administration",
    "todoAll": "À faire",
    "todoAllTooltip": "À faire : tous les items non cochés",
    "newList": "Nouvelle liste",
    "newTask": "Nouvelle tâche",
    "setDefaultList": "Liste par défaut (cet appareil)",
    "unsetDefaultList": "Ne plus être la liste par défaut",
    "defaultList": "Liste par défaut sur cet appareil",
    "newTaskHint": "Que faut-il faire ? (1 ligne = 1 tâche)",
    "emptyList": "Liste vide",
    "listTitleFallback": "Liste",
    "noList": "Aucune liste",
    "createOneBelow": "Créez-en une avec le bouton ci-dessous",
    "yourLists": "Vos listes",
    "search": "Rechercher (Ctrl+F)",
    "searchHint": "Rechercher dans toutes les listes…",
    "searchMinChars": "Tape au moins 2 caractères…",
    "noResult": "Aucun résultat",
    // --- connexion ---
    "login": "Se connecter",
    "createAccount": "Créer un compte",
    "haveAccount": "J'ai déjà un compte",
    "noAccount": "Je n'ai pas de compte",
    "serverUrl": "URL du serveur",
    "email": "Email",
    "password": "Mot de passe",
    "newPassword": "Nouveau mot de passe",
    "totpCode": "Code 2FA (si activé)",
    "haveInviteCode": "J'ai un code d'invitation",
    "inviteByCode": "Invitation par code",
    "pasteCode": "Collez le code reçu",
    "codeFromEmail": "Code reçu par email",
    "verifyEmail": "Vérifier mon email",
    "emailVerified": "Email vérifié — tu peux te connecter ✔",
    "emailOptional": "facultatif",
    "notConfigured": "Non configuré",
    "emailVerifiedShort": "Email vérifié",
    // --- listes / items ---
    "nothingToDo": "Rien à faire",
    "nothingToDoAdd": "Rien à faire — ajoutez un item !",
    "nothingToday": "Rien de prévu aujourd'hui",
    "allDone": "Tout est fait !",
    "addMultiline": "Ajouter… (collez plusieurs lignes = plusieurs items)",
    "addMultilineShort": "Ajouter… (multi-lignes = multi-items)",
    "addSubtask": "Ajouter une sous-tâche",
    "subtask": "Sous-tâche",
    "subtaskHint": "Sous-tâche… (multi-lignes = multi-items)",
    "setDueDate": "Définir une échéance",
    "editDueDate": "Modifier l'échéance",
    "dueDate": "Échéance",
    "removeDueDate": "Retirer l'échéance",
    "dueDates": "Échéances",
    "itemActions": "Actions de l'item",
    "note": "Note",
    "noRepeat": "Sans répétition",
    "addButton": "＋ Ajouter",
    "deleteAction": "Supprimer",
    "openAction": "Ouvrir",
    "daily": "Quotidien",
    "weekly": "Hebdomadaire",
    "monthly": "Mensuel",
    "dailyLabel": "quotidien",
    "weeklyLabel": "hebdomadaire",
    "monthlyLabel": "mensuel",
    "cleanDone": "Nettoyer les items cochés",
    "cleanDoneConfirm": "Nettoyer les cochés ?",
    "cleanDoneBody": "Les items cochés seront archivés (suppression douce).",
    "clean": "Nettoyer",
    "renameList": "Renommer la liste",
    "listColor": "Couleur de la liste",
    "color": "Couleur…",
    "duplicate": "Dupliquer",
    "deleteListConfirm": "Supprimer cette liste ?",
    "deleteListBody": "La liste sera supprimée pour tous les membres. Cette action est définitive.",
    "localOnly": "Local uniquement",
    "itemDeleted": "item supprimé",
    // --- dossiers ---
    "folders": "Dossiers",
    "folder": "Dossier",
    "folderEllipsis": "Dossier…",
    "folderName": "Nom du dossier",
    "groupByFolder": "Regrouper les listes par dossier",
    "shareFolder": "Partager le dossier",
    // --- partage ---
    "shareList": "Partager la liste",
    "members": "Membres",
    "noMembers": "Aucun membre partagé pour l'instant.",
    "addMemberByEmail": "Ajouter directement par email",
    "memberEmail": "Email du membre",
    "addMember": "Ajouter le membre",
    "inviteCode": "Code d'invitation",
    "generateCode": "Générer un code",
    "generateCodeHelp": "Génère un code valable 48h. La personne le colle dans son app (écran de connexion → « J'ai un code d'invitation »).",
    "codeCopied": "Code copié",
    "listAdded": "Liste partagée ajoutée ✔",
    "roleOwner": "propriétaire",
    "roleEditor": "editor",
    "roleViewer": "viewer",
    "invitationsSent": "Invitations envoyées",
    // --- réglages ---
    "features": "Fonctionnalités",
    "featuresHelp": "Activez uniquement ce dont vous avez besoin — l'interface reste minimale tant que tout est décoché.",
    "alerts": "Alertes",
    "alertsHelp": "Notification pour les items dus aujourd'hui",
    "alertsAppHelp": "Alerte des items dus aujourd'hui à l'ouverture",
    "templates": "Modèles",
    "templatesHelp": "Modèles de listes prêtes à l'emploi",
    "dueDatesHelp": "Dates d'échéance sur les items, vue « Aujourd'hui »",
    "visibleActions": "Actions visibles sur les items",
    "visibleActionsHelp": "Icônes échéance/actions sur chaque item ; sinon appui long",
    "dueKeywords": "Mots-clés d'échéance",
    "dueKeywordsHelp": "Vos raccourcis pour l'ajout rapide : tapez le mot-clé dans la barre d'ajout, il devient une échéance. Ex. « j+7 » → +7 jours, « réunion » → lundi.",
    "addKeyword": "Ajouter un mot-clé…",
    "newKeyword": "Nouveau mot-clé d'échéance",
    "keywordLabel": "Mot-clé (ex. j+7, réunion, next week)",
    "compact": "Volet & widget",
    "compactHelp": "Choisissez les fonctions visibles dans les surfaces compactes (volet Windows, widget Android).",
    "compactDue": "Échéances affichées",
    "compactDueHelp": "Badge 📅 sur les items du volet",
    "compactDelete": "Poubelle au survol",
    "compactDeleteHelp": "Bouton supprimer sur chaque item du volet",
    "notifications": "Notifications",
    "inApp": "Dans l'application",
    "byEmail": "Par email",
    "byEmailHelp": "Invitations, partages de listes (envoyés par le serveur)",
    "syncSection": "Synchronisation",
    "refreshDelay": "Délai de rafraîchissement",
    "syncDelay": "Délai de synchronisation",
    "enableSync": "Activer la synchro",
    "appearance": "Apparence",
    "theme": "Thème",
    "themeSystem": "Système",
    "themeLight": "Clair",
    "themeDark": "Sombre",
    "every30s": "Toutes les 30 s (défaut)",
    "every30sShort": "Toutes les 30 s",
    "every10s": "Toutes les 10 s",
    "everyMinute": "Chaque minute",
    "every5min": "Toutes les 5 min",
    "pollOff": "Désactivé (temps réel uniquement)",
    // --- volet tray ---
    "flyoutClose": "Fermer le volet",
    "quickPanel": "Volet rapide",
    "quit": "Quitter",
    "openApp": "Ouvrir l'application",
    "pinAlwaysVisible": "Toujours visible (épinglé)",
    "pinEnable": "Épingler : toujours visible",
    "pin": "Épingler",
    "unpin": "Détacher",
    "openAppBtn": "Bouton « Ouvrir l'app » du volet",
    "startHidden": "Démarrer dans la barre des tâches",
    "noPinnedList": "Aucune liste épinglée",
    "pinListsHelp": "Épinglez des listes dans l'application pour les voir ici.",
    "prevList": "Liste précédente",
    "nextList": "Liste suivante",
    "switchList": "Changer de liste",
    // --- admin ---
    "admin": "admin",
    "promoteAdmin": "Promouvoir admin",
    "demoteAdmin": "Retirer le rôle admin",
    "activate": "Réactiver",
    "deactivate": "Désactiver",
    "active": "actif",
    "disabled": "désactivé",
    "resetPassword": "Réinitialiser le mot de passe",
    // --- récurrence / dates (libellés) ---
    "monday": "lundi",
    "tuesday": "mardi",
    "wednesday": "mercredi",
    "thursday": "jeudi",
    "friday": "vendredi",
    "saturday": "samedi",
    "sunday": "dimanche",
  };

  /// English translation (partial → complete). Adding a language = adding
  /// a map here and a case in [t].
  static const _en = <String, String>{
    "ok": "OK",
    "cancel": "Cancel",
    "apply": "Apply",
    "close": "Close",
    "add": "Add",
    "create": "Create",
    "delete": "Delete",
    "rename": "Rename",
    "share": "Share",
    "later": "Later",
    "none": "None",
    "remove": "Remove",
    "undo": "UNDO",
    "today": "Today",
    "tomorrow": "Tomorrow",
    "todayLabel": "today",
    "tomorrowLabel": "tomorrow",
    "dayAfterTomorrow": "day after tomorrow",
    "yesterdayOverdue": "yesterday (overdue)",
    "inAWeek": "In a week",
    "chooseDate": "Pick a date…",
    "overdueSuffix": "  •  overdue",
    "appTitle": "Tapitask",
    "settings": "Settings",
    "account": "Account",
    "accountAndServer": "Account & server",
    "administration": "Administration",
    "todoAll": "To do",
    "todoAllTooltip": "To do: all unchecked items",
    "newList": "New list",
    "newTask": "New task",
    "setDefaultList": "Default list (this device)",
    "unsetDefaultList": "Stop being the default list",
    "defaultList": "Default list on this device",
    "newTaskHint": "What needs doing? (1 line = 1 task)",
    "emptyList": "Empty list",
    "listTitleFallback": "List",
    "noList": "No list",
    "createOneBelow": "Create one with the button below",
    "yourLists": "Your lists",
    "search": "Search (Ctrl+F)",
    "searchHint": "Search all lists…",
    "searchMinChars": "Type at least 2 characters…",
    "noResult": "No result",
    "login": "Sign in",
    "createAccount": "Create an account",
    "haveAccount": "I already have an account",
    "noAccount": "I don't have an account",
    "serverUrl": "Server URL",
    "email": "Email",
    "password": "Password",
    "newPassword": "New password",
    "totpCode": "2FA code (if enabled)",
    "haveInviteCode": "I have an invite code",
    "inviteByCode": "Invite by code",
    "pasteCode": "Paste the code you received",
    "codeFromEmail": "Code received by email",
    "verifyEmail": "Verify my email",
    "emailVerified": "Email verified — you can sign in ✔",
    "emailOptional": "optional",
    "notConfigured": "Not configured",
    "emailVerifiedShort": "Email verified",
    "nothingToDo": "Nothing to do",
    "nothingToDoAdd": "Nothing to do — add an item!",
    "nothingToday": "Nothing due today",
    "allDone": "All done!",
    "addMultiline": "Add… (paste several lines = several items)",
    "addMultilineShort": "Add… (multi-line = multi-items)",
    "addSubtask": "Add a subtask",
    "subtask": "Subtask",
    "subtaskHint": "Subtask… (multi-line = multi-items)",
    "setDueDate": "Set a due date",
    "editDueDate": "Edit due date",
    "dueDate": "Due date",
    "removeDueDate": "Remove due date",
    "dueDates": "Due dates",
    "itemActions": "Item actions",
    "note": "Note",
    "noRepeat": "No repeat",
    "daily": "Daily",
    "weekly": "Weekly",
    "monthly": "Monthly",
    "dailyLabel": "daily",
    "weeklyLabel": "weekly",
    "monthlyLabel": "monthly",
    "cleanDone": "Clean checked items",
    "cleanDoneConfirm": "Clean checked items?",
    "cleanDoneBody": "Checked items will be archived (soft delete).",
    "clean": "Clean",
    "renameList": "Rename the list",
    "listColor": "List color",
    "color": "Color…",
    "duplicate": "Duplicate",
    "deleteListConfirm": "Delete this list?",
    "deleteListBody": "The list will be deleted for every member. This cannot be undone.",
    "localOnly": "Local only",
    "itemDeleted": "deleted",
    "folders": "Folders",
    "folder": "Folder",
    "folderEllipsis": "Folder…",
    "folderName": "Folder name",
    "groupByFolder": "Group lists by folder",
    "shareFolder": "Share folder",
    "shareList": "Share the list",
    "members": "Members",
    "noMembers": "No member shared yet.",
    "addMemberByEmail": "Add directly by email",
    "memberEmail": "Member email",
    "addMember": "Add member",
    "inviteCode": "Invite code",
    "generateCode": "Generate a code",
    "generateCodeHelp": "Generates a code valid for 48h. The person pastes it in their app (login screen → “I have an invite code”).",
    "codeCopied": "Code copied",
    "listAdded": "Shared list added ✔",
    "roleOwner": "owner",
    "roleEditor": "editor",
    "roleViewer": "viewer",
    "invitationsSent": "Invitations sent",
    "features": "Features",
    "featuresHelp": "Enable only what you need — the interface stays minimal while everything is off.",
    "alerts": "Alerts",
    "alertsHelp": "Notification for items due today",
    "alertsAppHelp": "Alert for items due today on open",
    "templates": "Templates",
    "templatesHelp": "Ready-made list templates",
    "dueDatesHelp": "Due dates on items, “Today” view",
    "visibleActions": "Visible actions on items",
    "visibleActionsHelp": "Due date/action icons on each item; otherwise long-press",
    "dueKeywords": "Due-date keywords",
    "dueKeywordsHelp": "Your quick-add shortcuts: type the keyword in the add bar and it becomes a due date. E.g. “j+7” → +7 days, “meeting” → Monday.",
    "addKeyword": "Add a keyword…",
    "newKeyword": "New due-date keyword",
    "keywordLabel": "Keyword (e.g. j+7, meeting, next week)",
    "compact": "Flyout & widget",
    "compactHelp": "Choose the functions visible in compact surfaces (Windows flyout, Android widget).",
    "compactDue": "Show due dates",
    "compactDueHelp": "📅 badge on flyout items",
    "compactDelete": "Trash on hover",
    "compactDeleteHelp": "Delete button on each flyout item",
    "notifications": "Notifications",
    "inApp": "In the app",
    "byEmail": "By email",
    "byEmailHelp": "Invitations, list sharing (sent by the server)",
    "syncSection": "Synchronization",
    "refreshDelay": "Refresh interval",
    "syncDelay": "Sync interval",
    "enableSync": "Enable sync",
    "appearance": "Appearance",
    "theme": "Theme",
    "themeSystem": "System",
    "themeLight": "Light",
    "themeDark": "Dark",
    "every30s": "Every 30 s (default)",
    "every30sShort": "Every 30 s",
    "every10s": "Every 10 s",
    "everyMinute": "Every minute",
    "every5min": "Every 5 min",
    "pollOff": "Off (realtime only)",
    "flyoutClose": "Close the flyout",
    "quickPanel": "Quick panel",
    "quit": "Quit",
    "openApp": "Open the app",
    "pinAlwaysVisible": "Always on top (pinned)",
    "pinEnable": "Pin: always visible",
    "pin": "Pin",
    "unpin": "Unpin",
    "openAppBtn": "Flyout “open app” button",
    "startHidden": "Start in the system tray",
    "noPinnedList": "No pinned list",
    "pinListsHelp": "Pin lists in the app to see them here.",
    "prevList": "Previous list",
    "nextList": "Next list",
    "switchList": "Switch list",
    "admin": "admin",
    "promoteAdmin": "Promote to admin",
    "demoteAdmin": "Remove admin role",
    "activate": "Activate",
    "deactivate": "Deactivate",
    "active": "active",
    "disabled": "disabled",
    "resetPassword": "Reset password",
    "monday": "Monday",
    "tuesday": "Tuesday",
    "wednesday": "Wednesday",
    "thursday": "Thursday",
    "friday": "Friday",
    "saturday": "Saturday",
    "sunday": "Sunday",
    "addButton": "Add",
    "deleteAction": "Delete",
  };

  /// Apply the synced per-user language ("fr", "en"…). Unknown -> French.
  static void setLocale(String? lang) {
    locale = (lang == null || lang.isEmpty) ? "fr" : lang;
  }

  static String t(String key) {
    switch (locale) {
      case "en":
        return _en[key] ?? _fr[key] ?? key;
      default:
        return _fr[key] ?? key;
    }
  }

  // Getters statiques utilisés par l'UI (S.ok, S.cancel, …).
  static String get ok => t("ok");
  static String get cancel => t("cancel");
  static String get apply => t("apply");
  static String get close => t("close");
  static String get add => t("add");
  static String get create => t("create");
  static String get delete => t("delete");
  static String get rename => t("rename");
  static String get share => t("share");
  static String get later => t("later");
  static String get noneF => t("none");
  static String get addButton => t("addButton");
  static String get deleteAction => t("deleteAction");
  static String get openAction => t("openAction");
  static String get none => t("none");
  static String get remove => t("remove");
  static String get undo => t("undo");
  static String get today => t("today");
  static String get tomorrow => t("tomorrow");
  static String get dayAfterTomorrow => t("dayAfterTomorrow");
  static String get every30s => t("every30s");
  static String get every30sShort => t("every30sShort");
  static String get every10s => t("every10s");
  static String get everyMinute => t("everyMinute");
  static String get every5min => t("every5min");
  static String get pollOff => t("pollOff");
  static String get inAWeek => t("inAWeek");
  static String get chooseDate => t("chooseDate");
  static String get appTitle => t("appTitle");
  static String get settings => t("settings");
  static String get account => t("account");
  static String get accountAndServer => t("accountAndServer");
  static String get administration => t("administration");
  static String get todoAll => t("todoAll");
  static String get todoAllTooltip => t("todoAllTooltip");
  static String get newList => t("newList");
  static String get newTask => t("newTask");
  static String get setDefaultList => t("setDefaultList");
  static String get unsetDefaultList => t("unsetDefaultList");
  static String get defaultList => t("defaultList");
  static String get newTaskHint => t("newTaskHint");
  static String get emptyList => t("emptyList");
  static String get listTitleFallback => t("listTitleFallback");
  static String get noList => t("noList");
  static String get createOneBelow => t("createOneBelow");
  static String get yourLists => t("yourLists");
  static String get search => t("search");
  static String get searchHint => t("searchHint");
  static String get searchMinChars => t("searchMinChars");
  static String get noResult => t("noResult");
  static String get login => t("login");
  static String get createAccount => t("createAccount");
  static String get haveAccount => t("haveAccount");
  static String get noAccount => t("noAccount");
  static String get serverUrl => t("serverUrl");
  static String get email => t("email");
  static String get password => t("password");
  static String get newPassword => t("newPassword");
  static String get totpCode => t("totpCode");
  static String get haveInviteCode => t("haveInviteCode");
  static String get inviteByCode => t("inviteByCode");
  static String get pasteCode => t("pasteCode");
  static String get codeFromEmail => t("codeFromEmail");
  static String get verifyEmail => t("verifyEmail");
  static String get emailVerified => t("emailVerified");
  static String get emailOptional => t("emailOptional");
  static String get notConfigured => t("notConfigured");
  static String get nothingToDo => t("nothingToDo");
  static String get nothingToDoAdd => t("nothingToDoAdd");
  static String get nothingToday => t("nothingToday");
  static String get allDone => t("allDone");
  static String get addMultiline => t("addMultiline");
  static String get addMultilineShort => t("addMultilineShort");
  static String get addSubtask => t("addSubtask");
  static String get subtask => t("subtask");
  static String get subtaskHint => t("subtaskHint");
  static String get setDueDate => t("setDueDate");
  static String get editDueDate => t("editDueDate");
  static String get dueDate => t("dueDate");
  static String get removeDueDate => t("removeDueDate");
  static String get dueDates => t("dueDates");
  static String get itemActions => t("itemActions");
  static String get note => t("note");
  static String get noRepeat => t("noRepeat");
  static String get daily => t("daily");
  static String get weekly => t("weekly");
  static String get monthly => t("monthly");
  static String get cleanDone => t("cleanDone");
  static String get cleanDoneConfirm => t("cleanDoneConfirm");
  static String get cleanDoneBody => t("cleanDoneBody");
  static String get clean => t("clean");
  static String get renameList => t("renameList");
  static String get listColor => t("listColor");
  static String get color => t("color");
  static String get duplicate => t("duplicate");
  static String get deleteListConfirm => t("deleteListConfirm");
  static String get deleteListBody => t("deleteListBody");
  static String get localOnly => t("localOnly");
  static String get folders => t("folders");
  static String get folder => t("folder");
  static String get folderEllipsis => t("folderEllipsis");
  static String get folderName => t("folderName");
  static String get groupByFolder => t("groupByFolder");
  static String get shareFolder => t("shareFolder");
  static String get shareList => t("shareList");
  static String get members => t("members");
  static String get noMembers => t("noMembers");
  static String get addMemberByEmail => t("addMemberByEmail");
  static String get memberEmail => t("memberEmail");
  static String get addMember => t("addMember");
  static String get inviteCode => t("inviteCode");
  static String get generateCode => t("generateCode");
  static String get generateCodeHelp => t("generateCodeHelp");
  static String get codeCopied => t("codeCopied");
  static String get listAdded => t("listAdded");
  static String get roleOwner => t("roleOwner");
  static String get features => t("features");
  static String get featuresHelp => t("featuresHelp");
  static String get alerts => t("alerts");
  static String get alertsHelp => t("alertsHelp");
  static String get alertsAppHelp => t("alertsAppHelp");
  static String get templates => t("templates");
  static String get templatesHelp => t("templatesHelp");
  static String get dueDatesHelp => t("dueDatesHelp");
  static String get visibleActions => t("visibleActions");
  static String get visibleActionsHelp => t("visibleActionsHelp");
  static String get dueKeywords => t("dueKeywords");
  static String get dueKeywordsHelp => t("dueKeywordsHelp");
  static String get addKeyword => t("addKeyword");
  static String get newKeyword => t("newKeyword");
  static String get keywordLabel => t("keywordLabel");
  static String get compact => t("compact");
  static String get compactHelp => t("compactHelp");
  static String get compactDue => t("compactDue");
  static String get compactDueHelp => t("compactDueHelp");
  static String get compactDelete => t("compactDelete");
  static String get compactDeleteHelp => t("compactDeleteHelp");
  static String get notifications => t("notifications");
  static String get inApp => t("inApp");
  static String get byEmail => t("byEmail");
  static String get byEmailHelp => t("byEmailHelp");
  static String get syncSection => t("syncSection");
  static String get refreshDelay => t("refreshDelay");
  static String get syncDelay => t("syncDelay");
  static String get enableSync => t("enableSync");
  static String get appearance => t("appearance");
  static String get theme => t("theme");
  static String get themeSystem => t("themeSystem");
  static String get themeLight => t("themeLight");
  static String get themeDark => t("themeDark");
  static String get flyoutClose => t("flyoutClose");
  static String get quickPanel => t("quickPanel");
  static String get quit => t("quit");
  static String get openApp => t("openApp");
  static String get pinAlwaysVisible => t("pinAlwaysVisible");
  static String get pinEnable => t("pinEnable");
  static String get pin => t("pin");
  static String get unpin => t("unpin");
  static String get openAppBtn => t("openAppBtn");
  static String get startHidden => t("startHidden");
  static String get noPinnedList => t("noPinnedList");
  static String get pinListsHelp => t("pinListsHelp");
  static String get prevList => t("prevList");
  static String get nextList => t("nextList");
  static String get switchList => t("switchList");
  static String get adminRole => t("admin");
  static String get promoteAdmin => t("promoteAdmin");
  static String get demoteAdmin => t("demoteAdmin");
  static String get activate => t("activate");
  static String get deactivate => t("deactivate");
  static String get active => t("active");
  static String get disabled => t("disabled");
  static String get resetPassword => t("resetPassword");

  // --- messages paramétrés ---
  static String loginFailed(Object e) => locale == "en" ? "Failed: $e" : "Échec : $e";
  static String itemDeletedMsg(String label) => "« $label » ${t("itemDeleted")}";
  static String listCreatedMsg(String title) => "« $title » créée";
  static String dueDateOf(String label) => "${t("dueDate")} — $label";
  static String shareFolderOf(String folder) => "${t("shareFolder")} « $folder »";
  static String deleteListOf(String title) => "${t("delete")} « $title » ?";
  static String roleOf(String role) => "${t("adminRole")} · rôle : $role";
  static String nInFolder(int n) => "$n ${n > 1 ? "listes" : "liste"}";
  static String nDueToday(int n) => "$n à faire aujourd'hui";
}
