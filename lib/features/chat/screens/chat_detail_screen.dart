import 'dart:async';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/colors.dart';
import '../../../data/services/call_service.dart';
import '../../call/screens/call_screen.dart';

final ImagePicker _imagePicker = ImagePicker();

class DeleteOptions extends StatelessWidget {
  final VoidCallback onDeleteForMe;
  final VoidCallback? onDeleteForEveryone;

  const DeleteOptions({
    super.key,
    required this.onDeleteForMe,
    this.onDeleteForEveryone,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Delete Message',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          _buildOption(
            icon: Icons.delete_outline,
            title: 'Delete for me',
            subtitle: 'Remove this message only from your device',
            color: Colors.grey,
            onTap: onDeleteForMe,
            isDark: isDark,
          ),
          if (onDeleteForEveryone != null) ...[
            const SizedBox(height: 8),
            _buildOption(
              icon: Icons.delete_forever,
              title: 'Delete for everyone',
              subtitle: 'Remove this message for everyone in the chat',
              color: Colors.red,
              onTap: onDeleteForEveryone!,
              isDark: isDark,
            ),
          ],
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBackground : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatDetailScreen extends StatefulWidget {
  final String contactId;
  final String contactName;

  const ChatDetailScreen({
    super.key,
    required this.contactId,
    required this.contactName,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _chatId;
  bool _contactOnline = false;
  bool _contactIsTyping = false;
  Timer? _typingTimer;
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _statusChannel;
  RealtimeChannel? _typingChannel;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _messagesChannel?.unsubscribe();
    _statusChannel?.unsubscribe();
    _typingChannel?.unsubscribe();
    super.dispose();
  }

  void _setupTypingListener() {
    if (_chatId == null) return;

    _typingChannel = Supabase.instance.client
        .channel('typing_${_chatId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'typing_statuses',
          callback: (payload) {
            final newStatus = payload.newRecord;
            final userId = newStatus['user_id'];
            final isTyping = newStatus['is_typing'] ?? false;
            final chatId = newStatus['chat_id'];

            if (userId == widget.contactId && chatId == _chatId && mounted) {
              setState(() => _contactIsTyping = isTyping);
              if (isTyping) {
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted && _contactIsTyping)
                    setState(() => _contactIsTyping = false);
                });
              }
            }
          },
        )
        .subscribe();
  }

