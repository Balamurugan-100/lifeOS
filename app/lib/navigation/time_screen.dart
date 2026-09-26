import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

import '../app.dart';
import '../theme/theme_controller.dart';
import '../time/time_format.dart';
import '../time/time_providers.dart';

/// Where the time went, and a way to put more of it somewhere on purpose.
class TimeScreen extends ConsumerStatefulWidget {
  const TimeScreen({super.key});

  @override
  ConsumerState<TimeScreen> createState() => _TimeScreenState();
}

class _TimeScreenState extends ConsumerState<TimeScreen> {

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = ref.watch(activeTimeSessionProvider);
    final totals = ref.watch(timePeriodTotalsProvider(timeWindowDays));
    final strip = ref.watch(timeWeekStripProvider);
    final breakdown = ref.watch(timeBreakdownProvider(timeWindowDays));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      children: [
        _WindowToggle(
          window: timeWindowDays,
          onChanged: (value) => setState(() => timeWindowDays = value),
        ),
        const SizedBox(height: 20),
        _ActiveTimerCard(
          session: active.valueOrNull,
          tasks: ref.watch(taskListProvider).valueOrNull ?? const [],
          onStop: _stopActive,
        ),
        const SizedBox(height: 20),
        _TotalCard(
          totals: totals,
          window: timeWindowDays,
          shares: breakdown.valueOrNull,
        ),
        const SizedBox(height: 20),
        _WeekStrip(days: strip),
        const SizedBox(height: 24),
        _SectionHeader(
          title: 'Where it went',
          subtitle: timeWindowDays == 0
              ? 'Today, per task'
              : 'Last 7 days, per task',
        ),
        const SizedBox(height: 12),
        _BreakdownList(shares: breakdown),
        const SizedBox(height: 24),
        const _SectionHeader(
          title: 'Recent sessions',
          subtitle: 'Newest first',
        ),
        const SizedBox(height: 12),
        _SessionLog(log: ref.watch(timeSessionsLogProvider), scheme: scheme),
      ],
    );
  }

  Future<void> _stopActive() async {
    final session = ref.read(activeTimeSessionProvider).valueOrNull;
    if (session == null) return;
    await (await ref.read(timeRepositoryProvider.future))
        .stopSession(session.id);
    invalidateTime(ref);
  }
}

/// Today / 7 days segmented control.
class _WindowToggle extends StatelessWidget {
  const _WindowToggle({required this.window, required this.onChanged});

  final int window;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 0, label: Text('Today')),
        ButtonSegment(value: 1, label: Text('7 days')),
      ],
      selected: {window},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.comfortable,
        side: WidgetStatePropertyAll(
          BorderSide(color: LifeOSPalette.borderDark),
        ),
        foregroundColor: WidgetStatePropertyAll(scheme.onSurfaceVariant),
      ),
    );
  }
}

/// Live timer, or a picker to start one.
class _ActiveTimerCard extends ConsumerStatefulWidget {
  const _ActiveTimerCard({
    required this.session,
    required this.tasks,
    required this.onStop,
  });

  final TimeSession? session;
  final List<Task> tasks;
  final Future<void> Function() onStop;

  @override
  ConsumerState<_ActiveTimerCard> createState() => _ActiveTimerCardState();
}

class _ActiveTimerCardState extends ConsumerState<_ActiveTimerCard> {
  String? _selectedId;
  bool _starting = false;

