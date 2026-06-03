import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_provider.dart';

final ImagePicker _picker = ImagePicker();

class StoriesScreen extends StatefulWidget {
  const StoriesScreen({super.key});

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends State<StoriesScreen> {
  List<Map<String, dynamic>> _stories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStories();
    _setupRealtime();
  }

  void _setupRealtime() {
    Supabase.instance.client
        .channel('stories_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'stories',
          callback: (payload) => _loadStories(),
        )
        .subscribe();
  }

  Future<void> _loadStories() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    // Get friends
    final friendsResponse = await Supabase.instance.client
        .from('friend_requests')
        .select('sender_id, receiver_id')
        .or('sender_id.eq.${currentUser.id},receiver_id.eq.${currentUser.id}')
        .eq('status', 'accepted');

    List<String> friendIds = [currentUser.id]; // Include own stories
    
    for (var req in friendsResponse) {
      if (req['sender_id'] != currentUser.id) {
        friendIds.add(req['sender_id']);
      }
      if (req['receiver_id'] != currentUser.id) {
        friendIds.add(req['receiver_id']);
      }
    }

    if (friendIds.isEmpty) {
      setState(() {
        _stories = [];
        _isLoading = false;
      });
      return;
    }

    // Get stories for each friend individually (since in_ not working)
    List<Map<String, dynamic>> allStories = [];
    for (String userId in friendIds) {
      try {
        final stories = await Supabase.instance.client
            .from('stories')
            .select('*, users(full_name, username)')
            .eq('user_id', userId)
            .gt('expires_at', DateTime.now().toIso8601String())
            .order('created_at', ascending: false);
        
        allStories.addAll(List<Map<String, dynamic>>.from(stories));
      } catch (e) {
        print('Error loading stories for user $userId: $e');
      }
    }
    
    // Sort by created_at
    allStories.sort((a, b) => b['created_at'].compareTo(a['created_at']));

    setState(() {
      _stories = allStories;
      _isLoading = false;
    });
  }

  Future<void> _uploadStory() async {
  try {
    print('Starting story upload...');
    
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) {
      print('No image selected');
      return;
    }
    
    print('Image selected: ${pickedFile.path}');
    
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      print('No user logged in');
      return;
    }
    
    print('Current user: ${currentUser.id}');
    
    final file = File(pickedFile.path);
    final fileName = 'story_${DateTime.now().millisecondsSinceEpoch}_${currentUser.id}.jpg';
    
    print('Uploading file: $fileName');
    
    // Upload to Supabase Storage
    await Supabase.instance.client.storage.from('stories').upload(fileName, file);
    
    print('Upload successful, getting public URL');
    
    final imageUrl = Supabase.instance.client.storage.from('stories').getPublicUrl(fileName);
    
    print('Image URL: $imageUrl');
    
    // Save to stories table
    await Supabase.instance.client.from('stories').insert({
      'user_id': currentUser.id,
      'media_url': imageUrl,
      'type': 'image',
    });
    
    print('Story saved to database');
    
    await _loadStories();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Story posted!'), backgroundColor: AppColors.primary),
    );
    
  } catch (e) {
    print('Error uploading story: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
    );
  }
}

  void _viewStory(Map<String, dynamic> story) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  story['users']['full_name'],
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              Expanded(
                child: Center(
                  child: Image.network(
                    story['media_url'],
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.broken_image,
                      size: 100,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Stories'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _uploadStory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_outline,
                        size: 64,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No stories yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to share a story',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _stories.length,
                  itemBuilder: (context, index) {
                    final story = _stories[index];
                    return GestureDetector(
                      onTap: () => _viewStory(story),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          image: DecorationImage(
                            image: NetworkImage(story['media_url']),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.7),
                                ],
                              ),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                            ),
                            child: Text(
                              story['users']['full_name'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}