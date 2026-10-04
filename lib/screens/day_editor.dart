import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../providers/daily_plan_provider.dart';
import '../services/api_client.dart';

typedef Json = Map<String, dynamic>;

List<Json> _rows(dynamic value) =>
    (value as List? ?? [])
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();

String _uuid() {
  final r = Random.secure();
  final b = List.generate(16, (_) => r.nextInt(256));

  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;

  final s = b
      .map((v) => v.toRadixString(16).padLeft(2, '0'))
      .join();

  return '${s.substring(0, 8)}-'
      '${s.substring(8, 12)}-'
      '${s.substring(12, 16)}-'
      '${s.substring(16, 20)}-'
      '${s.substring(20)}';
}

String _clock(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}';

Future<void> openDayEditor(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const DayEditor(),
      ),
    );

// Dependency seams allow widget tests without live auth
// or paid requests.
class DayEditor extends ConsumerStatefulWidget {
  final Future<Json> Function()? load;
  final Future<Json> Function(String, Json)? post;

  const DayEditor({
    super.key,
    this.load,
    this.post,
  });

  @override
  ConsumerState<DayEditor> createState() =>
      _DayEditorState();
}

class _DayEditorState extends ConsumerState<DayEditor> {
  Json? _day;
  Json? _preview;
  List<Json> _edits = [];
  bool _busy = false;
  String? _message;
  Future<void> Function()? _retry;

  String get _base =>
      Env.plannerUrl.replaceFirst(RegExp(r'/$'), '');

