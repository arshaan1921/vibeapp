class AppUser {
  final String id;
  final String username;
  final String? bio;
  final String? avatarUrl;
  final int? questionsCount;
  final int? answersCount;
  final int? likesCount;
  final String? name;
  
  // Social Links
  final String? instagramHandle;
  final String? twitterHandle;
  final String? facebookHandle;
  final String? linkedinHandle;
  final String? youtubeHandle;
  final String? tiktokHandle;
  final String? snapchatHandle;
  final String? whatsappHandle;
  final String? telegramHandle;
  final String? gmailAddress;
  final bool showSocialLinks;
  final bool showGmail;

  AppUser({
    required this.id,
    required this.username,
    this.bio,
    this.avatarUrl,
    this.questionsCount,
    this.answersCount,
    this.likesCount,
    this.name,
    this.instagramHandle,
    this.twitterHandle,
    this.facebookHandle,
    this.linkedinHandle,
    this.youtubeHandle,
    this.tiktokHandle,
    this.snapchatHandle,
    this.whatsappHandle,
    this.telegramHandle,
    this.gmailAddress,
    this.showSocialLinks = true,
    this.showGmail = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'],
      username: json['username'] ?? '',
      avatarUrl: json['avatar_url'],
      bio: json['bio'],
      name: json['name'],
      questionsCount: json['questions_count'],
      answersCount: json['answers_count'],
      likesCount: json['likes_count'],
      instagramHandle: json['instagram_handle'],
      twitterHandle: json['twitter_handle'],
      facebookHandle: json['facebook_handle'],
      linkedinHandle: json['linkedin_handle'],
      youtubeHandle: json['youtube_handle'],
      tiktokHandle: json['tiktok_handle'],
      snapchatHandle: json['snapchat_handle'],
      whatsappHandle: json['whatsapp_handle'],
      telegramHandle: json['telegram_handle'],
      gmailAddress: json['gmail_address'],
      showSocialLinks: json['show_social_links'] ?? true,
      showGmail: json['show_gmail'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'bio': bio,
      'avatar_url': avatarUrl,
      'name': name,
      'instagram_handle': instagramHandle,
      'twitter_handle': twitterHandle,
      'facebook_handle': facebookHandle,
      'linkedin_handle': linkedinHandle,
      'youtube_handle': youtubeHandle,
      'tiktok_handle': tiktokHandle,
      'snapchat_handle': snapchatHandle,
      'whatsapp_handle': whatsappHandle,
      'telegram_handle': telegramHandle,
      'gmail_address': gmailAddress,
      'show_social_links': showSocialLinks,
      'show_gmail': showGmail,
    };
  }
}
