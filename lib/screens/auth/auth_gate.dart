import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';

/// Owns the authenticated navigator so signing out also removes pushed pages.
class AuthGate extends StatefulWidget {
  final AuthService service;
  final WidgetBuilder signedInBuilder;
  const AuthGate({
    super.key,
    required this.service,
    required this.signedInBuilder,
  });
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final _stream = widget.service.authStateChanges();
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthAccount?>(
    stream: _stream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Scaffold(
          body: Center(
            child: Text(
              'Unable to restore your session. Restart the app to retry.',
            ),
          ),
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final account = snapshot.data;
      if (account == null) return LoginScreen(service: widget.service);
      return _ProfileGate(
        key: ValueKey(account.uid),
        account: account,
        service: widget.service,
        signedInBuilder: widget.signedInBuilder,
      );
    },
  );
}

class _ProfileGate extends StatefulWidget {
  final AuthAccount account;
  final AuthService service;
  final WidgetBuilder signedInBuilder;
  const _ProfileGate({
    super.key,
    required this.account,
    required this.service,
    required this.signedInBuilder,
  });
  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  late Future<bool> _profile = widget.service.hasProfile(widget.account.uid);
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.saveProfile(
        widget.account.uid,
        _name.text,
        _phone.text,
      );
      if (mounted) setState(() => _profile = Future.value(true));
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await widget.service.signOut();
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _profile,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (!snapshot.hasError && snapshot.data == true) {
        return Navigator(
          onGenerateRoute: (_) =>
              MaterialPageRoute(builder: widget.signedInBuilder),
        );
      }
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Complete your profile',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text('Signed in as ${widget.account.email}'),
                      const SizedBox(height: 20),
                      if (snapshot.hasError) ...[
                        Text(authErrorMessage(snapshot.error!)),
                        FilledButton(
                          onPressed: () => setState(() {
                            _error = null;
                            _profile = widget.service.hasProfile(
                              widget.account.uid,
                            );
                          }),
                          child: const Text('Retry profile check'),
                        ),
                      ] else ...[
                        const Text(
                          'Your account is ready. Save your details to continue.',
                        ),
                        TextFormField(
                          controller: _name,
                          enabled: !_busy,
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'Enter your name.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phone,
                          enabled: !_busy,
                          decoration: const InputDecoration(
                            labelText: 'Phone (optional)',
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return null;
                            return RegExp(
                                  r'^\+?[0-9 ()-]{7,20}$',
                                ).hasMatch(value)
                                ? null
                                : 'Enter a valid phone number.';
                          },
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _busy ? null : _save,
                          child: Text(_busy ? 'Saving...' : 'Save profile'),
                        ),
                      ],
                      if (_error != null)
                        Semantics(liveRegion: true, child: Text(_error!)),
                      TextButton(
                        onPressed: _busy ? null : _signOut,
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
