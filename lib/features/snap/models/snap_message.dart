enum SnapStatus { sent, delivered, opened, screenshot }

class SnapMessage {
  final String id; // snap_recipients ID
  final String? snapId; // snaps ID
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
    this.snapId,
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
