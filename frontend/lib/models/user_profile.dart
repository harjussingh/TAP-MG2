import '../services/api_models.dart';

/// The member's account record. A guest has no profile, which is why this is
/// nullable on AppState rather than being filled with blanks.
class UserProfile {
  UserProfile({
    required this.name,
    required this.email,
    this.id = '',
    this.phone = '',
    Set<String>? dietary,
    Set<String>? allergens,
    this.marketingEmails = false,
    this.orderUpdates = true,
    this.loyaltyPoints = 0,
    this.loyaltyTier = 'bronze',
  })  : dietary = dietary ?? <String>{},
        allergens = allergens ?? <String>{};

  /// Built from the server's copy, which is always the one to trust.
  factory UserProfile.fromApi(ApiUser u, {bool orderUpdates = true}) =>
      UserProfile(
        id: u.id,
        name: u.fullName,
        email: u.email,
        phone: u.phone ?? '',
        dietary: u.dietaryPreferences.toSet(),
        allergens: u.allergens.toSet(),
        marketingEmails: u.marketingOptIn,
        orderUpdates: orderUpdates,
        loyaltyPoints: u.loyaltyPoints,
        loyaltyTier: u.loyaltyTier,
      );

  final String id;
  String name;
  String email;
  String phone;

  /// API values such as `vegan` and `gluten_free`.
  final Set<String> dietary;

  /// API values such as `peanut` and `shellfish`.
  final Set<String> allergens;
  bool marketingEmails;

  /// Kept on the device: the API has no setting for it.
  bool orderUpdates;
  int loyaltyPoints;
  String loyaltyTier;

  String get initial => name.isEmpty ? 'M' : name[0].toUpperCase();
}
