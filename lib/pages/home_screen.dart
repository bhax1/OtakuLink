import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:hive/hive.dart';
import 'package:otakulink/home_navbar/home.dart';
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

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
    _pages = [
      HomePage(),
      SearchPage(onTabChange: _onItemTapped), // Pass the instance method
      ProfilePage(),
    ];
  }

  Future<void> _loadUserPreferences() async {
    final userCache = Hive.box('userCache');
    setState(() {
      username = userCache.get('username', defaultValue: 'User Name');
    });
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
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();

      // Clear Hive data for userCache
      final userCache = Hive.box('userCache');
      await userCache.clear();

      // Navigate to login screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: primaryColor,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              // Add functionality for notifications
            },
          ),
          title: Center(
            child: Image.asset(
              'assets/logo/logo_flat_accent.png',
              height: 100,
            ),
          ),
          actions: [
            PopupMenuButton<int>(
              color: backgroundColor,
              icon: AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 300),
                child: const Icon(Icons.menu, color: Colors.white),
              ),
              onSelected: (value) {
                if (value == 1) {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) {
                        return const SettingPage(); // Replace with your settings page
                      },
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOut;

                        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                        var offsetAnimation = animation.drive(tween);

                        return SlideTransition(
                          position: offsetAnimation,
                          child: FadeTransition(opacity: animation, child: child),
                        );
                      },
                    ),
                  );
                } else if (value == 2) {
                  _logout();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 0,
                  enabled: false,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: user?.photoURL != null
                            ? CachedNetworkImageProvider(user!.photoURL!)
                            : const AssetImage('assets/pic/default_avatar.png') as ImageProvider,
                      ),
                      const SizedBox(width: 10),
                      Text(username, style: const TextStyle(color: Colors.black)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 1,
                  child: Row(
                    children: const [
                      Icon(Icons.settings, color: Colors.black),
                      SizedBox(width: 10),
                      Text('Settings'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 2,
                  child: Row(
                    children: const [
                      Icon(Icons.logout, color: Colors.black),
                      SizedBox(width: 10),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
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
            tabs: [
              const GButton(
                icon: Icons.home,
                text: 'Home',
              ),
              const GButton(
                icon: Icons.search,
                text: 'Search',
              ),
              const GButton(
                icon: Icons.person,
                text: 'Profile',
              ),
            ],
            selectedIndex: _selectedIndex,
            onTabChange: _onItemTapped,
          ),
        ),
      ),
    );
  }
}