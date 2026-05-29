class AiMemory {
  final String id;
  final String userId;
  final String companionId;
  final String memoryKey;
  final String memoryValue;
  final DateTime createdAt;

  AiMemory({
    required this.id,
    required this.userId,
    required this.companionId,
    required this.memoryKey,
    required this.memoryValue,
    required this.createdAt,
  });

  factory AiMemory.fromMap(Map<String, dynamic> map) {
    return AiMemory(
      id: map['id'],
      userId: map['user_id'],
      companionId: map['companion_id'],
      memoryKey: map['memory_key'],
      memoryValue: map['memory_value'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'companion_id': companionId,
      'memory_key': memoryKey,
      'memory_value': memoryValue,
    };
  }
}
