import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:otakulink/features/auth/pages/login_screen.dart';
import 'package:otakulink/features/auth/pages/signup_screen.dart';
import 'package:otakulink/features/auth/pages/forgot_password_screen.dart';
import 'package:otakulink/features/auth/pages/verify_email_page.dart';
import 'package:otakulink/features/home/settings.dart';
import 'package:otakulink/features/notifications/presentation/pages/notification_page.dart';

import 'package:otakulink/features/home/home_screen.dart';
import 'package:otakulink/pages/chat/create_group_page.dart';
import 'package:otakulink/pages/chat/message_page.dart';
import 'package:otakulink/pages/community/community_hub_page.dart';
import 'package:otakulink/pages/discussions/discussion_page.dart';
import 'package:otakulink/pages/home/home_page.dart';
import 'package:otakulink/pages/feed/feed_page.dart';
import 'package:otakulink/pages/manga/manga_details_page.dart';
import 'package:otakulink/pages/manga/person_details_page.dart';
import 'package:otakulink/pages/manga/person_list_page.dart';
import 'package:otakulink/pages/manga/see_more_page.dart';
import 'package:otakulink/pages/profile/follow_list_page.dart';
import 'package:otakulink/pages/profile/other_user_profile_page.dart';
import 'package:otakulink/pages/profile/profile_widgets/edit_profile_page.dart';
import 'package:otakulink/pages/profile/profile_widgets/edit_top_picks_page.dart';
import 'package:otakulink/pages/reader/reader_page.dart';
import 'package:otakulink/pages/search/search_page.dart';
import 'package:otakulink/pages/profile/profile_page.dart';

// --- TRANSITION HELPER ---
enum TransitionType { fade, slideRight, slideUp, zoom }

bool? globalOnboardingCache;

CustomTransitionPage<T> buildPageTransition<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
  TransitionType type = TransitionType.fade,
  Duration duration = const Duration(milliseconds: 300),
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      switch (type) {
        case TransitionType.fade:
          return FadeTransition(opacity: animation, child: child);
        case TransitionType.slideRight:
          return SlideTransition(
            position: Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutCubic))
                .animate(animation),
            child: child,
          );
        case TransitionType.slideUp:
          return SlideTransition(
            position: Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOut))
                .animate(animation),
            child: child,
          );
        case TransitionType.zoom:
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1.0)
                  .chain(CurveTween(curve: Curves.easeOutBack))
                  .animate(animation),
              child: child,
            ),
          );
      }
    },
  );
}

