import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart' show todayLocal;
import 'package:lifeos_focus/lifeos_focus.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

import '../app.dart';
import '../home/home_controller.dart';
import '../theme/theme_controller.dart';
import 'task_screen.dart';

final focusSessionsProvider =
    FutureProvider.autoDispose<List<FocusSession>>((ref) async {
  final repo = await ref.watch(focusRepositoryProvider.future);
  return repo.getAllSessions();
});

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  FocusMode _currentMode = FocusMode.pomodoro;
  int _secondsLeft = 1500; // 25 min default
  int _targetSeconds = 1500;
  bool _isRunning = false;
  Timer? _timer;
  Task? _selectedTask;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _switchMode(FocusMode mode) {
    _timer?.cancel();
    setState(() {
      _currentMode = mode;
      _isRunning = false;
      _targetSeconds = mode.defaultSeconds;
      _secondsLeft = mode.defaultSeconds;
    });
  }

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      setState(() => _isRunning = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_secondsLeft > 0) {
          setState(() => _secondsLeft--);
        } else {
          _timer?.cancel();
          setState(() => _isRunning = false);
          _completeSession();
        }
      });
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _secondsLeft = _targetSeconds;
    });
  }

  Future<void> _completeSession() async {
    final repo = await ref.read(focusRepositoryProvider.future);
    final id = 'focus_${DateTime.now().millisecondsSinceEpoch}';
    final elapsed = _targetSeconds - _secondsLeft;
    if (elapsed < 10) return; // Ignore accidental clicks

    await repo.recordSession(
      id: id,
      taskId: _selectedTask?.id,
      taskTitle: _selectedTask?.title,
      durationSeconds: elapsed,
      completedAt: DateTime.now(),
      mode: _currentMode,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🔥 Focus session complete! +${(elapsed / 60).round()} deep work mins logged.',
          ),
          backgroundColor: NeonPalette.mint,
        ),
      );
      ref.invalidate(focusSessionsProvider);
      ref.invalidate(summariesProvider);
      _resetTimer();
    }
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(focusSessionsProvider);
    final tasksAsync = ref.watch(taskListProvider);
    final theme = Theme.of(context);
    final progress = _targetSeconds > 0
        ? (1.0 - (_secondsLeft / _targetSeconds)).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus & Pomodoro'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          _buildModeSelector(),
          const SizedBox(height: 24),
          _buildCircularTimer(theme, progress),
          const SizedBox(height: 24),
          _buildControls(),
          const SizedBox(height: 24),
          _buildTaskLinker(theme, tasksAsync),
          const SizedBox(height: 28),
          _buildFocusStatsAndHistory(theme, sessionsAsync),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: NeonPalette.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NeonPalette.borderDark, width: 1),
      ),
      child: Row(
        children: [
          _modeButton('25m Focus', FocusMode.pomodoro),
          _modeButton('50m Deep', FocusMode.deepWork),
          _modeButton('5m Break', FocusMode.shortBreak),
          _modeButton('15m Rest', FocusMode.longBreak),
        ],
      ),
    );
  }

  Widget _modeButton(String title, FocusMode mode) {
    final isSelected = _currentMode == mode;
    return Expanded(
      child: GestureDetector(
        key: Key('focus_mode_${mode.name}'),
        onTap: () => _switchMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? NeonPalette.cyan : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.black : Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircularTimer(ThemeData theme, double progress) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 240,
            height: 240,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 10,
              backgroundColor: NeonPalette.borderDark,
              color: _currentMode == FocusMode.shortBreak ||
                      _currentMode == FocusMode.longBreak
                  ? NeonPalette.mint
                  : NeonPalette.cyan,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(_secondsLeft),
                key: const Key('timerDisplay'),
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _selectedTask != null
                    ? _selectedTask!.title
                    : _currentMode.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: NeonPalette.cyan.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.filledTonal(
          key: const Key('resetTimerButton'),
          onPressed: _resetTimer,
          icon: const Icon(Icons.refresh_rounded),
          iconSize: 26,
        ),
        const SizedBox(width: 16),
        FilledButton(
          key: const Key('toggleTimerButton'),
          onPressed: _toggleTimer,
          style: FilledButton.styleFrom(
            backgroundColor: _isRunning ? NeonPalette.rose : NeonPalette.cyan,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 28),
              const SizedBox(width: 8),
              Text(
                _isRunning ? 'Pause' : 'Start Focus',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        IconButton.filledTonal(
          key: const Key('finishTimerEarlyButton'),
          onPressed: _completeSession,
          tooltip: 'Save & Log Session',
          icon: const Icon(Icons.check_rounded),
          iconSize: 26,
        ),
      ],
    );
  }

  Widget _buildTaskLinker(
    ThemeData theme,
    AsyncValue<List<Task>> tasksAsync,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: NeonPalette.borderDark, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.link_rounded,
                    size: 18, color: NeonPalette.cyan),
                const SizedBox(width: 8),
                Text(
                  'Link Active Task (Optional)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            tasksAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Could not load tasks'),
              data: (tasks) {
                final pending = tasks.where((t) => !t.isCompleted).toList();
                if (pending.isEmpty) {
                  return const Text('No pending tasks available.');
                }
                return DropdownButtonFormField<Task>(
                  initialValue: _selectedTask,
                  hint: const Text('Select a task to focus on...'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<Task>(
                      value: null,
                      child: Text('None (General Focus)'),
                    ),
                    for (final t in pending)
                      DropdownMenuItem<Task>(
                        value: t,
                        child: Text(t.title, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (val) => setState(() => _selectedTask = val),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainer,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFocusStatsAndHistory(
    ThemeData theme,
    AsyncValue<List<FocusSession>> sessionsAsync,
  ) {
    return sessionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
      data: (sessions) {
        final today = todayLocal();
        final todaySessions = sessions
            .where((s) => s.completedAt.day == today.day && s.completedAt.month == today.month)
            .toList();
        final todayMinutes = todaySessions.fold<int>(
            0, (sum, s) => sum + s.durationMinutes);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    'Deep Work Today',
                    '$todayMinutes mins',
                    Icons.timer_outlined,
                    NeonPalette.cyan,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    'Sessions Done',
                    '${todaySessions.length}',
                    Icons.local_fire_department_rounded,
                    NeonPalette.rose,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Recent Sessions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            if (sessions.isEmpty)
              const Text('No focus sessions logged yet.')
            else
              ...sessions.take(5).map((s) => _sessionTile(theme, s)),
          ],
        );
      },
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NeonPalette.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 11, color: Colors.white60),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sessionTile(ThemeData theme, FocusSession s) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: NeonPalette.borderDark, width: 1),
      ),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.check_circle_outline, color: NeonPalette.mint),
        title: Text(
          s.taskTitle ?? s.mode.label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${s.durationMinutes} mins • ${s.completedAt.hour.toString().padLeft(2, '0')}:${s.completedAt.minute.toString().padLeft(2, '0')}',
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: NeonPalette.cyan.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '+${s.durationMinutes}m',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: NeonPalette.cyan,
            ),
          ),
        ),
      ),
    );
  }
}
