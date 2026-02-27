import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:otakulink/repository/follow_repository.dart';
import '../widgets/hub_search_bar.dart';
import '../widgets/mutual_grid_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/shimmer_loading.dart';

class MutualsGridView extends ConsumerStatefulWidget {
  const MutualsGridView({super.key});

  @override
  ConsumerState<MutualsGridView> createState() => _MutualsGridViewState();
}

class _MutualsGridViewState extends ConsumerState<MutualsGridView>
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
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final mutualsAsyncValue = ref.watch(mutualIdsFutureProvider(currentUserId));

    return GestureDetector(
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
                hintText: 'Search collection...',
                onClear: () {
                  _searchController.clear();
                  _onSearchChanged('');
                  FocusManager.instance.primaryFocus?.unfocus();
                },
              ),
            ),
          ),
          mutualsAsyncValue.when(
            loading: () => const SliverToBoxAdapter(child: ShimmerGrid()),
            error: (err, stack) => SliverToBoxAdapter(
              child: Center(child: Text('Error: $err')),
            ),
            data: (mutualIds) {
              if (mutualIds.isEmpty) {
                return const SliverFillRemaining(
                  child: EmptyStateWidget(
                    icon: Icons.auto_awesome_outlined,
                    title: "No connections yet",
                    subtitle: "Discover readers and creators.",
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.75, // Taller cards
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => MutualGridCard(
                      userId: mutualIds[index],
                      searchQuery: _searchQuery,
                    ),
                    childCount: mutualIds.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
