import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, dynamic>> _contacts = [];
  final Set<String> _selectedMembers = {};
  bool _isLoading = true;
  bool _isCreating = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (mounted) setState(() => _isLoading = true);
    try {
      final users = await Supabase.instance.client
          .from('users')
          .select('id, full_name, username, avatar_url')
          .neq('id', currentUser.id)
          .order('full_name');
      if (mounted) {
        setState(() {
          _contacts
            ..clear()
            ..addAll(List<Map<String, dynamic>>.from(users));
          _loadError = null;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadError =
              'People could not be loaded. Check your connection and try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createGroup() async {
    final groupName = _nameController.text.trim();
    if (groupName.isEmpty || _selectedMembers.isEmpty || _isCreating) return;
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    setState(() => _isCreating = true);
    try {
      final newGroup = await Supabase.instance.client
          .from('groups')
          .insert({'name': groupName, 'created_by': currentUser.id})
          .select()
          .single();
      await Supabase.instance.client.from('group_members').insert([
        {
          'group_id': newGroup['id'],
          'user_id': currentUser.id,
          'role': 'admin',
        },
        ..._selectedMembers.map(
          (memberId) => {
            'group_id': newGroup['id'],
            'user_id': memberId,
            'role': 'member',
          },
        ),
      ]);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The group could not be created. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  List<Map<String, dynamic>> get _filteredContacts {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _contacts;
    return _contacts.where((contact) {
      final name = (contact['full_name'] as String? ?? '').toLowerCase();
      final username = (contact['username'] as String? ?? '').toLowerCase();
      return name.contains(query) || username.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final canCreate =
        _nameController.text.trim().isNotEmpty &&
        _selectedMembers.isNotEmpty &&
        !_isCreating;

    return Scaffold(
      appBar: AppBar(title: const Text('New group')),
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
                      onPressed: _loadContacts,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bring your people together',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Give your group a name, then choose who to invite.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          maxLength: 60,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Group name',
                            prefixIcon: Icon(Icons.diversity_3_rounded),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Choose members',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${_selectedMembers.length} selected',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Search people',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: colors.surfaceContainerHighest
                                .withValues(alpha: .55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_filteredContacts.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        _contacts.isEmpty
                            ? 'No people are available yet.'
                            : 'No people match that search.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: _filteredContacts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final contact = _filteredContacts[index];
                        final id = contact['id'] as String;
                        final selected = _selectedMembers.contains(id);
                        final name =
                            contact['full_name'] as String? ?? 'Axiom member';
                        final avatarUrl = contact['avatar_url'] as String?;
                        return Material(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(18),
                          child: CheckboxListTile(
                            value: selected,
                            onChanged: (value) => setState(() {
                              if (value == true) {
                                _selectedMembers.add(id);
                              } else {
                                _selectedMembers.remove(id);
                              }
                            }),
                            secondary: CircleAvatar(
                              backgroundColor: colors.primary.withValues(
                                alpha: .14,
                              ),
                              backgroundImage:
                                  avatarUrl == null || avatarUrl.isEmpty
                                  ? null
                                  : NetworkImage(avatarUrl),
                              child: avatarUrl == null || avatarUrl.isEmpty
                                  ? Text(
                                      name.isEmpty
                                          ? '?'
                                          : name.characters.first.toUpperCase(),
                                      style: TextStyle(
                                        color: colors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text('@${contact['username'] ?? ''}'),
                            activeColor: colors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: _isLoading || _loadError != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                child: FilledButton.icon(
                  onPressed: canCreate ? _createGroup : null,
                  icon: _isCreating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_forward_rounded),
                  label: Text(_isCreating ? 'Creating…' : 'Create group'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ),
            ),
    );
  }
}