// --- FIREBASE AUTH LISTENER ---
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription =
        stream.asBroadcastStream().listen((dynamic _) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// --- THE ROUTER ---
final goRouter = GoRouter(
  initialLocation: '/home',

  // 1. Listen to Firebase User Changes
  refreshListenable: GoRouterRefreshStream(FirebaseAuth.instance.userChanges()),

  // 2. Security Redirect Logic
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final isLoggedIn = user != null;
    final isVerified = user?.emailVerified ?? false;

    final isAuthRoute = state.matchedLocation == '/login' ||
        state.matchedLocation == '/signup' ||
        state.matchedLocation == '/forgot-password';

    // Not logged in -> Must be on an auth route, otherwise kick to login
    if (!isLoggedIn) {
      return isAuthRoute ? null : '/login';
    }

    // Logged in but not verified -> Force to verification screen
    if (!isVerified) {
      return state.matchedLocation == '/verify-email' ? null : '/verify-email';
    }

    // Logged in & Verified -> Keep them out of auth routes
    if (isAuthRoute || state.matchedLocation == '/verify-email') {
      return '/home';
    }

    return null; // Proceed as normal
  },

  routes: [
    // --- AUTH ROUTES ---
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => buildPageTransition(
        context: context,
        state: state,
        child: const LoginScreen(),
        type: TransitionType.fade,
      ),
    ),
    GoRoute(
      path: '/signup',
      pageBuilder: (context, state) => buildPageTransition(
        context: context,
        state: state,
        child: const SignUpScreen(),
        type: TransitionType.fade,
      ),
    ),
    GoRoute(
      path: '/forgot-password',
      pageBuilder: (context, state) => buildPageTransition(
        context: context,
        state: state,
        child: const ForgotPasswordScreen(),
        type: TransitionType.fade,
      ),
    ),
    GoRoute(
      path: '/verify-email',
      pageBuilder: (context, state) => buildPageTransition(
        context: context,
        state: state,
        child: const VerifyEmailPage(),
        type: TransitionType.fade,
      ),
    ),

    // --- MAIN NAVIGATION SHELL ---
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return HomeScreen(navigationShell: navigationShell);
      },
      branches: [
        // Tab 0: Home
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomePage(),
            ),
          ],
        ),
        // Tab 1: Feed
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/feed',
              builder: (context, state) => FeedPage(
                // NOTE: You can safely remove 'onTabChange' from your FeedPage
                // constructor now. We pass a dummy function to avoid errors for now.
                onTabChange: (_) {},
              ),
            ),
          ],
        ),
        // Tab 2: Community
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/community',
              builder: (context, state) => const CommunityHubPage(),
            ),
          ],
        ),
        // Tab 3: Search
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => SearchPage(
                // NOTE: Same as FeedPage, 'onTabChange' can be removed from SearchPage
                onTabChange: (_) {},
              ),
            ),
          ],
        ),
        // Tab 4: Profile
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfilePage(),
              // REMOVE the nested settings route from here!
            ),
          ],
        ),
      ], // End of StatefulShellRoute branches
    ),

    // --- STANDALONE OVERLAY ROUTES (Full Screen) ---
    GoRoute(
      path: '/notifications',
      pageBuilder: (context, state) => buildPageTransition(
        context: context,
        state: state,
        child: const NotificationPage(),
      ),
    ),

    // ADD SETTINGS HERE
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) => buildPageTransition(
        context: context,
        state: state,
        child: const SettingPage(),
      ),
    ),

    GoRoute(
      path: '/manga/:id',
      pageBuilder: (context, state) => buildPageTransition(
        context: context,
        state: state,
        child:
            MangaDetailsPage(mangaId: int.parse(state.pathParameters['id']!)),
      ),
    ),

    GoRoute(
      path: '/manga/:id/discussion',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return buildPageTransition(
          context: context,
          state: state,
          child: DiscussionPage(
            mangaId: extra['mangaId'],
            mangaName: extra['mangaName'],
            userId: extra['userId'],
            jumpToCommentId: extra['commentId'],
          ),
        );
      },
    ),

    GoRoute(
      path: '/see-more/:slug',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return buildPageTransition(
          context: context,
          state: state,
          child: SeeMorePage(
            title: extra['title'],
            category: extra['category'],
          ),
        );
      },
    ),

    GoRoute(
      path: '/manga/:id/persons',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return buildPageTransition(
          context: context,
          state: state,
          child: PersonListPage(
            mangaId: int.parse(state.pathParameters['id']!),
            title: extra['title'],
            isStaff: extra['isStaff'],
            initialItems: extra['initialItems'],
          ),
        );
      },
    ),

    GoRoute(
      path: '/person/:id',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return buildPageTransition(
          context: context,
          state: state,
          child: PersonDetailsPage(
            id: int.parse(state.pathParameters['id']!),
            isStaff: extra['isStaff'],
            heroTag: extra['heroTag'],
          ),
        );
      },
    ),

    GoRoute(
      path: '/reader',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return ReaderPage(
          initialChapterIndex: extra['initialChapterIndex'],
          allChapters: extra['allChapters'],
          mangaId: extra['mangaId'],
          mangaTitle: extra['mangaTitle'],
          mangaCover: extra['mangaCover'],
        );
      },
    ),

    GoRoute(
      path: '/edit-profile',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return buildPageTransition(
          context: context,
          state: state,
          child: EditProfilePage(
            user: extra['user'],
          ),
        );
      },
    ),

    GoRoute(
      path: '/message/:chatId',
      pageBuilder: (context, state) {
        final extraRaw = state.extra;
        Map<String, dynamic> extra = {};

        if (extraRaw is Map) {
          extra = Map<String, dynamic>.from(extraRaw);
        }
        return buildPageTransition(
          context: context,
          state: state,
          child: MessengerPage(
            chatId: state.pathParameters['chatId'] ?? '',
            title: extra['title']?.toString() ?? 'Chat',
            profilePic: extra['profilePic']?.toString() ?? '',
            isGroup: extra['isGroup'] == true,
          ),
        );
      },
    ),

    GoRoute(
      path: '/create-group',
      pageBuilder: (context, state) => buildPageTransition<void>(
        context: context,
        state: state,
        child: const CreateGroupPage(),
      ),
    ),

    GoRoute(
      path: '/profile/:username',
      pageBuilder: (context, state) {
        // 1. Safely cast state.extra to a Map (it can be null if not passed)
        final extra = state.extra as Map<String, dynamic>?;

        // 2. Extract your targetUserId, providing a fallback just in case
        final targetUserId = extra?['targetUserId'] as String? ?? '';

        return buildPageTransition(
          context: context,
          state: state,
          child: OtherUserProfilePage(
            targetUserId: targetUserId,
          ),
        );
      },
    ),

    GoRoute(
      path: '/edit-top-picks/:userId',
      pageBuilder: (context, state) {
        final userId = state.pathParameters['userId']!;

        return buildPageTransition(
          context: context,
          state: state,
          child: EditTopPicksPage(userId: userId),
        );
      },
    ),

    GoRoute(
      path: '/follow-list/:userId/:type',
      pageBuilder: (context, state) {
        final userId = state.pathParameters['userId']!;
        final typeString = state.pathParameters['type']!;

        final listType = typeString == 'following'
            ? FollowListType.following
            : FollowListType.followers;

        return buildPageTransition(
          context: context,
          state: state,
          child: FollowListPage(
            userId: userId,
            listType: listType,
          ),
        );
      },
    ),
  ],
);
