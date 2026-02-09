import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:hive/hive.dart';
import 'package:otakulink/pages/feed/feed.dart';
import 'package:otakulink/pages/chat/friends.dart';
import 'package:otakulink/pages/home/home_page.dart';
import 'package:otakulink/main/notification.dart';
import 'package:otakulink/pages/profile/profile.dart';
import 'package:otakulink/pages/search/search.dart';
import 'package:otakulink/main/settings.dart';
import 'package:otakulink/main/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String username = '........';
  int _unreadNotifications = 0;
  late List<Widget> _pages;
  StreamSubscription? _notificationSubscription;

  static const double appBarLogoHeight = 100.0;
  static const int maxUsernameLength = 8;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }


  Future<void> _initialize() async {
    _pages = [
      HomePage(),
      FeedPage(onTabChange: _onItemTapped),
      FriendsPage(),
      SearchPage(onTabChange: _onItemTapped),
      ProfilePage(),
    ];
    await _loadUserPreferences();
    _fetchUnreadNotifications();
  }

  Future<void> _loadUserPreferences() async {
    final userCache = Hive.box('userCache');
    final userId = FirebaseAuth.instance.currentUser?.uid;

    final cachedUsername = userCache.get('username');
    if (cachedUsername != null) {
      setState(() => username = cachedUsername);
      return;
    }

    if (userId != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        final fetchedUsername = userDoc.get('username') ?? 'User Name';
        setState(() => username = fetchedUsername);
        userCache.put('username', fetchedUsername);
      } catch (e) {
        debugPrint('Error fetching username from Firestore: $e');
      }
    }
  }

  void _fetchUnreadNotifications() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    _notificationSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notification')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen(
      (snapshot) {
        if (mounted) {
          _updateUnreadNotifications(snapshot.size);
        }
      },
      onError: (error) => debugPrint('Error fetching notifications: $error'),
    );
  }

  void _updateUnreadNotifications(int count) {
    if (_unreadNotifications != count) {
      setState(() => _unreadNotifications = count);
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
            child: const Text("Cancel", style: TextStyle(color: Colors.blueGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      await Hive.box('userCache').clear();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  void _navigateToPage(Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.fastOutSlowIn;
          final tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
              position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Cleaner way to check for keyboard visibility
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: _buildAppBar(theme),
        body: Stack(
          children: [
            IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
          ],
        ),
        bottomNavigationBar: !isKeyboardVisible ? _buildBottomNavigationBar(theme) : null,
      ),
    );
  }

  AppBar _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: theme.colorScheme.primary,
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: Stack(
          children: [
            const Icon(Icons.notifications, color: Colors.white),
            if (_unreadNotifications > 0)
              Positioned(
                top: 0,
                right: 0,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.red,
                  child: Text(
                    _unreadNotifications.toString(),
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
        onPressed: () => _navigateToPage(const NotificationPage()),
      ),
      title: Center(
        child: Image.asset('assets/logo/logo_flat_accent.png',
            height: appBarLogoHeight),
      ),
      actions: [_buildPopupMenu(theme)],
    );
  }

  Widget _buildBottomNavigationBar(ThemeData theme) {
    return Container(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 10),
        child: GNav(
          gap: 4,
          backgroundColor: theme.colorScheme.primary,
          color: Colors.white,
          activeColor: theme.colorScheme.secondary,
          tabBackgroundColor: theme.brightness == Brightness.light 
              ? Colors.grey.shade200 
              : Colors.grey.shade800,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          tabs: const [
            GButton(icon: Icons.home, text: 'Home'),
            GButton(icon: Icons.public, text: 'Feed'),
            GButton(icon: Icons.chat_bubble, text: 'Chat'),
            GButton(icon: Icons.search, text: 'Search'),
            GButton(icon: Icons.person, text: 'Me'),
          ],
          selectedIndex: _selectedIndex,
          onTabChange: _onItemTapped,
        ),
      ),
    );
  }

  PopupMenuButton<int> _buildPopupMenu(ThemeData theme) {
    return PopupMenuButton<int>(
      color: theme.cardColor,
      icon: const Icon(Icons.menu, color: Colors.white),
      onSelected: (value) {
        if (value == 1) {
          _navigateToPage(const SettingPage());
        } else if (value == 2) {
          _logout();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 0, enabled: false, child: _buildUserHeader(theme)),
        const PopupMenuDivider(),
        _buildPopupMenuItem(1, Icons.settings, 'Settings', theme),
        _buildPopupMenuItem(2, Icons.logout, 'Logout', theme),
      ],
    );
  }

  Widget _buildUserHeader(ThemeData theme) {
    final user = FirebaseAuth.instance.currentUser;

    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundImage: user?.photoURL != null
              ? CachedNetworkImageProvider(user!.photoURL!) as ImageProvider
              : const AssetImage('assets/pic/default_avatar.png'),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Tooltip(
            message: username,
            child: Text(
              username.length > maxUsernameLength
                  ? "${username.substring(0, maxUsernameLength)}..."
                  : username,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
          ),
        ),
      ],
    );
  }

  PopupMenuItem<int> _buildPopupMenuItem(
      int value, IconData icon, String text, ThemeData theme) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.onSurface),
          const SizedBox(width: 10),
          Text(text),
        ],
      ),
    );
  }
}