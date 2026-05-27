import 'package:supabase_flutter/supabase_flutter.dart';

class SupportTicket {
  final String id;
  final String ticketId;
  final String userId;
  final String message;
  final String? screenshotUrl;
  final String status;
  final String? adminResponse;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;

  SupportTicket({
    required this.id,
    required this.ticketId,
    required this.userId,
    required this.message,
    this.screenshotUrl,
    required this.status,
    this.adminResponse,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
  });

  factory SupportTicket.fromMap(Map<String, dynamic> map) {
    return SupportTicket(
      id: map['id'],
      ticketId: map['ticket_id'],
      userId: map['user_id'],
      message: map['message'],
      screenshotUrl: map['screenshot_url'],
      status: map['status'],
      adminResponse: map['admin_response'],
      createdAt: DateTime.parse(map['created_at']).toLocal(),
      updatedAt: DateTime.parse(map['updated_at']).toLocal(),
      resolvedAt: map['resolved_at'] != null ? DateTime.parse(map['resolved_at']).toLocal() : null,
    );
  }
}
