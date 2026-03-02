import 'package:flutter/material.dart';
import '../config/hr_zones.dart';
import '../config/theme.dart';
import '../models/workout.dart';
import '../services/storage_service.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  List<Workout> _workouts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    final workouts = await StorageService.loadWorkouts();
    setState(() {
      _workouts = workouts.reversed.toList(); // Most recent first
      _loading = false;
    });
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  String _formatDate(DateTime dt) {
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month]} ${dt.year} · $hour:$min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout History'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _workouts.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _workouts.length,
                  itemBuilder: (context, index) =>
                      _buildWorkoutCard(_workouts[index]),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fitness_center, size: 64, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          Text(
            'No workouts yet',
            style: TextStyle(fontSize: 18, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete a workout to see it here',
            style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutCard(Workout workout) {
    final a = workout.analytics;
    final duration = workout.duration;

    // Find dominant zone
    int dominantZone = 1;
    Duration maxTime = Duration.zero;
    a.timeInZone.forEach((zone, time) {
      if (time > maxTime) {
        maxTime = time;
        dominantZone = zone;
      }
    });
    final zoneColor = HrZones.colors[dominantZone] ?? AppTheme.accent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: zoneColor.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date + Duration
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(workout.startTime),
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: zoneColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatDuration(duration),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: zoneColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Key metrics row
            Row(
              children: [
                _buildMini(Icons.favorite, '${a.avgHr}', 'Avg', AppTheme.accent),
                _buildMini(Icons.arrow_upward, '${a.maxHr}', 'Max', HrZones.colors[5]!),
                _buildMini(Icons.local_fire_department, '${a.calories.round()}', 'kcal', const Color(0xFFF97316)),
                _buildMini(Icons.timeline, a.trimp.toStringAsFixed(0), 'TRIMP', const Color(0xFF8B5CF6)),
                _buildMini(Icons.trending_up, a.trainingEffect.toStringAsFixed(1), 'TE', const Color(0xFF06B6D4)),
              ],
            ),
            const SizedBox(height: 12),

            // Zone bar
            Row(
              children: List.generate(5, (i) {
                final zone = i + 1;
                final pct = duration.inSeconds > 0
                    ? (a.timeInZone[zone]?.inSeconds ?? 0) / duration.inSeconds
                    : 0.0;
                return Expanded(
                  flex: (pct * 100).round().clamp(1, 100),
                  child: Container(
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: HrZones.colors[zone]!,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMini(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          Text(label,
              style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}
