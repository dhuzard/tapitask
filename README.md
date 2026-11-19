# Tapitask

**Listes de tâches à cocher hyper-réactives, offline-first, auto-hébergées.**
Client Windows (icône systray + volet rapide), Android (widgets d'écran d'accueil), webapp — avec un serveur de synchronisation et de partage auto-hébergé.

```
┌────────────┐   ┌────────────┐   ┌────────────┐
│  Windows   │   │  Android   │   │   Webapp   │
│ tray+volet │   │  widgets   │   │  (Flutter) │
└─────┬──────┘   └─────┬──────┘   └─────┬──────┘
      │      WebSocket + REST delta      │
      └──────────────┬───────────────────┘
                     ▼
        ┌─────────────────────────┐
        │  Serveur FastAPI        │
        │  Postgres + Docker      │
        │  comptes, partage, 2FA │
        └─────────────────────────┘
```

## Pourquoi Tapitask

- **Instantané** : chaque action s'applique localement (SQLite) puis se synchronise en arrière-plan. Pas de spinner, jamais.
- **Minimaliste ou complet** : chaque utilisateur active les fonctions qu'il veut (dossiers, alertes, templates — les échéances sont toujours disponibles) — synchronisées entre tous ses appareils.
- **Présent partout** : volet rapide dans la barre des tâches Windows, widgets Android (liste cochable + ajout rapide 1×1), webapp.
- **Partage** : invitations par code ou email, rôles viewer / editor / owner, dossiers partageables.
- **Auto-hébergé** : votre serveur, vos données, Docker Compose, HTTPS via votre reverse proxy (ou Caddy intégré).
- **Sécurisé** : Argon2id, JWT rotatifs, 2FA TOTP, clés API scopées, rate limiting (voir [SECURITY.md](SECURITY.md)).
- **Agentique** : API REST documentée (`/docs`), clés API, serveur MCP inclus.

## Fonctionnalités

| Domaine | Détail |
|---|---|
| Listes | création instantanée, couleurs, épinglage, duplication, listes locales (sans synchro) |
| Items | cochage, sous-tâches, notes, échéances, récurrence (quotidienne/hebdo/mensuelle), assignés |
| Ajout rapide | multi-lignes (1 ligne = 1 item), parseur de dates (« demain », « vendredi »…), mots-clés d'échéance personnels (« j+7 » → +7 jours), `#liste` |
| Réglages compacts | choix des fonctions visibles dans le volet/widget (échéances, poubelle) — tout synchronisé |
| Dossiers | glisser-déposer des listes, partage d'un dossier (toutes les listes incluses) |
| Synchro | delta par curseur `since`, WebSocket push, synchro à chaque action + au retour au premier plan, poll configurable (désactivable) |
| Volet Windows | ancré près du tray, ajout rapide en bas, listes épinglées en chips, épingle « toujours visible », redimensionnable/déplaçable |
| Widgets Android | liste cochable avec ◀▶, couleur par liste, bouton ＋, zone « Ouvrir », widget 1×1 d'ajout rapide |
| Partage | code d'invitation, email (SMTP), rôles, changement de rôle |
| Notifications | par appli et/ou par email, au choix de chaque utilisateur |
| Admin | création/désactivation de comptes, promotion admin, audit |
| Thème | clair / sombre / système (synchronisé) |

## Démarrage rapide — serveur (Ubuntu)

```bash
git clone <votre-repo> tapitask && cd tapitask
cp .env.example .env
# éditez .env : DB_PASSWORD, JWT_SECRET (openssl rand -hex 32), ADMIN_EMAIL/PASSWORD…
docker compose up -d --build
curl http://localhost:8000/health     # {"status":"ok"}
```

L'API est exposée sur `API_PORT` (défaut 8000) : pointez votre reverse proxy (nginx, Caddy…) dessus pour le TLS.
Alternative : TLS intégré avec `--profile caddy` (renseignez `DOMAIN`).

Docs API : `http://VOTRE_DOMAINE/docs` (Swagger) — spec : `/openapi.json`.

### Configuration (`.env`)

