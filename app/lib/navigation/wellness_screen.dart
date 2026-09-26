import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_wellness/lifeos_wellness.dart';

import '../app.dart';
import '../home/home_controller.dart';
import '../theme/theme_controller.dart';

final wellnessDataProvider = FutureProvider.autoDispose((ref) async {
  final repo = await ref.watch(wellnessRepositoryProvider.future);
  final today = isoDate(todayLocal());
  final todayLog = await repo.getLogForDate(today);
  final allLogs = await repo.getAllLogs(limit: 14);
  final averages = await repo.getAverages(days: 7);

  return (
    todayLog: todayLog,
    allLogs: allLogs,
    averages: averages,
  );
});

class WellnessScreen extends ConsumerStatefulWidget {
  const WellnessScreen({super.key});

  @override
  ConsumerState<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends ConsumerState<WellnessScreen> {
  double _sleepHours = 7.5;
  int _sleepQuality = 4;
  int _energyScore = 4;
  int _waterMl = 2000;
  final Set<String> _factors = {'exercise'};

  bool _initialized = false;

  void _initFromLog(WellnessLog? log) {
    if (_initialized || log == null) return;
    _sleepHours = log.sleepHours;
    _sleepQuality = log.sleepQualityScore;
    _energyScore = log.energyScore;
    _waterMl = log.waterMl;
    _factors.clear();
    _factors.addAll(log.factors);
    _initialized = true;
  }

  Future<void> _saveWellness() async {
    final repo = await ref.read(wellnessRepositoryProvider.future);
    final today = isoDate(todayLocal());
    final sleepMins = (_sleepHours * 60).round();

    await repo.logWellness(
      date: today,
      sleepDurationMinutes: sleepMins,
      sleepQualityScore: _sleepQuality,
      energyScore: _energyScore,
      waterMl: _waterMl,
      factors: _factors.toList(),
    );

    ref.invalidate(wellnessDataProvider);
    ref.invalidate(summariesProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ Sleep & Energy logged for today!'),
          backgroundColor: NeonPalette.mint,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(wellnessDataProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🔋 Sleep & Energy Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator(color: NeonPalette.cyan)),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (data) {
          _initFromLog(data.todayLog);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. 7-Day Performance Averages
              _buildAveragesCard(data.averages, isDark),
              const SizedBox(height: 20),

              // 2. Today's Sleep Duration
              _buildSectionCard(
                title: '🌙 Sleep Duration',
                subtitle: '${_sleepHours.toStringAsFixed(1)} hours (${(_sleepHours * 60).round()} mins)',
                color: NeonPalette.violet,
                isDark: isDark,
                child: Column(
                  children: [
                    Slider(
                      value: _sleepHours,
                      min: 3.0,
                      max: 12.0,
                      divisions: 18,
                      activeColor: NeonPalette.violet,
                      label: '${_sleepHours.toStringAsFixed(1)} hrs',
                      onChanged: (val) => setState(() => _sleepHours = val),
                    ),
                    const SizedBox(height: 8),
                    const Text('Sleep Quality Rating:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(5, (index) {
                        final star = index + 1;
                        return IconButton(
                          icon: Icon(
                            star <= _sleepQuality ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: NeonPalette.amber,
                            size: 32,
                          ),
                          onPressed: () => setState(() => _sleepQuality = star),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Morning Energy Level
              _buildSectionCard(
                title: '⚡ Morning Energy Level',
                subtitle: _getEnergyLabel(_energyScore),
                color: NeonPalette.cyan,
                isDark: isDark,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildEnergyButton(1, '🪫 1', isDark),
                    _buildEnergyButton(2, '🥱 2', isDark),
                    _buildEnergyButton(3, '⚖️ 3', isDark),
                    _buildEnergyButton(4, '🔋 4', isDark),
                    _buildEnergyButton(5, '⚡ 5', isDark),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Biomarkers & Lifestyle Factors
              _buildSectionCard(
                title: '🌿 Lifestyle Factors & Habits',
                subtitle: 'Tags affecting recovery',
                color: NeonPalette.mint,
                isDark: isDark,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFactorChip('exercise', '🏋️ Exercise'),
                    _buildFactorChip('meditation', '🧘 Meditation'),
                    _buildFactorChip('magnesium', '💊 Supplement'),
                    _buildFactorChip('no_late_screen', '📵 No Late Screen'),
                    _buildFactorChip('caffeine_after_2pm', '☕ Afternoon Coffee'),
                    _buildFactorChip('heavy_dinner', '🍕 Heavy Dinner'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 5. Save Button
              FilledButton.icon(
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Save Today\'s Vitals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: NeonPalette.cyan,
                  foregroundColor: Colors.black,
                ),
                onPressed: _saveWellness,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAveragesCard(
      ({double avgEnergyScore, double avgQualityScore, double avgSleepDurationHours}) averages,
      bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B4B) : Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NeonPalette.violet.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('7-DAY WELLNESS AVERAGES',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: NeonPalette.violet)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildAvgMetric('Avg Sleep', '${averages.avgSleepDurationHours.toStringAsFixed(1)}h', Icons.bedtime_outlined),
              _buildAvgMetric('Avg Energy', '${averages.avgEnergyScore.toStringAsFixed(1)}/5', Icons.bolt),
              _buildAvgMetric('Quality', '${averages.avgQualityScore.toStringAsFixed(1)}/5', Icons.auto_awesome),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvgMetric(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: NeonPalette.cyan),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Color color,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(subtitle, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildEnergyButton(int score, String label, bool isDark) {
    final isSelected = _energyScore == score;
    return InkWell(
      onTap: () => setState(() => _energyScore = score),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? NeonPalette.cyan : (isDark ? Colors.white10 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? NeonPalette.cyan : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.black : (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildFactorChip(String key, String label) {
    final isSelected = _factors.contains(key);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: NeonPalette.mint.withValues(alpha: 0.3),
      onSelected: (val) {
        setState(() {
          if (val) {
            _factors.add(key);
          } else {
            _factors.remove(key);
          }
        });
      },
    );
  }

  String _getEnergyLabel(int score) {
    return switch (score) {
      5 => '⚡ Supercharged',
      4 => '🔋 High Energy',
      3 => '⚖️ Balanced',
      2 => '🥱 Drained',
      _ => '🪫 Depleted',
    };
  }
}
