import 'package:flutter/foundation.dart';
import '../services/meme_mania_service.dart';

class GameProvider extends ChangeNotifier {
  final _service = MemeManiaService();
  int _unreadCount = 0;

  int get unreadCount => _unreadCount;

  Future<void> fetchUnreadCount() async {
    _unreadCount = await _service.getUnreadGamesCount();
    notifyListeners();
  }

  void decrementCount() {
    if (_unreadCount > 0) {
      _unreadCount--;
      notifyListeners();
    }
  }
}
