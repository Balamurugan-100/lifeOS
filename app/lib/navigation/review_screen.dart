import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_review/lifeos_review.dart';

import '../app.dart';
import '../home/home_controller.dart';
import '../theme/theme_controller.dart';

final weeklyReviewDataProvider = FutureProvider.autoDispose((ref) async {
  final reviewRepo = await ref.watch(reviewRepositoryProvider.future);
  final taskRepo = await ref.watch(taskRepositoryProvider.future);
  final habitRepo = await ref.watch(habitRepositoryProvider.future);
  final focusRepo = await ref.watch(focusRepositoryProvider.future);
  final journalRepo = await ref.watch(journalRepositoryProvider.future);

  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - 1));
  final weekStartDate = isoDate(monday);

  final currentReview = await reviewRepo.getReviewForWeek(weekStartDate);
  final pastReviews = await reviewRepo.getAllReviews();

  // Aggregate stats from other domains
  final allTasks = await taskRepo.all();
  final tasksDone = allTasks.where((t) => t.isCompleted).length;

  final habitEntries = await habitRepo.allEntries();
  final habitCount = habitEntries.length;

  final focusSessions = await focusRepo.getAllSessions();
  final totalFocusMins = focusSessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);

  final avgMood = await journalRepo.getAverageMoodScore(limit: 7);

  return (
    weekStartDate: weekStartDate,
    currentReview: currentReview,
    pastReviews: pastReviews,
    tasksDone: tasksDone,
    habitCount: habitCount,
    totalFocusMins: totalFocusMins,
    avgMood: avgMood,
  );
});

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final _winCtrl = TextEditingController();
  final _lessonCtrl = TextEditingController();
  final _bet1Ctrl = TextEditingController();
  final _bet2Ctrl = TextEditingController();
  final _bet3Ctrl = TextEditingController();

  int _rating = 4;
  bool _initialized = false;

  @override
  void dispose() {
    _winCtrl.dispose();
    _lessonCtrl.dispose();
    _bet1Ctrl.dispose();
    _bet2Ctrl.dispose();
    _bet3Ctrl.dispose();
    super.dispose();
  }

  void _initFields(WeeklyReview? review) {
    if (_initialized || review == null) return;
    _rating = review.rating;
    _winCtrl.text = review.biggestWin;
    _lessonCtrl.text = review.challengeOrLesson;
    if (review.bigBets.isNotEmpty) _bet1Ctrl.text = review.bigBets[0];
    if (review.bigBets.length > 1) _bet2Ctrl.text = review.bigBets[1];
    if (review.bigBets.length > 2) _bet3Ctrl.text = review.bigBets[2];
    _initialized = true;
  }

  Future<void> _saveReview(String weekStartDate, int tasks, int habits, int focus, double mood) async {
    final reviewRepo = await ref.read(reviewRepositoryProvider.future);
    final bets = <String>[];
    if (_bet1Ctrl.text.trim().isNotEmpty) bets.add(_bet1Ctrl.text.trim());
    if (_bet2Ctrl.text.trim().isNotEmpty) bets.add(_bet2Ctrl.text.trim());
    if (_bet3Ctrl.text.trim().isNotEmpty) bets.add(_bet3Ctrl.text.trim());

    await reviewRepo.saveReview(
      weekStartDate: weekStartDate,
      rating: _rating,
      biggestWin: _winCtrl.text.trim(),
      challengeOrLesson: _lessonCtrl.text.trim(),
      bigBets: bets,
      totalTasksCompleted: tasks,
      totalHabitCheckins: habits,
      totalFocusMinutes: focus,
      averageMood: mood,
    );

    ref.invalidate(weeklyReviewDataProvider);
    ref.invalidate(summariesProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🏆 Weekly Retrospective & Intentions Saved!'),
          backgroundColor: NeonPalette.mint,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(weeklyReviewDataProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📅 Weekly Review & Protocol', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator(color: NeonPalette.cyan)),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (data) {
          _initFields(data.currentReview);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Executive Performance Rollup Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E1B4B), NeonPalette.surfaceCard]
                        : [Colors.indigo.shade50, Colors.white],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: NeonPalette.violet.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WEEK OF ${data.weekStartDate}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: NeonPalette.violet,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMetricCol('Tasks Done', '${data.tasksDone}', Icons.checklist_rounded, NeonPalette.cyan),
                        _buildMetricCol('Habits Logged', '${data.habitCount}', Icons.loop, NeonPalette.mint),
                        _buildMetricCol('Focus', '${(data.totalFocusMins / 60).toStringAsFixed(1)}h', Icons.timer, NeonPalette.rose),
                        _buildMetricCol('Avg Mood', '${data.avgMood.toStringAsFixed(1)}/5', Icons.sentiment_satisfied_rounded, NeonPalette.amber),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. Weekly Satisfaction Rating
              _buildCard(
                title: '⭐ Rate Your Week',
                isDark: isDark,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(5, (index) {
                    final star = index + 1;
                    return IconButton(
                      icon: Icon(
                        star <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: NeonPalette.amber,
                        size: 36,
                      ),
                      onPressed: () => setState(() => _rating = star),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Wins & Lessons Reflection
              _buildCard(
                title: '🏆 Wins & Lessons',
                isDark: isDark,
                child: Column(
                  children: [
                    TextField(
                      controller: _winCtrl,
                      decoration: const InputDecoration(
                        labelText: 'What was your biggest win this week?',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _lessonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Key lesson learned or adjustment for next week?',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Next Week's 3 Big Bets (Intentions)
              _buildCard(
                title: '🎯 Next Week\'s 3 Big Bets',
                isDark: isDark,
                child: Column(
                  children: [
                    TextField(
                      controller: _bet1Ctrl,
                      decoration: const InputDecoration(
                        labelText: '1. Primary Objective (Must Win)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _bet2Ctrl,
                      decoration: const InputDecoration(
                        labelText: '2. Secondary Objective',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _bet3Ctrl,
                      decoration: const InputDecoration(
                        labelText: '3. Personal Growth / Health Bet',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 5. Submit Button
              FilledButton.icon(
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Save Weekly Retrospective', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: NeonPalette.violet,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _saveReview(
                  data.weekStartDate,
                  data.tasksDone,
                  data.habitCount,
                  data.totalFocusMins,
                  data.avgMood,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricCol(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? NeonPalette.surfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? NeonPalette.borderDark : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
