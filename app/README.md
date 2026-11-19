# Tapitask — App Flutter

Client offline-first : Windows (systray), Android (widget), Web.

## Prérequis
- Flutter SDK ≥ 3.4
- Pour Windows : Visual Studio Build Tools (charge de travail C++ desktop)
- Pour Android : Android Studio

## Installation

```bash
cd app
flutter create . --platforms=windows,android,web
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d windows     # ou -d android / -d chrome
```

`flutter create .` génère les dossiers plateforme sans toucher aux fichiers existants.

## Widget Android (natif)

Recopier les fichiers fournis dans le dossier android généré :

| Fichier fourni | Destination |
|---|---|
| `android/app/src/main/kotlin/com/example/checklists/ListWidgetProvider.kt` | idem (adapter le package au `applicationId` généré) |
| `android/app/src/main/res/layout/list_widget.xml` | idem |
| `android/app/src/main/res/xml/list_widget_info.xml` | idem |

Ajouter dans `AndroidManifest.xml` (dans `<application>`) :

```xml
<receiver android:name=".ListWidgetProvider" android:exported="false">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/list_widget_info" />
</receiver>
```

Et dans `strings.xml` : `<string name="widget_title">Liste</string>`.

Le widget lit les données posées par `WidgetService.update()` (cache local → fonctionne hors ligne) ; il se rafraîchit après chaque synchro. Brancher l'appel dans `AppState.toggleItem`/`addQuickItems` pour la liste épinglée.

## Tray Windows

`TrayController` (tray_manager + window_manager) :
- **1 clic gauche** sur l'icône → volet avec les listes épinglées + barre d'ajout rapide
- **multi-lignes collées = un item par ligne**
- clic droit → menu (Ouvrir / Quitter)
- fermer le volet = cacher la fenêtre, l'app continue en arrière-plan

Icône : déposer `assets/tray_icon.ico` (Windows) et `assets/tray_icon.png` dans `app/assets/` et déclarer le dossier dans `pubspec.yaml` :

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/
```

## Fonctionnalités incluses

- Listes + items, coche instantanée (offline-first), ajout rapide multi-lignes
- Épinglage de listes (affichées dans le tray Windows et le widget Android)
- **Partage** : bouton « Partager » sur une liste → code d'invitation (48 h) à copier, ajout direct par email avec rôle viewer/editor, liste des membres, retrait
- **Accepter une invitation** : écran de connexion → « J'ai un code d'invitation »
- Synchro delta + WebSocket temps réel, résolution last-write-wins

### Signature Android (release)

Si `android/key.properties` existe (créé par les scripts de build), ajoute dans `android/app/build.gradle.kts` :

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }
    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }
}
```

## Architecture

```
lib/
├── main.dart                  # entrée, routes, init tray
├── data/
│   ├── database.dart          # Drift/SQLite local (source de vérité UI)
│   ├── api_client.dart        # HTTP + JWT + refresh automatique
│   └── sync_service.dart      # outbox + delta sync + WebSocket
├── state/app_state.dart       # ChangeNotifier : actions instantanées, sync en fond
├── platform/
│   ├── tray_controller.dart   # systray Windows/Linux
│   └── widget_service.dart   # home_widget Android
└── ui/
    ├── home_screen.dart       # listes + épinglage
    ├── list_screen.dart       # items + ajout rapide multi-lignes
    └── login_screen.dart      # compte + URL serveur
```

Chaque action est **appliquée d'abord en local** (SQLite) et notifiée immédiatement à l'UI ; la synchro serveur part en arrière-plan — c'est ce qui rend l'app instantanée.
