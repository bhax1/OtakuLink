import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:otakulink/core/utils/secure_logger.dart';

import '../../../../core/utils/app_snackbar.dart';
import '../auth/presentation/controllers/auth_controller.dart';
import 'package:otakulink/features/notifications/application/chapter_update_service.dart';

// Convert to ConsumerStatefulWidget
class HomeScreen extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const HomeScreen({super.key, required this.navigationShell});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime? currentBackPressTime;

  static const double _appBarLogoHeight = 90.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final isGuest = ref.read(authControllerProvider).valueOrNull == null;
      if (isGuest) return;

      // Check for new chapter updates on app open
      ref.read(chapterUpdateServiceProvider).checkForUpdates();
    });
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
            child: const Text(
              "Logout",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      if (!mounted) return;

      // Show non-dismissible loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const PopScope(
          canPop: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      );

      try {
        final authController = ref.read(authControllerProvider.notifier);
        await authController.logout();
        if (mounted) {
          Navigator.of(context).pop(); // Dismiss loading dialog
          context.go('/login');
        }
      } catch (e) {
        SecureLogger.logError("HomeScreen logout", e);
        if (mounted) {
          Navigator.of(context).pop(); // Dismiss loading dialog
          AppSnackBar.show(
            context,
            'Logout failed: $e',
            type: SnackBarType.error,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

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
        bottomNavigationBar: !isKeyboardVisible
            ? _buildBottomNavigationBar(theme)
            : null,
      ),
    );
  }

  AppBar _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: theme.colorScheme.primary,
      automaticallyImplyLeading: false,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.notifications_none_rounded,
          color: Colors.white,
          size: 28,
        ),
        onPressed: () {
          context.pushNamed('notifications');
        },
      ),
      title: Center(
        child: Image.asset(
          'assets/logo/logo_flat_accent.png',
          height: _appBarLogoHeight,
        ),
      ),
      actions: [_buildPopupMenu(theme)],
    );
  }

  Widget _buildPopupMenu(ThemeData theme) {
    final userState = ref.watch(authControllerProvider);
    final isGuest = userState.valueOrNull == null;

    return PopupMenuButton<int>(
      constraints: const BoxConstraints.tightFor(width: 160),
      color: theme.cardColor,
      icon: const Icon(Icons.menu_rounded, color: Colors.white),
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) async {
        if (value == 1) {
          context.push('/settings');
        }
        if (value == 2) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('isGuest');
          if (!mounted) return;

          if (isGuest) {
            context.go('/login');
          } else {
            _logout();
          }
        }
      },
      itemBuilder: (_) => [
        _buildPopupMenuItem(1, Icons.settings_outlined, 'Settings', theme),
        if (isGuest)
          _buildPopupMenuItem(2, Icons.login_rounded, 'Join Us', theme)
        else
          _buildPopupMenuItem(2, Icons.logout_rounded, 'Logout', theme),
      ],
    );
  }

  PopupMenuItem<int> _buildPopupMenuItem(
    int value,
    IconData icon,
    String text,
    ThemeData theme,
  ) {
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
                ? Colors.white.withValues(alpha: 0.1)
                : theme.colorScheme.secondary.withValues(alpha: 0.12),
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
