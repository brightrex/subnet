import 'dart:convert';

enum SpaceVisibility { public, private, ghost }

enum SpaceLifetime { temporary, permanent }

class SpaceMeta {
  final String spaceId;
  final String adminId;
  final String adminName;
  final String name;
  final String description;
  final SpaceVisibility visibility;
  final SpaceLifetime lifetime;
  final String? accessKey;
  final int memberCount;
  final int reportCount;
  final DateTime createdAt;

  const SpaceMeta({
    required this.spaceId,
    required this.adminId,
    required this.adminName,
    required this.name,
    required this.description,
    required this.visibility,
    required this.lifetime,
    required this.memberCount,
    required this.reportCount,
    required this.createdAt,
    this.accessKey,
  });

  bool get isTemporary => lifetime == SpaceLifetime.temporary;

  SpaceMeta copyWith({
    String? name,
    String? description,
    SpaceVisibility? visibility,
    SpaceLifetime? lifetime,
    String? accessKey,
    int? memberCount,
    int? reportCount,
  }) {
    return SpaceMeta(
      spaceId: spaceId,
      adminId: adminId,
      adminName: adminName,
      name: name ?? this.name,
      description: description ?? this.description,
      visibility: visibility ?? this.visibility,
      lifetime: lifetime ?? this.lifetime,
      accessKey: accessKey ?? this.accessKey,
      memberCount: memberCount ?? this.memberCount,
      reportCount: reportCount ?? this.reportCount,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'spaceId': spaceId,
      'adminId': adminId,
      'adminName': adminName,
      'name': name,
      'description': description,
      'visibility': visibility.name,
      'lifetime': lifetime.name,
      'memberCount': memberCount,
      'reportCount': reportCount,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SpaceMeta.fromJson(Map<String, dynamic> json) {
    return SpaceMeta(
      spaceId: json['spaceId'] ?? '',
      adminId: json['adminId'] ?? '',
      adminName: json['adminName'] ?? 'Admin',
      name: json['name'] ?? 'Space',
      description: json['description'] ?? '',
      visibility: SpaceVisibility.values.firstWhere(
        (v) => v.name == json['visibility'],
        orElse: () => SpaceVisibility.public,
      ),
      lifetime: SpaceLifetime.values.firstWhere(
        (v) => v.name == json['lifetime'],
        orElse: () => SpaceLifetime.permanent,
      ),
      memberCount: json['memberCount'] ?? 1,
      reportCount: json['reportCount'] ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      accessKey: null,
    );
  }

  static String visibilityCode(SpaceVisibility visibility) {
    switch (visibility) {
      case SpaceVisibility.public:
        return 'pub';
      case SpaceVisibility.private:
        return 'pri';
      case SpaceVisibility.ghost:
        return 'gho';
    }
  }

  static SpaceVisibility visibilityFromCode(String? code) {
    switch (code) {
      case 'pri':
        return SpaceVisibility.private;
      case 'gho':
        return SpaceVisibility.ghost;
      case 'pub':
      default:
        return SpaceVisibility.public;
    }
  }

  static String lifetimeCode(SpaceLifetime lifetime) {
    return lifetime == SpaceLifetime.temporary ? 'tmp' : 'per';
  }

  static SpaceLifetime lifetimeFromCode(String? code) {
    return code == 'tmp' ? SpaceLifetime.temporary : SpaceLifetime.permanent;
  }

  static String encodeTxtValue(String value) {
    return base64Url.encode(utf8.encode(value));
  }

  static String decodeTxtValue(String value) {
    try {
      return utf8.decode(base64Url.decode(value));
    } catch (_) {
      return value;
    }
  }
}

extension SpaceVisibilityLabel on SpaceVisibility {
  String get label {
    switch (this) {
      case SpaceVisibility.public:
        return 'Public';
      case SpaceVisibility.private:
        return 'Private';
      case SpaceVisibility.ghost:
        return 'Ghost';
    }
  }
}

extension SpaceLifetimeLabel on SpaceLifetime {
  String get label {
    switch (this) {
      case SpaceLifetime.temporary:
        return 'Temporary';
      case SpaceLifetime.permanent:
        return 'Permanent';
    }
  }
}
