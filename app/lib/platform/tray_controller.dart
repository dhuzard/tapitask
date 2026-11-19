import "dart:io";

import "package:material_ui/material_ui.dart";
import "package:tray_manager/tray_manager.dart";
import "package:window_manager/window_manager.dart";

import "../l10n/s.dart";
import "../state/app_state.dart";
import "flyout_bridge.dart";

/// Windows systray — native API (tray_manager 0.9 / window_manager 0.7).
/// - Main window: normal (title bar, movable, resizable, closable to tray).
/// - Tray left-click: toggle the NATIVE flyout (volet rapide Win32, created
///   hidden at startup by the runner — showing it is instant, ~0 RAM).
/// - Pin ("toujours visible"): native HWND_TOPMOST + no-dismiss-on-focus-loss.
/// - Quit: clean shutdown (streams + sync timers + drift DB closed) before
///   closing the last window — no exit(0) mid-flight.
class TrayController {
  final AppState state;
  late final FlyoutBridge flyout;
  TrayIcon? _trayIcon;
  Window? _window;
  bool _quitting = false;
  bool _initialized = false;

  TrayController(this.state);

  Future<void> init() async {
    if (!Platform.isWindows && !Platform.isLinux) return;
    flyout = FlyoutBridge(state);
    flyout.onOpenApp = showMainWindow;

    // ---- Main window (native API: set properties, then show). ----
    final window = WindowManager.instance.getCurrent();
    if (window == null) return;
    _window = window;
    window.addListener(_onWindowEvent);
    window.title = "Tapitask";
    window.minimumSize = const Size(360, 480).toNative();
    window.setSize(const Size(440, 700).toNative(), false);
    // "Démarrer dans la barre des tâches" : la fenêtre principale reste
    // cachée, l'app vit dans le tray (volet rapide au clic).
    if (state.settings["start_hidden"] != true) {
      window.show();
      window.focus();
    }

    // ---- Tray icon. ----
    final trayIcon = TrayIcon.create();
    if (trayIcon == null) return;
    _trayIcon = trayIcon;
    trayIcon.icon = ImageAsset.fromAsset(
        Platform.isWindows ? "assets/tray_icon.ico" : "assets/tray_icon.png");
    trayIcon.addListener((event) {
      // Left click (reported when the click completes) → toggle flyout.
      // Right click opens the context menu via the trigger below.
      if (event is TrayIconClickedEvent && !_quitting) {
        flyout.toggle();
      }
    });
    _updateTooltip();
    state.addListener(_updateTooltip);

    final menu = Menu.create();
    final flyoutItem =
        MenuItem.createWithLabelAndType(S.quickPanel, MenuItemType.normal);
    flyoutItem?.addListener((event) {
      if (event is MenuItemClickedEvent && !_quitting) flyout.toggle();
    });
    final showItem =
        MenuItem.createWithLabelAndType(S.openApp, MenuItemType.normal);
    showItem?.addListener((event) {
      if (event is MenuItemClickedEvent) showMainWindow();
    });
    final quitItem =
        MenuItem.createWithLabelAndType(S.quit, MenuItemType.normal);
    quitItem?.addListener((event) {
      if (event is MenuItemClickedEvent) quit();
    });
    menu?.addItem(flyoutItem);
    menu?.addItem(showItem);
    menu?.addSeparator();
    menu?.addItem(quitItem);
    trayIcon.setContextMenu(menu);
    trayIcon.setContextMenuTrigger(ContextMenuTrigger.rightClicked);
    trayIcon.setVisible(true);

    // Native flyout: data streams + user actions (Windows only).
    flyout.init();
    _initialized = true;
  }

  bool get isInitialized => _initialized;

  void _onWindowEvent(WindowEvent event) {
    // Close button hides to tray; the app keeps syncing in the background.
    // When quitting, the request is left through and the app ends.
    if (event is WindowCloseRequestedEvent) {
      if (_quitting) return;
      event.request.cancel();
      _window?.hide();
    }
  }

  /// Badge: items remaining on pinned lists (+ due today if enabled).
  void _updateTooltip() {
    final trayIcon = _trayIcon;
    if (trayIcon == null) return;
    () async {
      try {
        final pinned = await state.db.pinnedLists();
        var remaining = 0;
        for (final list in pinned) {
          remaining += (await state.db.uncheckedItemsOf(list.id)).length;
        }
        final due = (await state.db.dueItems()).length;
        final badge = [
          if (remaining > 0) "$remaining à faire",
          if (due > 0) "$due aujourd'hui",
        ].join(" • ");
        trayIcon.setTooltip(badge.isEmpty ? "Tapitask" : "Tapitask — $badge");
      } catch (_) {}
    }();
  }

  Future<void> showMainWindow() async {
    _window?.show();
    _window?.focus();
  }

  /// Is the main window currently visible? (used by the flyout bridge to
  /// guarantee the app stays open when the flyout shows)
  Future<bool> isMainWindowVisible() async => _window?.isVisible ?? false;

  /// Restore the main window if anything hid it (no-op if visible).
  Future<void> restoreMainWindow() async {
    final window = _window;
    if (window != null && !window.isVisible) {
      window.show();
    }
  }

  /// Clean shutdown: stop streams/timers, close the drift database, then let
  /// the last window close (which ends the app — no exit(0)).
  Future<void> quit() async {
    if (_quitting) return;
    _quitting = true;
    state.removeListener(_updateTooltip);
    try {
      flyout.dispose();
    } catch (_) {}
    try {
      state.dispose();
    } catch (_) {}
    _trayIcon?.dispose();
    _window?.close();
  }
}