  List<Task> get _candidates {
    final live = widget.tasks.where((t) => !t.isCompleted).toList();
    return live.isEmpty ? widget.tasks : live;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final session = widget.session;

    if (session != null) {
      return Card(
        key: const Key('active-timer-card'),
        shape: _cardShape,
        color: scheme.primaryContainer.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.timelapse_rounded,
                      size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text('Tracking now',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: scheme.primary)),
                ],
              ),
              const SizedBox(height: 12),
              TickingTimer(
                builder: (elapsed) => Text(
                  formatClock(
                    Duration(seconds: session.durationSeconds) + elapsed,
                  ),
                  key: const Key('active-timer-clock'),
                  style: const TextStyle(
                      fontSize: 42, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                session.isPomodoro
                    ? 'Pomodoro · ${_titleFor(session, widget.tasks)}'
                    : 'Stopwatch · ${_titleFor(session, widget.tasks)}',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  FilledButton.icon(
                    key: const Key('active-timer-stop'),
                    onPressed: widget.onStop,
                    icon: const Icon(Icons.stop_rounded, size: 18),
                    label: const Text('Stop'),
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => _confirmDiscard(session.id),
                    child: const Text('Discard'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_candidates.isEmpty) {
      return Card(
        key: const Key('active-timer-empty'),
        shape: _cardShape,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Row(
            children: [
              Icon(Icons.timer_outlined, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Add a task first — every session is logged against one.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final selected = _candidates.firstWhere(
      (t) => t.id == (_selectedId ?? _candidates.first.id),
      orElse: () => _candidates.first,
    );

    return Card(
      key: const Key('start-timer-card'),
      shape: _cardShape,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Start tracking',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('start-timer-task'),
              initialValue: selected.id,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              items: [
                for (final task in _candidates)
                  DropdownMenuItem(
                    value: task.id,
                    child: Text(task.title, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _selectedId = value),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('start-stopwatch'),
                    onPressed: _starting
                        ? null
                        : () => _start(selected.id, pomodoro: false),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Stopwatch'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('start-pomodoro'),
                    onPressed: _starting
                        ? null
                        : () => _start(selected.id, pomodoro: true),
                    icon: const Icon(Icons.timer_outlined, size: 18),
                    label: const Text('Pomodoro'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _titleFor(TimeSession session, List<Task> tasks) {
    for (final task in tasks) {
      if (task.id == session.taskId) return task.title;
    }
    return session.label ?? 'a deleted task';
  }

  Future<void> _start(String taskId, {required bool pomodoro}) async {
    setState(() => _starting = true);
    try {
      await (await ref.read(timeRepositoryProvider.future))
          .startSession(taskId, isPomodoro: pomodoro, label: 'Time tab');
      invalidateTime(ref);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _confirmDiscard(String sessionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this session?'),
        content: const Text(
            'The running timer and its time will be deleted. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            key: const Key('confirm-discard'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await (await ref.read(timeRepositoryProvider.future))
        .deleteSession(sessionId);
    invalidateTime(ref);
  }
}

/// The headline number for the selected window.
class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.totals,
    required this.window,
    required this.shares,
  });

  final AsyncValue<TimePeriodTotals> totals;
  final int window;
  final List<TaskTimeShare>? shares;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('time-total-card'),
      shape: _cardShape,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(window == 0 ? 'Tracked today' : 'Tracked this week',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: scheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            totals.when(
              loading: () => const SizedBox(
                  height: 40,
                  width: 120,
                  child: LinearProgressIndicator()),
              error: (e, _) => Text('Could not load totals',
                  style: TextStyle(color: scheme.error)),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatTracked(Duration(seconds: data.seconds)),
                    key: const Key('time-total-value'),
                    style: const TextStyle(
                        fontSize: 38, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${data.sessions} session${data.sessions == 1 ? '' : 's'}'
                    ' · ${shares?.length ?? 0} task'
                    '${(shares?.length ?? 0) == 1 ? '' : 's'}',
                    style:
                        TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Last 7 days as a proportional column chart.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.days});

  final AsyncValue<List<TimeDayTotal>> days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Last 7 days',
          subtitle: 'Taller is more time tracked',
        ),
        const SizedBox(height: 12),
        Card(
          key: const Key('time-week-strip'),
          shape: _cardShape,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            child: days.when(
              loading: () => const SizedBox(
                  height: 92, child: LinearProgressIndicator()),
              error: (e, _) => SizedBox(
                height: 92,
                child: Center(
                  child: Text('Could not load the week',
                      style: TextStyle(color: scheme.error)),
                ),
              ),
              data: (data) => SizedBox(
                height: 92,
                child: _WeekBars(days: data, scheme: scheme),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.days, required this.scheme});

  final List<TimeDayTotal> days;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final peak = days.fold<int>(0, (m, d) => d.seconds > m ? d.seconds : m);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final day in days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    day.seconds == 0
                        ? '–'
                        : formatTracked(Duration(seconds: day.seconds)),
                    style: TextStyle(
                        fontSize: 9.5,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: peak == 0 ? 3 : 8 + (44 * day.seconds / peak),
                    decoration: BoxDecoration(
                      color: day.seconds == 0
                          ? LifeOSPalette.borderDark
                          : scheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(day.label,
                      style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Ranked per-task totals with a proportional bar each.
class _BreakdownList extends ConsumerWidget {
  const _BreakdownList({required this.shares, this.onOpenTask});

  final AsyncValue<List<TaskTimeShare>> shares;

  /// Called with the task id when a breakdown row is tapped. Null in tests
  /// that only assert on rendering.
  final void Function(String taskId)? onOpenTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return shares.when(
      loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: LinearProgressIndicator()),
      error: (e, _) => Text('Could not load the breakdown',
          style: TextStyle(color: scheme.error)),
      data: (data) {
        if (data.isEmpty) {
          return _EmptyNote(
            key: const Key('breakdown-empty'),
            icon: Icons.insights_rounded,
            message: 'No time tracked in this window yet. Start a session '
                'above and it will show up here.',
          );
        }
        final peak = data.first.seconds;
        return Card(
          key: const Key('time-breakdown'),
          shape: _cardShape,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final share in data)
                  _BreakdownRow(
                    share: share,
                    fraction: peak == 0 ? 0 : share.seconds / peak,
                    onTap: () => onOpenTask?.call(share.taskId),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.share,
    required this.fraction,
    this.onTap,
  });

  final TaskTimeShare share;
  final double fraction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: Key('breakdown-${share.taskId}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    share.title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      fontStyle:
                          share.isDeleted ? FontStyle.italic : FontStyle.normal,
                      color: share.isDeleted
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  formatTracked(Duration(seconds: share.seconds)),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  share.isDeleted ? LifeOSPalette.slate : LifeOSPalette.teal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The raw session log, newest first, deletable.
class _SessionLog extends StatelessWidget {
  const _SessionLog({required this.log, required this.scheme});

  final AsyncValue<List<TimeSession>> log;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return log.when(
      loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: LinearProgressIndicator()),
      error: (e, _) => Text('Could not load sessions',
          style: TextStyle(color: scheme.error)),
      data: (sessions) {
        if (sessions.isEmpty) {
          return const _EmptyNote(
            key: Key('sessions-empty'),
            icon: Icons.history_rounded,
            message: 'No sessions recorded yet.',
          );
        }
        return Card(
          key: const Key('time-session-log'),
          shape: _cardShape,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final session in sessions)
                  _SessionRow(session: session),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SessionRow extends ConsumerWidget {
  const _SessionRow({required this.session});

  final TimeSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      key: Key('session-${session.id}'),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      leading: Icon(
        session.isPomodoro ? Icons.timer_outlined : Icons.timelapse_rounded,
        size: 18,
        color: session.isRunning ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: Text(
        session.label ?? 'Tracked session',
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${_when(session.startedAt.toLocal())}'
        '${session.isPomodoro ? ' · Pomodoro' : ''}'
        '${session.isRunning ? ' · running' : ''}',
        style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatTracked(Duration(seconds: session.durationSeconds)),
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          IconButton(
            key: Key('delete-session-${session.id}'),
            tooltip: 'Delete session',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded,
                size: 16, color: scheme.onSurfaceVariant),
            onPressed: () async {
              await (await ref.read(timeRepositoryProvider.future))
                  .deleteSession(session.id);
              invalidateTime(ref);
            },
          ),
        ],
      ),
    );
  }

  static String _when(DateTime local) {
    final today = todayLocal();
    final day = DateTime(local.year, local.month, local.day);
    final isToday = day == DateTime(today.year, today.month, today.day);
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    if (isToday) return 'Today $h:$m';
    return '${local.day}/${local.month} $h:$m';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(subtitle,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: _cardShape,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message,
                  style: TextStyle(
                      fontSize: 13, color: scheme.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The shared card silhouette: soft radius, hairline border, generous padding.
final _cardShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(20),
  side: const BorderSide(color: LifeOSPalette.borderDark, width: 1),
);
