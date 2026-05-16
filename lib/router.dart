// lib/router.dart — GoRouter configuration.
// Auth redirect: unauthenticated → /sign-in.
// Notification deep links: FCM payload → correct screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/session_model.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/auth/sign_up_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/in_moment_card.dart';
import 'screens/onboarding/profile_screen.dart';
import 'screens/onboarding/ready_screen.dart';
import 'screens/onboarding/wearable_permissions_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/session_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/health_profile_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/add_event_screen.dart';
import 'screens/session_detail_screen.dart';
import 'models/session_record_model.dart';
import 'screens/subscription_screen.dart';
import 'screens/goals_screen.dart';
import 'screens/add_goal_screen.dart';
import 'models/goal_model.dart';

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

      // Dashboard
      GoRoute(
        path: '/dashboard',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return DashboardScreen(
            highlightEventId: extra?['highlightEventId'] as String?,
            recoveryEventId: extra?['recoveryEventId'] as String?,
          );
        },
      ),
      
      GoRoute(
        path: '/subscription',
        builder: (context, state) => const SubscriptionScreen(),
      ),
      
      // Session screen — voice + waveform avatar
      GoRoute(
        path: '/session',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final typeString = extra?['sessionType'] as String?;
          return SessionScreen(
            sessionType: _parseSessionType(typeString),
          );
        },
      ),

      // In-moment card — class_3 popup
      GoRoute(
        path: '/in-moment',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return InMomentCard(
            eventId: extra?['eventId'] as String? ?? '',
            interventionText: extra?['interventionText'] as String? ??
                'Take a moment to check in with how you feel right now.',
          );
        },
      ),

      // Session detail
      GoRoute(
        path: '/session-detail',
        builder: (context, state) {
          final session = state.extra as SessionRecordModel;
          return SessionDetailScreen(session: session);
        },
      ),

      // Schedule
      GoRoute(
        path: '/schedule',
        builder: (context, state) => const ScheduleScreen(),
      ),

      // Add event
      GoRoute(
        path: '/add-event',
        builder: (context, state) => const AddEventScreen(),
      ),

      // Edit profile
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),

      // Notification settings
      GoRoute(
        path: '/notification-settings',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),

      // Health profile
      GoRoute(
        path: '/health-profile',
        builder: (context, state) => const HealthProfileScreen(),
      ),

      // Goals
      GoRoute(
        path: '/goals',
        builder: (context, state) => const GoalsScreen(),
      ),
      GoRoute(
        path: '/add-goal',
        builder: (context, state) {
          final existing = state.extra as GoalModel?;
          return AddGoalScreen(existing: existing);
        },
      ),

      // Settings
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});

/// Parses a session type string from notification payload or route extras.
/// Defaults to morning if unknown.
SessionType _parseSessionType(String? type) {
  switch (type) {
    case 'morning':
      return SessionType.morning;
    case 'evening':
      return SessionType.evening;
    case 'inMoment':
    case 'in_moment':
      return SessionType.inMoment;
    default:
      return SessionType.morning;
  }
}

// HomeDecider — checks onboarding status and decides where to go.
// Session auto-open by time-of-day window can be added later if needed.
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

        final onboardingComplete =
            userData['onboarding_complete'] as bool? ?? false;
        if (!onboardingComplete) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/onboarding/welcome');
          });
          return const SizedBox.shrink();
        }

        // Onboarding done — go to dashboard
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
