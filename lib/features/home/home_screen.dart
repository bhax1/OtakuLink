import 'dart:async';
import 'dart:collection';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:otakulink/core/utils/app_snackbar.dart';

import 'package:otakulink/features/auth/data/auth_repository.dart';
import 'package:otakulink/features/notifications/data/notification_repository.dart';
import 'package:otakulink/features/shared/connectivity_wrapper.dart';
import 'package:otakulink/services/user_service.dart';

// Convert to ConsumerStatefulWidget
class HomeScreen extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const HomeScreen({
    super.key,
    required this.navigationShell,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime? currentBackPressTime;

  late final Stream<int> _unreadCountStream;

  StreamSubscription? _eventSubscription;
  Timer? _popupTimer;

  final List<OverlayEntry> _activeOverlays = [];
  final Queue<WidgetBuilder> _popupQueue = Queue<WidgetBuilder>();

  static const double _appBarLogoHeight = 90.0;

  @override
  void initState() {
    super.initState();
    _unreadCountStream =
        ref.read(notificationRepositoryProvider).getUnreadCountStream();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _popupTimer?.cancel();
    _popupQueue.clear();

    for (var entry in _activeOverlays) {
      if (entry.mounted) entry.remove();
    }
    _activeOverlays.clear();
    super.dispose();
  }

  void _onItemTapped(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child:
                const Text("Logout", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        // USE RIVERPOD PROVIDER TO CLEAR THE GLOBAL CACHE
        final authRepo = ref.read(authRepositoryProvider);
        await authRepo.logout();
      } catch (e) {
        AppSnackBar.show(
          context,
          'Logout failed: $e',
          type: SnackBarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return ConnectivityWrapper(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;

          if (widget.navigationShell.currentIndex != 0) {
            _onItemTapped(0);
            return;
          }

          final now = DateTime.now();
          if (currentBackPressTime == null ||
              now.difference(currentBackPressTime!) >
                  const Duration(seconds: 2)) {
            currentBackPressTime = now;

            AppSnackBar.show(
              context,
              'Tap back again to exit',
              type: SnackBarType.warning,
            );
            return;
          }
          SystemNavigator.pop();
        },
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          extendBody: false,
          appBar: _buildAppBar(theme),
          body: widget.navigationShell,
          bottomNavigationBar:
              !isKeyboardVisible ? _buildBottomNavigationBar(theme) : null,
        ),
      ),
    );
  }

  AppBar _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: theme.colorScheme.primary,
      automaticallyImplyLeading: false,
      elevation: 0,
      leading: StreamBuilder<int>(
        stream: _unreadCountStream,
        initialData: 0,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const SizedBox.shrink();
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const IconButton(
              icon: Icon(Icons.notifications_none_rounded,
                  color: Colors.white, size: 28),
              onPressed: null,
            );
          }

          final count = snapshot.data ?? 0;
          return IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded,
                    color: Colors.white, size: 28),
                if (count > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        count > 99 ? '!!' : count.toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => context.push('/notifications'),
          );
        },
      ),
      title: Center(
        child: Image.asset('assets/logo/logo_flat_accent.png',
            height: _appBarLogoHeight),
      ),
      actions: [_buildPopupMenu(theme)],
    );
  }

  Widget _buildPopupMenu(ThemeData theme) {
    return PopupMenuButton<int>(
      constraints: const BoxConstraints.tightFor(width: 160),
      color: theme.cardColor,
      icon: const Icon(Icons.menu_rounded, color: Colors.white),
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) {
        if (value == 1) context.push('/settings');
        if (value == 2) _logout();
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 0, enabled: false, child: _buildUserHeader(theme)),
        const PopupMenuDivider(),
        _buildPopupMenuItem(1, Icons.settings_outlined, 'Settings', theme),
        _buildPopupMenuItem(2, Icons.logout_rounded, 'Logout', theme),
      ],
    );
  }

  Widget _buildUserHeader(ThemeData theme) {
    // 1. Get the current user's ID
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Text("Guest User");
    }

    // 2. Watch the same profile provider used in DiscussionTile
    final profileAsync = ref.watch(userProfileProvider(userId));

    return profileAsync.when(
      loading: () => const Center(
          child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, __) => const Text("Error loading profile"),
      data: (user) {
        final userName = user?.username ?? 'User';
        final avatarUrl = user?.avatarUrl;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: ClipOval(
                child: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        width: 32,
                        height: 32,
                        placeholder: (context, url) => const Icon(Icons.person,
                            size: 18, color: Colors.grey),
                        errorWidget: (context, url, error) => const Icon(
                            Icons.person,
                            size: 18,
                            color: Colors.grey),
                      )
                    : const Icon(Icons.person, size: 18, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              // Changed from Expanded to Flexible for PopupMenu compatibility
              child: Text(
                userName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  PopupMenuItem<int> _buildPopupMenuItem(
      int value, IconData icon, String text, ThemeData theme) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.onSurface, size: 20),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12),
          child: GNav(
            gap: 1,
            backgroundColor: theme.scaffoldBackgroundColor,
            color: isDarkMode ? Colors.white70 : Colors.black54,
            activeColor: theme.colorScheme.secondary,
            tabBackgroundColor: isDarkMode
                ? Colors.white.withOpacity(0.1)
                : theme.colorScheme.secondary.withOpacity(0.12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            tabs: const [
              GButton(icon: Icons.home_filled, text: 'Home'),
              GButton(icon: Icons.public, text: 'Feed'),
              GButton(icon: Icons.chat_bubble_outline, text: 'Chat'),
              GButton(icon: Icons.search, text: 'Search'),
              GButton(icon: Icons.person_outline, text: 'Me'),
            ],
            selectedIndex: widget.navigationShell.currentIndex,
            onTabChange: _onItemTapped,
          ),
        ),
      ),
    );
  }
}
