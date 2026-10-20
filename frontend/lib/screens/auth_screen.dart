import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/user_profile.dart';
import '../theme/app_colors.dart';
import '../theme/app_settings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/kitchen_scene.dart';
import '../widgets/robomos_logo.dart';
import 'forgot_password_screen.dart';
import 'table_number_screen.dart';

enum AuthMode { signIn, signUp }

/// Sign in and sign up.
///
/// An illustrated scene fills the top of the screen and the form sits on a
/// white sheet curving over it. The scene is the Fishbowl machine dropping
/// ingredients into a bowl, so the first thing anyone sees is what the
/// restaurant does, and the sheet rises to meet the extra fields when the mode
/// changes rather than the form scrolling away under a fixed picture.
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
    with TickerProviderStateMixin {
  late AuthMode _mode = widget.mode;

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscure = true;
  bool _busy = false;
  bool _keepSignedIn = true;
  String? _failure;

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..forward();

  /// One slow loop drives the whole scene: clouds, sun and the falling
  /// ingredients all read from it.
  late final AnimationController _scene = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void dispose() {
    _intro.dispose();
    _scene.dispose();
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
      _failure = null;
      _formKey.currentState?.reset();
    });
  }

  Widget _stagger(double start, Widget child, {double rise = 18}) {
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
          offset: Offset(0, rise * (1 - curve.value)),
          child: child,
        ),
      ),
      child: child,
    );
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
    // The backend rule: 8 to 72 characters with at least one letter and one
    // number. Checking here saves a round trip to be told the same thing.
    if (value.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Include a number';
    if (!RegExp(r'[A-Za-z]').hasMatch(value)) return 'Include a letter';
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
    setState(() {
      _busy = true;
      _failure = null;
    });

    // TODO(api): RoboKitchenApi.login / register, then mergeGuestCart().
    // The role is read from the returned token on the server, never sent.
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

  @override
  Widget build(BuildContext context) {
    SettingsScope.watch(context);
    final still = MediaQuery.disableAnimationsOf(context);

    // Everything is measured from the space actually available, not from the
    // screen size. When the keyboard opens the Scaffold shrinks this box, the
    // scene shrinks with it, and the form keeps its room. Reading the screen
    // height instead is what put the sheet in the wrong place.
    return Scaffold(
      // Matches the sheet, so the strip the sheet is lifted over is invisible.
      backgroundColor: AppColors.card,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final sceneHeight = (constraints.maxHeight *
                  (_isSignUp ? 0.30 : 0.38))
              .clamp(130.0, 330.0);

          return Column(
            children: [
              SizedBox(
                height: sceneHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // The scene repaints every frame, so it is boundaried off
                    // from the form, which does not.
                    RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _scene,
                        builder: (context, _) =>
                            KitchenScene(t: _scene.value, still: still),
                      ),
                    ),
                    SafeArea(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: _stagger(0.00, const _TopBar(), rise: 10),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Transform.translate(
                  offset: const Offset(0, -AppSpacing.xl),
                  child: _stagger(0.12, _sheet(), rise: 26),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sheet() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusSheet)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusSheet)),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl,
                AppSpacing.xl, AppSpacing.xl),
            children: [
              _Headline(isSignUp: _isSignUp),
              const SizedBox(height: AppSpacing.xl),
              if (_failure != null) ...[
                _FailureNote(message: _failure!),
                const SizedBox(height: AppSpacing.md),
              ],
              // Keeps the form growing and shrinking smoothly as the extra
              // fields appear between the two modes.
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Column(children: _fields()),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SubmitButton(
                label: _isSignUp ? 'Create account' : 'Log in',
                busy: _busy,
                onTap: _submit,
              ),
              const SizedBox(height: AppSpacing.lg),
              _SwitchPrompt(
                isSignUp: _isSignUp,
                onTap: () => _switchTo(
                    _isSignUp ? AuthMode.signIn : AuthMode.signUp),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _fields() {
    return [
      if (_isSignUp)
        _Field(
          key: const ValueKey('name'),
          controller: _name,
          hint: 'Full name',
          icon: Icons.person_outline,
          validator: _validateName,
          textCapitalization: TextCapitalization.words,
        ),
      _Field(
        controller: _email,
        hint: 'Email',
        icon: Icons.mail_outline,
        keyboardType: TextInputType.emailAddress,
        validator: _validateEmail,
      ),
      _Field(
        controller: _password,
        hint: 'Password',
        icon: Icons.lock_outline,
        obscure: _obscure,
        validator: _validatePassword,
        trailing: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(
              _obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 21,
              color: AppColors.textSecondary),
          tooltip: _obscure ? 'Show password' : 'Hide password',
        ),
      ),
      if (_isSignUp)
        _Field(
          key: const ValueKey('confirm'),
          controller: _confirm,
          hint: 'Confirm password',
          icon: Icons.lock_outline,
          obscure: _obscure,
          validator: _validateConfirm,
        ),
      if (!_isSignUp)
        _OptionsRow(
          keepSignedIn: _keepSignedIn,
          onKeepChanged: (v) => setState(() => _keepSignedIn = v),
          onForgot: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ForgotPasswordScreen(email: _email.text.trim()),
            ),
          ),
        ),
    ];
  }
}

