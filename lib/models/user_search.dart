// lib/models/user_search_result.dart

class UserSearchResult {
  final String  uid;
  final String  name;
  final String  avatar;
  final String  bio;
  final String  city;
  final String  state;
  final int     followersCount;
  final int     followingCount;
  final double? latitude;   // ← novo: moradia do usuário
  final double? longitude;  // ← novo

  const UserSearchResult({
    required this.uid,
    required this.name,
    required this.avatar,
    required this.bio,
    required this.city,
    required this.state,
    required this.followersCount,
    required this.followingCount,
    this.latitude,
    this.longitude,
  });
}