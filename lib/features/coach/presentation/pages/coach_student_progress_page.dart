import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/coach_entities.dart';
import '../providers/coach_providers.dart';

const _kPrimary = Color(0xFF1E6F5C);
const _kBg = Color(0xFFF4F6F5);

/// Perkembangan satu siswa di satu ekskul: kehadiran + tren keaktifan +
/// riwayat penilaian (skor & catatan) yang pembina berikan selama ini.
class CoachStudentProgressPage extends ConsumerStatefulWidget {
  const CoachStudentProgressPage({
    super.key,
    required this.extracurricularId,
    required this.studentId,
    required this.studentName,
  });
  final String extracurricularId;
  final String studentId;
  final String studentName;

  @override
  ConsumerState<CoachStudentProgressPage> createState() => _State();
}

class _State extends ConsumerState<CoachStudentProgressPage> {
  String _period = 'weekly';

  @override
  Widget build(BuildContext context) {
    final args = (
      extracurricularId: widget.extracurricularId,
      studentId: widget.studentId,
      period: _period,
    );
    final async = ref.watch(studentProgressProvider(args));

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(title: Text(widget.studentName)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(studentProgressProvider(args));
          await ref.read(studentProgressProvider(args).future).catchError((_) => throw '');
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 80),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Gagal memuat perkembangan.\n$e', textAlign: TextAlign.center),
              ),
            ),
          ]),
          data: (p) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _Header(p: p),
              const SizedBox(height: 12),
              _AttendanceCard(p: p),
              const SizedBox(height: 12),
              _ActivenessCard(
                average: p.averageActiveness,
                points: p.trend,
                period: _period,
                onPeriod: (v) => setState(() => _period = v),
              ),
              const SizedBox(height: 12),
              if (p.evaluations.isEmpty)
                const _Card(
                  child: Text('Belum ada penilaian. Isi nilai keaktifan & catatan '
                      'saat presensi agar perkembangan siswa terekam.'),
                )
              else
                _EvaluationsCard(items: p.evaluations),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.p});
  final StudentProgress p;
  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFE4EFEA),
            child: Text(p.studentName.characters.first.toUpperCase(),
                style: const TextStyle(color: Color(0xFF155440), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.studentName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Kelas ${p.classGrade}   ·   NIS ${p.nis}',
                    style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
                if (p.ekskulName.isNotEmpty)
                  Text(p.ekskulName, style: const TextStyle(fontSize: 12.5, color: _kPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.p});
  final StudentProgress p;

  @override
  Widget build(BuildContext context) {
    final total = p.totalSessions;
    Widget seg(int n, Color c) => n == 0
        ? const SizedBox.shrink()
        : Expanded(flex: n, child: Container(height: 10, color: c));
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${p.attendancePct.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _kPrimary)),
              const SizedBox(width: 8),
              Text('kehadiran  ·  $total sesi',
                  style: const TextStyle(color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 10),
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(children: [
                seg(p.hadir, const Color(0xFF1E6F5C)),
                seg(p.izin, const Color(0xFF2F6FB0)),
                seg(p.sakit, const Color(0xFFB07C2F)),
                seg(p.alpa, const Color(0xFFB0402F)),
              ]),
            ),
          const SizedBox(height: 8),
          Text('Hadir ${p.hadir} · Izin ${p.izin} · Sakit ${p.sakit} · Alpa ${p.alpa}',
              style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
        ],
      ),
    );
  }
}

class _ActivenessCard extends StatelessWidget {
  const _ActivenessCard({
    required this.average,
    required this.points,
    required this.period,
    required this.onPeriod,
  });
  final double? average;
  final List<TrendPoint> points;
  final String period;
  final ValueChanged<String> onPeriod;

  static (String, Color) _band(double v) {
    if (v >= 4.5) return ('Sangat aktif', const Color(0xFF1E6F5C));
    if (v >= 3.5) return ('Aktif', const Color(0xFF2E8B57));
    if (v >= 2.5) return ('Cukup', const Color(0xFFB07C2F));
    if (v >= 1.5) return ('Kurang aktif', const Color(0xFFB0642F));
    return ('Perlu perhatian', const Color(0xFFB0402F));
  }

  @override
  Widget build(BuildContext context) {
    final labelEvery = (points.length / 4).ceil().clamp(1, points.isEmpty ? 1 : points.length);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Keaktifan', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              SegmentedButton<String>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: 'weekly', label: Text('Mingguan')),
                  ButtonSegment(value: 'monthly', label: Text('Bulanan')),
                ],
                selected: {period},
                onSelectionChanged: (s) => onPeriod(s.first),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (average != null) ...[
            Builder(builder: (_) {
              final (label, color) = _band(average!);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(average!.toStringAsFixed(1),
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color)),
                  const Text(' / 5', style: TextStyle(fontSize: 13, color: Colors.black54)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(label,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                  ),
                ],
              );
            }),
            const SizedBox(height: 2),
            const Text('Rata-rata skor keaktifan (1–5) dari penilaian tiap sesi.',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
          ] else
            const Text('Belum ada nilai keaktifan.',
                style: TextStyle(fontSize: 13, color: Colors.black54)),
          if (points.length > 1) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 140,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 5,
                  minX: 0,
                  maxX: (points.length - 1).toDouble(),
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 24, interval: 1),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final i = value.round();
                          if (i < 0 || i >= points.length || i % labelEvery != 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(points[i].label,
                                style: const TextStyle(fontSize: 10, color: Colors.black54)),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < points.length; i++)
                          FlSpot(i.toDouble(), points[i].avgScore),
                      ],
                      isCurved: points.length > 2,
                      barWidth: 3,
                      color: _kPrimary,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EvaluationsCard extends StatelessWidget {
  const _EvaluationsCard({required this.items});
  final List<StudentEvalEntry> items;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Riwayat penilaian per sesi',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          const Text('Skor keaktifan 1–5 dan catatan yang Anda berikan.',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
          for (final e in items) ...[
            const Divider(height: 18),
            Row(
              children: [
                Text(e.date, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const Spacer(),
                if (e.activenessScore != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4EFEA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Keaktifan ${e.activenessScore}/5',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF155440))),
                  ),
              ],
            ),
            if (e.skillNotes != null && e.skillNotes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Keterampilan: ${e.skillNotes}'),
              ),
            if (e.personalNotes != null && e.personalNotes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Catatan: ${e.personalNotes}',
                    style: const TextStyle(fontStyle: FontStyle.italic)),
              ),
            if (!e.hasNotes)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text('Tanpa catatan tambahan.',
                    style: TextStyle(fontSize: 12, color: Colors.black45)),
              ),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE6EAE8)),
        ),
        child: child,
      );
}
