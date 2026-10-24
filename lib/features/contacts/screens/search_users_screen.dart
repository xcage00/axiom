import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_provider.dart';

class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _existingFriends = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;
    try {
      // Load accepted friends
      final friendsResponse = await Supabase.instance.client
          .from('friend_requests')
          .select('sender_id, receiver_id')
          .or('sender_id.eq.${currentUser.id},receiver_id.eq.${currentUser.id}')
          .eq('status', 'accepted');

      // Load pending requests
      final pendingResponse = await Supabase.instance.client
          .from('friend_requests')
          .select('sender_id, receiver_id, status')
          .or('sender_id.eq.${currentUser.id},receiver_id.eq.${currentUser.id}')
          .neq('status', 'accepted');

      if (mounted) {
        setState(() {
          _existingFriends = List<Map<String, dynamic>>.from(friendsResponse);
          _pendingRequests = List<Map<String, dynamic>>.from(pendingResponse);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _searchError = 'Friend request status could not be refreshed.',
        );
      }
    }
  }

  bool _isAlreadyFriend(String userId) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    return _existingFriends.any(
      (req) =>
          (req['sender_id'] == currentUser?.id &&
              req['receiver_id'] == userId) ||
          (req['sender_id'] == userId && req['receiver_id'] == currentUser?.id),
    );
  }

  String _getRequestStatus(String userId) {
    final currentUser = Supabase.instance.client.auth.currentUser;

    // Check if current user sent a request
    final sentRequest = _pendingRequests.any(
      (req) =>
          req['sender_id'] == currentUser?.id && req['receiver_id'] == userId,
    );

    if (sentRequest) return 'sent';

    // Check if received a request
    final receivedRequest = _pendingRequests.any(
      (req) =>
          req['sender_id'] == userId &&
          req['receiver_id'] == currentUser?.id &&
          req['status'] == 'pending',
    );

    if (receivedRequest) return 'received';

    return 'none';
  }

  Future<void> _searchUsers() async {
    if (_searchQuery.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isLoading = true);

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select()
          .neq('id', currentUser.id)
          .ilike('full_name', '%${_searchQuery.trim()}%');

      if (mounted) {
        setState(() {
          _results = List<Map<String, dynamic>>.from(response);
          _searchError = null;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _searchError =
              'Search is unavailable right now. Check your connection and try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendFriendRequest(String receiverId) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      await Supabase.instance.client.from('friend_requests').insert({
        'sender_id': currentUser.id,
        'receiver_id': receiverId,
        'status': 'pending',
      });

      await _loadExistingData();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friend request sent!'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _acceptRequest(String senderId) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      await Supabase.instance.client
          .from('friend_requests')
          .update({'status': 'accepted'})
          .match({'sender_id': senderId, 'receiver_id': currentUser.id});

      await _loadExistingData();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friend request accepted!'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
              'Find people',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Grow your Axiom circle',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                      if (value.isEmpty) {
                        setState(() => _results = []);
                      }
                    },
                    onSubmitted: (_) => _searchUsers(),
                    style: TextStyle(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by name...',
                      hintStyle: TextStyle(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _searchUsers,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text('Search'),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchError != null
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
                          Text(_searchError!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _searchUsers,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_search_rounded,
                          size: 54,
                          color: colors.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Search by name to find your people'
                              : 'No people found',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final user = _results[index];
                      final isAlreadyFriend = _isAlreadyFriend(user['id']);
                      final requestStatus = _getRequestStatus(user['id']);

                      Widget actionButton;
                      if (isAlreadyFriend) {
                        actionButton = const Icon(
                          Icons.check_circle,
                          color: AppColors.primary,
                        );
                      } else if (requestStatus == 'sent') {
                        actionButton = const Chip(
                          label: Text('Sent'),
                          backgroundColor: Colors.orange,
                        );
                      } else if (requestStatus == 'received') {
                        actionButton = ElevatedButton(
                          onPressed: () => _acceptRequest(user['id']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text('Accept'),
                        );
                      } else {
                        actionButton = ElevatedButton(
                          onPressed: () => _sendFriendRequest(user['id']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text('Add Friend'),
                        );
                      }

                      final userName =
                          user['full_name'] as String? ?? 'Axiom member';
                      final avatarUrl = user['avatar_url'] as String?;
                      return Container(
                        margin: const EdgeInsets.fromLTRB(16, 5, 16, 5),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: colors.outline.withValues(alpha: .45),
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colors.primary.withValues(
                              alpha: .14,
                            ),
                            backgroundImage:
                                avatarUrl == null || avatarUrl.isEmpty
                                ? null
                                : NetworkImage(avatarUrl),
                            child: avatarUrl == null || avatarUrl.isEmpty
                                ? Text(
                                    userName.isEmpty
                                        ? '?'
                                        : userName.characters.first
                                              .toUpperCase(),
                                    style: TextStyle(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : null,
                          ),
                          title: Text(
                            userName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text('@${user['username'] ?? ''}'),
                          trailing: actionButton,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