Copiez `.env.example` (documenté) : mots de passe DB, secret JWT, compte admin créé au démarrage, ports (`API_PORT`, `WEB_PORT`), `CORS_ORIGINS`, SMTP (emails d'invitation et de partage), `REDIS_URL` optionnel (rate limiting multi-workers).

### Frontend web dans Docker

```bash
# machine de dev : builder la webapp
cd app && flutter build web --release
# transférer app/build/web sur le serveur, puis :
docker compose --profile web up -d      # nginx sert la webapp sur WEB_PORT (8080)
```

Détails et intégration reverse proxy : [DEPLOIEMENT-UBUNTU.md](DEPLOIEMENT-UBUNTU.md).

## Démarrage rapide — clients

### Windows (exe)

Machine Windows avec Flutter + Visual Studio :

```powershell
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build windows --release
# => app/build/windows/x64/runner/Release/tapitask.exe
```

Ou tout-en-un assisté : `powershell -File scripts\setup_tapitask.ps1` (build + zip + keystore APK).

L'icône tray s'installe au lancement ; clic gauche = volet rapide, clic droit = menu.

### Android (apk)

```bash
cd app
flutter build apk --release
# => app/build/app/outputs/flutter-apk/app-release.apk
```

Ajoutez ensuite le widget « Tapitask » sur l'écran d'accueil. Le keystore de signature est
`app/android/app/tapitask-release.jks` (avec `key.properties`) : gardez-le pour que les mises à jour s'installent par-dessus.

### Webapp

```bash
cd app && flutter build web --release
```

## Structure du monorepo

```
├── docker-compose.yml      # db (Postgres) + api + web (webapp) + caddy (optionnel)
├── .env.example            # configuration documentée
├── Caddyfile               # TLS intégré (optionnel)
├── DEPLOIEMENT-UBUNTU.md   # guide de déploiement pas à pas
├── SECURITY.md             # modèle de menace + bonnes pratiques
├── server/                 # backend FastAPI (async) + 38 tests
│   ├── app/                # auth, listes, partage, sync, admin, clés API, MCP HTTP
│   ├── tests/              # pytest (SQLite), couverture auth/sync/partage/smtp
│   └── Dockerfile
├── app/                    # client Flutter (Windows / Android / Web)
│   ├── lib/                # UI, base locale Drift/SQLite, synchro, tray, widgets
│   ├── android/            # natif : ListWidgetProvider, QuickAddWidget, layouts
│   └── windows/            # runner (channel natif topmost pour le volet)
└── scripts/                # setup assisté (Windows .ps1, Linux .sh), init_flutter
```

## Modèle de synchronisation

Le SQLite local est la source de vérité de l'UI. Chaque action est locale puis poussée
(`POST /sync`, delta par curseur, last-write-wins). Le serveur pousse les changements des
listes partagées via WebSocket ; le poll configurable n'est qu'un filet de secours
(désactivable pour l'autonomie de batterie). Synchro complète à l'ouverture, au retour
au premier plan et après chaque action.

## API agentique

1. **Clé API** : `POST /api-keys` (lecture seule ou lecture+écriture, scope par liste, révocable)
2. **REST** : `POST /lists/{id}/items/bulk` (texte multi-lignes), `/summary`, webhooks signés HMAC
3. **MCP** : `python server/mcp_server.py` (`CHECKLISTS_URL`, `CHECKLISTS_API_KEY`) — ou MCP HTTP/SSE intégré

## Environnement de développement — serveur

Le serveur est un projet **FastAPI / Python 3.12**. Toutes les dépendances (runtime
**et** tests, dont `aiohttp` pour le test de livraison HMAC des webhooks) sont
déclarées dans `server/requirements.txt`.

```bash
cd server
python3 -m venv .venv                 # Python 3.12+ ; `.venv` est dans .gitignore
.venv/bin/pip install --upgrade pip
.venv/bin/pip install -r requirements.txt
.venv/bin/pip check                   # aucune dépréciation / dépendance cassée
```

Lancer l'API (SQLite en dev, ou Postgres via `.env`) :

```bash
cd server
set -a; . ./.env; set +a              # .env local (cf .env.example) — jamais commité
.venv/bin/uvicorn app.main:app --reload --port 8000
```

Le venv (`.venv/`) et `.env` sont exclus du dépôt (voir `.gitignore`) : les secrets et
le keystore Android aussi.

## Tests

```bash
# Serveur — 38 tests (auth, sync, partage, admin, webhooks HMAC, MCP, rate limiting)
cd server
.venv/bin/python -m pytest -q
```

Client (Flutter) — 11 tests :

```bash
# Prérequis système (Linux) : les plugins tray_manager / window_manager
# déclenchent un build d'assets natifs (GTK 3, X11, Xi). Les paquets de
# développement sont indispensables pour que `flutter test` compile l'hôte :
#   sudo apt install libgtk-3-dev libxi-dev
cd app
flutter test
```

## CI / Releases

Le workflow [`.github/workflows/release-artifacts.yml`](.github/workflows/release-artifacts.yml)
construit, **à la publication d'un GitHub Release**, les deux binaires et les
attache au release :

| Artefact | Runner | Commande |
|---|---|---|
| `tapitask-<tag>-windows-x64.zip` (exe + data) | `windows-latest` | `flutter build windows --release` |
| `tapitask-<tag>-android.apk` (APK signé) | `ubuntu-latest` | `flutter build apk --release` |

### Configuration du signing Android

Le keystore (`app/android/app/tapitask-release.jks`) et sa `key.properties`
restent **hors du dépôt** (gitignored). `build.gradle.kts` les lit s'ils existent,
sinon il signe en debug. Le CI les restaure depuis deux secrets
GitHub Actions (jamais dans le code) :

| Secret | Contenu |
|---|---|
| `TAPITASK_KEYSTORE_B64` | le `.jks` encodé en base64 (1 ligne) |
| `TAPITASK_KEY_PROPERTIES` | le contenu de `key.properties` (tel quel) |

Pour (re)configurer les secrets depuis un repo local propre :

```bash
gh secret set TAPITASK_KEYSTORE_B64 <(base64 -w0 app/android/app/tapitask-release.jks)
gh secret set TAPITASK_KEY_PROPERTIES app/android/app/key.properties
```

Puis publie un release (tag `vX.Y.Z`) : les artefacts apparaissent sur
`/releases` en quelques minutes.

> **Note — warning KGP sur `home_widget`** : le build Android affiche
> « *Your app uses the following plugins that apply Kotlin Gradle Plugin
> (KGP): home_widget* ». C'est un **faux positif** : l'outil Flutter détecte
> l'application du KGP par scan regex des fichiers des plugins, et matche la
> ligne `apply plugin: 'kotlin-android'` de `home_widget` alors qu'elle est
> conditionnée par `if (!useBuiltInKotlin)` (inactive sous AGP 9+). Le plugin
> (0.10.0, dernière version) est fonctionnellement migré — le mainteneur le
> confirme [ici](https://github.com/ABausG/home_widget/issues/421). Le build
> n'est pas impacté.

## Sécurité — voir [SECURITY.md](SECURITY.md)

Argon2id · JWT à courte durée + refresh rotatifs révocables · 2FA TOTP · clés API hachées ·
rate limiting + lockout · CORS strict · Postgres non exposé · en-têtes de sécurité (Caddy).

## Licence

[MIT](LICENSE)
