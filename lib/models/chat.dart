class Conversation {
  final String id;
  final DateTime createdAt;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final String? lastMessageStatus;
  final String otherUserName;
  final String? otherUserAvatar;
  final String otherUserId;
  final int unreadCount;

  Conversation({
    required this.id,
    required this.createdAt,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.lastMessageStatus,
    required this.otherUserName,
    this.otherUserAvatar,
    required this.otherUserId,
    this.unreadCount = 0,
  });

  factory Conversation.fromMap(Map<String, dynamic> map, String currentUserId) {
    final participants = map['participants'] as List? ?? [];
    
    Map<String, dynamic>? otherUserProfile;
    String otherId = '';
    int unread = 0;

    for (var p in participants) {
      final profileData = p['profiles'];
      final userId = p['user_id']?.toString() ?? '';

      if (userId == currentUserId) {
        unread = p['unread_count'] ?? 0;
      } else {
        otherId = userId;
        if (profileData != null) {
          otherUserProfile = profileData is List 
              ? (profileData.isNotEmpty ? profileData[0] : {}) 
              : profileData as Map<String, dynamic>;
        }
      }
    }

    if (otherId.isEmpty && participants.isNotEmpty) {
      final firstP = participants[0];
      otherId = firstP['user_id']?.toString() ?? '';
      final profileData = firstP['profiles'];
      if (profileData != null) {
        otherUserProfile = profileData is List 
            ? (profileData.isNotEmpty ? profileData[0] : {}) 
            : profileData as Map<String, dynamic>;
      }
    }

    return Conversation(
      id: map['id']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      lastMessage: map['last_message'],
      lastMessageAt: map['last_message_at'] != null ? DateTime.tryParse(map['last_message_at']) : null,
      lastMessageSenderId: map['last_message_sender_id']?.toString(),
      lastMessageStatus: map['last_message_status']?.toString(),
      otherUserName: otherUserProfile?['username'] ?? 'User',
      otherUserAvatar: otherUserProfile?['avatar_url'],
      otherUserId: otherId,
      unreadCount: unread,
    );
  }
}

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String message;
  final DateTime createdAt;
  final String status; // 'sent', 'delivered', 'read'
  final String? mediaUrl;
  final String? mediaType;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.message,
    required this.createdAt,
    required this.status,
    this.mediaUrl,
    this.mediaType,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'].toString(),
      conversationId: map['conversation_id']?.toString() ?? '',
      senderId: map['sender_id']?.toString() ?? '',
      message: map['message'] ?? '',
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      status: map['status'] ?? 'sent',
      mediaUrl: map['media_url'],
      mediaType: map['media_type'],
    );
  }
}