  Future<Json> _post(String path, Json body) =>
      widget.post?.call(path, body) ??
      ApiClient.instance.postJson(
        '$_base$path',
        body: body,
      );

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _run(_load));
  }

  Future<void> _load({
    bool preserveEdits = false,
  }) async {
    final day = await (
      widget.load?.call() ??
      ApiClient.instance.getJson('$_base/day-editor')
    );

    if (!mounted) return;

    setState(() {
      final ids = _rows(day['items'])
          .map((v) => v['id'])
          .toSet();

      final preserve =
          preserveEdits &&
          day['plan_id'] == _day?['plan_id'] &&
          ids.length == _edits.length &&
          _edits.every((e) => ids.contains(e['id']));

      _day = day;

      if (!preserve) {
        _edits = _rows(day['items'])
            .map((v) => <String, dynamic>{
                  'id': v['id'],
                  'minutes': v['minutes'],
                  'after': v['after'],
                  'keep': true,
                })
            .toList();
      }

      _preview = null;
    });
  }

  Future<void> _run(
    Future<void> Function() work,
  ) async {
    if (_busy || !mounted) return;

    setState(() {
      _busy = true;
      _message = null;
      _retry = null;
    });

    try {
      await work();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _message = e is ApiException
            ? e.message
            : 'The request was not confirmed. '
                'Retry the same request or reload to check.';

        // A retry reuses the original preview/submission identity.
        if (e is! ApiException || e.statusCode >= 500) {
          _retry = work;
        }

        if (e is ApiException && e.statusCode == 409) {
          _preview = null;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _edit(void Function() change) {
    setState(() {
      change();
      _preview = null;
      _retry = null;
    });
  }

  Future<void> _window({Json? previous}) async {
    final day = _day!;
    var start = const TimeOfDay(hour: 9, minute: 0);
    var end = const TimeOfDay(hour: 17, minute: 0);
    var state = previous?['state'] as String? ?? 'free';

    TimeOfDay parse(String s) {
      final p = s.split(':');

      return TimeOfDay(
        hour: int.parse(p[0]),
        minute: int.parse(p[1]),
      );
    }

    if (previous != null) {
      start = parse(previous['start']);
      end = parse(previous['end']);
    }

    final value = await showDialog<Json>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Today’s availability'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${day['date']} · ${day['timezone']}',
              ),
              DropdownButton<String>(
                value: state,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: 'free',
                    child: Text(
                      'Available for work / study',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'busy',
                    child: Text('Busy / protected time'),
                  ),
                ],
                onChanged: (v) {
                  update(() => state = v!);
                },
              ),
              TextButton(
                onPressed: () async {
                  final t = await showTimePicker(
                    context: ctx,
                    initialTime: start,
                  );

                  if (t != null && ctx.mounted) {
                    update(() => start = t);
                  }
                },
                child: Text('From ${_clock(start)}'),
              ),
              TextButton(
                onPressed: () async {
                  final t = await showTimePicker(
                    context: ctx,
                    initialTime: end,
                  );

                  if (t != null && ctx.mounted) {
                    update(() => end = t);
                  }
                },
                child: Text('Until ${_clock(end)}'),
              ),
              const Text(
                'Saving updates today’s constraints. '
                'Preview to see the schedule changes.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed:
                  end.hour * 60 + end.minute <=
                          start.hour * 60 + start.minute
                      ? null
                      : () {
                          Navigator.pop(
                            ctx,
                            <String, dynamic>{
                              'request_id': _uuid(),
                              'date': day['date'],
                              'start_time': _clock(start),
                              'end_time': _clock(end),
                              'state': state,
                              if (previous != null)
                                'replaces': previous['id'],
                            },
                          );
                        },
              child: const Text('Save window'),
            ),
          ],
        ),
      ),
    );

    if (value == null || !mounted) return;

    await _run(() async {
      await _post('/day-availability', value);
      await _load(preserveEdits: true);
    });
  }

  Future<void> _previewEdits() async {
    final body = <String, dynamic>{
      'plan_id': _day!['plan_id'],
      'edits': _edits
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    };

    await _run(() async {
      final p = await _post(
        '/day-editor/preview',
        body,
      );

      if (mounted) {
        setState(() => _preview = p);
      }
    });
  }

  Future<void> _apply() async {
    final token = _preview!['token'];

    await _run(() async {
      final result = await _post(
        '/day-editor/apply',
        {'token': token},
      );

      final saved = await ref.refresh(
        dailyPlanProvider.future,
      );

      if (saved.planId != result['planId']) {
        throw ApiException(
          409,
          'The applied version is not loaded yet. '
          'Reload your plan.',
        );
      }

      await _load();

      if (mounted) {
        setState(() {
          _message = 'Your edited plan is saved.';
        });
      }
    });
  }

  Future<void> _respond(
    Json r,
    String response,
  ) async {
    final body = <String, dynamic>{
      'nudge_id': r['id'],
      'response_value': response,
      'response_id': _uuid(),
    };

    await _run(() async {
      if (widget.post != null) {
        await widget.post!('/nudge/respond', body);
      } else {
        await ApiClient.instance.postJson(
          '${Env.sessionPipelineUrl}/nudge/respond',
          body: body,
        );
      }

      ref.invalidate(dailyPlanProvider);
      await _load();

      if (mounted) {
        setState(() => _message = 'Response recorded.');
      }
    });
  }

  Future<void> _prepare() async {
    // Deliberate, separate paid preparation action.
    // Never retried automatically.
    await _run(() async {
      final result = widget.post != null
          ? await widget.post!(
              '/plan',
              {'trigger': 'user_request'},
            )
          : await ApiClient.instance.postJson(
              '$_base/plan',
              body: {'trigger': 'user_request'},
              timeout: const Duration(minutes: 3),
            );

      ref.invalidate(dailyPlanProvider);
      await _load();

      if (mounted) {
        setState(() {
          _message =
              result['clarification']?.toString() ??
              (
                result['planningStatus'] == 'published'
                    ? 'New activities prepared.'
                    : 'No replacement plan was published.'
              );
        });
      }
    });

    // After ambiguous failure, check the saved plan
    // before another paid request.
    if (mounted && _retry != null) {
      setState(() => _retry = _load);
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = _day;
    final items = _rows(day?['items']);

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Shape your day'),
          actions: [
            IconButton(
              tooltip: 'Reload and discard edits',
              onPressed: _busy
                  ? null
                  : () => _run(_load),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: _busy,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_busy)
                const LinearProgressIndicator(),

              if (_message != null) ...[
                Text(
                  _message!,
                  key: const Key('editor-message'),
                ),
                if (_retry != null)
                  TextButton(
                    onPressed: () => _run(_retry!),
                    child: const Text(
                      'Retry / check saved result',
                    ),
                  ),
              ],

              if (day != null) ...[
                Text(
                  '${day['date']} · ${day['timezone']}',
                ),
                const SizedBox(height: 12),
                const Text(
                  'What does today allow?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                if (day['clarification'] != null)
                  Text(
                    day['clarification'].toString(),
                  ),

                for (final w in _rows(day['windows']))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${w['state'] == 'free' ? 'Available' : 'Busy / protected'}'
                      ' · ${w['start']}–${w['end']}',
                    ),
                    trailing: const Icon(
                      Icons.edit_outlined,
                    ),
                    onTap: () => _window(previous: w),
                  ),

                OutlinedButton.icon(
                  onPressed: () => _window(),
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Add free or busy time',
                  ),
                ),

                for (final r in _rows(day['responses']))
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(r['title']),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (
                                final v in
                                    r['options'] as List
                              )
                                TextButton(
                                  onPressed: () =>
                                      _respond(
                                        r,
                                        v as String,
                                      ),
                                  child: Text(
                                    v == 'On it'
                                        ? 'Start now'
                                        : v == 'Done'
                                            ? 'Finished'
                                            : v.toString(),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),
                const Text(
                  'Arrange your remaining activities',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Times are “not before” limits. '
                  'Preview shows the actual fit. '
                  'Started or already prompted work stays fixed.',
                ),

                for (
                  var i = 0;
                  i < _edits.length;
                  i++
                )
                  _activity(
                    items.firstWhere(
                      (v) => v['id'] == _edits[i]['id'],
                    ),
                    i,
                  ),

                if (_edits.isNotEmpty) ...[
                  TextButton(
                    onPressed: () => _edit(() {
                      for (final e in _edits) {
                        e['after'] = null;
                      }
                    }),
                    child: const Text(
                      'Fit as early as possible',
                    ),
                  ),
                  FilledButton(
                    onPressed:
                        day['clarification'] == null
                            ? _previewEdits
                            : null,
                    child: const Text('Preview changes'),
                  ),
                ] else
                  const Text(
                    'No unstarted saved activities '
                    'are available to edit.',
                  ),

                if (_preview != null)
                  Card(
                    key: const Key('plan-preview'),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Preview · not saved',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          for (
                            final a in
                                _rows(_preview!['actions'])
                          )
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                              child: Text(
                                '${a['title']}\n'
                                '${a['before']} → ${a['after']}',
                              ),
                            ),

                          for (
                            final title in
                                _preview!['deferred'] as List
                          )
                            Text('Deferred: $title'),

                          Text(
                            _preview!['note'].toString(),
                          ),

                          Wrap(
                            spacing: 12,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _preview = null;
                                  });
                                },
                                child: const Text(
                                  'Discard preview',
                                ),
                              ),
                              FilledButton(
                                onPressed: _apply,
                                child: const Text(
                                  'Apply this plan',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
                const Text(
                  'Need different activities? '
                  'This asks Vela to prepare them '
                  'and may use model credits.',
                ),
                OutlinedButton(
                  onPressed: _prepare,
                  child: const Text(
                    'Prepare new activities',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _activity(Json item, int index) {
    final e = _edits[index];

    return Card(
      child: ExpansionTile(
        key: ValueKey(e['id']),
        title: Text(item['title']),
        subtitle: Text(
          '${e['minutes']} min · '
          '${e['after'] ?? 'Earliest fit'}'
          '${e['keep'] == true ? '' : ' · Deferred'}',
        ),
        childrenPadding: const EdgeInsets.all(12),
        children: [
          Text(item['instructions']),

          for (final step in item['steps'] as List)
            ListTile(
              dense: true,
              leading: const Icon(Icons.chevron_right),
              title: Text(step.toString()),
            ),

          Text('Result: ${item['expected_result']}'),

          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                tooltip: 'Shorter by 15 minutes',
                onPressed: e['minutes'] <= 15
                    ? null
                    : () => _edit(
                          () => e['minutes'] -= 15,
                        ),
                icon: const Icon(Icons.remove),
              ),
              Text('${e['minutes']} min'),
              IconButton(
                tooltip: 'Longer by 15 minutes',
                onPressed: e['minutes'] >= 120
                    ? null
                    : () => _edit(
                          () => e['minutes'] += 15,
                        ),
                icon: const Icon(Icons.add),
              ),
              IconButton(
                tooltip: 'Move earlier in order',
                onPressed: index == 0
                    ? null
                    : () => _edit(() {
                          _edits.removeAt(index);
                          _edits.insert(index - 1, e);
                        }),
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: 'Move later in order',
                onPressed:
                    index == _edits.length - 1
                        ? null
                        : () => _edit(() {
                              _edits.removeAt(index);
                              _edits.insert(index + 1, e);
                            }),
                icon: const Icon(Icons.arrow_downward),
              ),
            ],
          ),

          TextButton(
            onPressed: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: const TimeOfDay(
                  hour: 12,
                  minute: 0,
                ),
              );

              if (t != null && mounted) {
                _edit(() => e['after'] = _clock(t));
              }
            },
            child: Text(
              'Not before '
              '${e['after'] ?? 'earliest available time'}',
            ),
          ),

          CheckboxListTile(
            title: const Text('Keep in today’s plan'),
            value: e['keep'] as bool,
            onChanged: (v) {
              _edit(() => e['keep'] = v!);
            },
          ),
        ],
      ),
    );
  }
}
