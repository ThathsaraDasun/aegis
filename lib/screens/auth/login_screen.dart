import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';

/// Colour palette used by the sign-in / create-account screen.
class _AuthPalette {
  static const Color azure = Color(0xFF007FFF);
  static const Color sky = Color(0xFF66CCFF);
  static const Color mist = Color(0xFFF0F8FF);
  static const Color dodger = Color(0xFF1E90FF);
  static const Color ink = Color(0xFF0B2545);
  static const Color muted = Color(0xFF6B7A90);
  static const Color line = Color(0xFFD6ECFF);
  static const Color error = Color(0xFFD93025);
}

const TextStyle _inputText = TextStyle(color: _AuthPalette.ink, fontSize: 15);

class LoginScreen extends StatefulWidget {
  final AuthService service;
  const LoginScreen({super.key, required this.service});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_register) {
        await widget.service.register(_email.text.trim(), _password.text);
      } else {
        await widget.service.signIn(_email.text.trim(), _password.text);
      }
      // The auth-state gate owns navigation; failures never open the app.
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggleMode() => setState(() {
    _register = !_register;
    _error = null;
    _password.clear();
    _confirm.clear();
    _form.currentState?.reset();
  });

  Future<void> _showForgotPasswordDialog() async {
    final sentEmail = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => _ForgotPasswordDialog(
        service: widget.service,
        initialEmail: _email.text.trim(),
      ),
    );

    if (sentEmail != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Password reset link sent to $sentEmail. Check your email.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: _AuthPalette.azure,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------------------- styling

  static InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    required IconData icon,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _AuthPalette.muted, fontSize: 14),
      floatingLabelStyle: const TextStyle(
        color: _AuthPalette.azure,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      hintText: hint,
      hintStyle: TextStyle(
        color: _AuthPalette.muted.withValues(alpha: 0.7),
        fontSize: 14,
      ),
      prefixIcon: Icon(icon, color: _AuthPalette.azure, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: _AuthPalette.mist,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      errorStyle: const TextStyle(color: _AuthPalette.error, fontSize: 12),
      border: border(_AuthPalette.line),
      enabledBorder: border(_AuthPalette.line),
      disabledBorder: border(_AuthPalette.line),
      focusedBorder: border(_AuthPalette.azure, 1.6),
      errorBorder: border(_AuthPalette.error),
      focusedErrorBorder: border(_AuthPalette.error, 1.6),
    );
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: _AuthPalette.mist,
      body: SingleChildScrollView(
        child: Stack(
          children: [
            _Header(register: _register),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 250, 20, 24),
                    child: _buildCard(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildCard() => Container(
    padding: const EdgeInsets.fromLTRB(22, 26, 22, 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      boxShadow: [
        BoxShadow(
          color: _AuthPalette.azure.withValues(alpha: 0.12),
          blurRadius: 32,
          offset: const Offset(0, 14),
        ),
      ],
    ),
    child: Form(
      key: _form,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              enabled: !_busy,
              style: _inputText,
              cursorColor: _AuthPalette.azure,
              decoration: _fieldDecoration(
                label: 'Email address',
                hint: 'example@gmail.com',
                icon: Icons.mail_outline_rounded,
              ),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  RegExp(
                    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                  ).hasMatch((v ?? '').trim())
                  ? null
                  : 'Enter a valid email address.',
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _password,
              enabled: !_busy,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              style: _inputText,
              cursorColor: _AuthPalette.azure,
              autofillHints: [
                _register ? AutofillHints.newPassword : AutofillHints.password,
              ],
              decoration: _fieldDecoration(
                label: 'Password',
                hint: _register ? 'At least 6 characters' : null,
                icon: Icons.lock_outline_rounded,
                suffix: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: _AuthPalette.muted,
                    size: 20,
                  ),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Enter your password.';
                }
                if (_register && v.length < 6) {
                  return 'Use at least 6 characters.';
                }
                return null;
              },
              onFieldSubmitted: (_) {
                if (!_register) _submit();
              },
            ),
            if (!_register) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy ? null : _showForgotPasswordDialog,
                  style: TextButton.styleFrom(
                    foregroundColor: _AuthPalette.azure,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(
                      color: _AuthPalette.azure,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _register
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _confirm,
                          enabled: !_busy,
                          obscureText: _obscure,
                          autocorrect: false,
                          enableSuggestions: false,
                          style: _inputText,
                          cursorColor: _AuthPalette.azure,
                          decoration: _fieldDecoration(
                            label: 'Confirm password',
                            hint: 'Re-enter your password',
                            icon: Icons.verified_user_outlined,
                          ),
                          validator: (v) => v == _password.text
                              ? null
                              : 'Passwords do not match.',
                          onFieldSubmitted: (_) => _submit(),
                        ),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _AuthPalette.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _AuthPalette.error.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: _AuthPalette.error,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: _AuthPalette.error,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 26),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _AuthPalette.azure,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _AuthPalette.azure.withValues(
                    alpha: 0.55,
                  ),
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  shape: const StadiumBorder(),
                  textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(_register ? 'Create account' : 'Sign in'),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _register ? 'Already have an account?' : 'New to Aegis?',
                  style: const TextStyle(
                    color: _AuthPalette.muted,
                    fontSize: 14,
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _toggleMode,
                  style: TextButton.styleFrom(
                    foregroundColor: _AuthPalette.azure,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(_register ? 'Sign in' : 'Create an account'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Blue curved header with the Aegis logo and the page title.
class _Header extends StatelessWidget {
  final bool register;
  const _Header({required this.register});

  @override
  Widget build(BuildContext context) => Container(
    height: 340,
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_AuthPalette.azure, _AuthPalette.dodger],
      ),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        // Soft decorative circles, as in the reference design.
        Positioned(
          top: -70,
          right: -50,
          child: _circle(200, _AuthPalette.sky.withValues(alpha: 0.30)),
        ),
        Positioned(
          top: 140,
          left: -60,
          child: _circle(140, Colors.white.withValues(alpha: 0.08)),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/splash/splash_logo.png',
                  width: 76,
                  height: 76,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox(
                    width: 76,
                    height: 76,
                    child: Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'AEGIS SAFE WALK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.4,
                  ),
                ),
                const SizedBox(height: 14),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Column(
                    key: ValueKey(register),
                    children: [
                      Text(
                        register
                            ? 'Create Account'
                            : "Let's get you signed in!",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        register
                            ? 'Create your account, then complete your profile.'
                            : 'Welcome back! Sign in to your safety companion.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  static Widget _circle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _ForgotPasswordDialog extends StatefulWidget {
  final AuthService service;
  final String initialEmail;

  const _ForgotPasswordDialog({
    required this.service,
    required this.initialEmail,
  });

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (_sending || !_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final targetEmail = _emailController.text.trim();
    try {
      await widget.service.sendPasswordResetEmail(targetEmail);
      if (mounted) {
        Navigator.of(context).pop(targetEmail);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = authErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _AuthPalette.azure.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      color: _AuthPalette.azure,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Reset password',
                      style: TextStyle(
                        color: _AuthPalette.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Enter your registered email address and we will send you a password reset link.',
                style: TextStyle(
                  color: _AuthPalette.muted,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _emailController,
                enabled: !_sending,
                style: _inputText,
                cursorColor: _AuthPalette.azure,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                decoration: _LoginScreenState._fieldDecoration(
                  label: 'Email address',
                  hint: 'example@gmail.com',
                  icon: Icons.mail_outline_rounded,
                ),
                validator: (v) => RegExp(
                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                ).hasMatch((v ?? '').trim())
                    ? null
                    : 'Enter a valid email address.',
                onFieldSubmitted: (_) => _sendReset(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _AuthPalette.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _AuthPalette.error.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: _AuthPalette.error,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: _AuthPalette.error,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: _AuthPalette.muted,
          ),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _sending ? null : _sendReset,
          style: FilledButton.styleFrom(
            backgroundColor: _AuthPalette.azure,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 10,
            ),
          ),
          child: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Send reset link'),
        ),
      ],
    );
  }
}
