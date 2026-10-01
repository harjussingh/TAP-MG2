import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'forgot_password_screen.dart';

/// Step two of a password reset, opened by the link in the email.
///
/// The token comes from the deep link, not from the user. Register
/// `FRONTEND_URL/reset-password?token=...` as an app link on Android and pass
/// the token here.
///
/// Sends `POST /auth/reset-password {token, new_password}`. Backend rule:
/// 8 to 72 characters with at least one letter and one number. Resetting
/// signs the account out everywhere.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.token});

  final String token;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscure = true;
  bool _busy = false;
  bool _done = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
    _confirm.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _longEnough => _password.text.length >= 8;
  bool get _hasLetter => RegExp(r'[A-Za-z]').hasMatch(_password.text);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_password.text);
  bool get _matches =>
      _confirm.text.isNotEmpty && _confirm.text == _password.text;
  bool get _canSubmit => _longEnough && _hasLetter && _hasNumber && _matches;

  String get _strength {
    var score = 0;
    if (_longEnough) score++;
    if (_hasNumber) score++;
    if (RegExp(r'[A-Z]').hasMatch(_password.text)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(_password.text)) score++;
    return const ['Weak', 'Weak', 'Fair', 'Good', 'Strong'][score];
  }

  Color get _strengthColour => switch (_strength) {
        'Strong' || 'Good' => AppColors.success,
        'Fair' => AppColors.primary,
        _ => AppColors.error,
      };

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _failure = null;
    });

    // TODO(api): await api.resetPassword(widget.token, _password.text);
    // A 400 here means the link expired or was already used.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    setState(() {
      _busy = false;
      _done = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
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
            child: _done ? const _Success() : _form(),
          ),
        ],
      ),
    );
  }

  Widget _form() => AuthPane(
        icon: Icons.vpn_key_outlined,
        title: 'Create new password',
        subtitle:
            'Make it one you have not used before. You will be signed out on '
            'your other devices.',
        children: [
          if (_failure != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                border: Border.all(color: AppColors.error),
              ),
              child: Text(_failure!,
                  style:
                      AppTypography.secondary.copyWith(color: AppColors.error)),
            ),
          ],
          AuthField(
            controller: _password,
            hint: 'New password',
            icon: Icons.lock_outline,
            obscure: _obscure,
            trailing: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: Colors.white54),
            ),
          ),
          AuthField(
            controller: _confirm,
            hint: 'Confirm password',
            icon: Icons.lock_outline,
            obscure: _obscure,
            valid: _matches,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              AuthCheck(ok: _longEnough, label: '8 characters'),
              const SizedBox(width: AppSpacing.lg),
              AuthCheck(ok: _hasLetter && _hasNumber, label: 'Letter + number'),
              const Spacer(),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: AppTypography.label.copyWith(
                    color: _password.text.isEmpty
                        ? Colors.white30
                        : _strengthColour,
                    fontWeight: FontWeight.w700),
                child: Text(_password.text.isEmpty ? '' : _strength),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AuthCheck(ok: _matches, label: 'Passwords match'),
          const SizedBox(height: AppSpacing.xl),
          AuthButton(
            label: 'Reset password',
            busy: _busy,
            onPressed: _canSubmit ? _submit : null,
          ),
        ],
      );
}

class _Success extends StatefulWidget {
  const _Success();

  @override
  State<_Success> createState() => _SuccessState();
}

class _SuccessState extends State<_Success>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: CurvedAnimation(parent: _c, curve: Curves.elasticOut),
            child: Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                  color: AppColors.success, shape: BoxShape.circle),
              child:
                  const Icon(Icons.check_rounded, size: 52, color: Colors.white),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FadeTransition(
            opacity: _c,
            child: Column(
              children: [
                Text('Password updated',
                    style: AppTypography.sectionHeading
                        .copyWith(color: Colors.white)),
                const SizedBox(height: AppSpacing.xs),
                Text('Taking you back to sign in...',
                    style: AppTypography.secondary
                        .copyWith(color: Colors.white54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
