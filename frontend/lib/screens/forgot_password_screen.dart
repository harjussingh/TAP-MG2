import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Step one of a password reset: ask for the email.
///
/// The backend emails a link containing a token, not a six-digit code, so
/// there is nothing to type here afterwards. The link opens the app on
/// ResetPasswordScreen with the token attached.
///
/// `POST /auth/forgot-password` always returns success whether or not the
/// account exists, so this screen must not reveal anything either.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.email = ''});

  final String email;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _email =
      TextEditingController(text: widget.email);

  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final value = _email.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Enter your email address');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      setState(() => _error = 'That does not look like an email address');
      return;
    }

    setState(() {
      _error = null;
      _busy = true;
    });

    // TODO(api): await api.forgotPassword(value);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    setState(() {
      _busy = false;
      _sent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Scaffold(
      backgroundColor: AppColors.header,
      body: Stack(
        children: [
          const AuthGlow(),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                                begin: const Offset(0.12, 0), end: Offset.zero)
                            .animate(animation),
                        child: child,
                      ),
                    ),
                    child: _sent ? _sentPane() : _formPane(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _formPane() => AuthPane(
        key: const ValueKey('form'),
        icon: Icons.lock_outline,
        title: 'Forgot password?',
        subtitle:
            'It happens. Enter the email on your account and we will send you '
            'a link to set a new password.',
        children: [
          AuthField(
            controller: _email,
            hint: 'Email address',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            error: _error,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthButton(label: 'Send reset link', busy: _busy, onPressed: _send),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Remembered it? Log in',
                style: AppTypography.secondary.copyWith(color: Colors.white54)),
          ),
        ],
      );

  Widget _sentPane() => AuthPane(
        key: const ValueKey('sent'),
        icon: Icons.mark_email_read_outlined,
        title: 'Check your email',
        subtitle:
            'If an account exists for ${_email.text.trim()}, a reset link is '
            'on its way. The link opens this app and expires in 30 minutes.',
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 20, color: AppColors.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'No email after a few minutes? Check your spam folder, or '
                    'try again in case of a typo.',
                    style: AppTypography.secondary
                        .copyWith(color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthButton(
            label: 'Send again',
            busy: _busy,
            onPressed: () => setState(() => _sent = false),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Back to log in',
                style: AppTypography.secondary.copyWith(color: Colors.white54)),
          ),
        ],
      );
}

// ------------------------------------------------- shared auth-screen pieces

/// The saffron glow behind the dark entry screens.
class AuthGlow extends StatelessWidget {
  const AuthGlow({super.key});

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.8),
              radius: 1.0,
              colors: [
                AppColors.primary.withValues(alpha: 0.16),
                AppColors.header.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthPane extends StatelessWidget {
  const AuthPane({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
          AppSpacing.xl, AppSpacing.screenPadding, AppSpacing.xl),
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppSpacing.lg),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
          ),
          child: Icon(icon, color: AppColors.primary, size: 26),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(title,
            style: AppTypography.screenTitle
                .copyWith(color: Colors.white, fontSize: 30)),
        const SizedBox(height: AppSpacing.sm),
        Text(subtitle,
            style: AppTypography.secondary.copyWith(color: Colors.white54)),
        const SizedBox(height: AppSpacing.xl),
        ...children,
      ],
    );
  }
}

class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.error,
    this.valid = false,
    this.trailing,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? error;
  final bool valid;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final hasError = widget.error != null;
    final colour = hasError
        ? AppColors.error
        : widget.valid
            ? AppColors.success
            : _focused
                ? AppColors.primary
                : Colors.white.withValues(alpha: 0.12);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: AppSpacing.inputHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: hasError
                  ? AppColors.error.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(
                  color: colour, width: _focused || hasError ? 1.6 : 1),
            ),
            child: Row(
              children: [
                Icon(widget.icon,
                    size: 20,
                    color: hasError
                        ? AppColors.error
                        : _focused
                            ? AppColors.primary
                            : Colors.white38),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    obscureText: widget.obscure,
                    keyboardType: widget.keyboardType,
                    onChanged: widget.onChanged,
                    style: AppTypography.body.copyWith(color: Colors.white),
                    cursorColor: AppColors.primary,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: widget.hint,
                      hintStyle:
                          AppTypography.body.copyWith(color: Colors.white38),
                    ),
                  ),
                ),
                if (widget.valid)
                  const Icon(Icons.check_circle,
                      size: 20, color: AppColors.success),
                if (widget.trailing != null) widget.trailing!,
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topLeft,
            child: hasError
                ? Padding(
                    padding: const EdgeInsets.only(
                        top: AppSpacing.xs, left: AppSpacing.xs),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 14, color: AppColors.error),
                        const SizedBox(width: AppSpacing.xs),
                        Text(widget.error!,
                            style: AppTypography.secondary
                                .copyWith(color: AppColors.error)),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: busy
              ? SizedBox(
                  key: ValueKey('busy'),
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.base),
                )
              : Text(label, key: ValueKey(label)),
        ),
      ),
    );
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key, required this.ok, required this.label});

  final bool ok;
  final String label;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ok ? AppColors.success : Colors.white.withValues(alpha: 0.10),
          ),
          child:
              ok ? const Icon(Icons.check, size: 11, color: Colors.white) : null,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(label,
            style: AppTypography.secondary
                .copyWith(color: ok ? Colors.white70 : Colors.white38)),
      ],
    );
  }
}
