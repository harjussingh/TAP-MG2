import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/order.dart';
import '../models/user_profile.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/robomos_logo.dart';
import 'forgot_password_screen.dart';
import 'table_number_screen.dart';

enum AuthMode { signIn, signUp }

/// Sign in and sign up on one screen, with an animated toggle between them.
///
/// Dark, matching the QR and continue-as screens, so the whole entry flow
/// feels like one piece before the app opens into its light interface.
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.mode = AuthMode.signIn,
    this.linkGuestOrders = false,
    this.continueToTable = true,
  });

  final AuthMode mode;

  /// True when a guest is upgrading from their profile, so their existing
  /// orders are linked rather than discarded.
  final bool linkGuestOrders;

  /// False when opened from inside the app, where the table is already known.
  final bool continueToTable;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late AuthMode _mode = widget.mode;

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscure = true;
  bool _busy = false;
  bool _keepSignedIn = true;

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _intro.dispose();
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isSignUp => _mode == AuthMode.signUp;

  void _switchTo(AuthMode mode) {
    if (_mode == mode) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _mode = mode;
      _formKey.currentState?.reset();
    });
  }

  // ------------------------------------------------------------ validation

  String? _validateName(String? v) {
    if (!_isSignUp) return null;
    return (v ?? '').trim().isEmpty ? 'Enter your name' : null;
  }

  String? _validateEmail(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Enter your email address';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      return 'That does not look like an email address';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Enter your password';
    if (!_isSignUp) return null;
    if (value.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Include at least one number';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (!_isSignUp) return null;
    return (v ?? '') == _password.text ? null : 'Passwords do not match';
  }

  // ---------------------------------------------------------------- submit

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);

    // TODO(backend): RoboKitchenApi.login / register, then use the returned
    // token. The role is read from that token on the server.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final state = AppScope.of(context);
    final linked = widget.linkGuestOrders ? state.history.length : 0;
    final email = _email.text.trim();

    state.signIn(
      UserProfile(
        name: _isSignUp ? _name.text.trim() : email.split('@').first,
        email: email,
      ),
      token: 'demo-token',
    );

    if (widget.continueToTable) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const TableNumberScreen()),
      );
      return;
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(linked > 0
            ? 'Account created. $linked past order'
                '${linked == 1 ? '' : 's'} linked to it.'
            : 'Welcome to Robomos.'),
      ),
    );
  }

  void _continueAsGuest() {
    AppScope.of(context).setRole(UserRole.guest);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const TableNumberScreen()),
    );
  }

  /// Staggered entrance: each piece fades and rises a moment after the last.
  Widget _stagger(double start, Widget child) {
    final curve = CurvedAnimation(
      parent: _intro,
      curve: Interval(start, (start + 0.55).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (context, _) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - curve.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Scaffold(
      backgroundColor: AppColors.header,
      body: Stack(
        children: [
          const _Glow(),
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
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
                        0, AppSpacing.screenPadding, AppSpacing.xl),
                    children: [
                      _stagger(0.00, const _Brand()),
                      const SizedBox(height: AppSpacing.xl),
                      _stagger(0.10, _Heading(isSignUp: _isSignUp)),
                      const SizedBox(height: AppSpacing.xl),
                      _stagger(0.20, _card()),
                      const SizedBox(height: AppSpacing.lg),
                      _stagger(0.32, _guestRow()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.xl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _ModeToggle(mode: _mode, onChanged: _switchTo),
            const SizedBox(height: AppSpacing.lg),

            // AnimatedSize keeps the card growing and shrinking smoothly as
            // fields appear and disappear between the two modes.
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                children: [
                  if (_isSignUp)
                    _AuthField(
                      key: const ValueKey('name'),
                      controller: _name,
                      hint: 'Full name',
                      icon: Icons.person_outline,
                      validator: _validateName,
                    ),
                  _AuthField(
                    controller: _email,
                    hint: 'Email address',
                    icon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                  ),
                  _AuthField(
                    controller: _password,
                    hint: 'Password',
                    icon: Icons.lock_outline,
                    obscure: _obscure,
                    validator: _validatePassword,
                    trailing: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: Colors.white54,
                      ),
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                    ),
                  ),
                  if (_isSignUp)
                    _AuthField(
                      key: const ValueKey('confirm'),
                      controller: _confirm,
                      hint: 'Confirm password',
                      icon: Icons.lock_outline,
                      obscure: _obscure,
                      validator: _validateConfirm,
                    ),
                ],
              ),
            ),

            if (!_isSignUp)
              Row(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Checkbox(
                      value: _keepSignedIn,
                      onChanged: (v) =>
                          setState(() => _keepSignedIn = v ?? false),
                      activeColor: AppColors.primary,
                      checkColor: AppColors.onPrimary,
                      side: const BorderSide(color: Colors.white38),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Keep me signed in',
                      style: AppTypography.secondary
                          .copyWith(color: Colors.white70)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ForgotPasswordScreen(email: _email.text.trim()),
                      ),
                    ),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        minimumSize: const Size(0, AppSpacing.minTouchTarget)),
                    child: Text('Forgot password?',
                        style: AppTypography.secondary
                            .copyWith(color: AppColors.primary)),
                  ),
                ],
              ),

            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _busy
                      ? SizedBox(
                          key: ValueKey('busy'),
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.onPrimary),
                        )
                      : Text(_isSignUp ? 'Create account' : 'Sign in',
                          key: ValueKey(_mode)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _guestRow() {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider(color: Colors.white24)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text('OR',
                  style: AppTypography.label.copyWith(
                      color: Colors.white38, letterSpacing: 1.6)),
            ),
            const Expanded(child: Divider(color: Colors.white24)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (widget.continueToTable)
          SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonHeight,
            child: OutlinedButton.icon(
              onPressed: _continueAsGuest,
              icon: const Icon(Icons.person_outline, size: 20),
              label: const Text('Continue as a guest'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                ),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        TextButton(
          onPressed: () =>
              _switchTo(_isSignUp ? AuthMode.signIn : AuthMode.signUp),
          child: RichText(
            text: TextSpan(
              style: AppTypography.secondary.copyWith(color: Colors.white54),
              children: [
                TextSpan(
                    text: _isSignUp
                        ? 'Already with Robomos? '
                        : 'New to Robomos? '),
                TextSpan(
                  text: _isSignUp ? 'Sign in' : 'Create an account',
                  style: AppTypography.secondary.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- pieces

/// A soft saffron glow behind the top of the screen, so the dark background
/// is not flat.
class _Glow extends StatelessWidget {
  const _Glow();

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.75),
              radius: 1.0,
              colors: [
                AppColors.primary.withValues(alpha: 0.18),
                AppColors.header.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Column(
      children: [
        const RobomosWordmark(size: 64),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.isSignUp});

  final bool isSignUp;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(0, 0.25), end: Offset.zero)
              .animate(animation),
          child: child,
        ),
      ),
      child: Column(
        key: ValueKey(isSignUp),
        children: [
          Text(isSignUp ? 'Make it yours.' : 'Welcome back.',
              textAlign: TextAlign.center,
              style: AppTypography.screenTitle
                  .copyWith(color: Colors.white, fontSize: 32)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isSignUp
                ? 'Save your bowls, keep your orders, skip the queue.'
                : 'Pick up where you left off \u2014 your bowls are waiting.',
            textAlign: TextAlign.center,
            style: AppTypography.secondary.copyWith(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

/// The sliding pill. The indicator animates between halves rather than
/// snapping, which is what makes the switch feel considered.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});

  final AuthMode mode;
  final ValueChanged<AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    return Container(
      height: AppSpacing.minTouchTarget,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final half = constraints.maxWidth / 2;
          return Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: mode == AuthMode.signIn
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  width: half,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                ),
              ),
              Row(
                children: [
                  _half('Sign in', AuthMode.signIn),
                  _half('Sign up', AuthMode.signUp),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _half(String label, AuthMode value) {
    final selected = mode == value;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: () => onChanged(value),
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: AppTypography.body.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                // Dark text on saffron, white elsewhere. Same contrast rule
                // as the rest of the app.
                color: selected ? AppColors.base : Colors.white70,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

/// A field that lights up on focus and turns red with an inline message when
/// validation fails.
class _AuthField extends StatefulWidget {
  const _AuthField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.trailing,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? trailing;

  @override
  State<_AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<_AuthField> {
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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: FormField<String>(
        validator: (_) => widget.validator?.call(widget.controller.text),
        builder: (field) {
          final hasError = field.errorText != null;
          final borderColour = hasError
              ? AppColors.error
              : _focused
                  ? AppColors.primary
                  : Colors.white.withValues(alpha: 0.12);

          return Column(
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
                      color: borderColour, width: _focused || hasError ? 1.6 : 1),
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
                        style:
                            AppTypography.body.copyWith(color: Colors.white),
                        cursorColor: AppColors.primary,
                        onChanged: (v) {
                          if (hasError) field.validate();
                        },
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          hintText: widget.hint,
                          hintStyle: AppTypography.body
                              .copyWith(color: Colors.white38),
                        ),
                      ),
                    ),
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
                            Text(field.errorText!,
                                style: AppTypography.secondary
                                    .copyWith(color: AppColors.error)),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          );
        },
      ),
    );
  }
}
