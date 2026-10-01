import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The five accent choices. Saffron is the brand colour and the default.
///
/// Each carries the text colour that passes contrast on it, so the rule
/// "never white on a light accent" is enforced by the palette rather than
/// remembered on every screen.
enum AccentColour {
  saffron('Saffron', Color(0xFFF0A020), Color(0xFF141210)),
  ocean('Ocean', Color(0xFF2F6FED), Colors.white),
  berry('Berry', Color(0xFFE0409A), Colors.white),
  matcha('Matcha', Color(0xFF2E9E63), Colors.white),
  ember('Ember', Color(0xFFE2593F), Colors.white);

  const AccentColour(this.label, this.colour, this.onColour);

  final String label;
  final Color colour;
  final Color onColour;
}

enum TextScale {
  small('Small', 0.90),
  standard('Default', 1.00),
  large('Large', 1.15),
  extraLarge('Extra large', 1.30);

  const TextScale(this.label, this.factor);
  final String label;
  final double factor;
}

/// Corner treatment across the whole app.
enum UiStyle {
  rounded('Rounded', 16, 12, 999),
  soft('Soft', 10, 8, 20),
  crisp('Crisp', 4, 4, 6);

  const UiStyle(this.label, this.card, this.input, this.pill);

  final String label;
  final double card;
  final double input;
  final double pill;
}

enum AppLanguage {
  english('English', 'English', 'en'),
  hindi('Hindi', '\u0939\u093f\u0928\u094d\u0926\u0940', 'hi'),
  chinese('Chinese', '\u7b80\u4f53\u4e2d\u6587', 'zh'),
  vietnamese('Vietnamese', 'Ti\u1ebfng Vi\u1ec7t', 'vi');

  const AppLanguage(this.englishName, this.nativeName, this.code);

  final String englishName;
  final String nativeName;
  final String code;
}

