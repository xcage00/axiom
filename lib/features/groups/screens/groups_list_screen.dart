import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_provider.dart';
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
    if (currentUser == null) return;

    final memberGroups = await Supabase.instance.client
        .from('group_members')
        .select('group_id')
        .eq('user_id', currentUser.id);

    final List<String> groupIds = memberGroups.map((g) => g['group_id'] as String).toList();

    if (groupIds.isEmpty) {
      setState(() {
        _groups = [];
        _isLoading = false;
      });
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
        'last_message': lastMessage.isNotEmpty ? lastMessage.first['message'] : 'No messages yet',
      });
    }

    setState(() {
      _groups = processedGroups;
      _isLoading = false;
    });
  }

  Future<void> _leaveGroup(String groupId) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    await Supabase.instance.client
        .from('group_members')
        .delete()
        .match({'group_id': groupId, 'user_id': currentUser!.id});

    await _loadGroups();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Left group'), backgroundColor: AppColors.accent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Groups'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
              ).then((_) => _loadGroups());
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.group,
                        size: 64,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No groups yet',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
                          ).then((_) => _loadGroups());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Create Group'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _groups.length,
                  itemBuilder: (context, index) {
                    final group = _groups[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.accent.withOpacity(0.2),
                          child: Text(
                            group['name'][0].toUpperCase(),
                            style: const TextStyle(color: AppColors.accent),
                          ),
                        ),
                        title: Text(
                          group['name'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          group['last_message'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: PopupMenuButton(
                          icon: const Icon(Icons.more_vert),
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'leave', child: Text('Leave Group')),
                          ],
                          onSelected: (value) {
                            if (value == 'leave') {
                              _leaveGroup(group['id']);
                            }
                          },
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GroupChatScreen(
                                groupId: group['id'],
                                groupName: group['name'],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
          ).then((_) => _loadGroups());
        },
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add),
      ),
    );
  }
}
