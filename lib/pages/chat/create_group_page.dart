import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:otakulink/core/models/user_model.dart';
import 'package:otakulink/repository/chat_repository.dart';
import 'package:otakulink/repository/follow_repository.dart';
import 'package:otakulink/services/user_service.dart';

class CreateGroupPage extends ConsumerStatefulWidget {
  const CreateGroupPage({super.key});

  @override
  ConsumerState<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends ConsumerState<CreateGroupPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _iconUrlController = TextEditingController();
  final Set<String> _selectedUserIds = {};

  bool _isLoading = false;
  bool _isLoadingMutuals = true;
  List<UserModel> _availableMutuals = [];

  bool _isValidImageUrl(String url) {
    if (url.isEmpty) return true;
    if (url.length > 500) return false;
    final regex = RegExp(r'^https:\/\/.+\.(jpeg|jpg|png|gif|webp)(\?.*)?$',
        caseSensitive: false);
    return regex.hasMatch(url);
  }

  bool get _canCreateGroup {
    final isNameValid = _nameController.text.trim().isNotEmpty;
    final isMembersValid = _selectedUserIds.isNotEmpty;
    final isUrlValid = _isValidImageUrl(_iconUrlController.text.trim());
    return isNameValid && isMembersValid && isUrlValid && !_isLoading;
  }

  @override
  void initState() {
    super.initState();
    _fetchRealMutuals();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _iconUrlController.dispose();
    super.dispose();
  }

  Future<void> _fetchRealMutuals() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final mutualIds =
          await ref.read(followRepositoryProvider).getMutualIds(currentUserId);
      final userService = ref.read(userServiceProvider);

      List<UserModel> loadedUsers = [];
      for (String uid in mutualIds) {
        final userModel = await userService.getUserProfile(uid);
        if (userModel != null) loadedUsers.add(userModel);
      }

      if (mounted) {
        setState(() {
          _availableMutuals = loadedUsers;
          _isLoadingMutuals = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMutuals = false);
    }
  }

  Future<void> _handleCreateGroup() async {
    if (!_canCreateGroup) return;
    setState(() => _isLoading = true);

    try {
      final iconUrl = _iconUrlController.text.trim();
      final chatRepo = ref.read(chatRepositoryProvider);

      await chatRepo.createGroupChat(
        groupName: _nameController.text.trim(),
        selectedUserIds: _selectedUserIds.toList(),
        groupIconUrl: iconUrl.isNotEmpty ? iconUrl : null,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUrl = _iconUrlController.text.trim();
    final isUrlValid = _isValidImageUrl(currentUrl);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text("Create Group",
            style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: theme.dividerColor.withOpacity(0.2)),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: theme.dividerColor.withOpacity(0.2)),
                    image: (currentUrl.isNotEmpty && isUrlValid)
                        ? DecorationImage(
                            image: NetworkImage(currentUrl), fit: BoxFit.cover)
                        : null,
                  ),
                  child: (currentUrl.isEmpty || !isUrlValid)
                      ? Icon(Icons.group_add_rounded,
                          size: 32, color: theme.colorScheme.primary)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        onChanged: (value) => setState(() {}),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: "Group Name",
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest
                              .withOpacity(0.3),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _iconUrlController,
                        onChanged: (value) => setState(() {}),
                        maxLength: 500,
                        style: theme.textTheme.bodyMedium,
                        decoration: InputDecoration(
                          hintText: "Cover Image URL (Optional)",
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest
                              .withOpacity(0.3),
                          counterText: "",
                          errorText: (currentUrl.isNotEmpty && !isUrlValid)
                              ? "Must be a secure image link"
                              : null,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            width: double.infinity,
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
            child: Text(
              "SELECT MEMBERS",
              style: theme.textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ),
          if (_isLoadingMutuals)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_availableMutuals.isEmpty)
            Expanded(
                child: Center(
                    child: Text("No connections available.",
                        style: TextStyle(color: theme.hintColor))))
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                itemCount: _availableMutuals.length,
                separatorBuilder: (context, index) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final user = _availableMutuals[index];
                  final isSelected = _selectedUserIds.contains(user.id);

                  return ListTile(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedUserIds.remove(user.id);
                        } else {
                          _selectedUserIds.add(user.id);
                        }
                      });
                    },
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    tileColor: isSelected
                        ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                        : null,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        image: user.avatarUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(user.avatarUrl),
                                fit: BoxFit.cover)
                            : null,
                      ),
                      child: user.avatarUrl.isEmpty
                          ? const Icon(Icons.person, size: 20)
                          : null,
                    ),
                    title: Text(user.username,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Checkbox(
                      value: isSelected,
                      activeColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedUserIds.add(user.id);
                          } else {
                            _selectedUserIds.remove(user.id);
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: FilledButton(
            onPressed: _canCreateGroup ? _handleCreateGroup : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: theme.colorScheme.onPrimary, strokeWidth: 2),
                  )
                : const Text("Initialize Group",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