  Future<void> _updateTypingStatus(bool isTyping) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null || _chatId == null) return;

    try {
      await Supabase.instance.client.from('typing_statuses').upsert({
        'chat_id': _chatId,
        'user_id': currentUser.id,
        'is_typing': isTyping,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Silent fail
    }
  }

  void _onTextChanged(String text) {
    if (text.isNotEmpty) {
      _updateTypingStatus(true);
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(milliseconds: 800), () {
        _updateTypingStatus(false);
      });
    } else {
      _updateTypingStatus(false);
      _typingTimer?.cancel();
    }
  }

  Future<void> _initChat() async {
    final currentUser = Supabase.instance.client.auth.currentUser;

    await _getContactStatus();

    final existingChats = await Supabase.instance.client
        .from('chats')
        .select()
        .or(
          'participant1.eq.${currentUser!.id},participant2.eq.${currentUser.id}',
        );

    Map<String, dynamic>? chat;
    for (var c in existingChats) {
      if ((c['participant1'] == widget.contactId &&
              c['participant2'] == currentUser.id) ||
          (c['participant2'] == widget.contactId &&
              c['participant1'] == currentUser.id)) {
        chat = c;
        break;
      }
    }

    if (chat == null) {
      final newChat = await Supabase.instance.client
          .from('chats')
          .insert({
            'participant1': currentUser.id,
            'participant2': widget.contactId,
          })
          .select()
          .single();
      _chatId = newChat['id'];
    } else {
      _chatId = chat['id'];
    }

    await _loadMessages();
    _subscribeToMessages();
    _subscribeToContactStatus();
    _setupTypingListener();
    setState(() => _isLoading = false);
    _scrollToBottom();
  }

  Future<void> _getContactStatus() async {
    final contactData = await Supabase.instance.client
        .from('users')
        .select()
        .eq('id', widget.contactId)
        .single();
    setState(() => _contactOnline = contactData['online_status'] ?? false);
  }

  void _subscribeToMessages() {
    _messagesChannel = Supabase.instance.client
        .channel('chat_messages_${_chatId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: _chatId!,
          ),
          callback: (payload) async {
            final newMessage = payload.newRecord;
            if (mounted) {
              setState(
                () => _messages.add(Map<String, dynamic>.from(newMessage)),
              );
              _scrollToBottom();
            }

            if (newMessage['sender_id'] == widget.contactId && mounted) {
              await _markAsRead(newMessage['id']);
            }
          },
        )
        .subscribe();
  }

  void _subscribeToContactStatus() {
    _statusChannel = Supabase.instance.client
        .channel('user_status_${widget.contactId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.contactId,
          ),
          callback: (payload) {
            final newStatus = payload.newRecord['online_status'] ?? false;
            if (mounted) setState(() => _contactOnline = newStatus);
          },
        )
        .subscribe();
  }

  Future<void> _markAsRead(String messageId) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    final message = _messages.firstWhere((m) => m['id'] == messageId);
    if (message['sender_id'] == currentUser.id) return;

    await Supabase.instance.client
        .from('messages')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('id', messageId);

    setState(() {
      final index = _messages.indexWhere((m) => m['id'] == messageId);
      if (index != -1) {
        _messages[index]['read_at'] = DateTime.now().toIso8601String();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _loadMessages() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    final messages = await Supabase.instance.client
        .from('messages')
        .select()
        .eq('chat_id', _chatId!)
        .order('created_at', ascending: true);

    final List<Map<String, dynamic>> filteredMessages = [];
    for (var msg in messages) {
      final deletedFor = msg['deleted_for'] as List? ?? [];
      if (!deletedFor.contains(currentUser.id)) {
        filteredMessages.add(Map<String, dynamic>.from(msg));
      }
    }

    setState(() => _messages = filteredMessages);

    for (var msg in _messages) {
      if (msg['sender_id'] == widget.contactId && msg['read_at'] == null) {
        await _markAsRead(msg['id']);
      }
    }
  }

  Future<void> _sendMessage({String? text, String? imageUrl}) async {
    if ((text == null || text.isEmpty) && imageUrl == null) return;

    final currentUser = Supabase.instance.client.auth.currentUser;

    await Supabase.instance.client.from('messages').insert({
      'chat_id': _chatId,
      'sender_id': currentUser!.id,
      'receiver_id': widget.contactId,
      'message': text ?? '',
      'image_url': imageUrl,
      'is_read': false,
    });

    _updateTypingStatus(false);
    if (mounted) _messageController.clear();
  }

  Future<void> _sendCurrentMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      await _sendMessage(text: text);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Message not sent. Check your connection and try again.',
            ),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _sendCurrentMessage,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Widget _buildStatusIcon(Map<String, dynamic> message, bool isMe) {
    if (!isMe) return const SizedBox.shrink();

    final wasRead = message['read_at'] != null;
    return Icon(
      wasRead ? Icons.done_all_rounded : Icons.done_rounded,
      size: 15,
      color: wasRead ? AppColors.success : Colors.white70,
      semanticLabel: wasRead ? 'Read' : 'Sent',
    );
  }

  String _formatMessageTime(dynamic value) {
    final timestamp = value is String ? DateTime.tryParse(value) : null;
    return timestamp == null ? '' : DateFormat.jm().format(timestamp.toLocal());
  }

  Future<void> _addReaction(String messageId, String emoji) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    final messageIndex = _messages.indexWhere((m) => m['id'] == messageId);
    if (messageIndex == -1) return;

    final message = _messages[messageIndex];
    Map<String, dynamic> reactions = {};

    if (message['reactions'] != null && message['reactions'] is Map) {
      reactions = Map<String, dynamic>.from(message['reactions']);
    }

    String? oldEmoji;
    for (var entry in reactions.entries) {
      if (entry.value.contains(currentUser.id)) {
        oldEmoji = entry.key;
        break;
      }
    }

    if (oldEmoji != null) {
      final users = List.from(reactions[oldEmoji]);
      users.remove(currentUser.id);
      if (users.isEmpty) {
        reactions.remove(oldEmoji);
      } else {
        reactions[oldEmoji] = users;
      }
    }

    if (oldEmoji != emoji) {
      List<dynamic> users = reactions[emoji] ?? [];
      users.add(currentUser.id);
      reactions[emoji] = users;
    }

    setState(() {
      _messages[messageIndex]['reactions'] = reactions;
    });

    try {
      await Supabase.instance.client
          .from('messages')
          .update({'reactions': reactions})
          .eq('id', messageId);
    } catch (e) {
      await _loadMessages();
    }
  }

  Future<void> _deleteForMe(String messageId) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    final messageIndex = _messages.indexWhere((m) => m['id'] == messageId);
    if (messageIndex == -1) return;

    setState(() {
      _messages.removeAt(messageIndex);
    });

    try {
      await Supabase.instance.client.rpc(
        'add_deleted_for',
        params: {'message_id': messageId, 'user_id': currentUser.id},
      );
    } catch (e) {
      await _loadMessages();
    }
  }

  Future<void> _deleteForEveryone(String messageId) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    final messageIndex = _messages.indexWhere((m) => m['id'] == messageId);
    if (messageIndex == -1) return;

    final message = _messages[messageIndex];
    if (message['sender_id'] != currentUser.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only delete your own messages for everyone'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _messages.removeAt(messageIndex);
    });

    try {
      await Supabase.instance.client
          .from('messages')
          .delete()
          .eq('id', messageId);
    } catch (e) {
      await _loadMessages();
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile == null) return;

      setState(() => _isSending = true);

      final currentUser = Supabase.instance.client.auth.currentUser;
      final file = File(pickedFile.path);
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${currentUser!.id}.jpg';

      await Supabase.instance.client.storage
          .from('chat_images')
          .upload(fileName, file);
      final imageUrl = Supabase.instance.client.storage
          .from('chat_images')
          .getPublicUrl(fileName);
      await _sendMessage(imageUrl: imageUrl);

      setState(() => _isSending = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image sent!'),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _makeCall(bool isVideo) async {
    final callService = CallService();

    try {
      final call = await callService.createCall(
        receiverId: widget.contactId,
        callType: isVideo ? 'video' : 'audio',
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CallScreen(
              contactId: widget.contactId,
              contactName: widget.contactName,
              isVideoCall: isVideo,
              callId: call['id'],
              isInitiator: true,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting call: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildReactionButton(String emoji, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 28)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 70,
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: colors.primary.withValues(alpha: .14),
                  child: Text(
                    widget.contactName.isEmpty
                        ? '?'
                        : widget.contactName.characters.first.toUpperCase(),
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _contactOnline
                          ? AppColors.success
                          : colors.onSurfaceVariant,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.surface, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.contactName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      _contactIsTyping
                          ? 'Typing…'
                          : _contactOnline
                          ? 'Online now'
                          : 'Offline',
                      key: ValueKey((_contactIsTyping, _contactOnline)),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _contactIsTyping || _contactOnline
                            ? AppColors.secondary
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back to conversations',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Voice call',
            icon: const Icon(Icons.call_rounded),
            onPressed: () => _makeCall(false),
          ),
          IconButton(
            tooltip: 'Video call',
            icon: const Icon(Icons.videocam_rounded),
            onPressed: () => _makeCall(true),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No messages yet',
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Send a message to start the conversation',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isMe = message['sender_id'] == currentUserId;
                            final hasImage =
                                message['image_url'] != null &&
                                message['image_url'].isNotEmpty;
                            final hasText =
                                message['message'] != null &&
                                message['message'].isNotEmpty;

                            return GestureDetector(
                              onLongPress: () {
                                showModalBottomSheet(
                                  context: context,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(20),
                                    ),
                                  ),
                                  builder: (context) => Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            _buildReactionButton('❤️', () {
                                              Navigator.pop(context);
                                              _addReaction(message['id'], '❤️');
                                            }),
                                            _buildReactionButton('👍', () {
                                              Navigator.pop(context);
                                              _addReaction(message['id'], '👍');
                                            }),
                                            _buildReactionButton('😂', () {
                                              Navigator.pop(context);
                                              _addReaction(message['id'], '😂');
                                            }),
                                            _buildReactionButton('😮', () {
                                              Navigator.pop(context);
                                              _addReaction(message['id'], '😮');
                                            }),
                                            _buildReactionButton('😢', () {
                                              Navigator.pop(context);
                                              _addReaction(message['id'], '😢');
                                            }),
                                            _buildReactionButton('😡', () {
                                              Navigator.pop(context);
                                              _addReaction(message['id'], '😡');
                                            }),
                                          ],
                                        ),
                                      ),
                                      const Divider(height: 1),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
                                        title: const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                        onTap: () {
                                          Navigator.pop(context);
                                          showModalBottomSheet(
                                            context: context,
                                            shape: const RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.vertical(
                                                    top: Radius.circular(20),
                                                  ),
                                            ),
                                            builder: (context) => DeleteOptions(
                                              onDeleteForMe: () =>
                                                  _deleteForMe(message['id']),
                                              onDeleteForEveryone: isMe
                                                  ? () => _deleteForEveryone(
                                                      message['id'],
                                                    )
                                                  : null,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 440,
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      12,
                                      7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMe ? null : colors.surface,
                                      gradient: isMe
                                          ? AppColors.primaryGradient
                                          : null,
                                      border: isMe
                                          ? null
                                          : Border.all(
                                              color: colors.outline.withValues(
                                                alpha: .5,
                                              ),
                                            ),
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(20),
                                        topRight: const Radius.circular(20),
                                        bottomLeft: Radius.circular(
                                          isMe ? 20 : 5,
                                        ),
                                        bottomRight: Radius.circular(
                                          isMe ? 5 : 20,
                                        ),
                                      ),
                                      boxShadow: isMe
                                          ? [
                                              BoxShadow(
                                                color: colors.primary
                                                    .withValues(alpha: .14),
                                                blurRadius: 16,
                                                offset: const Offset(0, 6),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: isMe
                                          ? CrossAxisAlignment.end
                                          : CrossAxisAlignment.start,
                                      children: [
                                        if (hasImage)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            child: Image.network(
                                              message['image_url'],
                                              width: 236,
                                              height: 220,
                                              fit: BoxFit.cover,
                                              loadingBuilder:
                                                  (
                                                    context,
                                                    child,
                                                    loadingProgress,
                                                  ) {
                                                    if (loadingProgress == null)
                                                      return child;
                                                    return Container(
                                                      width: 236,
                                                      height: 220,
                                                      color: colors
                                                          .surfaceContainerHighest,
                                                      child: const Center(
                                                        child:
                                                            CircularProgressIndicator(),
                                                      ),
                                                    );
                                                  },
                                              errorBuilder:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => Container(
                                                    width: 236,
                                                    height: 220,
                                                    color: colors
                                                        .surfaceContainerHighest,
                                                    child: const Icon(
                                                      Icons
                                                          .broken_image_outlined,
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        if (hasText)
                                          Padding(
                                            padding: EdgeInsets.only(
                                              top: hasImage ? 9 : 0,
                                              left: 2,
                                              right: 2,
                                              bottom: 4,
                                            ),
                                            child: Text(
                                              message['message'],
                                              style: theme.textTheme.bodyLarge
                                                  ?.copyWith(
                                                    color: isMe
                                                        ? Colors.white
                                                        : colors.onSurface,
                                                    height: 1.35,
                                                  ),
                                            ),
                                          ),
                                        if (message['reactions'] != null &&
                                            (message['reactions'] as Map)
                                                .isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Wrap(
                                              spacing: 4,
                                              children:
                                                  (message['reactions']
                                                          as Map<
                                                            String,
                                                            dynamic
                                                          >)
                                                      .entries
                                                      .map((entry) {
                                                        return Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                                vertical: 2,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: isMe
                                                                ? Colors.white
                                                                      .withValues(
                                                                        alpha:
                                                                            .18,
                                                                      )
                                                                : colors
                                                                      .surfaceContainerHighest,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            '${entry.key} ${entry.value.length}',
                                                            style: theme
                                                                .textTheme
                                                                .labelSmall
                                                                ?.copyWith(
                                                                  color: isMe
                                                                      ? Colors
                                                                            .white
                                                                      : colors
                                                                            .onSurface,
                                                                ),
                                                          ),
                                                        );
                                                      })
                                                      .toList(),
                                            ),
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 3,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _formatMessageTime(
                                                  message['created_at'],
                                                ),
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: isMe
                                                          ? Colors.white70
                                                          : colors
                                                                .onSurfaceVariant,
                                                      fontSize: 10,
                                                    ),
                                              ),
                                              if (isMe) ...[
                                                const SizedBox(width: 4),
                                                _buildStatusIcon(message, isMe),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    10,
                    12,
                    10 + MediaQuery.paddingOf(context).bottom,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border(
                      top: BorderSide(
                        color: colors.outline.withValues(alpha: .55),
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Attach an image',
                        onPressed: _isSending ? null : _pickAndSendImage,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          constraints: const BoxConstraints(
                            minHeight: 48,
                            maxHeight: 132,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest.withValues(
                              alpha: .62,
                            ),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: colors.outline.withValues(alpha: .5),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: _messageController,
                            enabled: !_isSending,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (value) {
                              _onTextChanged(value);
                              setState(() {});
                            },
                            style: theme.textTheme.bodyLarge,
                            decoration: InputDecoration(
                              hintText: 'Write a message',
                              hintStyle: theme.textTheme.bodyLarge?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) => _sendCurrentMessage(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Send message',
                        onPressed:
                            _messageController.text.trim().isEmpty || _isSending
                            ? null
                            : _sendCurrentMessage,
                        icon: _isSending
                            ? const SizedBox(
                                width: 19,
                                height: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.arrow_upward_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
