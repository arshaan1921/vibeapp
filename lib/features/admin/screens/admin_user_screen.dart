import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../theme.dart';
import '../models/admin_user_item.dart';
import '../repositories/admin_user_repository.dart';
import 'admin_user_details_screen.dart';

class AdminUserScreen extends StatefulWidget {
  const AdminUserScreen({super.key});

  @override
  State<AdminUserScreen> createState() => _AdminUserScreenState();
}

class _AdminUserScreenState extends State<AdminUserScreen> {
  final AdminUserRepository _repository = AdminUserRepository();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<AdminUserItem> _users = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;

  String _selectedFilter =
      'all'; // 'all', 'active', 'suspended', 'shadow_banned'
  String _selectedSort = 'newest'; // 'newest', 'oldest', 'username_az'
  int _currentPage = 1;

  final Map<String, String> _filterLabels = {
    'all': 'All Users',
    'active': 'Active',
    'suspended': 'Suspended',
    'shadow_banned': 'Shadow Banned',
  };

  final Map<String, String> _sortLabels = {
    'newest': 'Newest First',
    'oldest': 'Oldest First',
    'username_az': 'Username A-Z',
  };

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore &&
        !_isLoading) {
      _loadMoreUsers();
    }
  }

  Future<void> _fetchUsers({bool reset = true}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _currentPage = 1;
        _users.clear();
        _hasMore = true;
      });
    }

    try {
      final fetched = await _repository.fetchUsers(
        filter: _selectedFilter,
        sort: _selectedSort,
        searchQuery: _searchController.text,
        page: _currentPage,
        pageSize: 20,
      );

      if (!mounted) return;

      setState(() {
        if (reset) {
          _users = fetched;
        } else {
          _users.addAll(fetched);
        }
        _isLoading = false;
        _isLoadingMore = false;
        _hasMore = fetched.length >= 20;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadMoreUsers() async {
    if (!_hasMore || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    _currentPage++;
    await _fetchUsers(reset: false);
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchUsers(reset: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Top Filter Bar & Search Box
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            children: [
              // Search Input
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161618) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: isDark
                          ? Colors.white10
                          : Colors.black.withOpacity(0.06)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: "Search username, name, or UUID...",
                    hintStyle: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white38 : Colors.grey.shade500),
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 20,
                        color: isDark ? Colors.white38 : Colors.grey.shade500),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _fetchUsers(reset: true);
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Filter Chips + Sort Dropdown Row
              Row(
                children: [
                  // Filter Chips
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _filterLabels.entries.map((entry) {
                          final isSelected = _selectedFilter == entry.key;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: FilterChip(
                              label: Text(
                                entry.value,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                          ? Colors.white70
                                          : Colors.grey.shade800),
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (_) {
                                if (_selectedFilter != entry.key) {
                                  setState(() => _selectedFilter = entry.key);
                                  _fetchUsers(reset: true);
                                }
                              },
                              selectedColor: AppTheme.primaryColor,
                              backgroundColor: isDark
                                  ? const Color(0xFF161618)
                                  : Colors.grey.shade100,
                              side: BorderSide(
                                color: isSelected
                                    ? AppTheme.accentColor
                                    : (isDark
                                        ? Colors.white10
                                        : Colors.black.withOpacity(0.05)),
                                width: isSelected ? 1.2 : 1,
                              ),
                              showCheckmark: false,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Sort Menu Dropdown
                  PopupMenuButton<String>(
                    initialValue: _selectedSort,
                    onSelected: (val) {
                      if (_selectedSort != val) {
                        setState(() => _selectedSort = val);
                        _fetchUsers(reset: true);
                      }
                    },
                    icon: Icon(
                      Icons.sort_rounded,
                      color:
                          isDark ? AppTheme.accentColor : AppTheme.primaryColor,
                      size: 20,
                    ),
                    itemBuilder: (context) => _sortLabels.entries
                        .map(
                          (e) => PopupMenuItem(
                            value: e.key,
                            child: Text(
                              e.value,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // User List View
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _fetchUsers(reset: true),
            child: _buildListContent(isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildListContent(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.redAccent, size: 40),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.grey.shade800),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _fetchUsers(reset: true),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_rounded,
                size: 48,
                color: isDark ? Colors.white38 : Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(
              "No users found matching query",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Try adjusting search keyword or filters",
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _users.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _users.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final user = _users[index];
        return _buildUserCard(user, isDark);
      },
    );
  }

  Widget _buildUserCard(AdminUserItem user, bool isDark) {
    final joinedDate = user.createdAt != null
        ? DateFormat('MMM dd, yyyy').format(user.createdAt!)
        : 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161618) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final updated = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => AdminUserDetailsScreen(user: user),
            ),
          );
          if (updated == true) {
            _fetchUsers(reset: true);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CachedNetworkImage(
                  imageUrl: user.avatarUrl ?? '',
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 44,
                    height: 44,
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                    child:
                        const Icon(Icons.person, size: 24, color: Colors.grey),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 44,
                    height: 44,
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                    child:
                        const Icon(Icons.person, size: 24, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.name != null && user.name!.trim().isNotEmpty
                                ? user.name!
                                : "@${user.username}",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildUserBadge(user),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            "@${user.username}",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "•  $joinedDate",
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                isDark ? Colors.white38 : Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserBadge(AdminUserItem user) {
    if (user.isSuperAdmin) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.accentColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppTheme.accentColor, width: 0.6),
        ),
        child: const Text(
          "SUPER ADMIN",
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            color: AppTheme.accentColor,
          ),
        ),
      );
    }

    if (user.isSuspended) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.redAccent, width: 0.6),
        ),
        child: const Text(
          "SUSPENDED",
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            color: Colors.redAccent,
          ),
        ),
      );
    }

    if (user.isShadowBanned) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orangeAccent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.orangeAccent, width: 0.6),
        ),
        child: const Text(
          "SHADOW BANNED",
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            color: Colors.orangeAccent,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF34D399).withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF34D399), width: 0.6),
      ),
      child: const Text(
        "ACTIVE",
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: Color(0xFF34D399),
        ),
      ),
    );
  }
}
