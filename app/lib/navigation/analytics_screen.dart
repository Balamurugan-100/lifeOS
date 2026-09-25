import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart' show calendarDate, todayLocal;
import 'package:lifeos_finance/lifeos_finance.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

import '../app.dart';
import '../theme/theme_controller.dart';

class AnalyticsData {
  const AnalyticsData({
    required this.habitsHistory,
    required this.netWorth,
    required this.cashflow,
    required this.categorySpending,
    required this.categories,
    required this.tasks,
    required this.focusMinutes,
    required this.moodMap,
  });

  final Map<DateTime, int> habitsHistory; // Date -> completed count
  final NetWorth netWorth;
  final MonthlyCashflow cashflow;
  final Map<String, double> categorySpending;
  final List<FinanceCategory> categories;
  final List<Task> tasks;
  final Map<String, int> focusMinutes;
  final Map<String, int> moodMap;
}

final analyticsDataProvider =
    FutureProvider.autoDispose<AnalyticsData>((ref) async {
  final habitsRepo = await ref.watch(habitRepositoryProvider.future);
  final financeRepo = await ref.watch(financeRepositoryProvider.future);
  final tasksRepo = await ref.watch(taskRepositoryProvider.future);
  final focusRepo = await ref.watch(focusRepositoryProvider.future);
  final journalRepo = await ref.watch(journalRepositoryProvider.future);

  final today = todayLocal();
  final entries = await habitsRepo.allEntries();
  final habitsHistory = <DateTime, int>{};
  for (final e in entries) {
    final d = calendarDate(e.date);
    habitsHistory[d] = (habitsHistory[d] ?? 0) + 1;
  }

  final netWorth = await financeRepo.getNetWorth();
  final cashflow = await financeRepo.getMonthlyCashflow(today);
  final catSpending = await financeRepo.getMonthlyCategorySpending(today);
  final categories = await financeRepo.getCategories();
  final tasks = await tasksRepo.all();
  final focusMinutes = await focusRepo.getDailyFocusMinutes(days: 7);
  final moodMap = await journalRepo.getMoodHistory(limit: 30);

  return AnalyticsData(
    habitsHistory: habitsHistory,
    netWorth: netWorth,
    cashflow: cashflow,
    categorySpending: catSpending,
    categories: categories,
    tasks: tasks,
    focusMinutes: focusMinutes,
    moodMap: moodMap,
  );
});

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(analyticsDataProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Interactive Analytics & Trends'),
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading analytics: $e')),
        data: (data) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(analyticsDataProvider),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _buildHeatmapSection(theme, data.habitsHistory),
                const SizedBox(height: 20),
                _buildFinanceCashflowSection(
                    theme, data.netWorth, data.cashflow, data.categorySpending, data.categories),
                const SizedBox(height: 20),
                _buildProductivitySection(
                    theme, data.tasks, data.focusMinutes),
                const SizedBox(height: 20),
                _buildMoodHabitsCorrelationSection(
                    theme, data.moodMap, data.habitsHistory),
              ],
            ),
          );
        },
      ),
    );
  }

  // 1. GitHub-Style Yearly Habit Contribution Heatmap
  Widget _buildHeatmapSection(
    ThemeData theme,
    Map<DateTime, int> history,
  ) {
    final today = todayLocal();
    const weeksCount = 20; // Last 20 weeks for mobile landscape scrolling
    const totalDays = weeksCount * 7;
    final startDate = today.subtract(const Duration(days: totalDays - 1));

    int totalCompletions = 0;
    history.forEach((_, count) => totalCompletions += count);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: NeonPalette.borderDark, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: NeonPalette.mint.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.grid_on_rounded,
                      color: NeonPalette.mint, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'Habit Consistency Heatmap',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '$totalCompletions done',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: NeonPalette.mint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (int w = 0; w < weeksCount; w++)
                        Column(
                          children: [
                            for (int d = 0; d < 7; d++)
                              _buildHeatmapCell(
                                startDate.add(Duration(days: (w * 7) + d)),
                                history,
                              ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('Less', style: TextStyle(fontSize: 10, color: Colors.white54)),
                const SizedBox(width: 4),
                _legendCell(0),
                _legendCell(1),
                _legendCell(2),
                _legendCell(4),
                const SizedBox(width: 4),
                const Text('More', style: TextStyle(fontSize: 10, color: Colors.white54)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmapCell(DateTime date, Map<DateTime, int> history) {
    final count = history[calendarDate(date)] ?? 0;
    Color color = NeonPalette.surfaceDark;
    if (count == 1) {
      color = NeonPalette.mint.withValues(alpha: 0.35);
    } else if (count == 2) {
      color = NeonPalette.mint.withValues(alpha: 0.65);
    } else if (count >= 3) {
      color = NeonPalette.mint;
    }

    return Container(
      width: 13,
      height: 13,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: count > 0 ? Colors.transparent : NeonPalette.borderDark,
          width: 0.5,
        ),
      ),
    );
  }

  Widget _legendCell(int count) {
    Color color = NeonPalette.surfaceDark;
    if (count == 1) {
      color = NeonPalette.mint.withValues(alpha: 0.35);
    } else if (count == 2) {
      color = NeonPalette.mint.withValues(alpha: 0.65);
    } else if (count >= 3) {
      color = NeonPalette.mint;
    }
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // 2. Net Worth & Cashflow Breakdown
  Widget _buildFinanceCashflowSection(
    ThemeData theme,
    NetWorth netWorth,
    MonthlyCashflow cashflow,
    Map<String, double> catSpending,
    List<FinanceCategory> categories,
  ) {
    final savingsRate = cashflow.income > 0
        ? (cashflow.netSavings / cashflow.income * 100)
        : 0.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: NeonPalette.borderDark, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: NeonPalette.violet.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bar_chart_rounded,
                      color: NeonPalette.violet, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'Financial Health & Cashflow',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _financeMetricBox(
                    'Net Worth',
                    '₹${netWorth.netWorth.toStringAsFixed(0)}',
                    NeonPalette.violet,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _financeMetricBox(
                    'Monthly Savings',
                    '${savingsRate.toStringAsFixed(1)}%',
                    savingsRate >= 0 ? NeonPalette.mint : NeonPalette.rose,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Top Expense Categories (This Month)',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            if (catSpending.isEmpty)
              const Text('No expense transactions recorded this month.')
            else
              ...catSpending.entries.take(4).map((entry) {
                final cat = categories.firstWhere(
                  (c) => c.id == entry.key,
                  orElse: () => FinanceCategory(
                    id: entry.key,
                    name: entry.key,
                    iconName: 'category',
                    colorHex: '#A855F7',
                    type: CategoryType.expense,
                    isPredefined: false,
                    createdAt: DateTime.now(),
                  ),
                );
                final fraction = cashflow.expense > 0
                    ? (entry.value / cashflow.expense).clamp(0.0, 1.0)
                    : 0.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(cat.name, style: const TextStyle(fontSize: 12)),
                          const Spacer(),
                          Text(
                            '₹${entry.value.toStringAsFixed(0)} (${(fraction * 100).toStringAsFixed(0)}%)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 6,
                          backgroundColor: NeonPalette.surfaceDark,
                          color: NeonPalette.violet,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _financeMetricBox(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NeonPalette.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.white60)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // 3. Productivity Velocity & Focus Time
  Widget _buildProductivitySection(
    ThemeData theme,
    List<Task> tasks,
    Map<String, int> focusMinutes,
  ) {
    final completed = tasks.where((t) => t.isCompleted).length;
    final total = tasks.length;
    final rate = total > 0 ? (completed / total * 100).round() : 0;
    final totalFocusMins = focusMinutes.values.fold<int>(0, (s, m) => s + m);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: NeonPalette.borderDark, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: NeonPalette.cyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bolt_rounded,
                      color: NeonPalette.cyan, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'Productivity & Focus Velocity',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _financeMetricBox(
                    'Tasks Completed',
                    '$completed / $total ($rate%)',
                    NeonPalette.cyan,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _financeMetricBox(
                    '7-Day Deep Work',
                    '$totalFocusMins mins',
                    NeonPalette.amber,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 4. Mood & Habit Correlation Matrix
  Widget _buildMoodHabitsCorrelationSection(
    ThemeData theme,
    Map<String, int> moodMap,
    Map<DateTime, int> habitsHistory,
  ) {
    double avgMoodOnHabitDays = 0.0;
    int habitDaysCount = 0;
    double avgMoodOnMissedDays = 0.0;
    int missedDaysCount = 0;

    moodMap.forEach((dateStr, moodScore) {
      try {
        final parsed = DateTime.parse(dateStr);
        final count = habitsHistory[calendarDate(parsed)] ?? 0;
        if (count > 0) {
          avgMoodOnHabitDays += moodScore;
          habitDaysCount++;
        } else {
          avgMoodOnMissedDays += moodScore;
          missedDaysCount++;
        }
      } catch (_) {}
    });

    final scoreWithHabits =
        habitDaysCount > 0 ? (avgMoodOnHabitDays / habitDaysCount) : 0.0;
    final scoreWithoutHabits =
        missedDaysCount > 0 ? (avgMoodOnMissedDays / missedDaysCount) : 0.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: NeonPalette.borderDark, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: NeonPalette.rose.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.psychology_rounded,
                      color: NeonPalette.rose, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'Habit & Mood Correlation',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Does completing habits boost your daily mood score?',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: NeonPalette.mint.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: NeonPalette.mint.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'On Habit Days',
                          style: TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          scoreWithHabits > 0
                              ? '${scoreWithHabits.toStringAsFixed(1)} / 5.0 😊'
                              : 'No data yet',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: NeonPalette.mint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: NeonPalette.rose.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: NeonPalette.rose.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'On Zero-Habit Days',
                          style: TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          scoreWithoutHabits > 0
                              ? '${scoreWithoutHabits.toStringAsFixed(1)} / 5.0 😐'
                              : 'No data yet',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: NeonPalette.rose,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
