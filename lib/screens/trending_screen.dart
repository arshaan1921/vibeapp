import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/answer.dart';
import '../widgets/answer_card.dart';
import '../services/block_service.dart';
import '../main.dart';
import 'profile.dart';
import 'search_screen.dart';

class TrendingScreen extends StatefulWidget {
  const TrendingScreen({super.key});

  @override
  State<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen> with RouteAware {
  int _selectedTabIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;
  List<AnswerModel> _trendingAnswers = [];
  List<Map<String, dynamic>> _suggestedPeople = [];
  List<Map<String, dynamic>> _verifiedCreators = [];
  List<AnswerModel> _mostLikedWeekly = [];
  List<Map<String, dynamic>> _newRisingCreators = [];

  final List<String> _categories = [
    'Trending',
    'People',
    'Answers',
    'Verified',
    'New'
  ];

  static const String _answerSelectQuery = '''
    id,
    answer_text,
    created_at,
    likes_count,
    user_id,
    profiles:profiles!answers_user_id_fkey(id, username, avatar_url, premium_plan, is_verified:youtube_verified),
    questions:questions!answers_question_id_fkey(
      text,
      image_url,
      is_anonymous,
      from_user,
      asker:profiles!from_user(id, username)
    )
  ''';

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await Future.wait([
        _fetchTrendingAnswers().catchError((e) => debugPrint('Error trending: $e')),
        _fetchSuggestedPeople().catchError((e) => debugPrint('Error suggested: $e')),
        _fetchVerifiedCreators().catchError((e) => debugPrint('Error verified: $e')),
        _fetchMostLikedWeekly().catchError((e) => debugPrint('Error weekly: $e')),
        _fetchNewRisingCreators().catchError((e) => debugPrint('Error rising: $e')),
      ]);
    } catch (e) {
      debugPrint('Error loading trending data: $e');
      _errorMessage = "Failed to load trending data. Tap to retry.";
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchTrendingAnswers() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final response = await Supabase.instance.client
          .from('answers')
          .select(_answerSelectQuery)
          .order('likes_count', ascending: false)
          .limit(20);
      
      final data = response as List;
      
      Set<String> likedIds = {};
      if (user != null) {
        final likesRes = await Supabase.instance.client.from('answer_likes').select('answer_id').eq('user_id', user.id);
        likedIds = (likesRes as List).map((l) => l['answer_id'].toString()).toSet();
      }

      _trendingAnswers = data.map((map) {
        try {
          return AnswerModel.fromMap(map, isLiked: likedIds.contains(map['id'].toString()));
        } catch (e) {
          debugPrint('Error parsing answer ${map['id']}: $e');
          return null;
        }
      }).whereType<AnswerModel>().toList();
    } catch (e, st) {
      debugPrint('Error fetching trending answers: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> _fetchSuggestedPeople() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      var query = Supabase.instance.client
          .from('profiles')
          .select('id, username, avatar_url, premium_plan, created_at, youtube_verified');
      
      if (user != null) {
        query = query.neq('id', user.id);
      }
      
      final response = await query.order('created_at', ascending: false).limit(15);
      
      _suggestedPeople = List<Map<String, dynamic>>.from(response as List);
    } catch (e, st) {
      debugPrint('Error fetching suggested people: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> _fetchVerifiedCreators() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      var query = Supabase.instance.client
          .from('profiles')
          .select('id, username, avatar_url, premium_plan, youtube_verified')
          .or('youtube_verified.eq.true,premium_plan.neq.free');
      
      if (user != null) {
        query = query.neq('id', user.id);
      }
      
      final response = await query.limit(10);
      
      _verifiedCreators = List<Map<String, dynamic>>.from(response as List);
    } catch (e, st) {
      debugPrint('Error fetching verified creators: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> _fetchMostLikedWeekly() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
      final response = await Supabase.instance.client
          .from('answers')
          .select(_answerSelectQuery)
          .gte('created_at', sevenDaysAgo)
          .order('likes_count', ascending: false)
          .limit(10);
      
      final data = response as List;

      Set<String> likedIds = {};
      if (user != null) {
        final likesRes = await Supabase.instance.client.from('answer_likes').select('answer_id').eq('user_id', user.id);
        likedIds = (likesRes as List).map((l) => l['answer_id'].toString()).toSet();
      }

      _mostLikedWeekly = data.map((map) {
        try {
          return AnswerModel.fromMap(map, isLiked: likedIds.contains(map['id'].toString()));
        } catch (e) {
          debugPrint('Error parsing weekly answer ${map['id']}: $e');
          return null;
        }
      }).whereType<AnswerModel>().toList();
    } catch (e, st) {
      debugPrint('Error fetching weekly most liked: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> _fetchNewRisingCreators() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id, username, avatar_url, premium_plan, is_premium, created_at')
          .gte('created_at', thirtyDaysAgo)
          .order('created_at', ascending: false)
          .limit(10);
      
      _newRisingCreators = List<Map<String, dynamic>>.from(response as List);
    } catch (e, st) {
      debugPrint('Error fetching new rising creators: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Trending 🔥",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 24,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.search_rounded, color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: theme.colorScheme.onSurface),
            onPressed: _loadAllData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildCategoryChips(),
            ),
            if (_isLoading)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildSkeletonItem(),
                    childCount: 5,
                  ),
                ),
              )
            else if (_errorMessage != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadAllData, child: const Text("RETRY")),
                    ],
                  ),
                ),
              )
            else
              _buildContentForTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonItem() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 40, height: 40, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 100, height: 12, color: Colors.grey),
                  const SizedBox(height: 4),
                  Container(width: 60, height: 10, color: Colors.grey.withOpacity(0.5)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(width: double.infinity, height: 14, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 8),
          Container(width: 200, height: 14, color: Colors.grey.withOpacity(0.3)),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedTabIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(_categories[index]),
              selected: isSelected,
              onSelected: (val) {
                setState(() => _selectedTabIndex = index);
              },
              backgroundColor: isSelected 
                ? Theme.of(context).colorScheme.primary 
                : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              selectedColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildContentForTab() {
    switch (_selectedTabIndex) {
      case 0: // Trending (All Sections)
        return SliverList(
          delegate: SliverChildListDelegate([
            _buildSectionHeader("Trending Answers"),
            if (_trendingAnswers.isEmpty)
              _buildEmptyState("No trending answers yet.")
            else
              ..._trendingAnswers.asMap().entries.map((entry) {
                return Stack(
                  children: [
                    AnswerCard(answer: entry.value),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: _buildRankBadge(entry.key + 1),
                    ),
                  ],
                );
              }).toList(),
            
            _buildSectionHeader("Suggested People"),
            if (_suggestedPeople.isEmpty)
              _buildEmptyState("No users found.")
            else
              _buildHorizontalPeopleList(_suggestedPeople),
            
            _buildSectionHeader("Verified Creators"),
            if (_verifiedCreators.isEmpty)
              _buildEmptyState("No verified creators yet.")
            else
              _buildHorizontalPeopleList(_verifiedCreators),
            
            _buildSectionHeader("Most Liked This Week"),
            if (_mostLikedWeekly.isEmpty)
              _buildEmptyState("No popular answers this week.")
            else
              ..._mostLikedWeekly.map((a) => AnswerCard(answer: a)).toList(),
            
            _buildSectionHeader("New Rising Creators"),
            if (_newRisingCreators.isEmpty)
              _buildEmptyState("No new rising creators.")
            else
              _buildRisingCreatorsList(_newRisingCreators),
            
            const SizedBox(height: 100),
          ]),
        );
      case 1: // People
        if (_suggestedPeople.isEmpty) return SliverToBoxAdapter(child: _buildEmptyState("No users found."));
        return SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.7,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildPersonGridItem(_suggestedPeople[index]),
              childCount: _suggestedPeople.length,
            ),
          ),
        );
      case 2: // Answers
        if (_trendingAnswers.isEmpty) return SliverToBoxAdapter(child: _buildEmptyState("No trending answers yet."));
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => AnswerCard(answer: _trendingAnswers[index]),
            childCount: _trendingAnswers.length,
          ),
        );
      case 3: // Verified
        if (_verifiedCreators.isEmpty) return SliverToBoxAdapter(child: _buildEmptyState("No verified creators yet."));
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildPersonListTile(_verifiedCreators[index]),
            childCount: _verifiedCreators.length,
          ),
        );
      case 4: // New
        if (_newRisingCreators.isEmpty) return SliverToBoxAdapter(child: _buildEmptyState("No new rising creators."));
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildPersonListTile(_newRisingCreators[index], showDate: true),
            childCount: _newRisingCreators.length,
          ),
        );
      default:
        return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.bubble_chart_outlined, size: 48, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.grey.withOpacity(0.5)),
        ],
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    Color color = Colors.grey;
    if (rank == 1) color = const Color(0xFFFFD700);
    if (rank == 2) color = const Color(0xFFC0C0C0);
    if (rank == 3) color = const Color(0xFFCD7F32);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        "#$rank",
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildHorizontalPeopleList(List<Map<String, dynamic>> people) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: people.length,
        itemBuilder: (context, index) {
          final person = people[index];
          return _buildPersonCard(person);
        },
      ),
    );
  }

  Widget _buildPersonCard(Map<String, dynamic> person) {
    final theme = Theme.of(context);
    final avatarUrl = person['avatar_url'] as String?;
    
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(128)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) 
              ? NetworkImage(avatarUrl) 
              : null,
            child: (avatarUrl == null || avatarUrl.isEmpty) ? const Icon(Icons.person) : null,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  person['username'] ?? 'User',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (person['youtube_verified'] == true || (person['premium_plan'] != null && person['premium_plan'] != 'free'))
                const Icon(Icons.verified_rounded, color: Colors.blue, size: 14),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "${person['likes_count'] ?? 0} High5s",
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfileScreen(userId: person['id'])),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Visit", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonGridItem(Map<String, dynamic> person) {
    return _buildPersonCard(person);
  }

  Widget _buildPersonListTile(Map<String, dynamic> person, {bool showDate = false}) {
    final avatarUrl = person['avatar_url'] as String?;
    
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) 
          ? NetworkImage(avatarUrl) 
          : null,
        child: (avatarUrl == null || avatarUrl.isEmpty) ? const Icon(Icons.person) : null,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              person['username'] ?? 'User', 
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (person['youtube_verified'] == true || (person['premium_plan'] != null && person['premium_plan'] != 'free'))
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.verified_rounded, color: Colors.blue, size: 16),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("${person['likes_count'] ?? 0} High5s", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (showDate && person['created_at'] != null)
            Text("Joined ${DateTime.parse(person['created_at']).toLocal().toString().split(' ')[0]}", style: const TextStyle(fontSize: 10)),
        ],
      ),
      trailing: OutlinedButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProfileScreen(userId: person['id'])),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text("View"),
      ),
    );
  }

  Widget _buildRisingCreatorsList(List<Map<String, dynamic>> creators) {
    return Column(
      children: creators.map((c) => _buildPersonListTile(c, showDate: true)).toList(),
    );
  }
}
