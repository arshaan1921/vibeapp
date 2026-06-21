import 'dart:async';
import 'dart:math';

class ZayloService {
  static final ZayloService _instance = ZayloService._internal();
  factory ZayloService() => _instance;
  ZayloService._internal();

  bool _isInQueue = false;

  Future<void> joinZayloQueue() async {
    // Mock joining queue
    _isInQueue = true;
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> leaveZayloQueue() async {
    _isInQueue = false;
  }

  Future<bool> findZayloMatch() async {
    if (!_isInQueue) return false;
    
    // Simulating random matching success
    // In a real app, this would call a Supabase function or similar
    await Future.delayed(const Duration(milliseconds: 500));
    return Random().nextDouble() > 0.7; // 30% chance to match every call
  }
}

final zayloService = ZayloService();
