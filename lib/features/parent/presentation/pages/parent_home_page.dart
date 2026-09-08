import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/parent_entities.dart';
import '../providers/parent_providers.dart';

/// Home Dashboard Orang Tua (dokumen desain bagian 5.2).
class ParentHomePage extends ConsumerWidget {
  const ParentHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(childrenProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perkembangan Anak'),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authSessionProvider.notifier).logout(),
          ),
        ],
      ),
      body: childrenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Centered(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Gagal memuat data.\n$e', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref.invalidate(childrenProvider),
              child: const Text('Coba lagi'),
            ),
          ]),
        ),
        data: (children) {
          if (children.isEmpty) return const _NoChildLinked();
          final selectedId = ref.watch(selectedChildProvider) ?? children.first.id;
          final active = children.firstWhere(
            (c) => c.id == selectedId,
            orElse: () => children.first,
          );
          return Column(
            children: [
              if (children.length > 1) _ChildSelector(children: children, selectedId: active.id),
              Expanded(child: _ProgressView(child: active)),
            ],
          );
        },
      ),
    );
  }
}

class _ChildSelector extends ConsumerWidget {
  const _ChildSelector({required this.children, required this.selectedId});
  final List<Child> children;
  final String selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = children[i];
          final on = c.id == selectedId;
          return ChoiceChip(
            selected: on,
            label: Text(c.fullName.split(' ').first),
            avatar: CircleAvatar(child: Text(c.fullName.characters.first)),
            onSelected: (_) => ref.read(selectedChildProvider.notifier).select(c.id),
          );
        },
      ),
    );
  }
}

