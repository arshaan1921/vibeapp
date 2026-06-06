enum SnapStatus { sent, delivered, opened, screenshot }

class SnapMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String? text;
  final String? imageUrl;
  final String? caption;
  final DateTime createdAt;
  final SnapStatus? status;
  final String? reaction;

  SnapMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.text,
    this.imageUrl,
    this.caption,
    required this.createdAt,
    this.status,
    this.reaction,
  });

  bool get isSnap => imageUrl != null;
}
