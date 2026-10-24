import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../chat/screens/chat_detail_screen.dart';
import 'search_users_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _loadError;
  RealtimeChannel? _requestsChannel;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealtime();
  }

  void _setupRealtime() {
    _requestsChannel = Supabase.instance.client
        .channel('friend_requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'friend_requests',
          callback: (payload) => _loadData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'friend_requests',
          callback: (payload) => _loadData(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _requestsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      // Load accepted friends
      final friendsResponse = await Supabase.instance.client
          .from('friend_requests')
          .select('''
          sender_id,
          receiver_id,
          sender:sender_id(*),
          receiver:receiver_id(*)
        ''')
          .or('sender_id.eq.${currentUser.id},receiver_id.eq.${currentUser.id}')
          .eq('status', 'accepted');

      final List<Map<String, dynamic>> friendsList = [];
      for (var req in friendsResponse) {
        final isSender = req['sender_id'] == currentUser.id;
        final friendData = isSender ? req['receiver'] : req['sender'];
        if (friendData != null) {
          friendsList.add(Map<String, dynamic>.from(friendData));
        }
      }

      // Load pending requests received
      final pendingResponse = await Supabase.instance.client
          .from('friend_requests')
          .select('''
          *,
          sender:sender_id(*)
        ''')
          .eq('receiver_id', currentUser.id)
          .eq('status', 'pending');

      if (mounted) {
        setState(() {
          _friends = friendsList;
          _pendingRequests = List<Map<String, dynamic>>.from(pendingResponse);
          _loadError = null;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadError =
              'Contacts could not be loaded. Check your connection and try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _acceptRequest(String requestId) async {
    await Supabase.instance.client
        .from('friend_requests')
        .update({'status': 'accepted'})
        .eq('id', requestId);

    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Friend request accepted!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _declineRequest(String requestId) async {
    await Supabase.instance.client
        .from('friend_requests')
        .delete()
        .eq('id', requestId);

    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Friend request declined'),
        backgroundColor: Colors.grey,
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredFriends {
    if (_searchQuery.isEmpty) return _friends;
    return _friends.where((friend) {
      final name = friend['full_name'].toLowerCase();
      final username = friend['username'].toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || username.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'People',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Your circle, all in one place',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Find people',
            icon: const Icon(Icons.person_add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchUsersScreen(),
                ),
              ).then((_) => _loadData());
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 42,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loadData,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 2),
                      child: Text(
                        '${_friends.length} ${_friends.length == 1 ? 'friend' : 'friends'}${_pendingRequests.isEmpty ? '' : ' · ${_pendingRequests.length} request${_pendingRequests.length == 1 ? '' : 's'}'}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  // Pending Requests Section
                  if (_pendingRequests.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Friend Requests',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._pendingRequests.map(
                              (request) => Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.darkSurface
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AppColors.primary
                                          .withValues(alpha: 0.2),
                                      child: Text(
                                        request['sender']['full_name'][0]
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            request['sender']['full_name'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            '@${request['sender']['username']}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark
                                                  ? AppColors.darkTextSecondary
                                                  : AppColors
                                                        .lightTextSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.red,
                                      ),
                                      onPressed: () =>
                                          _declineRequest(request['id']),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          _acceptRequest(request['id']),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                      ),
                                      child: const Text('Accept'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Search Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest.withValues(
                            alpha: .62,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: colors.outline.withValues(alpha: .45),
                          ),
                        ),
                        child: TextField(
                          onChanged: (value) =>
                              setState(() => _searchQuery = value),
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkText
                                : AppColors.lightText,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search friends...',
                            hintStyle: TextStyle(
                              color: colors.onSurfaceVariant,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Friends List
                  if (_filteredFriends.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No friends yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to search and add friends',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final friend = _filteredFriends[index];
                        final isOnline = friend['online_status'] ?? false;
                        final friendName =
                            friend['full_name'] as String? ?? 'Axiom friend';
                        final avatarUrl = friend['avatar_url'] as String?;

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                      ) => ChatDetailScreen(
                                        contactId: friend['id'],
                                        contactName: friend['full_name'],
                                      ),
                                  transitionsBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                        child,
                                      ) {
                                        const begin = Offset(1.0, 0.0);
                                        const end = Offset.zero;
                                        const curve = Curves.easeOutCubic;
                                        var tween = Tween(
                                          begin: begin,
                                          end: end,
                                        ).chain(CurveTween(curve: curve));
                                        return SlideTransition(
                                          position: animation.drive(tween),
                                          child: child,
                                        );
                                      },
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: colors.outline.withValues(alpha: .45),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 27,
                                        backgroundColor: colors.primary
                                            .withValues(alpha: .14),
                                        backgroundImage:
                                            avatarUrl == null ||
                                                avatarUrl.isEmpty
                                            ? null
                                            : NetworkImage(avatarUrl),
                                        child:
                                            avatarUrl == null ||
                                                avatarUrl.isEmpty
                                            ? Text(
                                                friendName.isEmpty
                                                    ? '?'
                                                    : friendName
                                                          .characters
                                                          .first
                                                          .toUpperCase(),
                                                style: theme
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      color: colors.primary,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              )
                                            : null,
                                      ),
                                      if (isOnline)
                                        Positioned(
                                          right: 2,
                                          bottom: 2,
                                          child: Container(
                                            width: 14,
                                            height: 14,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppColors.success,
                                              border: Border.all(
                                                color: colors.surface,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          friendName,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isOnline ? 'Online' : 'Offline',
                                          style: TextStyle(
                                            color: isOnline
                                                ? AppColors.success
                                                : colors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.chat_bubble_outline,
                                      size: 20,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }, childCount: _filteredFriends.length),
                    ),
                ],
              ),
            ),
    );
  }
}
