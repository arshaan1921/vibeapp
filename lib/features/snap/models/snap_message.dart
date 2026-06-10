enum SnapStatus { sent, delivered, opened, screenshot }

class MessageReaction {
  final String userId;
  final String reaction;

  MessageReaction({required this.userId, required this.reaction});

  factory MessageReaction.fromMap(Map<String, dynamic> map) {
    return MessageReaction(
      userId: map['user_id'],
      reaction: map['reaction_type'],
    );
  }
}

class SnapMessage {
  final String id; // snap_recipients ID or messages ID
  final String? snapId; // snaps ID
  final String senderId;
  final String receiverId;
  final String? text;
  final String? imageUrl;
  final String? caption;
  final DateTime createdAt;
  final SnapStatus? status;
  final String? reaction; // Snap reaction

  // New fields for text messages
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final String? repliedToId;
  final SnapMessage? repliedToMessage;
  final List<MessageReaction> reactions;

  SnapMessage({
    required this.id,
    this.snapId,
    required this.senderId,
    required this.receiverId,
    this.text,
    this.imageUrl,
    this.caption,
    required this.createdAt,
    this.status,
    this.reaction,
    this.deliveredAt,
    this.readAt,
    this.repliedToId,
    this.repliedToMessage,
    this.reactions = const [],
  });

  bool get isSnap => imageUrl != null;

  SnapMessage copyWith({
    SnapMessage? repliedToMessage,
    List<MessageReaction>? reactions,
  }) {
    return SnapMessage(
      id: id,
      snapId: snapId,
      senderId: senderId,
      receiverId: receiverId,
      text: text,
      imageUrl: imageUrl,
      caption: caption,
      createdAt: createdAt,
      status: status,
      reaction: reaction,
      deliveredAt: deliveredAt,
      readAt: readAt,
      repliedToId: repliedToId,
      repliedToMessage: repliedToMessage ?? this.repliedToMessage,
      reactions: reactions ?? this.reactions,
    );
  }
}
