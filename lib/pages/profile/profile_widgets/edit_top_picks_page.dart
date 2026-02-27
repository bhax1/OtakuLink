import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Note: Adjust these import paths if they differ slightly in your project structure
import 'package:otakulink/core/models/user_model.dart';
import 'package:otakulink/core/providers/settings_provider.dart';
import 'package:otakulink/pages/profile/profile_widgets/manga_search_delegate.dart';
import 'package:otakulink/repository/profile_repository.dart';

class EditTopPicksPage extends ConsumerStatefulWidget {
  final String userId;

  const EditTopPicksPage({super.key, required this.userId});

  @override
  ConsumerState<EditTopPicksPage> createState() => _EditTopPicksPageState();
}

class _EditTopPicksPageState extends ConsumerState<EditTopPicksPage> {
  late List<TopPickItem?> _slots;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _slots = List<TopPickItem?>.filled(5, null);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      // Fetch the user profile (uses your RAM cache if available)
      final user = await ref
          .read(profileRepositoryProvider)
          .getUserProfileById(widget.userId);

      if (mounted && user != null) {
        setState(() {
          for (int i = 0; i < user.topPicks.length; i++) {
            if (i < 5) _slots[i] = user.topPicks[i];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading picks: $e')));
      }
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final cleanList = _slots.whereType<TopPickItem>().toList();
      await ref.read(profileRepositoryProvider).updateTopPicks(cleanList);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Favorites saved successfully!")));
        Navigator.pop(context, true);
        // Note: If you fully transition to go_router imports here,
        // you can change the above line to: context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _openSearch(int index) async {
    final settings = ref.read(settingsProvider).value;
    final isNsfw = settings?.isNsfw ?? false;
    final isDataSaver = settings?.isDataSaver ?? false;

    final result = await showSearch(
      context: context,
      delegate: MangaSearchDelegate(isNsfw: isNsfw, isDataSaver: isDataSaver),
    );

    if (result != null) {
      setState(() {
        _slots[index] = result;
        _hasChanges = true;
      });
    }
  }

  void _clearSlot(int index) {
    setState(() {
      _slots[index] = null;
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pick Your Top 5",
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: theme.dividerColor.withOpacity(0.2)),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: (_isSaving || !_hasChanges || _isLoading) ? null : _save,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)), // Square FAB
        backgroundColor:
            _hasChanges ? theme.colorScheme.primary : theme.disabledColor,
        foregroundColor:
            _hasChanges ? theme.colorScheme.onPrimary : Colors.white,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.save_rounded),
        label: Text(_isSaving ? "Saving..." : "Save Changes",
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: 5,
              proxyDecorator: (child, index, animation) {
                return Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5))
                      ],
                    ),
                    child: child,
                  ),
                );
              },
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _slots.removeAt(oldIndex);
                  _slots.insert(newIndex, item);
                  _hasChanges = true;
                });
              },
              itemBuilder: (context, index) {
                final item = _slots[index];
                final isFilled = item != null;

                return Container(
                  key: ValueKey('slot_$index'),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: theme.dividerColor.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          offset: const Offset(2, 2),
                          blurRadius: 0)
                    ],
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("#${index + 1}",
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: index == 0
                                    ? Colors.amber
                                    : theme.colorScheme.onSurface)),
                        const SizedBox(width: 16),
                        Container(
                          width: 44,
                          height: 64,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: theme.dividerColor.withOpacity(0.2)),
                          ),
                          child: isFilled
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: CachedNetworkImage(
                                    imageUrl: item.coverUrl,
                                    fit: BoxFit.cover,
                                    memCacheHeight: 150,
                                    errorWidget: (_, __, ___) =>
                                        const Icon(Icons.error, size: 20),
                                  ),
                                )
                              : Icon(Icons.add_photo_alternate_outlined,
                                  color: theme.disabledColor),
                        ),
                      ],
                    ),
                    title: Text(
                      isFilled ? item.title : "Empty Panel",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight:
                            isFilled ? FontWeight.bold : FontWeight.normal,
                        color: isFilled
                            ? theme.colorScheme.onSurface
                            : theme.hintColor,
                        fontStyle:
                            isFilled ? FontStyle.normal : FontStyle.italic,
                        fontSize: 14,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isFilled)
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                color: theme.colorScheme.error),
                            onPressed: () => _clearSlot(index),
                          ),
                        const SizedBox(width: 4),
                        Icon(Icons.drag_indicator_rounded,
                            color: theme.hintColor),
                      ],
                    ),
                    onTap: () => _openSearch(index),
                  ),
                );
              },
            ),
    );
  }
}
