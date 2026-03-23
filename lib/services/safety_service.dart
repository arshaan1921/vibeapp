import 'package:flutter/material.dart';

class SafetyService {
  static final SafetyService _instance = SafetyService._internal();
  factory SafetyService() => _instance;
  SafetyService._internal();

  int dailyAskLimit = 5;
  int anonDailyLimit = 3;
  int asksSentToday = 0;
  int anonsSentToday = 0;

  bool isPremium = false;

  final List<String> blockedUsers = [];
  final List<String> bannedUsers = [];
  final Map<String, int> reportCount = {};
  final List<String> shadowBannedUsers = [];

  final List<String> _forbiddenWords = ["hate", "kill", "die", "ugly", "stupid"];

  bool canAsk({bool anonymous = false}) {
    if (isPremium) return true;
    if (anonymous) {
      return anonsSentToday < anonDailyLimit;
    }
    return asksSentToday < dailyAskLimit;
  }

  bool containsForbiddenWords(String text) {
    String lower = text.toLowerCase();
    return _forbiddenWords.any((word) => lower.contains(word));
  }

  void reportUser(String username) {
    reportCount[username] = (reportCount[username] ?? 0) + 1;
    if (reportCount[username]! >= 3 && reportCount[username]! < 5) {
      if (!shadowBannedUsers.contains(username)) shadowBannedUsers.add(username);
    } else if (reportCount[username]! >= 5) {
      if (!bannedUsers.contains(username)) bannedUsers.add(username);
    }
  }

  void blockUser(String username) {
    if (!blockedUsers.contains(username)) blockedUsers.add(username);
  }

  void recordAsk({bool anonymous = false}) {
    if (anonymous) {
      anonsSentToday++;
    } else {
      asksSentToday++;
    }
  }
}

final safetyService = SafetyService();