// ----------------------------------------------------------------- top bar

/// A white circular back button and the brand, floating on the illustration.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      child: Row(
        children: [
          Material(
            color: AppColors.card,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: AppSpacing.minTouchTarget,
                height: AppSpacing.minTouchTarget,
                child: Icon(Icons.arrow_back,
                    size: 21, color: AppColors.base),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          RobomosLogo(size: 36, onDark: false),
          const SizedBox(width: AppSpacing.sm),
          Text('Robomos',
              style: AppTypography.cardTitle.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.base,
                  shadows: [
                    Shadow(
                        color: AppColors.card.withValues(alpha: 0.8),
                        blurRadius: 8),
                  ])),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- headline

class _Headline extends StatelessWidget {
  const _Headline({required this.isSignUp});

  final bool isSignUp;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
                  .animate(animation),
          child: child,
        ),
      ),
      child: Column(
        key: ValueKey(isSignUp),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isSignUp ? 'Create account' : 'Welcome back',
              style: AppTypography.screenTitle
                  .copyWith(fontSize: 30, height: 1.1, letterSpacing: -0.6)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isSignUp
                ? 'Save your bowls, keep your orders and skip the queue.'
                : 'Log in to pick up where you left off.',
            style: AppTypography.secondary.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ field

/// Filled, borderless and softly rounded, following the reference. A filled
/// field reads as something to type into without needing an outline, which
/// keeps four of them on one screen from looking like a grid of boxes.
class _Field extends StatefulWidget {
  const _Field({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.trailing,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? trailing;
  final TextCapitalization textCapitalization;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: FormField<String>(
        validator: (_) => widget.validator?.call(widget.controller.text),
        builder: (field) {
          final hasError = field.errorText != null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 62,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: hasError
                      ? AppColors.error.withValues(alpha: 0.06)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                  border: Border.all(
                    color: hasError
                        ? AppColors.error
                        : _focused
                            ? AppColors.primary
                            : Colors.transparent,
                    width: 1.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(widget.icon,
                        size: 21,
                        color: hasError
                            ? AppColors.error
                            : _focused
                                ? AppColors.primary
                                : AppColors.textSecondary),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _focus,
                        obscureText: widget.obscure,
                        keyboardType: widget.keyboardType,
                        textCapitalization: widget.textCapitalization,
                        style: AppTypography.body,
                        cursorColor: AppColors.primary,
                        onChanged: (_) {
                          // Clear the error as soon as it is fixed, rather
                          // than making the person submit again to find out.
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
                              .copyWith(color: AppColors.textSecondary),
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
                            top: AppSpacing.xs, left: AppSpacing.md),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                size: 14, color: AppColors.error),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(field.errorText!,
                                  style: AppTypography.label
                                      .copyWith(color: AppColors.error)),
                            ),
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

// ----------------------------------------------------------------- pieces

class _OptionsRow extends StatelessWidget {
  const _OptionsRow({
    required this.keepSignedIn,
    required this.onKeepChanged,
    required this.onForgot,
  });

  final bool keepSignedIn;
  final ValueChanged<bool> onKeepChanged;
  final VoidCallback onForgot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          InkWell(
            onTap: () => onKeepChanged(!keepSignedIn),
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: keepSignedIn
                          ? AppColors.primary
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: keepSignedIn
                              ? AppColors.primary
                              : AppColors.border,
                          width: 1.8),
                    ),
                    child: keepSignedIn
                        ? Icon(Icons.check,
                            size: 15, color: AppColors.onPrimary)
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Keep me signed in', style: AppTypography.secondary),
                ],
              ),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onForgot,
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                minimumSize: const Size(0, AppSpacing.minTouchTarget)),
            child: Text('Forgot password?',
                style: AppTypography.secondary.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// A tall pill with the arrow, matching the reference. The arrow slides a
/// little on press, which is the only feedback a flat button gets.
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 62,
      child: ElevatedButton(
        onPressed: busy ? null : onTap,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: busy
              ? SizedBox(
                  key: const ValueKey('busy'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: AppColors.onPrimary),
                )
              : Row(
                  key: ValueKey(label),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label,
                        style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.onPrimary)),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(Icons.arrow_forward,
                        size: 19, color: AppColors.onPrimary),
                  ],
                ),
        ),
      ),
    );
  }
}

class _FailureNote extends StatelessWidget {
  const _FailureNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 20, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message,
                style:
                    AppTypography.secondary.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _SwitchPrompt extends StatelessWidget {
  const _SwitchPrompt({required this.isSignUp, required this.onTap});

  final bool isSignUp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
            minimumSize: const Size(0, AppSpacing.minTouchTarget)),
        child: RichText(
          text: TextSpan(
            style: AppTypography.secondary,
            children: [
              TextSpan(
                  text: isSignUp
                      ? 'Already have an account? '
                      : "Don't have an account? "),
              TextSpan(
                text: isSignUp ? 'Log in' : 'Create an account',
                style: AppTypography.secondary.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