/// Appearance and language preferences.
///
/// Changes apply immediately so the person can see them, but the previous
/// state is held until they accept or discard. That is what drives the
/// "N changes / Discard / Review" bar: live preview without committing.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs) {
    _load();
  }

  static const _kDark = 'ap_dark';
  static const _kAccent = 'ap_accent';
  static const _kTextScale = 'ap_text';
  static const _kUiStyle = 'ap_ui';
  static const _kLanguage = 'ap_lang';
  static const _kPushNotifications = 'ap_push';
  static const _kMessageAlerts = 'ap_msg';
  static const _kPromotionAlerts = 'ap_promo';
  static const _kSound = 'ap_sound';
  static const _kVibration = 'ap_vibe';

  final SharedPreferences _prefs;

  static Future<AppSettings> open() async =>
      AppSettings._(await SharedPreferences.getInstance());

  // ------------------------------------------------------------- values

  bool darkMode = false;
  AccentColour accent = AccentColour.saffron;
  TextScale textScale = TextScale.standard;
  UiStyle uiStyle = UiStyle.rounded;
  AppLanguage language = AppLanguage.english;

  bool pushNotifications = true;
  bool messageAlerts = true;
  bool promotionAlerts = false;
  bool sound = true;
  bool vibration = true;

  void _load() {
    darkMode = _prefs.getBool(_kDark) ?? false;
    accent = AccentColour.values[
        (_prefs.getInt(_kAccent) ?? 0).clamp(0, AccentColour.values.length - 1)];
    textScale = TextScale.values[
        (_prefs.getInt(_kTextScale) ?? 1).clamp(0, TextScale.values.length - 1)];
    uiStyle = UiStyle.values[
        (_prefs.getInt(_kUiStyle) ?? 0).clamp(0, UiStyle.values.length - 1)];
    language = AppLanguage.values[
        (_prefs.getInt(_kLanguage) ?? 0).clamp(0, AppLanguage.values.length - 1)];
    pushNotifications = _prefs.getBool(_kPushNotifications) ?? true;
    messageAlerts = _prefs.getBool(_kMessageAlerts) ?? true;
    promotionAlerts = _prefs.getBool(_kPromotionAlerts) ?? false;
    sound = _prefs.getBool(_kSound) ?? true;
    vibration = _prefs.getBool(_kVibration) ?? true;
  }

  Future<void> _save() async {
    await _prefs.setBool(_kDark, darkMode);
    await _prefs.setInt(_kAccent, accent.index);
    await _prefs.setInt(_kTextScale, textScale.index);
    await _prefs.setInt(_kUiStyle, uiStyle.index);
    await _prefs.setInt(_kLanguage, language.index);
    await _prefs.setBool(_kPushNotifications, pushNotifications);
    await _prefs.setBool(_kMessageAlerts, messageAlerts);
    await _prefs.setBool(_kPromotionAlerts, promotionAlerts);
    await _prefs.setBool(_kSound, sound);
    await _prefs.setBool(_kVibration, vibration);
  }

  // ------------------------------------------------- staged editing

  Map<String, Object>? _snapshot;

  Map<String, Object> get _current => {
        'dark': darkMode,
        'accent': accent.index,
        'text': textScale.index,
        'ui': uiStyle.index,
        'lang': language.index,
        'push': pushNotifications,
        'msg': messageAlerts,
        'promo': promotionAlerts,
        'sound': sound,
        'vibe': vibration,
      };

  /// Call when a settings screen opens, so Discard has something to go back
  /// to. Calling it again while editing does nothing, which keeps the count
  /// correct when the person moves between settings screens.
  void beginEditing() {
    _snapshot ??= _current;
  }

  int get changeCount {
    final before = _snapshot;
    if (before == null) return 0;
    final now = _current;
    return now.entries.where((e) => before[e.key] != e.value).length;
  }

  bool get hasChanges => changeCount > 0;

  /// Puts everything back to how it was when editing started.
  void discard() {
    final before = _snapshot;
    if (before == null) return;
    darkMode = before['dark']! as bool;
    accent = AccentColour.values[before['accent']! as int];
    textScale = TextScale.values[before['text']! as int];
    uiStyle = UiStyle.values[before['ui']! as int];
    language = AppLanguage.values[before['lang']! as int];
    pushNotifications = before['push']! as bool;
    messageAlerts = before['msg']! as bool;
    promotionAlerts = before['promo']! as bool;
    sound = before['sound']! as bool;
    vibration = before['vibe']! as bool;
    _snapshot = null;
    _save();
    notifyListeners();
  }

  /// Accepts the changes and writes them to the device.
  Future<void> commit() async {
    _snapshot = null;
    await _save();
    notifyListeners();
  }

  /// A short description of what changed, for the review sheet.
  List<String> get changeSummary {
    final before = _snapshot;
    if (before == null) return const [];
    return [
      if (before['dark'] != darkMode)
        darkMode ? 'Switched to dark mode' : 'Switched to light mode',
      if (before['accent'] != accent.index) 'Theme colour: ${accent.label}',
      if (before['text'] != textScale.index) 'Text size: ${textScale.label}',
      if (before['ui'] != uiStyle.index) 'UI style: ${uiStyle.label}',
      if (before['lang'] != language.index)
        'Language: ${language.nativeName}',
      if (before['push'] != pushNotifications)
        pushNotifications
            ? 'Push notifications on'
            : 'Push notifications off',
      if (before['msg'] != messageAlerts)
        messageAlerts ? 'Order updates on' : 'Order updates off',
      if (before['promo'] != promotionAlerts)
        promotionAlerts ? 'Offers on' : 'Offers off',
      if (before['sound'] != sound) sound ? 'Sound on' : 'Sound off',
      if (before['vibe'] != vibration)
        vibration ? 'Vibration on' : 'Vibration off',
    ];
  }

  // -------------------------------------------------------- setters

  void _set(VoidCallback change) {
    beginEditing();
    change();
    _save();
    notifyListeners();
  }

  void setDarkMode(bool v) => _set(() => darkMode = v);
  void toggleDarkMode() => _set(() => darkMode = !darkMode);
  void setAccent(AccentColour v) => _set(() => accent = v);
  void setTextScale(TextScale v) => _set(() => textScale = v);
  void setUiStyle(UiStyle v) => _set(() => uiStyle = v);
  void setLanguage(AppLanguage v) => _set(() => language = v);
  void setPushNotifications(bool v) => _set(() => pushNotifications = v);
  void setMessageAlerts(bool v) => _set(() => messageAlerts = v);
  void setPromotionAlerts(bool v) => _set(() => promotionAlerts = v);
  void setSound(bool v) => _set(() => sound = v);
  void setVibration(bool v) => _set(() => vibration = v);

  /// One-line summary for the Appearance row on the settings screen.
  String get appearanceSummary =>
      '${accent.label} \u00b7 ${textScale.label} text \u00b7 ${uiStyle.label}';
}

/// Set once at startup by main(). Read by the token classes below, which have
/// to be usable from places that do not have a BuildContext.
AppSettings? _active;

AppSettings get settings => _active ?? (throw StateError(
    'AppSettings.install() must be called before the app builds'));

void installSettings(AppSettings value) => _active = value;

/// Makes a settings change reach the screens.
///
/// The colour, spacing and type tokens are plain static getters, so a widget
/// that reads them has no dependency on anything and Flutter never marks it
/// dirty. Rebuilding from the root does not help either: pushed routes cache
/// their content, and a `const` widget is skipped entirely.
///
/// So every screen calls [watch] once at the top of build. That registers a
/// real dependency on this notifier, and changing a setting rebuilds them all.
class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope({
    super.key,
    required AppSettings super.notifier,
    required super.child,
  });

  /// Call as the first line of build in any widget that reads AppColors,
  /// AppSpacing or AppTypography.
  static void watch(BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<SettingsScope>();
  }

  static AppSettings of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'SettingsScope is missing above this widget');
    return scope!.notifier!;
  }
}
