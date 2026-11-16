import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';

/// Shown after registration (or for any unverified account) until the user
/// opens the verification link Firebase emailed them.
class _VerifyEmailScreen extends StatefulWidget {
  final AuthAccount account;
  final AuthService service;
  const _VerifyEmailScreen({
    super.key,
    required this.account,
    required this.service,
  });
  @override
  State<_VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<_VerifyEmailScreen> {
  static const _azure = Color(0xFF007FFF);
  static const _mist = Color(0xFFF0F8FF);
  static const _ink = Color(0xFF0B2545);
  static const _muted = Color(0xFF6B7A90);
  static const _resendWait = 60;

  bool _checking = false, _sending = false;
  int _cooldown = _resendWait; // the link was just sent at registration
  String? _message;
  bool _messageIsError = false;
  Timer? _ticker, _autoCheck;

  @override
  void initState() {
    super.initState();
    _startCooldown();
    // Notice verification automatically while this screen is open.
    _autoCheck = Timer.periodic(const Duration(seconds: 6), (_) => _check());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _autoCheck?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _ticker?.cancel();
    _cooldown = _resendWait;
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _cooldown = _cooldown > 0 ? _cooldown - 1 : 0);
      if (_cooldown == 0) t.cancel();
    });
  }

  Future<void> _check({bool manual = false}) async {
    if (_checking) return;
    if (manual) setState(() => _checking = true);
    try {
      final verified = await widget.service.refreshEmailVerified();
      // When verified, the auth stream updates and AuthGate moves on.
      if (!verified && manual && mounted) {
        setState(() {
          _message =
              'Not verified yet. Open the link in the email, then tap the button again.';
          _messageIsError = true;
        });
      }
    } catch (e) {
      if (manual && mounted) {
        setState(() {
          _message = authErrorMessage(e);
          _messageIsError = true;
        });
      }
    } finally {
      if (manual && mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    if (_sending || _cooldown > 0) return;
    setState(() {
      _sending = true;
      _message = null;
    });
    try {
      await widget.service.sendEmailVerification();
      if (mounted) {
        setState(() {
          _message = 'A new verification email was sent.';
          _messageIsError = false;
        });
        _startCooldown();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = authErrorMessage(e);
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await widget.service.signOut();
    } catch (e) {
      if (mounted) setState(() => _message = authErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _mist,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: _azure.withValues(alpha: 0.12),
                    blurRadius: 32,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: _azure.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_unread_outlined,
                        color: _azure,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Verify your email',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'We sent a verification link to\n${widget.account.email}\n\nOpen the email and tap the link, then come back here. Check your spam folder if you can\'t find it.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: _muted,
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 14),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: _messageIsError
                              ? const Color(0xFFD93025)
                              : const Color(0xFF1E8E5A),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _checking ? null : () => _check(manual: true),
                      style: FilledButton.styleFrom(
                        backgroundColor: _azure,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                      ),
                      child: _checking
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "I've verified my email",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _sending || _cooldown > 0 ? null : _resend,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _azure,
                      side: const BorderSide(color: _azure),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      _cooldown > 0
                          ? 'Resend email in ${_cooldown}s'
                          : (_sending ? 'Sending…' : 'Resend email'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _signOut,
                    style: TextButton.styleFrom(foregroundColor: _muted),
                    child: const Text('Use a different account (sign out)'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

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
      // The app stays locked until the email address is verified.
      if (!account.emailVerified) {
        return _VerifyEmailScreen(
          key: ValueKey('verify-${account.uid}'),
          account: account,
          service: widget.service,
        );
      }
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
