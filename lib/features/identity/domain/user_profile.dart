import 'package:flutter/foundation.dart';

/// Editable self-description shown to peers.
@immutable
final class UserProfile {
  const UserProfile({
    required this.displayName,
    required this.avatarColor,
    this.tagline,
  });

  /// Name chosen by the user (shown in mesh UIs and QR cards).
  final String displayName;

  /// Palette index for the avatar accent (0..N-1 per the app palette).
  final int avatarColor;

  /// Optional short self-description; `null` when unset.
  final String? tagline;

  UserProfile copyWith({
    String? displayName,
    int? avatarColor,
    String? Function()? tagline,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      avatarColor: avatarColor ?? this.avatarColor,
      tagline: tagline != null ? tagline() : this.tagline,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'displayName': displayName,
    'avatarColor': avatarColor,
    if (tagline != null) 'tagline': tagline,
  };

  static UserProfile fromJson(Map<String, Object?> json) => UserProfile(
    displayName: json['displayName']! as String,
    avatarColor: json['avatarColor']! as int,
    tagline: json['tagline'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.displayName == displayName &&
      other.avatarColor == avatarColor &&
      other.tagline == tagline;

  @override
  int get hashCode => Object.hash(displayName, avatarColor, tagline);

  @override
  String toString() => 'UserProfile($displayName, color:$avatarColor)';
}
