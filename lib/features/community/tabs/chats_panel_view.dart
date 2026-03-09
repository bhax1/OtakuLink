import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:otakulink/features/chat/domain/entities/chat_room_entity.dart';
import 'package:otakulink/features/chat/data/repositories/chat_repository.dart';
import 'package:otakulink/features/profile/data/repositories/profile_repository.dart';
import '../widgets/hub_search_bar.dart';
import '../widgets/chat_panel_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/shimmer_loading.dart';

class ChatsPanelView extends ConsumerStatefulWidget {
  const ChatsPanelView({super.key});

  @override
  ConsumerState<ChatsPanelView> createState() => _ChatsPanelViewState();
}

class _ChatsPanelViewState extends ConsumerState<ChatsPanelView>
    with AutomaticKeepAliveClientMixin {
  String _searchQuery = '';
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _searchQuery = val.toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final conversationsAsync = ref.watch(conversationsStreamProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.colorScheme.primary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Icon(Icons.edit_square, color: theme.colorScheme.onPrimary),
        onPressed: () => context.push('/create-group'),
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: HubSearchBar(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  hintText: 'Search inbox...',
                  onClear: () {
                    _searchController.clear();
                    _onSearchChanged('');
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                ),
              ),
            ),
            conversationsAsync.when(
              loading: () => const SliverToBoxAdapter(child: ShimmerList()),
              error: (err, stack) =>
                  SliverToBoxAdapter(child: Center(child: Text('Error: $err'))),
              data: (chats) {
                final currentUid =
                    Supabase.instance.client.auth.currentUser?.id ?? '';
                return FutureBuilder<List<ChatRoomEntity>>(
                  future: _filterChats(chats, currentUid),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SliverToBoxAdapter(child: ShimmerList());
                    }

                    final filteredChats = snapshot.data!;

                    if (filteredChats.isEmpty) {
                      return const SliverFillRemaining(
                        child: EmptyStateWidget(
                          icon: Icons.mark_email_read_outlined,
                          title: "Inbox empty",
                          subtitle: "Messages and updates will appear here.",
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ChatPanelCard(chat: filteredChats[index]),
                          );
                        }, childCount: filteredChats.length),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<List<ChatRoomEntity>> _filterChats(
    List<ChatRoomEntity> chats,
    String currentUid,
  ) async {
    if (_searchQuery.isEmpty) return chats;
    final profileRepo = ref.read(profileRepositoryProvider);

    List<ChatRoomEntity> matchedChats = [];

    for (var chat in chats) {
      String title = '';
      if (chat.isGroup) {
        title = chat.groupName?.toLowerCase() ?? '';
      } else {
        final otherUserId = chat.participants.firstWhere(
          (id) => id != currentUid,
          orElse: () => currentUid,
        );
        final profile = await profileRepo.getUserProfileById(otherUserId);
        title = profile?.username.toLowerCase() ?? '';
      }

      final lastMsg = (chat.lastMessageText)?.toLowerCase() ?? '';
      if (title.contains(_searchQuery) || lastMsg.contains(_searchQuery)) {
        matchedChats.add(chat);
      }
    }

    return matchedChats;
  }
}
