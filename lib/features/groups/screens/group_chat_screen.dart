import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/colors.dart';

final ImagePicker _imagePicker = ImagePicker();

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _loadError;
  RealtimeChannel? _messagesChannel;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _initChat() async {
    try {
      await _loadMembers();
      await _loadMessages();
      if (!mounted) return;
      _subscribeToMessages();
      if (mounted) setState(() => _isLoading = false);
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadError = 'This group conversation could not be loaded.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMembers() async {
    final members = await Supabase.instance.client
        .from('group_members')
        .select('user_id, users(full_name, avatar_url)')
        .eq('group_id', widget.groupId);

    if (!mounted) return;
    setState(() {
      _members = List<Map<String, dynamic>>.from(members);
    });
  }

  void _subscribeToMessages() {
    _messagesChannel = Supabase.instance.client
        .channel('group_messages_${widget.groupId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'group_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'group_id',
            value: widget.groupId,
          ),
          callback: (payload) {
            final newMessage = payload.newRecord;
            if (mounted &&
                !_messages.any(
                  (message) => message['id'] == newMessage['id'],
                )) {
              setState(
                () => _messages.add(Map<String, dynamic>.from(newMessage)),
              );
              _scrollToBottom();
            }
          },
        )
        .subscribe();
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
    final messages = await Supabase.instance.client
        .from('group_messages')
        .select()
        .eq('group_id', widget.groupId)
        .order('created_at', ascending: true);

    if (mounted) {
      setState(() => _messages = List<Map<String, dynamic>>.from(messages));
    }
  }

  Future<void> _sendMessage({String? text, String? imageUrl}) async {
    if ((text == null || text.isEmpty) && imageUrl == null) return;

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) throw StateError('Sign in to send messages.');

    await Supabase.instance.client.from('group_messages').insert({
      'group_id': widget.groupId,
      'sender_id': currentUser.id,
      'message': text ?? '',
      'image_url': imageUrl,
    });

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

  Future<void> _pickAndSendImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile == null) return;
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) throw StateError('Sign in to send images.');

      setState(() => _isSending = true);

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${currentUser.id}.jpg';
      final storage = Supabase.instance.client.storage.from('chat_images');
      await storage.uploadBinary(fileName, await pickedFile.readAsBytes());
      final imageUrl = storage.getPublicUrl(fileName);
      await _sendMessage(imageUrl: imageUrl);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image could not be sent. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showGroupInfo() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Group Info',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('${_members.length} members'),
            const SizedBox(height: 8),
            ..._members.map(
              (member) => ListTile(
                leading: const Icon(Icons.person),
                title: Text(member['users']['full_name'] ?? 'User'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSenderName(String userId) {
    final member = _members.firstWhere(
      (m) => m['user_id'] == userId,
      orElse: () => {
        'users': {'full_name': 'Unknown'},
      },
    );
    final user = member['users'] as Map<String, dynamic>?;
    return user?['full_name'] as String? ?? 'Axiom member';
  }

  String _formatTime(dynamic value) {
    final date = value is String ? DateTime.tryParse(value) : null;
    return date == null ? '' : DateFormat.jm().format(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: colors.primary.withValues(alpha: .14),
              child: Icon(
                Icons.diversity_3_rounded,
                color: colors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.groupName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${_members.length} members',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        leading: IconButton(
          tooltip: 'Back to groups',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Group information',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: _showGroupInfo,
          ),
          const SizedBox(width: 4),
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
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _loadError = null;
                        });
                        _initChat();
                      },
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 78,
                                  height: 78,
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(27),
                                  ),
                                  child: const Icon(
                                    Icons.diversity_3_rounded,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'A space for everyone',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  'Send the first message to get the conversation going.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isMe = message['sender_id'] == currentUserId;
                            final imageUrl = message['image_url'] as String?;
                            final text = message['message'] as String? ?? '';
                            return Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 420,
                                ),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 9),
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    9,
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
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (!isMe)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 5,
                                          ),
                                          child: Text(
                                            _getSenderName(
                                              message['sender_id'] as String? ??
                                                  '',
                                            ),
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: colors.primary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                      if (imageUrl != null &&
                                          imageUrl.isNotEmpty)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          child: Image.network(
                                            imageUrl,
                                            width: 240,
                                            height: 220,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (
                                                  context,
                                                  error,
                                                  stackTrace,
                                                ) => const SizedBox(
                                                  width: 240,
                                                  height: 180,
                                                  child: Center(
                                                    child: Icon(
                                                      Icons
                                                          .broken_image_outlined,
                                                    ),
                                                  ),
                                                ),
                                          ),
                                        ),
                                      if (text.isNotEmpty)
                                        Padding(
                                          padding: EdgeInsets.only(
                                            top:
                                                imageUrl != null &&
                                                    imageUrl.isNotEmpty
                                                ? 8
                                                : 0,
                                            bottom: 4,
                                          ),
                                          child: Text(
                                            text,
                                            style: theme.textTheme.bodyLarge
                                                ?.copyWith(
                                                  color: isMe
                                                      ? Colors.white
                                                      : colors.onSurface,
                                                  height: 1.35,
                                                ),
                                          ),
                                        ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          _formatTime(message['created_at']),
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: isMe
                                                    ? Colors.white70
                                                    : colors.onSurfaceVariant,
                                                fontSize: 10,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(
                    10,
                    9,
                    10,
                    9 + MediaQuery.paddingOf(context).bottom,
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
                            maxHeight: 128,
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
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Write a message',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
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
