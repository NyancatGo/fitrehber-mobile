// Profil ekranı: son 30 günlük aktivite ısı haritası bölümü.
part of '../profile_screen.dart';

class _ActivityHeatmapSection extends StatelessWidget {
  final DailyActivitySummary activity;

  const _ActivityHeatmapSection({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.grid_view_rounded,
            title: 'Aktivite Haritası',
            subtitle:
                'Son 30 gün: ${activity.averageMinutes} dk günlük ortalama',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: activity.days.map((day) {
              return Tooltip(
                message: '${day.label}: ${day.minutes} dk',
                triggerMode: TooltipTriggerMode.tap,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _activityLevelColor(day.minutes),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
