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

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;
    
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
    
    setState(() {
      _existingFriends = List<Map<String, dynamic>>.from(friendsResponse);
      _pendingRequests = List<Map<String, dynamic>>.from(pendingResponse);
    });
  }

  bool _isAlreadyFriend(String userId) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    return _existingFriends.any((req) =>
        (req['sender_id'] == currentUser?.id && req['receiver_id'] == userId) ||
        (req['sender_id'] == userId && req['receiver_id'] == currentUser?.id));
  }

  String _getRequestStatus(String userId) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    
    // Check if current user sent a request
    final sentRequest = _pendingRequests.any((req) =>
        req['sender_id'] == currentUser?.id && 
        req['receiver_id'] == userId);
    
    if (sentRequest) return 'sent';
    
    // Check if received a request
    final receivedRequest = _pendingRequests.any((req) =>
        req['sender_id'] == userId && 
        req['receiver_id'] == currentUser?.id &&
        req['status'] == 'pending');
    
    if (receivedRequest) return 'received';
    
    return 'none';
  }

  Future<void> _searchUsers() async {
    if (_searchQuery.trim().isEmpty) return;
    
    setState(() => _isLoading = true);
    
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;
    
    final response = await Supabase.instance.client
        .from('users')
        .select()
        .neq('id', currentUser.id)
        .ilike('full_name', '%${_searchQuery.trim()}%');
    
    setState(() {
      _results = List<Map<String, dynamic>>.from(response);
      _isLoading = false;
    });
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friend request sent!'),
          backgroundColor: AppColors.primary,
        ),
      );
      
    } catch (e) {
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friend request accepted!'),
          backgroundColor: AppColors.primary,
        ),
      );
      
    } catch (e) {
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Add Friends'),
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
                      _searchQuery = value;
                      if (value.isEmpty) {
                        setState(() => _results = []);
                      }
                    },
                    style: TextStyle(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by name...',
                      hintStyle: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
                      borderRadius: BorderRadius.circular(12),
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
                : _results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search,
                              size: 64,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty ? 'Search for users to add' : 'No users found',
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
                            actionButton = const Icon(Icons.check_circle, color: AppColors.primary);
                          } else if (requestStatus == 'sent') {
                            actionButton = const Chip(label: Text('Sent'), backgroundColor: Colors.orange);
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
                          
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withOpacity(0.2),
                              child: Text(
                                user['full_name'][0].toUpperCase(),
                                style: const TextStyle(color: AppColors.primary),
                              ),
                            ),
                            title: Text(user['full_name']),
                            subtitle: Text('@${user['username']}'),
                            trailing: actionButton,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}