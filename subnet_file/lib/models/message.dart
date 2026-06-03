class ChatMessage {
  final String senderId;
  final String displayName;
  final String text;
  final DateTime timestamp;
  final bool isAnonymous;
  final String type; // "message", "report", "expose", "typing"
  final String? sourceIp;
  final Map<String, List<String>> reactions; // emoji -> [userIds]

  ChatMessage({
    required this.senderId,
    required this.displayName,
    required this.text,
    required this.timestamp,
    required this.isAnonymous,
    this.sourceIp,
    this.type = "message",
    this.reactions = const {},
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    Map<String, List<String>> reactionsMap = {};
    if (json['reactions'] is Map) {
      json['reactions'].forEach((emoji, users) {
        reactionsMap[emoji] = List<String>.from(users ?? []);
      });
    }

    return ChatMessage(
      senderId: json['senderId'] ?? '',
      displayName: json['displayName'] ?? 'Unknown',
      text: json['text'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      isAnonymous: json['isAnonymous'] ?? true,
      type: json['type'] ?? 'message',
      sourceIp: json['sourceIp'],
      reactions: reactionsMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'displayName': displayName,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'isAnonymous': isAnonymous,
      'type': type,
      'sourceIp': sourceIp,
      'reactions': reactions,
    };
  }

  ChatMessage copyWith({
    String? senderId,
    String? displayName,
    String? text,
    DateTime? timestamp,
    bool? isAnonymous,
    String? type,
    String? sourceIp,
    Map<String, List<String>>? reactions,
  }) {
    return ChatMessage(
      senderId: senderId ?? this.senderId,
      displayName: displayName ?? this.displayName,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      type: type ?? this.type,
      sourceIp: sourceIp ?? this.sourceIp,
      reactions: reactions ?? this.reactions,
    );
  }
}
