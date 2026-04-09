// lib/router.dart — GoRouter configuration.
// Auth redirect: unauthenticated → /sign-in.
// Session auto-open: morning/evening window → session screen.
// Notification deep links: FCM payload → correct screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/auth/sign_up_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/onboarding/wearable_permissions_screen.dart';
import 'screens/onboarding/profile_screen.dart';
import 'screens/onboarding/ready_screen.dart';
import 'screens/placeholder/dashboard_placeholder.dart';
import 'screens/placeholder/session_placeholder.dart';
import 'screens/placeholder/in_moment_placeholder.dart';
import 'screens/placeholder/settings_placeholder.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isAuthenticated = session != null;
      final isAuthRoute = state.matchedLocation == '/sign-in' ||
          state.matchedLocation == '/sign-up';
      

      // Not authenticated → send to sign-in (unless already there)
      if (!isAuthenticated && !isAuthRoute) return '/sign-in';

      // Authenticated but on auth route → send to home
      if (isAuthenticated && isAuthRoute) return '/';

      return null;
    },
    routes: [
      // Home — decides between dashboard and session auto-open
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeDecider(),
      ),

      // Auth
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/sign-up',
        builder: (context, state) => const SignUpScreen(),
      ),

      // Onboarding
      GoRoute(
        path: '/onboarding/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/onboarding/permissions',
        builder: (context, state) => const WearablePermissionsScreen(),
      ),
      GoRoute(
        path: '/onboarding/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/onboarding/ready',
        builder: (context, state) => const ReadyScreen(),
      ),

      // Main screens (placeholders — filled in 6.3 and 6.4)
      GoRoute(
        path: '/dashboard',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return DashboardPlaceholder(
            highlightEventId: extra?['highlightEventId'] as String?,
            recoveryEventId: extra?['recoveryEventId'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/session',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return SessionPlaceholder(
            sessionType: extra?['sessionType'] as String?,
            eventId: extra?['eventId'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/in-moment',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return InMomentPlaceholder(
            eventId: extra?['eventId'] as String?,
            metricType: extra?['metricType'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPlaceholder(),
      ),
    ],
  );
});

// HomeDecider — checks onboarding status and session windows
// Sends user to the right screen based on current state
class HomeDecider extends StatelessWidget {
  const HomeDecider({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchUserState(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF050507),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userData = snapshot.data;
        if (userData == null) {
          // No user record — start onboarding
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/onboarding/welcome');
          });
          return const SizedBox.shrink();
        }

        final onboardingComplete = userData['onboarding_complete'] as bool? ?? false;
        if (!onboardingComplete) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/onboarding/welcome');
          });
          return const SizedBox.shrink();
        }

        // Onboarding done — go to dashboard
        // Session auto-open will be handled in 6.3 when session screen is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.go('/dashboard');
        });
        return const SizedBox.shrink();
      },
    );
  }

  Future<Map<String, dynamic>?> _fetchUserState() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;
    return Supabase.instance.client
        .from('users')
        .select('onboarding_complete')
        .eq('user_id', userId)
        .maybeSingle();
  }
}