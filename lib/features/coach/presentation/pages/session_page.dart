import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/coach_entities.dart';
import '../providers/coach_providers.dart';

/// Layar Sesi Ekskul — Tab "Presensi Cepat" + Tab "Materi Latihan" (bagian 5.1).
class SessionPage extends ConsumerStatefulWidget {
  const SessionPage({super.key, required this.extracurricularId, required this.session});

  final String extracurricularId;
  final TodaySession? session;

  @override
  ConsumerState<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends ConsumerState<SessionPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _descCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  bool _submitting = false;

  /// index siswa (dari path `attendances[i]`) → pesan error validasi.
  Map<int, String> _rowErrors = {};

  String get _ekskulId => widget.extracurricularId;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(attendanceDraftsProvider.notifier).draftFor(_ekskulId);
    _descCtrl.text = draft.materialDescription;
    _targetCtrl.text = draft.targetAchievement;
  }

  @override
  void dispose() {
    _tabs.dispose();
    _descCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rosterAsync = ref.watch(rosterProvider(_ekskulId));
    final title = widget.session?.extracurricularName ?? 'Sesi Ekskul';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Presensi Cepat'), Tab(text: 'Materi Latihan')],
        ),
      ),
      body: rosterAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat roster.\n$e', textAlign: TextAlign.center)),
        data: (roster) {
          // Seed default "Hadir" sekali.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref
                .read(attendanceDraftsProvider.notifier)
                .seedRoster(_ekskulId, roster.students.map((s) => s.id).toList());
          });
          return TabBarView(
            controller: _tabs,
            children: [
              _PresenceTab(
                ekskulId: _ekskulId,
                students: roster.students,
                rowErrors: _rowErrors,
              ),
              _MaterialTab(
                ekskulId: _ekskulId,
                descCtrl: _descCtrl,
                targetCtrl: _targetCtrl,
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: FilledButton(
          onPressed: _submitting || rosterAsync.value == null
              ? null
              : () => _submit(rosterAsync.value!),
          child: Text(_submitting ? 'Mengirim…' : 'Submit Presensi & Materi'),
        ),
      ),
    );
  }

  Future<void> _submit(Roster roster) async {
    setState(() {
      _submitting = true;
      _rowErrors = {};
    });
    final notifier = ref.read(attendanceDraftsProvider.notifier);
    final draft = notifier.draftFor(_ekskulId);
    final s = widget.session;

    final payload = <String, dynamic>{
      'client_generated_id': draft.clientGeneratedId,
      'extracurricular_id': _ekskulId,
      if (s != null) 'schedule_id': s.scheduleId,
      'session_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      if (s != null) 'start_time': s.startTime,
      if (s != null) 'end_time': s.endTime,
      if (s?.location != null) 'location': s!.location,
      'material': {
        'description': _descCtrl.text.trim(),
        'duration_minutes': draft.durationMinutes,
        if (_targetCtrl.text.trim().isNotEmpty) 'target_achievement': _targetCtrl.text.trim(),
      },
      'attendances': roster.students
          .map((st) => {
                'student_id': st.id,
                'status': (draft.statuses[st.id] ?? AttendanceStatus.hadir).code,
              })
          .toList(),
    };

    try {
      notifier.setMaterial(_ekskulId,
          description: _descCtrl.text.trim(), targetAchievement: _targetCtrl.text.trim());
      final result = await ref.read(coachRepositoryProvider).submitAttendance(payload);
      notifier.clear(_ekskulId);
      ref.invalidate(todaySessionsProvider);
      if (!mounted) return;
      final sm = result.summary;
      _toast('Berhasil disinkronkan — ${sm.hadir} hadir, ${sm.izin} izin, '
          '${sm.sakit} sakit, ${sm.alpa} alpa.');
      context.pop();
    } on SubmitValidationException catch (e) {
      final rowErrors = <int, String>{};
      for (final d in e.details) {
        final m = RegExp(r'attendances\[(\d+)\]').firstMatch(d.field);
        if (m != null) {
          rowErrors[int.parse(m.group(1)!)] = d.message;
        }
      }
      setState(() => _rowErrors = rowErrors);
      _toast(rowErrors.isEmpty ? e.toString() : 'Ada ${e.details.length} data tidak valid.');
      if (rowErrors.isNotEmpty) _tabs.animateTo(0);
    } on SessionAlreadySyncedException {
      notifier.clear(_ekskulId);
      ref.invalidate(todaySessionsProvider);
      if (!mounted) return;
      _toast('Sesi ini sudah pernah disubmit sebelumnya.');
      context.pop();
    } catch (e) {
      _toast('Gagal submit: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

/* -------- Tab Presensi -------- */
class _PresenceTab extends ConsumerWidget {
  const _PresenceTab({required this.ekskulId, required this.students, required this.rowErrors});

  final String ekskulId;
  final List<RosterStudent> students;
  final Map<int, String> rowErrors;

  static const _colors = {
    AttendanceStatus.hadir: Color(0xFF1E6F5C),
    AttendanceStatus.izin: Color(0xFF2F6FB0),
    AttendanceStatus.sakit: Color(0xFFB07C2F),
    AttendanceStatus.alpa: Color(0xFFB0402F),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(attendanceDraftsProvider)[ekskulId];
    final notifier = ref.read(attendanceDraftsProvider.notifier);

    return ListView.separated(
      itemCount: students.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final st = students[i];
        final status = draft?.statuses[st.id] ?? AttendanceStatus.hadir;
        final err = rowErrors[i];
        return ListTile(
          onTap: () => notifier.cycle(ekskulId, st.id),
          onLongPress: () => _pickStatus(context, notifier, st.id),
          leading: CircleAvatar(child: Text(st.fullName.characters.first)),
          title: Text(st.fullName),
          subtitle: Text(
            err ?? '${st.classGrade} · ${st.nis}',
            style: err != null ? const TextStyle(color: Colors.red) : null,
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _colors[status],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(status.label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        );
      },
    );
  }

  void _pickStatus(BuildContext context, AttendanceDraftsNotifier notifier, String studentId) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: AttendanceStatus.values
              .map((s) => ListTile(
                    title: Text(s.label),
                    onTap: () {
                      notifier.setStatus(ekskulId, studentId, s);
                      Navigator.pop(context);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }
}

/* -------- Tab Materi -------- */
class _MaterialTab extends ConsumerWidget {
  const _MaterialTab({
    required this.ekskulId,
    required this.descCtrl,
    required this.targetCtrl,
  });

  final String ekskulId;
  final TextEditingController descCtrl;
  final TextEditingController targetCtrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(attendanceDraftsProvider)[ekskulId];
    final notifier = ref.read(attendanceDraftsProvider.notifier);
    final duration = draft?.durationMinutes ?? 90;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: descCtrl,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Deskripsi latihan',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text('Durasi (menit)', style: TextStyle(fontSize: 16)),
            const Spacer(),
            IconButton.filledTonal(
              onPressed: duration > 5
                  ? () => notifier.setMaterial(ekskulId, durationMinutes: duration - 5)
                  : null,
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 48,
              child: Text('$duration', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
            ),
            IconButton.filledTonal(
              onPressed: () => notifier.setMaterial(ekskulId, durationMinutes: duration + 5),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: targetCtrl,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Target capaian',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
