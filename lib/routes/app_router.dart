import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:go_router/go_router.dart';
import 'package:otakulink/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:otakulink/features/auth/presentation/pages/signup_page.dart';
import 'package:otakulink/features/chat/create_group_page.dart';
import 'package:otakulink/features/chat/message_page.dart';
import 'package:otakulink/features/community/community_hub_page.dart';
import 'package:otakulink/features/notifications/presentation/pages/notification_page.dart';
import 'package:otakulink/features/discussions/discussion_page.dart';
import 'package:otakulink/features/manga/manga_details_page.dart';
import 'package:otakulink/features/manga/person_details_page.dart';
import 'package:otakulink/features/manga/person_list_page.dart';
import 'package:otakulink/features/reader/reader_page.dart';
import 'package:otakulink/features/search/search_page.dart';
import 'package:otakulink/features/settings/setting_page.dart';
import 'package:otakulink/features/profile/profile_page.dart';
import 'package:otakulink/features/profile/other_user_profile_page.dart';
import 'package:otakulink/features/profile/follow_list_page.dart';
import 'package:otakulink/features/profile/profile_widgets/edit_profile_page.dart';
import 'package:otakulink/features/profile/profile_widgets/edit_top_picks_page.dart';
import 'package:otakulink/features/settings/policy_viewer_page.dart';
import 'package:otakulink/features/profile/domain/entities/profile_entities.dart';

import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/home/home_page.dart';
import '../features/main/home_screen.dart';
import '../features/main/pages/blank_tab_page.dart';

import 'package:otakulink/core/providers/shared_prefs_provider.dart';
import 'package:otakulink/core/widgets/login_required_widget.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  final isGuestMode = prefs.getBool('isGuest') ?? false;

  final authStateNotifier = ValueNotifier(ref.read(authControllerProvider));

  ref.listen(
    authControllerProvider,
    (_, next) => authStateNotifier.value = next,
  );

  return GoRouter(
    initialLocation: isGuestMode ? '/' : '/login',
    refreshListenable: authStateNotifier,
    observers: [BotToastNavigatorObserver()],
    redirect: (context, state) {
      final authState = authStateNotifier.value;
      final isAuth = authState.valueOrNull != null;
      // We also enforce they have verified their email
      final isVerified = authState.valueOrNull?.isEmailVerified ?? false;

      final isGoingToLogin = state.uri.path == '/login';
      final isGoingToSignup = state.uri.path == '/signup';
      final isGoingToForgot = state.uri.path == '/forgot-password';

      final isGoingToAuthPage =
          isGoingToLogin || isGoingToSignup || isGoingToForgot;

      // If user IS authenticated and verified, but they try to go "back" to login/signup
      // redirect them back to the home page securely
      if (isAuth && isVerified && isGoingToAuthPage) {
        return '/';
      }

      // No redirect needed
      return null;
    },
    routes: [
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationPage(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingPage(),
        routes: [
          GoRoute(
            path: 'privacy-policy',
            name: 'privacy-policy',
            builder: (context, state) => const PolicyViewerPage(
              title: 'Privacy Policy',
              assetPath: 'assets/legal/privacy_policy.md',
            ),
          ),
          GoRoute(
            path: 'terms-of-service',
            name: 'terms-of-service',
            builder: (context, state) => const PolicyViewerPage(
              title: 'Terms of Service',
              assetPath: 'assets/legal/terms_of_service.md',
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignupPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/person/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          final extra = state.extra as Map<String, dynamic>?;

          return PersonDetailsPage(
            id: id,
            isStaff: extra?['isStaff'] ?? false,
            heroTag:
                extra?['heroTag'] ??
                'person_$id', // Fallback hero tag just in case
          );
        },
      ),
      GoRoute(
        path: '/manga/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return MangaDetailsPage(mangaId: id);
        },
        routes: [
          GoRoute(
            path: 'persons',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              final extra = state.extra as Map<String, dynamic>?;
              return PersonListPage(
                mangaId: id,
                title: extra?['title'] ?? 'Characters & Staff',
                isStaff: extra?['isStaff'] ?? false,
                initialItems: extra?['initialItems'],
              );
            },
          ),
          GoRoute(
            path: 'discussion',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              final extra = state.extra as Map<String, dynamic>?;
              return DiscussionPage(
                mangaId: id,
                mangaName: extra?['mangaName'] ?? 'Discussion',
                chapterId: extra?['chapterId'],
                highlightedCommentId: extra?['highlightedCommentId'],
              );
            },
          ),
          GoRoute(
            path: 'read/:chapterIndex',
            builder: (context, state) {
              final mangaId = state.pathParameters['id']!;
              final chapterIndex = int.parse(
                state.pathParameters['chapterIndex']!,
              );

              // Grab the heavy data from extra
              final extra = state.extra as Map<String, dynamic>?;

              if (extra == null) {
                // If you ever support deep links, you'd trigger a loading screen
                // here and fetch the manga data using the mangaId.
                return const Scaffold(
                  body: Center(child: Text("Deep linking not supported yet.")),
                );
              }

              return ReaderPage(
                initialChapterIndex: chapterIndex,
                allChapters: extra['allChapters'] as List<Map<String, dynamic>>,
                mangaId: mangaId,
                mangaTitle: extra['mangaTitle'] as String,
                mangaCover: extra['mangaCover'] as String,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/profile/:username',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final targetUserId = extra?['targetUserId'] as String?;

          if (targetUserId == null) {
            return const Scaffold(
              body: Center(child: Text("Invalid User Profile Link")),
            );
          }
          return OtherUserProfilePage(targetUserId: targetUserId);
        },
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final user = extra?['user'] as ProfileEntity?;
          if (user == null) return const SizedBox();
          return EditProfilePage(user: user);
        },
      ),
      GoRoute(
        path: '/edit-top-picks/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          return EditTopPicksPage(userId: userId);
        },
      ),
      GoRoute(
        path: '/follow-list/:userId/:type',
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          final typeString = state.pathParameters['type']!;
          final type = typeString == 'followers'
              ? FollowListType.followers
              : FollowListType.following;
          return FollowListPage(userId: userId, listType: type);
        },
      ),
      GoRoute(
        path: '/message/:chatId',
        builder: (context, state) {
          final chatId = state.pathParameters['chatId']!;
          final extra = state.extra as Map<String, dynamic>?;

          return MessengerPage(
            chatId: chatId,
            title: extra?['title'] ?? 'Chat',
            profilePic: extra?['profilePic'],
            isGroup: extra?['isGroup'] ?? false,
          );
        },
      ),
      GoRoute(
        path: '/create-group',
        builder: (context, state) {
          if (authStateNotifier.value.valueOrNull == null) {
            return const LoginRequiredWidget(title: 'Community');
          }
          return const CreateGroupPage();
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/', builder: (context, state) => const HomePage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/feed',
                builder: (context, state) {
                  if (authStateNotifier.value.valueOrNull == null) {
                    return const LoginRequiredWidget(title: 'Feed');
                  }
                  return const BlankTabPage(title: 'Feed');
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/community',
                builder: (context, state) {
                  if (authStateNotifier.value.valueOrNull == null) {
                    return const LoginRequiredWidget(title: 'Community');
                  }
                  return const CommunityHubPage();
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => SearchPage(
                  onTabChange: (index) {
                    StatefulNavigationShell.of(context).goBranch(index);
                  },
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/me',
                builder: (context, state) {
                  if (authStateNotifier.value.valueOrNull == null) {
                    return const LoginRequiredWidget(title: 'Profile');
                  }
                  return const ProfilePage();
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
