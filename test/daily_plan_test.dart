import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vela_main/models/daily_plan_model.dart';
import 'package:vela_main/providers/daily_plan_provider.dart';
import 'package:vela_main/screens/daily_plan_screen.dart';

DailyPlanModel fixture() => DailyPlanModel.fromJson({
      'date': '2026-10-02',
      'timezone': 'Africa/Lagos',
      'fetchedAt': '2026-10-02T12:00:00Z',
      'planId': 'plan',
      'summary': 'Work through your questions this afternoon.',
      'activities': [
        {
          'id': 'activity',
          'kind': 'work',
          'title': 'Practice questions',
          'goalTitle': 'Exam preparation',
          'startsAt': '2026-10-02T13:00:00Z',
          'endsAt': '2026-10-02T14:00:00Z',
          'timeLabel': '14:00–15:00',
          'status': 'Planned',
          'minutes': 60,
          'instruction':
              'Attempt the questions, then review your answers.',
          'reasoning': null,
          'actualMinutes': null,
          'completionStandard': null,
          'steps': [
            {
              'title': 'Attempt questions',
              'minutes': 40,
            },
          ],
        },
      ],
      'deferred': [
        {
          'title': 'Review article',
          'reason': 'Moved out of this afternoon.',
        },
      ],
      'history': [
        {
          'id': 'plan',
          'at': '07:00',
          'label': 'Morning plan',
        },
      ],
    });

void main() {
  test('retains server timezone labels and unknown measured values', () {
    final plan = fixture();

    expect(plan.activities.single.timeLabel, '14:00–15:00');
    expect(plan.activities.single.actualMinutes, isNull);
    expect(plan.activities.single.isCompleted, isFalse);
    expect(plan.nextActivity?.id, 'activity');
    expect(plan.activity('removed'), isNull);
  });

  testWidgets(
    'Home opens the full plan and a block opens its details',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(
              body: SafeArea(child: TodayPlanCard()),
            ),
          ),
          GoRoute(
            path: '/plan',
            builder: (_, __) => const DailyPlanScreen(),
          ),
          GoRoute(
            path: '/plan/activity/:activityId',
            builder: (_, state) => PlanActivityScreen(
              activityId: state.pathParameters['activityId']!,
            ),
          ),
        ],
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dailyPlanProvider.overrideWith(
              (ref) async => fixture(),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('View all'));
      await tester.pumpAndSettle();

      expect(find.text('Your day, in order'), findsOneWidget);

      await tester.tap(find.text('Practice questions'));
      await tester.pumpAndSettle();

      expect(find.text('Activity details'), findsOneWidget);
      expect(find.text('What to do'), findsOneWidget);
      expect(find.text('Planning explanation'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a removed block shows the new-plan message instead of stale details',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dailyPlanProvider.overrideWith(
              (ref) async => fixture(),
            ),
          ],
          child: const MaterialApp(
            home: PlanActivityScreen(activityId: 'removed'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.textContaining('no longer in today'),
        findsOneWidget,
      );
      expect(find.text('What to do'), findsNothing);
    },
  );

  testWidgets(
    'large text at a narrow phone width does not overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dailyPlanProvider.overrideWith(
              (ref) async => fixture(),
            ),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.5),
              ),
              child: child!,
            ),
            home: const DailyPlanScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}