class _ProgressView extends ConsumerWidget {
  const _ProgressView({required this.child});
  final Child child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(trendPeriodProvider);
    final args = (studentId: child.id, period: period);
    final progressAsync = ref.watch(childProgressProvider(args));

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(childProgressProvider(args).future),
      child: progressAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          if (e is UnauthorizedRelationException) {
            return _Centered(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.hourglass_top, size: 48, color: Colors.orange),
                const SizedBox(height: 12),
                Text(
                  'Menunggu persetujuan admin sekolah untuk melihat data ${child.fullName}.',
                  textAlign: TextAlign.center,
                ),
              ]),
            );
          }
          return _Centered(child: Text('Gagal memuat perkembangan.\n$e', textAlign: TextAlign.center));
        },
        data: (p) {
          if (!p.hasAnySession) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ChildHeader(child: child),
                const SizedBox(height: 40),
                _Centered(
                  child: Text(
                    '${p.studentName} belum memiliki sesi presensi yang tercatat.\n'
                    'Data akan muncul setelah pembina melakukan presensi.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ChildHeader(child: child),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: _PeriodToggle(
                  period: period,
                  onChanged: (v) => ref.read(trendPeriodProvider.notifier).set(v),
                ),
              ),
              const SizedBox(height: 8),
              for (final ek in p.extracurriculars) ...[
                Text(ek.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _DonutCard(summary: ek.summary),
                if (ek.averageActiveness != null || ek.activenessTrend.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ActivenessCard(
                    average: ek.averageActiveness,
                    points: ek.activenessTrend,
                    period: period,
                  ),
                ],
                if (ek.evaluations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _EvaluationsCard(items: ek.evaluations),
                ],
                if (ek.materials.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _MaterialsCard(materials: ek.materials),
                ],
                const SizedBox(height: 24),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DonutCard extends StatelessWidget {
  const _DonutCard({required this.summary});
  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final sections = <PieChartSectionData>[
      if (s.hadir > 0) PieChartSectionData(value: s.hadir.toDouble(), color: const Color(0xFF1E6F5C), title: 'H', radius: 46),
      if (s.izin > 0) PieChartSectionData(value: s.izin.toDouble(), color: const Color(0xFF2F6FB0), title: 'I', radius: 46),
      if (s.sakit > 0) PieChartSectionData(value: s.sakit.toDouble(), color: const Color(0xFFB07C2F), title: 'S', radius: 46),
      if (s.alpa > 0) PieChartSectionData(value: s.alpa.toDouble(), color: const Color(0xFFB0402F), title: 'A', radius: 46),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 130,
              height: 130,
              child: Stack(alignment: Alignment.center, children: [
                PieChart(PieChartData(sections: sections, centerSpaceRadius: 34, sectionsSpace: 2)),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${s.percentage.toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Text('hadir', style: TextStyle(fontSize: 12)),
                ]),
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${s.totalSessions} sesi tercatat'),
                  const SizedBox(height: 4),
                  Text('Hadir ${s.hadir} · Izin ${s.izin} · Sakit ${s.sakit} · Alpa ${s.alpa}',
                      style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.period, required this.onChanged});
  final String period;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: const [
        ButtonSegment(value: 'weekly', label: Text('Mingguan')),
        ButtonSegment(value: 'monthly', label: Text('Bulanan')),
      ],
      selected: {period},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _ActivenessCard extends StatelessWidget {
  const _ActivenessCard({
    required this.average,
    required this.points,
    required this.period,
  });
  final double? average;
  final List<ActivenessPoint> points;
  final String period;

  static (String, Color) _band(double v) {
    if (v >= 4.5) return ('Sangat aktif', const Color(0xFF1E6F5C));
    if (v >= 3.5) return ('Aktif', const Color(0xFF2E8B57));
    if (v >= 2.5) return ('Cukup', const Color(0xFFB07C2F));
    if (v >= 1.5) return ('Kurang aktif', const Color(0xFFB0642F));
    return ('Perlu perhatian', const Color(0xFFB0402F));
  }

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].avgScore),
    ];
    final unit = period == 'monthly' ? 'per bulan' : 'per minggu';
    // Interval label sumbu-X: jarangkan bila titik banyak agar tidak tumpang tindih.
    final labelEvery = (points.length / 4).ceil().clamp(1, points.isEmpty ? 1 : points.length);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Keaktifan', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            if (average != null) ...[
              Builder(builder: (_) {
                final (label, color) = _band(average!);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(average!.toStringAsFixed(1),
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: color)),
                    const Text(' / 5', style: TextStyle(fontSize: 14, color: Colors.black54)),
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
              const Text('Rata-rata skor keaktifan yang diberi pembina (skala 1–5) tiap sesi anak hadir.',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
            ] else
              const Text('Belum ada nilai keaktifan.',
                  style: TextStyle(fontSize: 13, color: Colors.black54)),
            if (points.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Tren $unit',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 8),
            ],
            if (points.isNotEmpty)
            SizedBox(
              height: 150,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 5,
                  minX: 0,
                  maxX: (points.length - 1).toDouble().clamp(0, double.infinity),
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
                        reservedSize: 28,
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
                      spots: spots,
                      isCurved: points.length > 2,
                      barWidth: 3,
                      color: const Color(0xFF1E6F5C),
                      dotData: const FlDotData(show: true),
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
}

class _MaterialsCard extends StatelessWidget {
  const _MaterialsCard({required this.materials});
  final List<MaterialEntry> materials;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Timeline materi latihan', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final m in materials) ...[
              const Divider(height: 16),
              Text(m.date, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              Text(m.description),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChildHeader extends StatelessWidget {
  const _ChildHeader({required this.child});
  final Child child;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = child.photoUrl != null && child.photoUrl!.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFFE4EFEA),
              backgroundImage: hasPhoto ? NetworkImage(child.photoUrl!) : null,
              child: hasPhoto
                  ? null
                  : Text(
                      child.fullName.characters.first.toUpperCase(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Color(0xFF155440)),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(child.fullName,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Kelas ${child.classGrade}   ·   NIS ${child.nis}',
                      style: const TextStyle(color: Colors.black54, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvaluationsCard extends StatelessWidget {
  const _EvaluationsCard({required this.items});
  final List<EvalEntry> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Penilaian pembina per sesi',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            const Text('Skor keaktifan 1–5 dan catatan perkembangan anak.',
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
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF155440))),
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
                  child: Text('Catatan pembina: ${e.personalNotes}',
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
      ),
    );
  }
}

class _NoChildLinked extends StatelessWidget {
  const _NoChildLinked();

  @override
  Widget build(BuildContext context) {
    return _Centered(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.family_restroom, size: 56),
        const SizedBox(height: 12),
        const Text('Belum ada anak terhubung ke akun ini.', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => context.push('/parent/link-child'),
          child: const Text('Hubungkan ke Anak'),
        ),
      ]),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      Center(child: Padding(padding: const EdgeInsets.all(24), child: child));
}
