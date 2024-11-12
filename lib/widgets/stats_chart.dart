import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/session_stats.dart';

class StatsChart extends StatelessWidget {
  final List<SessionStats> stats;
  final String period;

  const StatsChart({
    super.key,
    required this.stats,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Focus Time',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text('${value.toInt()}h'),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) => _getBottomTitle(value, period),
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _generateSpots(),
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _generateSpots() {
    if (stats.isEmpty || stats.first.focusSessions.isEmpty) {
      return [const FlSpot(0, 0)];
    }

    return List.generate(
      stats.first.focusSessions.length,
      (index) => FlSpot(
        index.toDouble(),
        stats.first.focusSessions[index].inMinutes.toDouble(),
      ),
    );
  }

  Widget _getBottomTitle(double value, String period) {
    final labels = {
      'daily': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      'weekly': ['W1', 'W2', 'W3', 'W4'],
      'monthly': ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
      'yearly': ['2023', '2024'],
    };

    final list = labels[period] ?? labels['daily']!;
    final index = value.toInt();
    if (index >= 0 && index < list.length) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(list[index], style: const TextStyle(fontSize: 12)),
      );
    }
    return const SizedBox();
  }
} 