import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_provider.dart';

// Mobile image picker only
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
        color: isDark ? AxiomColors.darkSurface : Colors.white,
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
          color: isDark ? AxiomColors.darkBackground : Colors.grey.shade50,
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
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? AxiomColors.darkTextSecondary : AxiomColors.lightTextSecondary)),
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
                  if (mounted && _contactIsTyping) setState(() => _contactIsTyping = false);
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
      await Supabase.instance.client
          .from('typing_statuses')
          .upsert({
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
        .or('participant1.eq.${currentUser!.id},participant2.eq.${currentUser.id}');
    
    Map<String, dynamic>? chat;
    for (var c in existingChats) {
      if ((c['participant1'] == widget.contactId && c['participant2'] == currentUser.id) ||
          (c['participant2'] == widget.contactId && c['participant1'] == currentUser.id)) {
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
              setState(() => _messages.add(Map<String, dynamic>.from(newMessage)));
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
    _messageController.clear();
  }

  Widget _buildStatusIcon(Map<String, dynamic> message, bool isMe) {
    if (!isMe) return const SizedBox.shrink();
    
    if (message['read_at'] != null) {
      return const Icon(Icons.done_all, size: 12, color: Color(0xFF10B981));
    } else if (message['created_at'] != null) {
      return const Icon(Icons.done_all, size: 12, color: Colors.grey);
    } else {
      return const Icon(Icons.done, size: 12, color: Colors.grey);
    }
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
      await Supabase.instance.client.rpc('add_deleted_for', params: {
        'message_id': messageId,
        'user_id': currentUser.id,
      });
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
      final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;
      
      setState(() => _isSending = true);
      
      final currentUser = Supabase.instance.client.auth.currentUser;
      final file = File(pickedFile.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${currentUser!.id}.jpg';
      
      await Supabase.instance.client.storage.from('chat_images').upload(fileName, file);
      final imageUrl = Supabase.instance.client.storage.from('chat_images').getPublicUrl(fileName);
      await _sendMessage(imageUrl: imageUrl);
      
      setState(() => _isSending = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image sent!'), backgroundColor: AxiomColors.accent, duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    
    return Scaffold(
      backgroundColor: isDark ? AxiomColors.darkBackground : AxiomColors.lightBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.contactName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: _contactOnline ? AxiomColors.accent : Colors.grey)),
                const SizedBox(width: 4),
                Text(_contactIsTyping ? 'Typing...' : (_contactOnline ? 'Online' : 'Offline'), style: TextStyle(fontSize: 11, color: _contactIsTyping ? AxiomColors.accent : (_contactOnline ? AxiomColors.accent : Colors.grey))),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back, color: isDark ? AxiomColors.darkText : AxiomColors.lightText)),
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
                              Icon(Icons.chat_bubble_outline, size: 64, color: isDark ? AxiomColors.darkTextSecondary : AxiomColors.lightTextSecondary),
                              const SizedBox(height: 16),
                              Text('No messages yet', style: TextStyle(color: isDark ? AxiomColors.darkTextSecondary : AxiomColors.lightTextSecondary)),
                              const SizedBox(height: 8),
                              Text('Send a message to start the conversation', style: TextStyle(fontSize: 12, color: isDark ? AxiomColors.darkTextSecondary : AxiomColors.lightTextSecondary)),
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
                            final hasImage = message['image_url'] != null && message['image_url'].isNotEmpty;
                            final hasText = message['message'] != null && message['message'].isNotEmpty;
                            
                            return GestureDetector(
                              onLongPress: () {
                                showModalBottomSheet(
                                  context: context,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                  ),
                                  builder: (context) => Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                                        leading: const Icon(Icons.delete_outline, color: Colors.red),
                                        title: const Text('Delete', style: TextStyle(color: Colors.red)),
                                        onTap: () {
                                          Navigator.pop(context);
                                          showModalBottomSheet(
                                            context: context,
                                            shape: const RoundedRectangleBorder(
                                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                            ),
                                            builder: (context) => DeleteOptions(
                                              onDeleteForMe: () => _deleteForMe(message['id']),
                                              onDeleteForEveryone: isMe ? () => _deleteForEveryone(message['id']) : null,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Align(
                                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isMe ? AxiomColors.accent : (isDark ? AxiomColors.darkSurface : Colors.white),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (hasImage)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.network(
                                            message['image_url'],
                                            width: 200,
                                            height: 200,
                                            fit: BoxFit.cover,
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return Container(width: 200, height: 200, color: Colors.grey.withOpacity(0.3), child: const Center(child: CircularProgressIndicator()));
                                            },
                                            errorBuilder: (context, error, stackTrace) => Container(width: 200, height: 200, color: Colors.grey, child: const Icon(Icons.broken_image)),
                                          ),
                                        ),
                                      if (hasText)
                                        Padding(
                                          padding: EdgeInsets.only(top: hasImage ? 8 : 0, left: 8, right: 8, bottom: 4),
                                          child: Text(message['message'], style: TextStyle(color: isMe ? Colors.white : (isDark ? AxiomColors.darkText : AxiomColors.lightText), fontSize: 14)),
                                        ),
                                      if (message['reactions'] != null && (message['reactions'] as Map).isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Wrap(
                                            spacing: 4,
                                            children: (message['reactions'] as Map<String, dynamic>).entries.map((entry) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                                                child: Text('${entry.key} ${entry.value.length}', style: const TextStyle(fontSize: 11)),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      if (isMe)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: _buildStatusIcon(message, isMe),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (_isSending) const Padding(padding: EdgeInsets.all(8), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text('Sending image...')])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: isDark ? AxiomColors.darkSurface : Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, -2))]),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _isSending ? null : _pickAndSendImage,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: isDark ? AxiomColors.darkBackground : const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(25)),
                          child: Icon(Icons.image, color: _isSending ? Colors.grey : AxiomColors.accent, size: 24),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(color: isDark ? AxiomColors.darkBackground : const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(25)),
                          child: TextField(
                            controller: _messageController,
                            enabled: !_isSending,
                            onChanged: _onTextChanged,
                            style: TextStyle(color: isDark ? AxiomColors.darkText : AxiomColors.lightText),
                            decoration: InputDecoration(
                              hintText: 'Message...',
                              hintStyle: TextStyle(color: isDark ? AxiomColors.darkTextSecondary : AxiomColors.lightTextSecondary),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onSubmitted: (_) {
                              if (_messageController.text.trim().isNotEmpty && !_isSending) _sendMessage(text: _messageController.text.trim());
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          if (_messageController.text.trim().isNotEmpty && !_isSending) _sendMessage(text: _messageController.text.trim());
                        },
                        child: Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: AxiomColors.accent, shape: BoxShape.circle), child: const Icon(Icons.send, color: Colors.white, size: 20)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}