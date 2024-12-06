import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:hive/hive.dart';
import 'package:otakulink/home_navbar/friends.dart';
import 'package:otakulink/home_navbar/home.dart';
import 'package:otakulink/home_navbar/notification.dart';
import 'package:otakulink/home_navbar/profile.dart';
import 'package:otakulink/home_navbar/search.dart';
import 'package:otakulink/home_navbar/settings.dart';
import 'package:otakulink/main.dart';
import 'package:otakulink/pages/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String username = 'User Name';
  int _unreadNotifications = 0;
  late List<Widget> _pages;
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
    _fetchUnreadNotifications();
    _pages = [
      HomePage(),
      FriendsPage(),
      SearchPage(onTabChange: _onItemTapped),
      ProfilePage(),
    ];
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserPreferences() async {
    final userCache = Hive.box('userCache');
    final userId = FirebaseAuth.instance.currentUser?.uid;

    // Check if username exists in Hive
    String? cachedUsername = userCache.get('username');
    if (cachedUsername != null) {
      setState(() {
        username = cachedUsername;
      });
    } else if (userId != null) {
      // Fetch username from Firestore if not in cache
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        String fetchedUsername = userDoc.get('username') ?? 'User Name';

        // Update the state and cache
        setState(() {
          username = fetchedUsername;
        });
        userCache.put('username', fetchedUsername);
      } catch (e) {
        debugPrint('Error fetching username from Firestore: $e');
      }
    } else {
      // Fallback if no user is logged in
      setState(() {
        username = 'User Name';
      });
    }
  }

  void _fetchUnreadNotifications() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _notificationSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notification')
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          _updateUnreadNotifications(snapshot.size);
        }
      });
    }
  }

  void _updateUnreadNotifications(int count) {
    if (_unreadNotifications != count) {
      setState(() {
        _unreadNotifications = count;
      });
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
            child: const Text("Cancel"),
            style: TextButton.styleFrom(
              foregroundColor:
                  primaryColor, // Set the text color to red for Cancel
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Logout"),
            style: TextButton.styleFrom(
              foregroundColor:
                  Colors.red, // Set the text color to green for Logout
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();

      final userCache = Hive.box('userCache');
      await userCache.clear();

      if (mounted) {
        // Check if the widget is still mounted before navigating
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
        pageBuilder: (context, animation, secondaryAnimation) {
          return page;
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.fastOutSlowIn;
          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: _buildAppBar(),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
        
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: primaryColor,
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
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
        onPressed: () => _navigateToPage(const NotificationPage()),
      ),
      title: Center(
        child: Image.asset(
          'assets/logo/logo_flat_accent.png',
          height: 100,
        ),
      ),
      actions: [_buildPopupMenu()],
    );
  }

  PopupMenuButton<int> _buildPopupMenu() {
    return PopupMenuButton<int>(
      color: backgroundColor,
      icon: const Icon(Icons.menu, color: Colors.white),
      onSelected: (value) {
        if (value == 1) {
          _navigateToPage(const SettingPage());
        } else if (value == 2) {
          _logout();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 0,
          enabled: false,
          child: _buildUserHeader(),
        ),
        const PopupMenuDivider(),
        _buildPopupMenuItem(1, Icons.settings, 'Settings'),
        _buildPopupMenuItem(2, Icons.logout, 'Logout'),
      ],
    );
  }

  Widget _buildUserHeader() {
    final user = FirebaseAuth.instance.currentUser;
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundImage: user?.photoURL != null
              ? CachedNetworkImageProvider(user!.photoURL!)
              : const AssetImage('assets/pic/default_avatar.png')
                  as ImageProvider,
        ),
        const SizedBox(width: 10),
        Text(username, style: const TextStyle(color: Colors.black)),
      ],
    );
  }

  PopupMenuItem<int> _buildPopupMenuItem(
      int value, IconData icon, String text) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: Colors.black),
          const SizedBox(width: 10),
          Text(text),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      color: primaryColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10),
        child: GNav(
          gap: 8,
          backgroundColor: primaryColor,
          color: Colors.white,
          activeColor: accentColor,
          tabBackgroundColor: secondaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          tabs: const [
            GButton(icon: Icons.home, text: 'Home'),
            GButton(icon: Icons.people, text: 'Friends'),
            GButton(icon: Icons.search, text: 'Search'),
            GButton(icon: Icons.person, text: 'Profile'),
          ],
          selectedIndex: _selectedIndex,
          onTabChange: _onItemTapped,
        ),
      ),
    );
  }
}
