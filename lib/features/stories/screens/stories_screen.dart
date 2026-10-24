import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/colors.dart';

final ImagePicker _picker = ImagePicker();

class StoriesScreen extends StatefulWidget {
  const StoriesScreen({super.key});

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends State<StoriesScreen> {
  List<Map<String, dynamic>> _stories = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String? _loadError;
  RealtimeChannel? _storiesChannel;

  @override
  void initState() {
    super.initState();
    _loadStories();
    _storiesChannel = Supabase.instance.client
        .channel('stories_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'stories',
          callback: (_) => _loadStories(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _storiesChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadStories() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final friendsResponse = await Supabase.instance.client
          .from('friend_requests')
          .select('sender_id, receiver_id')
          .or('sender_id.eq.${currentUser.id},receiver_id.eq.${currentUser.id}')
          .eq('status', 'accepted');
      final friendIds = <String>{currentUser.id};
      for (final request in friendsResponse) {
        final sender = request['sender_id'];
        final receiver = request['receiver_id'];
        if (sender is String && sender != currentUser.id) friendIds.add(sender);
        if (receiver is String && receiver != currentUser.id) {
          friendIds.add(receiver);
        }
      }

      final batches = await Future.wait(
        friendIds.map((userId) async {
          final rows = await Supabase.instance.client
              .from('stories')
              .select('*, users(full_name, username, avatar_url)')
              .eq('user_id', userId)
              .gt('expires_at', DateTime.now().toIso8601String())
              .order('created_at', ascending: false);
          return List<Map<String, dynamic>>.from(rows);
        }),
      );
      final stories = batches.expand((batch) => batch).toList()
        ..sort(
          (a, b) =>
              (b['created_at'] as String).compareTo(a['created_at'] as String),
        );

      if (mounted) {
        setState(() {
          _stories = stories;
          _loadError = null;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadError =
              'Stories could not be loaded. Check your connection and try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _uploadStory() async {
    if (_isUploading) return;
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null || !mounted) return;
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;
      setState(() => _isUploading = true);

      final bytes = await pickedFile.readAsBytes();
      final extension = pickedFile.name.contains('.')
          ? pickedFile.name.split('.').last.toLowerCase()
          : 'jpg';
      final fileName =
          'story_${DateTime.now().millisecondsSinceEpoch}_${currentUser.id}.$extension';
      final storage = Supabase.instance.client.storage.from('stories');
      await storage.uploadBinary(fileName, bytes);
      await Supabase.instance.client.from('stories').insert({
        'user_id': currentUser.id,
        'media_url': storage.getPublicUrl(fileName),
        'type': 'image',
      });
      await _loadStories();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Story posted')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Story could not be posted. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _viewStory(Map<String, dynamic> story) {
    final owner = story['users'] as Map<String, dynamic>? ?? const {};
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              story['media_url'] as String? ?? '',
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 64,
                  color: Colors.white70,
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 16, 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black54, Colors.transparent],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Close story',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          owner['full_name'] as String? ?? 'Story',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final stories = _stories;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stories',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Moments from your people',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton.filledTonal(
            tooltip: 'Add a story',
            onPressed: _isUploading ? null : _uploadStory,
            icon: _isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? _StoriesMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Stories are taking a break',
              message: _loadError!,
              actionLabel: 'Try again',
              onAction: _loadStories,
            )
          : stories.isEmpty
          ? _StoriesMessage(
              icon: Icons.auto_awesome_rounded,
              title: 'Make the first moment',
              message:
                  'Share a photo with your friends. Stories disappear after their usual expiry.',
              actionLabel: 'Add a story',
              onAction: _uploadStory,
            )
          : RefreshIndicator(
              onRefresh: _loadStories,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 720
                      ? 4
                      : constraints.maxWidth >= 460
                      ? 3
                      : 2;
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: .72,
                    ),
                    itemCount: stories.length,
                    itemBuilder: (context, index) {
                      final story = stories[index];
                      final owner =
                          story['users'] as Map<String, dynamic>? ?? const {};
                      return _StoryCard(
                        name: owner['full_name'] as String? ?? 'Axiom friend',
                        imageUrl: story['media_url'] as String? ?? '',
                        onTap: () => _viewStory(story),
                      );
                    },
                  );
                },
              ),
            ),
    );
  }
}

class _StoriesMessage extends StatelessWidget {
  const _StoriesMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: .24),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 22),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.name,
    required this.imageUrl,
    required this.onTap,
  });

  final String name;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'View story from $name',
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const Center(child: CircularProgressIndicator()),
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.image_not_supported_outlined),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
              Positioned(
                left: 13,
                right: 13,
                bottom: 14,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
