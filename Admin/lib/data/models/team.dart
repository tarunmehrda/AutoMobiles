import 'package:flutter/foundation.dart';

import 'access.dart';

/// Somebody who can sign in to this workshop (`garage_team()`,
/// 31_staff_logins.sql).
@immutable
class TeamMember {
  const TeamMember({
    required this.profileId,
    required this.email,
    required this.role,
    this.name = '',
    this.staffId = '',
    this.lastSignIn,
    this.me = false,
  });

  final String profileId;
  final String email;
  final StaffRole role;
  final String name;
  final String staffId;
  final DateTime? lastSignIn;
  final bool me;

  factory TeamMember.fromJson(Map<String, dynamic> j) => TeamMember(
    profileId: (j['profile_id'] ?? '') as String,
    email: (j['email'] ?? '') as String,
    role: StaffRole.parse(j['role'] as String?),
    name: (j['name'] ?? '') as String,
    staffId: (j['staff_id'] ?? '') as String,
    lastSignIn: DateTime.tryParse((j['last_sign_in_at'] ?? '') as String),
    me: (j['me'] ?? false) as bool,
  );
}

/// An email the owner has given access to, waiting for its first sign-in.
@immutable
class TeamInvite {
  const TeamInvite({
    required this.email,
    required this.role,
    required this.staffId,
    this.sentAt,
  });

  final String email;
  final StaffRole role;
  final String staffId;
  final DateTime? sentAt;

  factory TeamInvite.fromJson(Map<String, dynamic> j) => TeamInvite(
    email: (j['email'] ?? '') as String,
    role: StaffRole.parse(j['role'] as String?),
    staffId: (j['staff_id'] ?? '') as String,
    sentAt: DateTime.tryParse((j['created_at'] ?? '') as String),
  );
}

@immutable
class Team {
  const Team({this.members = const [], this.invites = const []});

  final List<TeamMember> members;
  final List<TeamInvite> invites;

  TeamMember? memberFor(String staffId) {
    for (final m in members) {
      if (m.staffId == staffId && staffId.isNotEmpty) return m;
    }
    return null;
  }

  TeamInvite? inviteFor(String staffId) {
    for (final i in invites) {
      if (i.staffId == staffId) return i;
    }
    return null;
  }

  factory Team.fromJson(Map<String, dynamic> j) => Team(
    members: [
      for (final m in (j['members'] as List? ?? const []))
        TeamMember.fromJson(Map<String, dynamic>.from(m as Map)),
    ],
    invites: [
      for (final i in (j['invites'] as List? ?? const []))
        TeamInvite.fromJson(Map<String, dynamic>.from(i as Map)),
    ],
  );
}
