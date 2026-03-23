class FeedItem {
  final String id;
  final String username;
  final String avatarUrl;
  final String questionText;
  final String answerText;
  final String timeAgo;
  final int likes;

  FeedItem({
    required this.id,
    required this.username,
    required this.avatarUrl,
    required this.questionText,
    required this.answerText,
    required this.timeAgo,
    required this.likes,
  });
}

final List<FeedItem> mockFeed = List.generate(10, (index) => FeedItem(
  id: 'f$index',
  username: 'user_$index',
  avatarUrl: 'https://i.pravatar.cc/150?u=$index',
  questionText: 'This is a sample question number $index?',
  answerText: 'This is the sample answer for the question above. Everything is looking premium and clean.',
  timeAgo: '${index + 1}h ago',
  likes: (index + 1) * 12,
));
