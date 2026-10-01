/// The member's account record. A guest has no profile, which is why this is
/// nullable on AppState rather than being filled with blanks.
class UserProfile {
  UserProfile({
    required this.name,
    required this.email,
    this.phone = '',
    this.address = '',
    this.dateOfBirth = '',
    Set<String>? dietary,
    this.marketingEmails = false,
    this.orderUpdates = true,
  }) : dietary = dietary ?? <String>{};

  String name;
  String email;
  String phone;
  String address;

  /// DD/MM/YYYY, the Australian format used throughout the interface.
  String dateOfBirth;

  final Set<String> dietary;
  bool marketingEmails;
  bool orderUpdates;

  String get initial => name.isEmpty ? 'M' : name[0].toUpperCase();

  UserProfile copy() => UserProfile(
        name: name,
        email: email,
        phone: phone,
        address: address,
        dateOfBirth: dateOfBirth,
        dietary: Set<String>.from(dietary),
        marketingEmails: marketingEmails,
        orderUpdates: orderUpdates,
      );
}
