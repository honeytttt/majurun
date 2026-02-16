enum MessagePrivacy {
  everyone,      // Anyone can message
  followersOnly, // Only followers can message
  noOne,         // No one can message
}

class UserPrivacy {
  final String userId;
  final MessagePrivacy messagePrivacy;
  final bool showReadReceipts;
  final bool showTypingIndicator;

  UserPrivacy({
    required this.userId,
    this.messagePrivacy = MessagePrivacy.everyone,
    this.showReadReceipts = true,
    this.showTypingIndicator = true,
  });

  factory UserPrivacy.fromFirestore(Map<String, dynamic> data, String userId) {
    return UserPrivacy(
      userId: userId,
      messagePrivacy: _parsePrivacy(data['messagePrivacy']),
      showReadReceipts: data['showReadReceipts'] ?? true,
      showTypingIndicator: data['showTypingIndicator'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messagePrivacy': messagePrivacy.name,
      'showReadReceipts': showReadReceipts,
      'showTypingIndicator': showTypingIndicator,
    };
  }

  static MessagePrivacy _parsePrivacy(String? value) {
    switch (value) {
      case 'followersOnly':
        return MessagePrivacy.followersOnly;
      case 'noOne':
        return MessagePrivacy.noOne;
      default:
        return MessagePrivacy.everyone;
    }
  }
}