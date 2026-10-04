import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vela_main/screens/day_editor.dart';
import 'package:vela_main/services/api_client.dart';

Json day() => {
      'plan_id': 'old',
      'date': '2026-10-04',
      'timezone': 'Africa/Lagos',
      'clarification': null,
      'windows': [],
      'responses': [],
      'items': [
        for (final id in ['a', 'b'])
          {
            'id': id,
            'title': 'Practice $id',
            'minutes': 30,
            'after': id == 'a' ? '10:00' : '11:00',
            'instructions': 'Present the case.',
            'steps': ['Outline the findings'],
            'expected_result': 'A presentation',
          },
      ],
    };

Json preview() => {
      'token': 'signed-preview',
      'actions': [
        {
          'title': 'Practice a',
          'before': '10:00',
          'after': '12:00',
        },
      ],
      'deferred': [],
      'note': 'Personal forecasts unavailable.',
    };

Future<void> mount(
  WidgetTester t,
  Future<Json> Function(String, Json) post,
) async {
  t.view.physicalSize = const Size(1200, 2400);
  t.view.devicePixelRatio = 1;

  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  await t.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: DayEditor(
          load: () async => day(),
          post: post,
        ),
      ),
    ),
  );

  await t.pumpAndSettle();
}

Future<void> tap(
  WidgetTester t,
  Finder f,
) async {
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'preview does not apply; a later edit invalidates the preview',
    (t) async {
      final paths = <String>[];

      await mount(t, (path, body) async {
        paths.add(path);
        return preview();
      });

      await tap(t, find.text('Preview changes'));

      expect(
        find.byKey(const Key('plan-preview')),
        findsOneWidget,
      );
      expect(paths, ['/day-editor/preview']);

      await tap(
        t,
        find.text('Practice a').first,
      );
      await tap(
        t,
        find.byTooltip('Longer by 15 minutes').first,
      );

      expect(
        find.byKey(const Key('plan-preview')),
        findsNothing,
      );
      expect(paths, ['/day-editor/preview']);
    },
  );

  testWidgets(
    'reordering preserves explicit local time constraints',
    (t) async {
      Json? request;

      await mount(t, (path, body) async {
        request = body;
        return preview();
      });

      await tap(t, find.text('Practice b'));
      await tap(
        t,
        find.byTooltip('Move earlier in order').first,
      );
      await tap(t, find.text('Preview changes'));

      final edits = request!['edits'] as List;

      expect(
        edits.map((e) => e['id']).toList(),
        ['b', 'a'],
      );
      expect(
        edits.map((e) => e['after']).toList(),
        ['11:00', '10:00'],
      );
    },
  );

  testWidgets(
    'ambiguous Apply failure retries the exact token without requesting a model',
    (t) async {
      final paths = <String>[];
      final bodies = <Json>[];

      await mount(t, (path, body) async {
        paths.add(path);
        bodies.add(body);

        if (path == '/day-editor/apply') {
          throw ApiException(
            503,
            'Apply not confirmed',
          );
        }

        return preview();
      });

      await tap(t, find.text('Preview changes'));
      await tap(t, find.text('Apply this plan'));

      expect(
        find.byKey(const Key('plan-preview')),
        findsOneWidget,
      );

      await tap(
        t,
        find.text('Retry / check saved result'),
      );

      expect(paths, [
        '/day-editor/preview',
        '/day-editor/apply',
        '/day-editor/apply',
      ]);
      expect(
        bodies[1],
        {'token': 'signed-preview'},
      );
      expect(bodies[2], bodies[1]);
    },
  );

  testWidgets(
    'stale Apply clears the preview and requires another preview',
    (t) async {
      await mount(t, (path, body) async {
        if (path == '/day-editor/apply') {
          throw ApiException(
            409,
            'Your day changed',
          );
        }

        return preview();
      });

      await tap(t, find.text('Preview changes'));
      await tap(t, find.text('Apply this plan'));

      expect(
        find.text('Your day changed'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('plan-preview')),
        findsNothing,
      );
      expect(
        find.text('Retry / check saved result'),
        findsNothing,
      );
    },
  );
}
