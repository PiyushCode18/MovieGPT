/// A lightweight, UI-safe representation of the authenticated user.
///
/// This model is independent of Firebase and Supabase so the UI
/// does not depend directly on an authentication provider.
class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? phoneNumber;
  final String? photoUrl;

  const AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.phoneNumber,
    this.photoUrl,
  });

  /// Build an AppUser from a Supabase auth user.
  ///
  /// Supabase stores additional profile information in `user_metadata`.
  factory AppUser.fromSupabase(dynamic user) {
    final metadata = user.userMetadata;

    return AppUser(
      uid: user.id,
      email: user.email,
      displayName: metadata?['display_name']?.toString() ??
          metadata?['full_name']?.toString(),
      phoneNumber: user.phone,
      photoUrl: metadata?['avatar_url']?.toString(),
    );
  }

  /// Whether the user is signed in.
  bool get isAuthenticated => uid.isNotEmpty;

  /// Convert the user to a simple Map.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
    };
  }

  @override
  String toString() {
    return 'AppUser('
        'uid: $uid, '
        'email: $email, '
        'displayName: $displayName'
        ')';
  }
}