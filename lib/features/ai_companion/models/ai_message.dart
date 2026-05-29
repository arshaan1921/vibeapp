class AiMessage {
  final String id;
  final String userId;
  final String companionId;
  final String message;
  final String sender; // 'user' or 'ai'
  final DateTime createdAt;

  AiMessage({
    required this.id,
    required this.userId,
    required this.companionId,
    required this.message,
    required this.sender,
    required this.createdAt,
  });

  factory AiMessage.fromMap(Map<String, dynamic> map) {
    return AiMessage(
      id: map['id'],
      userId: map['user_id'],
      companionId: map['companion_id'],
      message: map['message'],
      sender: map['sender'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'companion_id': companionId,
      'message': message,
      'sender': sender,
    };
  }
}
