import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/colors.dart';
import 'chat_detail_screen.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  final _searchController = TextEditingController();
  final List<Map<String, dynamic>> _chats = [];
  RealtimeChannel? _realtimeChannel;
  Timer? _refreshTimer;
  int _loadRevision = 0;
  bool _isLoading = true;
  String? _loadError;
  String _searchQuery = '';
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    _loadChats();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToMessages() {
    _realtimeChannel = Supabase.instance.client
        .channel('chats_messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (_) => _scheduleReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          callback: (_) => _scheduleReload(),
        )
        .subscribe();
  }

  void _scheduleReload() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 250), _loadChats);
  }

  Future<void> _loadChats() async {
    final revision = ++_loadRevision;
    final client = Supabase.instance.client;
    final currentUser = client.auth.currentUser;

    if (currentUser == null) {
      if (mounted) {
        setState(() {
          _loadError = 'Your session has expired. Sign in again.';
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted && _chats.isEmpty) setState(() => _isLoading = true);

    try {
      final chatRows = await client
          .from('chats')
          .select('id, participant1, participant2')
          .or(
            'participant1.eq.${currentUser.id},participant2.eq.${currentUser.id}',
          );

      final chatIds = <String>[];
      final otherUserIds = <String>{};
      for (final row in chatRows) {
        final chat = Map<String, dynamic>.from(row);
        final chatId = chat['id']?.toString();
        final participant1 = chat['participant1']?.toString();
        final participant2 = chat['participant2']?.toString();
        if (chatId == null || participant1 == null || participant2 == null)
          continue;

        final otherUserId = participant1 == currentUser.id
            ? participant2
            : participant1;
        chatIds.add(chatId);
        otherUserIds.add(otherUserId);
      }

      if (chatIds.isEmpty) {
        if (mounted && revision == _loadRevision) {
          setState(() {
            _chats.clear();
            _loadError = null;
            _isLoading = false;
          });
        }
        return;
      }

      // Fetch related rows in batches to avoid two network round trips per chat.
      final userRows = await client
          .from('users')
          .select('id, full_name, username, online_status, avatar_url')
          .inFilter('id', otherUserIds.toList());
      final messageRows = await client
          .from('messages')
          .select(
            'chat_id, sender_id, message, created_at, read_at, deleted_for',
          )
          .inFilter('chat_id', chatIds)
          .order('created_at', ascending: false);

      final usersById = <String, Map<String, dynamic>>{
        for (final row in userRows)
          if (row['id'] != null)
            row['id'].toString(): Map<String, dynamic>.from(row),
      };
      final messagesByChatId = <String, List<Map<String, dynamic>>>{};
      for (final row in messageRows) {
        final message = Map<String, dynamic>.from(row);
        final chatId = message['chat_id']?.toString();
        if (chatId == null) continue;
        messagesByChatId.putIfAbsent(chatId, () => []).add(message);
      }

      final processedChats = <Map<String, dynamic>>[];
      for (final row in chatRows) {
        final chat = Map<String, dynamic>.from(row);
        final chatId = chat['id']?.toString();
        final participant1 = chat['participant1']?.toString();
        final participant2 = chat['participant2']?.toString();
        if (chatId == null || participant1 == null || participant2 == null)
          continue;

        final otherUserId = participant1 == currentUser.id
            ? participant2
            : participant1;
        final user = usersById[otherUserId];
        final messages = messagesByChatId[chatId] ?? const [];
        var unreadCount = 0;
        String? lastMessage;
        String? lastMessageTime;
        DateTime? lastMessageAt;

        for (final message in messages) {
          final deletedFor = message['deleted_for'];
          final isDeletedForUser =
              deletedFor is List && deletedFor.contains(currentUser.id);
          if (isDeletedForUser) continue;

          if (lastMessage == null) {
            final messageText = message['message']?.toString().trim();
            lastMessage = messageText == null || messageText.isEmpty
                ? 'Attachment'
                : messageText;
            final timestamp = message['created_at']?.toString();
            lastMessageAt = timestamp == null
                ? null
                : DateTime.tryParse(timestamp);
            lastMessageTime = _formatTime(timestamp);
          }

          if (message['sender_id']?.toString() == otherUserId &&
              message['read_at'] == null) {
            unreadCount++;
          }
        }

        processedChats.add({
          'chat_id': chatId,
          'user_id': otherUserId,
          'name': (user?['full_name'] as String?)?.trim().isNotEmpty == true
              ? (user!['full_name'] as String).trim()
              : (user?['username'] as String?) ?? 'Unknown contact',
          'last_message': lastMessage ?? 'No messages yet',
          'last_message_time': lastMessageTime ?? '',
          'last_message_at': lastMessageAt,
          'online_status': user?['online_status'] == true,
          'avatar_url': user?['avatar_url'] as String?,
          'unread_count': unreadCount,
        });
      }

      processedChats.sort((a, b) {
        final aTime = a['last_message_at'] as DateTime?;
        final bTime = b['last_message_at'] as DateTime?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      if (!mounted || revision != _loadRevision) return;
      setState(() {
        _chats
          ..clear()
          ..addAll(processedChats);
        _loadError = null;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Unable to refresh chats: $error');
      if (!mounted || revision != _loadRevision) return;
      setState(() {
        _loadError =
            'Could not load your conversations. Check your connection and try again.';
        _isLoading = false;
      });
    }
  }

  String _formatTime(String? timestamp) {
    final dateTime = timestamp == null ? null : DateTime.tryParse(timestamp);
    if (dateTime == null) return '';

    final difference = DateTime.now().difference(dateTime);
    if (difference.isNegative || difference.inMinutes < 1) return 'Now';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    return '${(difference.inDays / 7).floor()}w';
  }

  List<Map<String, dynamic>> get _visibleChats {
    final query = _searchQuery.trim().toLowerCase();
    return _chats.where((chat) {
      final matchesQuery =
          query.isEmpty ||
          (chat['name'] as String).toLowerCase().contains(query) ||
          (chat['last_message'] as String).toLowerCase().contains(query);
      final matchesUnread = !_unreadOnly || (chat['unread_count'] as int) > 0;
      return matchesQuery && matchesUnread;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final visibleChats = _visibleChats;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadChats,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOUR SPACE',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Your conversations',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _chats.isEmpty
                            ? 'Your private conversations, all in one place.'
                            : '${_chats.length} ${_chats.length == 1 ? 'conversation' : 'conversations'}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search conversations',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchQuery.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 9,
                        children: [
                          ChoiceChip(
                            label: const Text('All messages'),
                            selected: !_unreadOnly,
                            onSelected: (_) =>
                                setState(() => _unreadOnly = false),
                          ),
                          ChoiceChip(
                            avatar: Icon(
                              Icons.mark_chat_unread_outlined,
                              size: 17,
                              color: _unreadOnly
                                  ? colors.onPrimary
                                  : colors.onSurfaceVariant,
                            ),
                            label: const Text('Unread'),
                            selected: _unreadOnly,
                            onSelected: (_) =>
                                setState(() => _unreadOnly = true),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_loadError != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: _ErrorBanner(
                      message: _loadError!,
                      onRetry: _loadChats,
                    ),
                  ),
                ),
              if (_isLoading && _chats.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (visibleChats.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    isSearching: _searchQuery.isNotEmpty,
                    isUnreadFilter: _unreadOnly,
                    hasError: _loadError != null,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverList.separated(
                    itemCount: visibleChats.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _buildChatTile(visibleChats[index]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> chat) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final name = chat['name'] as String;
    final unreadCount = chat['unread_count'] as int;
    final hasUnread = unreadCount > 0;
    final avatarUrl = chat['avatar_url'] as String?;

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: hasUnread
              ? colors.primary.withValues(alpha: 0.32)
              : colors.outline.withValues(alpha: 0.45),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatDetailScreen(
                contactId: chat['user_id'] as String,
                contactName: name,
              ),
            ),
          );
          if (mounted) await _loadChats();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: colors.primary.withValues(alpha: 0.14),
                    child: avatarUrl == null || avatarUrl.isEmpty
                        ? _avatarInitial(name, theme, colors)
                        : ClipOval(
                            child: Image.network(
                              avatarUrl,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _avatarInitial(name, theme, colors),
                            ),
                          ),
                  ),
                  if (chat['online_status'] == true)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.surface, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: hasUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          chat['last_message_time'] as String,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: hasUnread
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chat['last_message'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: hasUnread
                                  ? colors.onSurface
                                  : colors.onSurfaceVariant,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 9),
                          Semantics(
                            label: '$unreadCount unread messages',
                            child: Container(
                              constraints: const BoxConstraints(
                                minWidth: 22,
                                minHeight: 22,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarInitial(String name, ThemeData theme, ColorScheme colors) =>
      Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: theme.textTheme.titleMedium?.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w700,
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.isSearching,
    required this.isUnreadFilter,
    required this.hasError,
  });

  final bool isSearching;
  final bool isUnreadFilter;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final title = hasError
        ? 'Your chats are unavailable'
        : isSearching
        ? 'No matches found'
        : isUnreadFilter
        ? 'Nothing unread'
        : 'Start a conversation';
    final message = hasError
        ? 'Pull down to try again.'
        : isSearching
        ? 'Try a different name or message.'
        : isUnreadFilter
        ? 'You are all caught up.'
        : 'When you message someone, your conversations will appear here.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasError
                  ? Icons.cloud_off_rounded
                  : isUnreadFilter
                  ? Icons.done_all_rounded
                  : Icons.chat_bubble_outline_rounded,
              size: 40,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 7),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.errorContainer,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
