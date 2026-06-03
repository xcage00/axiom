import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_provider.dart';
import 'chat_detail_screen.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadChats();
    _subscribeToMessages();
    _subscribeToReadReceipts();
  }

  @override
  void dispose() {
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
          callback: (payload) async {
            await _loadChats(); // Reload when new message arrives
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            await _loadChats(); // Reload when message is read
          },
        )
        .subscribe();
  }

  void _subscribeToReadReceipts() {
    // Listen for read status updates
    Supabase.instance.client
        .channel('read_receipts')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            await _loadChats();
          },
        )
        .subscribe();
  }

  Future<void> _loadChats() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;
    
    // Get all chats for current user
    final chatsData = await Supabase.instance.client
        .from('chats')
        .select()
        .or('participant1.eq.${currentUser.id},participant2.eq.${currentUser.id}');
    
    final List<Map<String, dynamic>> processedChats = [];
    
    for (var chat in chatsData) {
      // Get other participant
      final otherUserId = chat['participant1'] == currentUser.id 
          ? chat['participant2'] 
          : chat['participant1'];
      
      // Get user details
      final userData = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', otherUserId)
          .single();
      
      // Get messages for this chat
      final messages = await Supabase.instance.client
          .from('messages')
          .select()
          .eq('chat_id', chat['id'])
          .order('created_at', ascending: false);
      
      // Count unread messages (messages from other user that are not read)
      int unreadCount = 0;
      String lastMessage = 'No messages yet';
      String lastMessageTime = '';
      
      for (var msg in messages) {
        final deletedFor = msg['deleted_for'] as List? ?? [];
        if (deletedFor.contains(currentUser.id)) continue;
        
        if (lastMessage == 'No messages yet') {
          lastMessage = msg['message'] ?? 'Image';
          lastMessageTime = _formatTime(msg['created_at']);
        }
        
        // Count unread: message from other user AND read_at is null
        if (msg['sender_id'] == otherUserId && msg['read_at'] == null) {
          unreadCount++;
        }
      }
      
      processedChats.add({
        'chat_id': chat['id'],
        'user_id': otherUserId,
        'name': userData['full_name'],
        'username': userData['username'],
        'last_message': lastMessage,
        'last_message_time': lastMessageTime,
        'online_status': userData['online_status'] ?? false,
        'unread_count': unreadCount,
      });
    }
    
    // Sort by last message time (newest first)
    // For simplicity, we'll keep order as is or sort by unread first
    processedChats.sort((a, b) {
      // Chats with unread messages come first
      if (a['unread_count'] > 0 && b['unread_count'] == 0) return -1;
      if (a['unread_count'] == 0 && b['unread_count'] > 0) return 1;
      return 0;
    });
    
    setState(() {
      _chats = processedChats;
      _isLoading = false;
    });
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    
    final dateTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    return '${(difference.inDays / 7).floor()}w';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No chats yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Go to Contacts tab to start a chat',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _chats.length,
                  itemBuilder: (context, index) {
                    final chat = _chats[index];
                    return _buildChatTile(chat, isDark);
                  },
                ),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> chat, bool isDark) {
    final bool hasUnread = chat['unread_count'] > 0;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          // Navigate to chat detail and refresh when coming back
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatDetailScreen(
                contactId: chat['user_id'],
                contactName: chat['name'],
              ),
            ),
          );
          // Reload chats to update unread count
          _loadChats();
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hasUnread 
                ? (isDark ? AppColors.darkSurface.withOpacity(0.8) : AppColors.lightSurface)
                : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
            borderRadius: BorderRadius.circular(16),
            border: hasUnread
                ? Border.all(color: AppColors.accent, width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              // Avatar with online indicator
              Stack(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent.withOpacity(0.1),
                    ),
                    child: Center(
                      child: Text(
                        chat['name'][0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ),
                  if (chat['online_status'])
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accent,
                          border: Border.all(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              
              // Chat info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chat['name'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                              color: isDark ? AppColors.darkText : AppColors.lightText,
                            ),
                          ),
                        ),
                        Text(
                          chat['last_message_time'],
                          style: TextStyle(
                            fontSize: 11,
                            color: hasUnread 
                                ? AppColors.accent 
                                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chat['last_message'],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                              color: hasUnread 
                                  ? (isDark ? Colors.white : AppColors.lightText)
                                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasUnread)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${chat['unread_count']}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
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
}
