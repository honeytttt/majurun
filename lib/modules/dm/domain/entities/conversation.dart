import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastMessageTime;
  final Map<String, int> unreadCount;
  final Map<String, String> participantNames; // userId -> displayName
  final Map<String, String> participantPhotos; // userId -> photoUrl

  Conversation({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    this.participantNames = const {},
    this.participantPhotos = const {},
  });

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Conversation(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCount: Map<String, int>.from(
        (data['unreadCount'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, (value as num).toInt()),
        ) ?? {},
      ),
      participantNames: Map<String, String>.from(data['participantNames'] ?? {}),
      participantPhotos: Map<String, String>.from(data['participantPhotos'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'unreadCount': unreadCount,
      'participantNames': participantNames,
      'participantPhotos': participantPhotos,
    };
  }

  /// Get the other participant's ID (for 1-on-1 conversations)
  String getOtherParticipantId(String currentUserId) {
    return participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }

  /// Get other participant's name
  String getOtherParticipantName(String currentUserId) {
    final otherId = getOtherParticipantId(currentUserId);
    return participantNames[otherId] ?? 'Unknown';
  }

  /// Get other participant's photo
  String? getOtherParticipantPhoto(String currentUserId) {
    final otherId = getOtherParticipantId(currentUserId);
    return participantPhotos[otherId];
  }

  /// Get unread count for current user
  int getUnreadCount(String userId) {
    return unreadCount[userId] ?? 0;
  }
}
