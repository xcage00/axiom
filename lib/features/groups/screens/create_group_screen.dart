import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_provider.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final List<Map<String, dynamic>> _contacts = [];
  final List<String> _selectedMembers = [];
  bool _isLoading = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final users = await Supabase.instance.client
        .from('users')
        .select()
        .neq('id', currentUser!.id);

    setState(() {
      _contacts.addAll(List<Map<String, dynamic>>.from(users));
      _isLoading = false;
    });
  }

  Future<void> _createGroup() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one member'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isCreating = true);

    final currentUser = Supabase.instance.client.auth.currentUser;

    // Create group
    final newGroup = await Supabase.instance.client
        .from('groups')
        .insert({
          'name': _nameController.text.trim(),
          'created_by': currentUser!.id,
        })
        .select()
        .single();

    // Add creator as admin
    await Supabase.instance.client.from('group_members').insert({
      'group_id': newGroup['id'],
      'user_id': currentUser.id,
      'role': 'admin',
    });

    // Add selected members
    for (var memberId in _selectedMembers) {
      await Supabase.instance.client.from('group_members').insert({
        'group_id': newGroup['id'],
        'user_id': memberId,
        'role': 'member',
      });
    }

    setState(() => _isCreating = false);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group created!'), backgroundColor: AxiomColors.accent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AxiomColors.darkBackground : AxiomColors.lightBackground,
      appBar: AppBar(
        title: const Text('Create Group'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Group Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Select Members',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  ..._contacts.map((contact) => CheckboxListTile(
                    value: _selectedMembers.contains(contact['id']),
                    title: Text(contact['full_name']),
                    subtitle: Text('@${contact['username']}'),
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedMembers.add(contact['id']);
                        } else {
                          _selectedMembers.remove(contact['id']);
                        }
                      });
                    },
                  )),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : _createGroup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AxiomColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isCreating
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Create Group', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}