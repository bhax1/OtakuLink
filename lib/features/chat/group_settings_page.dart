import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/core/utils/app_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:otakulink/features/chat/data/repositories/chat_repository.dart';
import 'package:otakulink/features/profile/domain/entities/profile_entities.dart';
import 'package:otakulink/features/profile/data/repositories/profile_repository.dart';
import 'package:otakulink/features/profile/data/repositories/follow_repository.dart';
import 'package:otakulink/core/utils/secure_logger.dart';
import 'package:otakulink/core/services/audit_service.dart';
import 'package:otakulink/core/utils/validators.dart';

class GroupSettingsPage extends ConsumerStatefulWidget {
  final String roomId;
  final String currentName;
  final String? currentIconUrl;

  const GroupSettingsPage({
    super.key,
    required this.roomId,
    required this.currentName,
    this.currentIconUrl,
  });

  @override
  ConsumerState<GroupSettingsPage> createState() => _GroupSettingsPageState();
}

class _GroupSettingsPageState extends ConsumerState<GroupSettingsPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _iconUrlController = TextEditingController();
  final Set<String> _selectedNewUserIds = {};

  bool _isLoading = false;
  bool _isLoadingMembers = true;
  String? _adminId;
  List<ProfileEntity> _currentMembers = [];
  List<ProfileEntity> _availableMutuals = [];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.currentName;
    _iconUrlController.text = widget.currentIconUrl ?? '';
    _fetchMembersAndMutuals();
  }

  Future<void> _fetchMembersAndMutuals() async {
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final followRepo = ref.read(followRepositoryProvider);
      final profileRepo = ref.read(profileRepositoryProvider);
      final myId = Supabase.instance.client.auth.currentUser?.id;

      if (myId == null) return;

      // Fetch admin ID
      _adminId = await chatRepo.getRoomAdminId(widget.roomId);

      // Fetch current members
      final memberIds = await chatRepo.getGroupMemberIds(widget.roomId);
      List<ProfileEntity> members = [];
      for (String uid in memberIds) {
        final p = await profileRepo.getUserProfileById(uid);
        if (p != null) members.add(p);
      }

      // Fetch mutuals to suggest as new members
      final mutualIds = await followRepo.getMutualIds(myId);
      final potentialNewIds = mutualIds
          .where((id) => !memberIds.contains(id))
          .toList();

      List<ProfileEntity> loadedMutuals = [];
      for (String uid in potentialNewIds) {
        final profile = await profileRepo.getUserProfileById(uid);
        if (profile != null) loadedMutuals.add(profile);
      }

      if (mounted) {
        setState(() {
          _currentMembers = members;
          _availableMutuals = loadedMutuals;
          _isLoadingMembers = false;
        });
      }
    } catch (e, stack) {
      SecureLogger.logError(
        "GroupSettingsPage _fetchMembersAndMutuals",
        e,
        stack,
      );
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  bool _isValidImageUrl(String url) {
    if (url.isEmpty) return true;
    final regex = RegExp(
      r'^https:\/\/.+\.(jpeg|jpg|png|gif|webp)(\?.*)?$',
      caseSensitive: false,
    );
    return regex.hasMatch(url);
  }

  Future<void> _handleUpdate() async {
    setState(() => _isLoading = true);
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final audit = ref.read(auditServiceProvider);
      final newName = _nameController.text.trim();
      final newIcon = _iconUrlController.text.trim();

      final validationError = AppValidators.validateRequired(
        newName,
        'Group Name',
      );
      if (validationError != null) {
        AppSnackBar.show(context, validationError, type: SnackBarType.error);
        setState(() => _isLoading = false);
        return;
      }

      // Update Group Info if changed
      if (newName != widget.currentName ||
          newIcon != (widget.currentIconUrl ?? '')) {
        await chatRepo.updateGroupInfo(
          roomId: widget.roomId,
          name: newName != widget.currentName ? newName : null,
          iconUrl: newIcon != (widget.currentIconUrl ?? '') ? newIcon : null,
        );

        audit.logAction(
          action: 'update_group_info',
          targetTable: 'chat_rooms',
          targetId: widget.roomId,
          details: {
            'nameChanged': newName != widget.currentName,
            'iconChanged': newIcon != (widget.currentIconUrl ?? ''),
          },
        );
      }

      // Add new members if any
      if (_selectedNewUserIds.isNotEmpty) {
        await chatRepo.addMembersToGroup(
          roomId: widget.roomId,
          userIds: _selectedNewUserIds.toList(),
        );

        audit.logAction(
          action: 'add_group_members',
          targetTable: 'chat_rooms',
          targetId: widget.roomId,
          details: {'count': _selectedNewUserIds.length},
        );
      }

      if (mounted) {
        AppSnackBar.show(
          context,
          "Group updated successfully",
          type: SnackBarType.success,
        );
        Navigator.pop(context);
      }
    } catch (e, stack) {
      SecureLogger.logError("GroupSettingsPage _handleUpdate", e, stack);
      if (mounted) {
        AppSnackBar.show(context, "Error: $e", type: SnackBarType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLeave() async {
    final isAdmin = Supabase.instance.client.auth.currentUser?.id == _adminId;

    if (isAdmin && _currentMembers.length > 1) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Transfer Admin Rights"),
            content: const Text(
              "You must transfer admin rights to another member before leaving.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (isAdmin && _currentMembers.length <= 1) {
        // Last person and admin, just delete
        await ref.read(chatRepositoryProvider).deleteGroup(widget.roomId);
        ref
            .read(auditServiceProvider)
            .logAction(
              action: 'delete_chat_group',
              targetTable: 'chat_rooms',
              targetId: widget.roomId,
              details: {'reason': 'last_member_left'},
            );
      } else {
        await ref.read(chatRepositoryProvider).leaveGroup(widget.roomId);
        ref
            .read(auditServiceProvider)
            .logAction(
              action: 'leave_chat_group',
              targetTable: 'chat_rooms',
              targetId: widget.roomId,
            );
      }

      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e, stack) {
      SecureLogger.logError("GroupSettingsPage _handleLeave", e, stack);
      if (mounted) {
        AppSnackBar.show(context, "Error: $e", type: SnackBarType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDeleteGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Group"),
        content: const Text(
          "Are you sure you want to delete this group? This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(chatRepositoryProvider).deleteGroup(widget.roomId);

      ref
          .read(auditServiceProvider)
          .logAction(
            action: 'delete_chat_group',
            targetTable: 'chat_rooms',
            targetId: widget.roomId,
            details: {'reason': 'manual_admin_action'},
          );

      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e, stack) {
      SecureLogger.logError("GroupSettingsPage _handleDeleteGroup", e, stack);
      if (mounted) {
        AppSnackBar.show(context, "Error: $e", type: SnackBarType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleTransferAdmin(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Transfer Admin"),
        content: const Text(
          "Are you sure you want to transfer admin rights to this member?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Transfer"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref
          .read(chatRepositoryProvider)
          .transferAdminRights(roomId: widget.roomId, newAdminId: userId);

      ref
          .read(auditServiceProvider)
          .logAction(
            action: 'transfer_group_admin',
            targetTable: 'chat_rooms',
            targetId: widget.roomId,
            details: {'newAdminId': userId},
          );

      await _fetchMembersAndMutuals(); // Refresh to update admin status
      if (mounted) {
        AppSnackBar.show(
          context,
          "Admin rights transferred",
          type: SnackBarType.success,
        );
      }
    } catch (e, stack) {
      SecureLogger.logError("GroupSettingsPage _handleTransferAdmin", e, stack);
      if (mounted) {
        AppSnackBar.show(context, "Error: $e", type: SnackBarType.error);
      }
    }
  }

  Future<void> _handleRemoveMember(String userId) async {
    try {
      await ref
          .read(chatRepositoryProvider)
          .removeMemberFromGroup(roomId: widget.roomId, userId: userId);

      ref
          .read(auditServiceProvider)
          .logAction(
            action: 'remove_group_member',
            targetTable: 'chat_rooms',
            targetId: widget.roomId,
            details: {'removedUserId': userId},
          );

      await _fetchMembersAndMutuals(); // Refresh list
    } catch (e, stack) {
      SecureLogger.logError("GroupSettingsPage _handleRemoveMember", e, stack);
      if (mounted) {
        AppSnackBar.show(context, "Error: $e", type: SnackBarType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUrlValid = _isValidImageUrl(_iconUrlController.text.trim());
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final isAdmin = myId != null && myId == _adminId;
    final totalPotentialMembers =
        _currentMembers.length + _selectedNewUserIds.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Group Settings",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Group Info Section
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        image:
                            (isUrlValid && _iconUrlController.text.isNotEmpty)
                            ? DecorationImage(
                                image: NetworkImage(
                                  _iconUrlController.text.trim(),
                                ),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: (!isUrlValid || _iconUrlController.text.isEmpty)
                          ? const Icon(Icons.group)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: "Group Name",
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _iconUrlController,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: "Cover Image URL",
                              border: const OutlineInputBorder(),
                              errorText:
                                  (!isUrlValid &&
                                      _iconUrlController.text.isNotEmpty)
                                  ? "Invalid image URL"
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  "CURRENT MEMBERS (${_currentMembers.length})",
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (_isLoadingMembers)
                  const Center(child: CircularProgressIndicator())
                else
                  ..._currentMembers.map((member) {
                    final isMe = member.id == myId;
                    final isMemberAdmin = member.id == _adminId;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundImage: member.avatarUrl.isNotEmpty
                            ? NetworkImage(member.avatarUrl)
                            : null,
                        child: member.avatarUrl.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(member.username + (isMe ? " (You)" : "")),
                      subtitle: isMemberAdmin
                          ? Text(
                              "Admin",
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 12,
                              ),
                            )
                          : null,
                      trailing: isAdmin
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isMe)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.star_outline,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        _handleTransferAdmin(member.id),
                                    tooltip: "Transfer Admin Rights",
                                  ),
                                if (!isMe)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.person_remove,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        _handleRemoveMember(member.id),
                                    tooltip: "Remove Member",
                                  ),
                              ],
                            )
                          : null,
                    );
                  }),
                const SizedBox(height: 32),
                Text(
                  "ADD NEW MEMBERS ($totalPotentialMembers/10)",
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (_isLoadingMembers)
                  const Center(child: CircularProgressIndicator())
                else if (_availableMutuals.isEmpty)
                  const Text(
                    "All mutual connections are already in the group or none available.",
                  )
                else
                  ..._availableMutuals.map((user) {
                    final isSelected = _selectedNewUserIds.contains(user.id);
                    return CheckboxListTile(
                      title: Text(user.username),
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            if (totalPotentialMembers >= 10) {
                              AppSnackBar.show(
                                context,
                                "Limit of 10 members reached",
                                type: SnackBarType.error,
                              );
                              return;
                            }
                            _selectedNewUserIds.add(user.id);
                          } else {
                            _selectedNewUserIds.remove(user.id);
                          }
                        });
                      },
                      secondary: CircleAvatar(
                        backgroundImage: user.avatarUrl.isNotEmpty
                            ? NetworkImage(user.avatarUrl)
                            : null,
                        child: user.avatarUrl.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                    );
                  }),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        _isLoading ||
                            !isUrlValid ||
                            _nameController.text.trim().isEmpty
                        ? null
                        : _handleUpdate,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("Apply Changes"),
                  ),
                ),
                const SizedBox(height: 8),
                if (isAdmin)
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _isLoading ? null : _handleDeleteGroup,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text("Delete Group"),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _isLoading ? null : _handleLeave,
                    style: TextButton.styleFrom(
                      foregroundColor: isAdmin
                          ? theme.colorScheme.error.withOpacity(0.5)
                          : theme.colorScheme.error,
                    ),
                    child: const Text("Leave Group"),
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
