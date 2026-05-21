import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_provider.dart';

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
    await _loadMembers();
    await _loadMessages();
    _subscribeToMessages();
    setState(() => _isLoading = false);
    _scrollToBottom();
  }

  Future<void> _loadMembers() async {
    final members = await Supabase.instance.client
        .from('group_members')
        .select('user_id, users(full_name)')
        .eq('group_id', widget.groupId);

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
            if (mounted) {
              setState(() => _messages.add(Map<String, dynamic>.from(newMessage)));
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

    setState(() => _messages = List<Map<String, dynamic>>.from(messages));
  }

  Future<void> _sendMessage({String? text, String? imageUrl}) async {
    if ((text == null || text.isEmpty) && imageUrl == null) return;

    final currentUser = Supabase.instance.client.auth.currentUser;

    await Supabase.instance.client.from('group_messages').insert({
      'group_id': widget.groupId,
      'sender_id': currentUser!.id,
      'message': text ?? '',
      'image_url': imageUrl,
    });

    _messageController.clear();
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
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
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
            const Text('Group Info', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('${_members.length} members'),
            const SizedBox(height: 8),
            ..._members.map((member) => ListTile(
              leading: const Icon(Icons.person),
              title: Text(member['users']['full_name'] ?? 'User'),
            )),
          ],
        ),
      ),
    );
  }

  String _getSenderName(String userId) {
    final member = _members.firstWhere(
      (m) => m['user_id'] == userId,
      orElse: () => {'users': {'full_name': 'Unknown'}},
    );
    return member['users']['full_name'] ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: isDark ? AxiomColors.darkBackground : AxiomColors.lightBackground,
      appBar: AppBar(
        title: Text(widget.groupName),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back, color: isDark ? AxiomColors.darkText : AxiomColors.lightText),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showGroupInfo,
          ),
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
                              Icon(Icons.group, size: 64, color: isDark ? AxiomColors.darkTextSecondary : AxiomColors.lightTextSecondary),
                              const SizedBox(height: 16),
                              Text('No messages yet', style: TextStyle(color: isDark ? AxiomColors.darkTextSecondary : AxiomColors.lightTextSecondary)),
                              const SizedBox(height: 8),
                              Text('Send a message to start the conversation', style: TextStyle(fontSize: 12)),
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

                            return Align(
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
                                    if (!isMe)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          _getSenderName(message['sender_id']),
                                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                                        ),
                                      ),
                                    if (hasImage)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          message['image_url'],
                                          width: 200,
                                          height: 200,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            width: 200,
                                            height: 200,
                                            color: Colors.grey,
                                            child: const Icon(Icons.broken_image),
                                          ),
                                        ),
                                      ),
                                    if (hasText)
                                      Padding(
                                        padding: EdgeInsets.only(top: hasImage ? 8 : 0, left: 8, right: 8, bottom: 4),
                                        child: Text(
                                          message['message'],
                                          style: TextStyle(color: isMe ? Colors.white : (isDark ? AxiomColors.darkText : AxiomColors.lightText)),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (_isSending) const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AxiomColors.darkSurface : Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, -2))],
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _pickAndSendImage,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? AxiomColors.darkBackground : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Icon(Icons.image, color: AxiomColors.accent),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark ? AxiomColors.darkBackground : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: TextField(
                            controller: _messageController,
                            style: TextStyle(color: isDark ? AxiomColors.darkText : AxiomColors.lightText),
                            decoration: InputDecoration(
                              hintText: 'Message...',
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onSubmitted: (_) {
                              if (_messageController.text.trim().isNotEmpty) _sendMessage(text: _messageController.text.trim());
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          if (_messageController.text.trim().isNotEmpty) _sendMessage(text: _messageController.text.trim());
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(color: AxiomColors.accent, shape: BoxShape.circle),
                          child: const Icon(Icons.send, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}