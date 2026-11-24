import "package:flutter/foundation.dart" show kIsWeb;
import "package:material_ui/material_ui.dart";

import "../data/api_client.dart";
import "../state/app_state.dart";
import "../l10n/s.dart";

class LoginScreen extends StatefulWidget {
  final AppState state;
  const LoginScreen({super.key, required this.state});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _totp = TextEditingController();
  final _server = TextEditingController();
  bool _register = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Web build: the webapp is served behind the same origin as the API
    // (reverse proxy), so default the server URL to the page origin.
    final saved = widget.state.api.baseUrl;
    _server.text = saved.isEmpty && kIsWeb ? Uri.base.origin : saved;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.accountAndServer)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _server,
              decoration: InputDecoration(
                  labelText: S.serverUrl, hintText: "https://checklists.mondomaine.fr"),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: InputDecoration(labelText: S.email),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              decoration: InputDecoration(labelText: S.password),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _totp,
              decoration: InputDecoration(
                  labelText: S.totpCode, hintText: S.emailOptional),
              keyboardType: TextInputType.number,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: Text(_register ? S.createAccount : "Se connecter"),
            ),
            TextButton(
              onPressed: () => setState(() => _register = !_register),
              child: Text(_register
                  ? S.haveAccount
                  : "Je n'ai pas de compte"),
            ),
            TextButton(
              onPressed: _acceptInvite,
              child: Text(S.haveInviteCode),
            ),
            TextButton(
              onPressed: _verifyEmail,
              child: Text(S.verifyEmail),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptInvite() async {
    final code = await _promptInviteCode();
    if (code == null || code.trim().isEmpty) return;
    final api = widget.state.api;
    api.baseUrl = _server.text.trim().replaceAll(RegExp(r"/$"), "");
    try {
      if (api.accessToken == null || api.accessToken!.isEmpty) {
        await _submit(silent: true);
      }
      await api.post("/lists/invites/${code.trim()}/accept", {});
      await widget.state.sync.fullSync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.listAdded)));
        Navigator.pushReplacementNamed(context, "/home");
      }
    } on ApiException catch (e) {
      setState(() => _error = "Invitation refusée : ${e.message}");
    } catch (e) {
      setState(() => _error = S.loginFailed(e));
    }
  }

  Future<void> _verifyEmail() async {
    final code = await _promptCode(S.codeFromEmail);
    if (code == null || code.trim().isEmpty) return;
    try {
      await widget.state.api
          .post("/auth/verify-email", {"token": code.trim()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(S.emailVerified)));
      }
    } on ApiException catch (e) {
      setState(() => _error = "Vérification échouée : ${e.message}");
    }
  }

  Future<String?> _promptCode(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text("Valider")),
        ],
      ),
    );
  }

  Future<String?> _promptInviteCode() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.inviteCode),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: S.pasteCode),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text("Valider")),
        ],
      ),
    );
  }

  Future<void> _submit({bool silent = false}) async {
    final api = widget.state.api;
    api.baseUrl = _server.text.trim().replaceAll(RegExp(r"/$"), "");
    try {
      if (_register) {
        await api.register(_email.text.trim(), _password.text);
      } else {
        await api.login(_email.text.trim(), _password.text,
            totpCode: _totp.text.trim().isEmpty ? null : _totp.text.trim());
      }
      await api.persist();
      // Fresh login: pull everything, start realtime, reload the profile
      // (admin flag + feature settings) instead of waiting for a restart.
      await widget.state.sync.fullSync();
      await widget.state.sync.listenRealtime();
      await widget.state.reloadProfile();
      await widget.state.refreshAfterLogin();
      if (mounted && !silent) Navigator.pushReplacementNamed(context, "/home");
    } catch (e) {
      setState(() => _error = S.loginFailed(e));
    }
  }
}
