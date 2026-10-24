import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/colors.dart';
import 'group_chat_screen.dart';
import 'create_group_screen.dart';

class GroupsListScreen extends StatefulWidget {
  const GroupsListScreen({super.key});

  @override
  State<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends State<GroupsListScreen> {
  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;
  String? _loadError;
  RealtimeChannel? _groupsChannel;

  @override
  void initState() {
    super.initState();
    _loadGroups();
    _subscribeToGroups();
  }

  @override
  void dispose() {
    _groupsChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToGroups() {
    _groupsChannel = Supabase.instance.client
        .channel('groups_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'group_members',
          callback: (payload) => _loadGroups(),
        )
        .subscribe();
  }

  Future<void> _loadGroups() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (mounted) setState(() => _isLoading = true);
    try {
      final memberGroups = await Supabase.instance.client
          .from('group_members')
          .select('group_id')
          .eq('user_id', currentUser.id);

      final List<String> groupIds = memberGroups
          .map((g) => g['group_id'] as String)
          .toList();

      if (groupIds.isEmpty) {
        if (mounted) {
          setState(() {
            _groups = [];
            _loadError = null;
            _isLoading = false;
          });
        }
        return;
      }

      // Fix: Use 'filter' instead of 'in_'
      final List<Map<String, dynamic>> groups = [];
      for (var id in groupIds) {
        final group = await Supabase.instance.client
            .from('groups')
            .select()
            .eq('id', id)
            .maybeSingle();
        if (group != null) {
          groups.add(group);
        }
      }

      // Sort by created_at
      groups.sort((a, b) => b['created_at'].compareTo(a['created_at']));

      // Get last message for each group
      final List<Map<String, dynamic>> processedGroups = [];
      for (var group in groups) {
        final lastMessage = await Supabase.instance.client
            .from('group_messages')
            .select()
            .eq('group_id', group['id'])
            .order('created_at', ascending: false)
            .limit(1);

        processedGroups.add({
          ...group,
          'last_message': lastMessage.isNotEmpty
              ? lastMessage.first['message']
              : 'No messages yet',
        });
      }

      if (mounted) {
        setState(() {
          _groups = processedGroups;
          _loadError = null;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadError =
              'Groups could not be loaded. Check your connection and try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _leaveGroup(String groupId) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    await Supabase.instance.client.from('group_members').delete().match({
      'group_id': groupId,
      'user_id': currentUser!.id,
    });

    await _loadGroups();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Left group'),
          backgroundColor: AppColors.accent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Groups',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Good conversations happen together',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Create a group',
            icon: const Icon(Icons.group_add_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateGroupScreen(),
                ),
              ).then((_) => _loadGroups());
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
                    const Icon(Icons.cloud_off_rounded, size: 42),
                    const SizedBox(height: 12),
                    Text(_loadError!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loadGroups,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : _groups.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.diversity_3_rounded,
                    size: 48,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Your people, together',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 34),
                    child: Text(
                      'Create a group to bring a conversation to everyone.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateGroupScreen(),
                        ),
                      ).then((_) => _loadGroups());
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create a group'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadGroups,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
                itemCount: _groups.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final group = _groups[index];
                  final name = group['name'] as String? ?? 'Group';
                  return Material(
                    color: colors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: colors.outline.withValues(alpha: .45),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 7,
                      ),
                      leading: CircleAvatar(
                        radius: 27,
                        backgroundColor: colors.primary.withValues(alpha: .14),
                        child: Text(
                          name.isEmpty
                              ? '?'
                              : name.characters.first.toUpperCase(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        group['last_message'] as String? ?? 'No messages yet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Group options',
                        icon: const Icon(Icons.more_horiz_rounded),
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'leave',
                            child: Text('Leave group'),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'leave') {
                            _leaveGroup(group['id'] as String);
                          }
                        },
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GroupChatScreen(
                              groupId: group['id'],
                              groupName: name,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
          ).then((_) => _loadGroups());
        },
        tooltip: 'Create a group',
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
