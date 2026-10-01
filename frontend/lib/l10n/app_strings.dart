import '../theme/app_settings.dart';

/// Translations.
///
/// A plain map keyed by the language code, rather than Flutter's ARB
/// tooling, so the team can add a string without a code generation step. If
/// a key is missing in a language it falls back to English rather than
/// showing a blank, which is the behaviour you want during a demo.
///
/// Read as `S.t('settings')`.
class S {
  const S._();

  static String t(String key) {
    final code = settings.language.code;
    return _all[code]?[key] ?? _all['en']![key] ?? key;
  }

  static const Map<String, Map<String, String>> _all = {
    'en': {
      'settings': 'Settings',
      'settingsSubtitle': 'Make the app feel like yours',
      'personalisation': 'PERSONALISATION',
      'alerts': 'ALERTS',
      'account': 'ACCOUNT',
      'appearance': 'Appearance',
      'language': 'Language',
      'notifications': 'Notifications',
      'darkMode': 'Dark mode',
      'darkModeOn': 'Easy on the eyes at night',
      'darkModeOff': 'Tap for night-time',
      'themeColour': 'THEME COLOUR',
      'textSize': 'TEXT SIZE',
      'uiStyle': 'UI STYLE',
      'preview': 'Preview',
      'changes': 'changes',
      'change': 'change',
      'discard': 'Discard',
      'review': 'Review',
      'apply': 'Apply',
      'cancel': 'Cancel',
      'reviewChanges': 'Review changes',
      'noChanges': 'Nothing has changed yet',
      'keepChanges': 'Keep changes',
      'pushNotifications': 'Push notifications',
      'pushNotificationsHint': 'On for this device',
      'notifyMeAbout': 'NOTIFY ME ABOUT',
      'orderUpdates': 'Order updates',
      'orderUpdatesHint': 'When your bowl is ready',
      'offers': 'Offers and news',
      'offersHint': 'Occasional emails about new bowls',
      'soundAndVibration': 'SOUND AND VIBRATION',
      'sound': 'Sound',
      'soundHint': 'A soft chime for new alerts',
      'vibration': 'Vibration',
      'vibrationHint': 'A gentle buzz for new alerts',
      'chooseLanguage': 'Choose your language',
      'languageHint':
          'The menu and your order still come from the restaurant in English.',
      'order': 'Order',
      'history': 'History',
      'saved': 'Saved',
      'profile': 'Profile',
      'logOut': 'Log out',
      'editDetails': 'Edit personal details',
      'dietary': 'Dietary preferences',
      'member': 'Member',
      'guest': 'Guest',
    },
    'hi': {
      'settings': '\u0938\u0947\u091f\u093f\u0902\u0917\u094d\u0938',
      'settingsSubtitle':
          '\u0910\u092a \u0915\u094b \u0905\u092a\u0928\u0947 \u0939\u093f\u0938\u093e\u092c \u0938\u0947 \u092c\u0928\u093e\u090f\u0901',
      'personalisation':
          '\u0935\u094d\u092f\u0915\u094d\u0924\u093f\u0917\u0924 \u092c\u0928\u093e\u090f\u0901',
      'alerts': '\u0905\u0932\u0930\u094d\u091f',
      'account': '\u0916\u093e\u0924\u093e',
      'appearance': '\u0926\u093f\u0916\u093e\u0935\u091f',
      'language': '\u092d\u093e\u0937\u093e',
      'notifications':
          '\u0938\u0942\u091a\u0928\u093e\u090f\u0901',
      'darkMode': '\u0921\u093e\u0930\u094d\u0915 \u092e\u094b\u0921',
      'darkModeOn':
          '\u0930\u093e\u0924 \u092e\u0947\u0902 \u0906\u0902\u0916\u094b\u0902 \u0915\u0947 \u0932\u093f\u090f \u0906\u0930\u093e\u092e\u0926\u093e\u092f\u0915',
      'darkModeOff':
          '\u0930\u093e\u0924 \u0915\u0947 \u0932\u093f\u090f \u091f\u0948\u092a \u0915\u0930\u0947\u0902',
      'themeColour': '\u0925\u0940\u092e \u0930\u0902\u0917',
      'textSize':
          '\u091f\u0947\u0915\u094d\u0938\u094d\u091f \u0915\u093e \u0906\u0915\u093e\u0930',
      'uiStyle': '\u092f\u0942\u0906\u0908 \u0938\u094d\u091f\u093e\u0907\u0932',
      'preview': '\u092a\u0942\u0930\u094d\u0935\u093e\u0935\u0932\u094b\u0915\u0928',
      'changes': '\u092c\u0926\u0932\u093e\u0935',
      'change': '\u092c\u0926\u0932\u093e\u0935',
      'discard': '\u0930\u0926\u094d\u0926 \u0915\u0930\u0947\u0902',
      'review': '\u0938\u092e\u0940\u0915\u094d\u0937\u093e',
      'apply': '\u0932\u093e\u0917\u0942 \u0915\u0930\u0947\u0902',
      'cancel': '\u0930\u0926\u094d\u0926',
      'reviewChanges':
          '\u092c\u0926\u0932\u093e\u0935 \u0926\u0947\u0916\u0947\u0902',
      'noChanges':
          '\u0905\u092d\u0940 \u0915\u0941\u091b \u0928\u0939\u0940\u0902 \u092c\u0926\u0932\u093e',
      'keepChanges':
          '\u092c\u0926\u0932\u093e\u0935 \u0930\u0916\u0947\u0902',
      'pushNotifications':
          '\u092a\u0941\u0936 \u0938\u0942\u091a\u0928\u093e\u090f\u0901',
      'pushNotificationsHint':
          '\u0907\u0938 \u0921\u093f\u0935\u093e\u0907\u0938 \u092a\u0930 \u091a\u093e\u0932\u0942',
      'notifyMeAbout':
          '\u092e\u0941\u091d\u0947 \u092c\u0924\u093e\u090f\u0901',
      'orderUpdates':
          '\u0911\u0930\u094d\u0921\u0930 \u0905\u092a\u0921\u0947\u091f',
      'orderUpdatesHint':
          '\u091c\u092c \u0906\u092a\u0915\u093e \u092c\u093e\u0909\u0932 \u0924\u0948\u092f\u093e\u0930 \u0939\u094b',
      'offers': '\u0911\u092b\u093c\u0930 \u0914\u0930 \u0916\u092c\u0930\u0947\u0902',
      'offersHint':
          '\u0928\u090f \u092c\u093e\u0909\u0932 \u0915\u0947 \u092c\u093e\u0930\u0947 \u092e\u0947\u0902 \u0915\u092d\u0940-\u0915\u092d\u0940 \u0908\u092e\u0947\u0932',
      'soundAndVibration':
          '\u0927\u094d\u0935\u0928\u093f \u0914\u0930 \u0915\u0902\u092a\u0928',
      'sound': '\u0927\u094d\u0935\u0928\u093f',
      'soundHint':
          '\u0928\u090f \u0905\u0932\u0930\u094d\u091f \u0915\u0947 \u0932\u093f\u090f \u0939\u0932\u094d\u0915\u0940 \u0906\u0935\u093e\u091c\u093c',
      'vibration': '\u0915\u0902\u092a\u0928',
      'vibrationHint':
          '\u0928\u090f \u0905\u0932\u0930\u094d\u091f \u0915\u0947 \u0932\u093f\u090f \u0939\u0932\u094d\u0915\u093e \u0915\u0902\u092a\u0928',
      'chooseLanguage':
          '\u0905\u092a\u0928\u0940 \u092d\u093e\u0937\u093e \u091a\u0941\u0928\u0947\u0902',
      'languageHint':
          '\u092e\u0947\u0928\u094d\u092f\u0942 \u0914\u0930 \u0911\u0930\u094d\u0921\u0930 \u0930\u0947\u0938\u094d\u091f\u0930\u093e\u0902 \u0938\u0947 \u0905\u0902\u0917\u094d\u0930\u0947\u091c\u093c\u0940 \u092e\u0947\u0902 \u0906\u0924\u0947 \u0939\u0948\u0902\u0964',
      'order': '\u0911\u0930\u094d\u0921\u0930',
      'history': '\u0907\u0924\u093f\u0939\u093e\u0938',
      'saved': '\u0938\u0939\u0947\u091c\u093e',
      'profile': '\u092a\u094d\u0930\u094b\u092b\u093c\u093e\u0907\u0932',
      'logOut': '\u0932\u0949\u0917 \u0906\u0909\u091f',
      'editDetails':
          '\u0935\u094d\u092f\u0915\u094d\u0924\u093f\u0917\u0924 \u0935\u093f\u0935\u0930\u0923 \u092c\u0926\u0932\u0947\u0902',
      'dietary':
          '\u0906\u0939\u093e\u0930 \u092a\u094d\u0930\u093e\u0925\u092e\u093f\u0915\u0924\u093e\u090f\u0901',
      'member': '\u0938\u0926\u0938\u094d\u092f',
      'guest': '\u092e\u0947\u0939\u092e\u093e\u0928',
    },
    'zh': {
      'settings': '\u8bbe\u7f6e',
      'settingsSubtitle': '\u8ba9\u5e94\u7528\u66f4\u5408\u5fc3\u610f',
      'personalisation': '\u4e2a\u6027\u5316',
      'alerts': '\u63d0\u9192',
      'account': '\u8d26\u6237',
      'appearance': '\u5916\u89c2',
      'language': '\u8bed\u8a00',
      'notifications': '\u901a\u77e5',
      'darkMode': '\u6df1\u8272\u6a21\u5f0f',
      'darkModeOn': '\u591c\u95f4\u66f4\u62a4\u773c',
      'darkModeOff': '\u70b9\u51fb\u5207\u6362\u5230\u591c\u95f4',
      'themeColour': '\u4e3b\u9898\u8272',
      'textSize': '\u6587\u5b57\u5927\u5c0f',
      'uiStyle': '\u754c\u9762\u98ce\u683c',
      'preview': '\u9884\u89c8',
      'changes': '\u9879\u66f4\u6539',
      'change': '\u9879\u66f4\u6539',
      'discard': '\u653e\u5f03',
      'review': '\u67e5\u770b',
      'apply': '\u5e94\u7528',
      'cancel': '\u53d6\u6d88',
      'reviewChanges': '\u67e5\u770b\u66f4\u6539',
      'noChanges': '\u8fd8\u6ca1\u6709\u66f4\u6539',
      'keepChanges': '\u4fdd\u7559\u66f4\u6539',
      'pushNotifications': '\u63a8\u9001\u901a\u77e5',
      'pushNotificationsHint': '\u5df2\u5728\u6b64\u8bbe\u5907\u5f00\u542f',
      'notifyMeAbout': '\u901a\u77e5\u5185\u5bb9',
      'orderUpdates': '\u8ba2\u5355\u66f4\u65b0',
      'orderUpdatesHint': '\u9910\u70b9\u505a\u597d\u65f6\u63d0\u9192',
      'offers': '\u4f18\u60e0\u4e0e\u8d44\u8baf',
      'offersHint': '\u5076\u5c14\u53d1\u9001\u65b0\u54c1\u90ae\u4ef6',
      'soundAndVibration': '\u58f0\u97f3\u4e0e\u9707\u52a8',
      'sound': '\u58f0\u97f3',
      'soundHint': '\u65b0\u63d0\u9192\u7684\u8f7b\u67d4\u94c3\u58f0',
      'vibration': '\u9707\u52a8',
      'vibrationHint': '\u65b0\u63d0\u9192\u7684\u8f7b\u5fae\u9707\u52a8',
      'chooseLanguage': '\u9009\u62e9\u8bed\u8a00',
      'languageHint':
          '\u83dc\u5355\u548c\u8ba2\u5355\u4ecd\u7531\u9910\u5385\u4ee5\u82f1\u6587\u63d0\u4f9b\u3002',
      'order': '\u70b9\u9910',
      'history': '\u8bb0\u5f55',
      'saved': '\u6536\u85cf',
      'profile': '\u6211\u7684',
      'logOut': '\u9000\u51fa\u767b\u5f55',
      'editDetails': '\u7f16\u8f91\u4e2a\u4eba\u8d44\u6599',
      'dietary': '\u996e\u98df\u504f\u597d',
      'member': '\u4f1a\u5458',
      'guest': '\u8bbf\u5ba2',
    },
    'vi': {
      'settings': 'C\u00e0i \u0111\u1eb7t',
      'settingsSubtitle': 'L\u00e0m cho \u1ee9ng d\u1ee5ng h\u1ee3p \u00fd b\u1ea1n',
      'personalisation': 'C\u00c1 NH\u00c2N HO\u00c1',
      'alerts': 'TH\u00d4NG B\u00c1O',
      'account': 'T\u00c0I KHO\u1EA2N',
      'appearance': 'Giao di\u1ec7n',
      'language': 'Ng\u00f4n ng\u1eef',
      'notifications': 'Th\u00f4ng b\u00e1o',
      'darkMode': 'Ch\u1ebf \u0111\u1ed9 t\u1ed1i',
      'darkModeOn': 'D\u1ec5 ch\u1ecbu cho m\u1eaft v\u00e0o ban \u0111\u00eam',
      'darkModeOff': 'Ch\u1ea1m \u0111\u1ec3 chuy\u1ec3n sang ban \u0111\u00eam',
      'themeColour': 'M\u00c0U CH\u1EE6 \u0110\u1EA0O',
      'textSize': 'C\u1EE0 CH\u1EEE',
      'uiStyle': 'KI\u1EC2U GIAO DI\u1EC6N',
      'preview': 'Xem tr\u01b0\u1edbc',
      'changes': 'thay \u0111\u1ed5i',
      'change': 'thay \u0111\u1ed5i',
      'discard': 'Hu\u1ef7 b\u1ecf',
      'review': 'Xem l\u1ea1i',
      'apply': '\u00c1p d\u1ee5ng',
      'cancel': 'Hu\u1ef7',
      'reviewChanges': 'Xem l\u1ea1i thay \u0111\u1ed5i',
      'noChanges': 'Ch\u01b0a c\u00f3 thay \u0111\u1ed5i n\u00e0o',
      'keepChanges': 'Gi\u1eef thay \u0111\u1ed5i',
      'pushNotifications': 'Th\u00f4ng b\u00e1o \u0111\u1ea9y',
      'pushNotificationsHint': '\u0110ang b\u1eadt tr\u00ean thi\u1ebft b\u1ecb n\u00e0y',
      'notifyMeAbout': 'TH\u00d4NG B\u00c1O V\u1EC0',
      'orderUpdates': 'C\u1eadp nh\u1eadt \u0111\u01a1n h\u00e0ng',
      'orderUpdatesHint': 'Khi m\u00f3n c\u1ee7a b\u1ea1n s\u1eb5n s\u00e0ng',
      'offers': '\u01afu \u0111\u00e3i v\u00e0 tin t\u1ee9c',
      'offersHint': 'Email th\u1ec9nh tho\u1ea3ng v\u1ec1 m\u00f3n m\u1edbi',
      'soundAndVibration': '\u00c2M THANH V\u00c0 RUNG',
      'sound': '\u00c2m thanh',
      'soundHint': 'Chu\u00f4ng nh\u1eb9 cho th\u00f4ng b\u00e1o m\u1edbi',
      'vibration': 'Rung',
      'vibrationHint': 'Rung nh\u1eb9 cho th\u00f4ng b\u00e1o m\u1edbi',
      'chooseLanguage': 'Ch\u1ecdn ng\u00f4n ng\u1eef',
      'languageHint':
          'Th\u1ef1c \u0111\u01a1n v\u00e0 \u0111\u01a1n h\u00e0ng v\u1eabn b\u1eb1ng ti\u1ebfng Anh.',
      'order': '\u0110\u1eb7t m\u00f3n',
      'history': 'L\u1ecbch s\u1eed',
      'saved': '\u0110\u00e3 l\u01b0u',
      'profile': 'H\u1ed3 s\u01a1',
      'logOut': '\u0110\u0103ng xu\u1ea5t',
      'editDetails': 'S\u1eeda th\u00f4ng tin c\u00e1 nh\u00e2n',
      'dietary': 'S\u1edf th\u00edch \u0103n u\u1ed1ng',
      'member': 'Th\u00e0nh vi\u00ean',
      'guest': 'Kh\u00e1ch',
    },
  };
}
