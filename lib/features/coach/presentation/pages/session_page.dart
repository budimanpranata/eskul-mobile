import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/connectivity.dart';
import '../../data/local/local_session_store.dart';
import '../../data/submit_outcome.dart';
import '../../domain/entities/coach_entities.dart';
import '../providers/coach_providers.dart';
import 'qr_scan_page.dart';

/// Layar Sesi Ekskul — Tab "Presensi Cepat" + Tab "Materi Latihan" (bagian 5.1).
/// Offline-first: draft otomatis tersimpan ke local DB; submit saat offline
/// menandai PENDING_SYNC dan disinkronkan otomatis saat online (bagian 6).
class SessionPage extends ConsumerStatefulWidget {
  const SessionPage({super.key, required this.extracurricularId, required this.session});

  final String extracurricularId;
  final TodaySession? session;

  @override
  ConsumerState<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends ConsumerState<SessionPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _descCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  bool _submitting = false;
  bool _restored = false;
  Map<int, String> _rowErrors = {};

  final _sessionDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String get _ekskulId => widget.extracurricularId;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(attendanceDraftsProvider.notifier).draftFor(_ekskulId);
    _descCtrl.text = draft.materialDescription;
    _targetCtrl.text = draft.targetAchievement;

    // Tulis-lewat: setiap perubahan draft → simpan payload ke local DB.
    ref.listenManual(attendanceDraftsProvider, (_, __) => _persistDraft());
  }

  @override
  void dispose() {
    _tabs.dispose();
    _descCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _restoreLocalDraft(Roster roster) async {
    if (_restored) return;
    _restored = true;
    final store = ref.read(localSessionStoreProvider);
    final existing = await store.findByEkskulDate(_ekskulId, _sessionDate);
    final notifier = ref.read(attendanceDraftsProvider.notifier);

    if (existing != null && existing.status != SyncStatus.synced) {
      notifier.adoptExistingId(_ekskulId, existing.clientGeneratedId);
      final atts = (existing.payload['attendances'] as List?) ?? const [];
      for (final a in atts) {
        final m = a as Map;
        final sid = m['student_id'] as String;
        final st = AttendanceStatus.values.firstWhere(
          (s) => s.code == m['status'],
          orElse: () => AttendanceStatus.hadir,
        );
        notifier.setStatus(_ekskulId, sid, st);
        if (m['activeness_score'] != null || m['skill_notes'] != null || m['personal_notes'] != null) {
          notifier.setEval(
            _ekskulId,
            sid,
            activenessScore: m['activeness_score'] as int?,
            skillNotes: (m['skill_notes'] as String?) ?? '',
            personalNotes: (m['personal_notes'] as String?) ?? '',
          );
        }
      }
      final mat = existing.payload['material'] as Map?;
      if (mat != null) {
        _descCtrl.text = (mat['description'] as String?) ?? '';
        _targetCtrl.text = (mat['target_achievement'] as String?) ?? '';
        notifier.setMaterial(_ekskulId,
            description: _descCtrl.text,
            durationMinutes: (mat['duration_minutes'] as int?) ?? 90,
            targetAchievement: _targetCtrl.text);
      }
    }
    notifier.seedRoster(_ekskulId, roster.students.map((s) => s.id).toList());
    _persistDraft(roster: roster);
    if (mounted) setState(() {});
  }

  Map<String, dynamic> _buildPayload(Roster roster, AttendanceDraft draft) {
    final s = widget.session;
    return {
      'client_generated_id': draft.clientGeneratedId,
      'extracurricular_id': _ekskulId,
      if (s != null) 'schedule_id': s.scheduleId,
      'session_date': _sessionDate,
      if (s != null) 'start_time': s.startTime,
      if (s != null) 'end_time': s.endTime,
      if (s?.location != null) 'location': s!.location,
      'material': {
        'description': _descCtrl.text.trim(),
        'duration_minutes': draft.durationMinutes,
        if (_targetCtrl.text.trim().isNotEmpty) 'target_achievement': _targetCtrl.text.trim(),
      },
      'attendances': roster.students.map((st) {
        final status = draft.statuses[st.id] ?? AttendanceStatus.hadir;
        final ev = draft.evals[st.id];
        return {
          'student_id': st.id,
          'status': status.code,
          // activeness_score hanya dikirim bila HADIR (backend menolak selain itu).
          if (status == AttendanceStatus.hadir && ev?.activenessScore != null)
            'activeness_score': ev!.activenessScore,
          if (ev != null && ev.skillNotes.trim().isNotEmpty) 'skill_notes': ev.skillNotes.trim(),
          if (ev != null && ev.personalNotes.trim().isNotEmpty)
            'personal_notes': ev.personalNotes.trim(),
        };
      }).toList(),
    };
  }

  void _persistDraft({Roster? roster}) {
    final r = roster ?? ref.read(rosterProvider(_ekskulId)).value;
    if (r == null) return;
    final draft = ref.read(attendanceDraftsProvider.notifier).draftFor(_ekskulId);
    ref.read(coachRepositoryProvider).saveDraft(
          clientGeneratedId: draft.clientGeneratedId,
          extracurricularId: _ekskulId,
          extracurricularName: widget.session?.extracurricularName,
          sessionDate: _sessionDate,
          payload: _buildPayload(r, draft),
        );
  }

  @override
  Widget build(BuildContext context) {
    final rosterAsync = ref.watch(rosterProvider(_ekskulId));
    final online = ref.watch(connectivityProvider).value ?? true;
    final title = widget.session?.extracurricularName ?? 'Sesi Ekskul';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Presensi Cepat'), Tab(text: 'Materi Latihan')],
        ),
      ),
      floatingActionButton: rosterAsync.value == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => QrScanPage(extracurricularId: _ekskulId),
                  ),
                );
                _persistDraft();
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR'),
            ),
      body: Column(
        children: [
          if (!online)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF3CD),
              padding: const EdgeInsets.all(10),
              child: const Text(
                'Mode offline — presensi tersimpan di perangkat dan akan disinkronkan otomatis saat online.',
                style: TextStyle(color: Color(0xFF7A5B00)),
              ),
            ),
          Expanded(
            child: rosterAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Gagal memuat roster.\n$e', textAlign: TextAlign.center)),
              data: (roster) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _restoreLocalDraft(roster));
                return TabBarView(
                  controller: _tabs,
                  children: [
                    _PresenceTab(ekskulId: _ekskulId, students: roster.students, rowErrors: _rowErrors),
                    _MaterialTab(ekskulId: _ekskulId, descCtrl: _descCtrl, targetCtrl: _targetCtrl),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: FilledButton(
          onPressed: _submitting || rosterAsync.value == null
              ? null
              : () => _submit(rosterAsync.value!),
          child: Text(_submitting
              ? 'Menyimpan…'
              : online
                  ? 'Submit Presensi & Materi'
                  : 'Simpan (akan disinkron saat online)'),
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
    final repo = ref.read(coachRepositoryProvider);
    final draft = notifier.draftFor(_ekskulId);
    notifier.setMaterial(_ekskulId,
        description: _descCtrl.text.trim(), targetAchievement: _targetCtrl.text.trim());

    // Pastikan payload terbaru tersimpan lokal sebelum submit.
    await repo.saveDraft(
      clientGeneratedId: draft.clientGeneratedId,
      extracurricularId: _ekskulId,
      extracurricularName: widget.session?.extracurricularName,
      sessionDate: _sessionDate,
      payload: _buildPayload(roster, draft),
    );

    try {
      final outcome = await repo.submit(draft.clientGeneratedId);
      ref.invalidate(pendingSessionsProvider);
      ref.invalidate(todaySessionsProvider);
      if (!mounted) return;
      switch (outcome) {
        case SubmitSynced(:final result):
          notifier.clear(_ekskulId);
          final sm = result.summary;
          _toast('Berhasil disinkronkan — ${sm.hadir} hadir, ${sm.izin} izin, '
              '${sm.sakit} sakit, ${sm.alpa} alpa.');
          context.pop();
        case SubmitAlreadySynced():
          notifier.clear(_ekskulId);
          _toast('Sesi ini sudah pernah disinkronkan.');
          context.pop();
        case SubmitQueuedOffline():
          notifier.clear(_ekskulId);
          _toast('Tersimpan. Akan disinkronkan otomatis saat online.');
          context.pop();
      }
    } on SubmitValidationException catch (e) {
      final rowErrors = <int, String>{};
      for (final d in e.details) {
        final m = RegExp(r'attendances\[(\d+)\]').firstMatch(d.field);
        if (m != null) rowErrors[int.parse(m.group(1)!)] = d.message;
      }
      setState(() => _rowErrors = rowErrors);
      _toast(rowErrors.isEmpty ? e.toString() : 'Ada ${e.details.length} data tidak valid.');
      if (rowErrors.isNotEmpty) _tabs.animateTo(0);
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

  void _openEval(
    BuildContext context,
    RosterStudent st,
    AttendanceStatus status,
    StudentEval? ev,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EvalSheet(
        ekskulId: ekskulId,
        student: st,
        status: status,
        eval: ev ?? const StudentEval(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(attendanceDraftsProvider)[ekskulId];
    final notifier = ref.read(attendanceDraftsProvider.notifier);

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: const Color(0xFFEEF3F1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const Text(
            'Ketuk baris untuk ubah status kehadiran. Ketuk tombol "Nilai" '
            'untuk memberi nilai keaktifan (1–5) & catatan tiap siswa.',
            style: TextStyle(fontSize: 12, color: Color(0xFF3E5C54)),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: students.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final st = students[i];
              final status = draft?.statuses[st.id] ?? AttendanceStatus.hadir;
              final ev = draft?.evals[st.id];
              final err = rowErrors[i];
              return ListTile(
                onTap: () => notifier.cycle(ekskulId, st.id),
                onLongPress: () => _openEval(context, st, status, ev),
                leading: CircleAvatar(child: Text(st.fullName.characters.first)),
                title: Text(st.fullName),
                subtitle: Text(err ?? '${st.classGrade} · ${st.nis}',
                    style: err != null ? const TextStyle(color: Colors.red) : null),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                          color: _colors[status], borderRadius: BorderRadius.circular(20)),
                      child: Text(status.label,
                          style:
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 4),
                    // Tombol eksplisit untuk beri nilai & catatan per siswa.
                    TextButton.icon(
                      onPressed: () => _openEval(context, st, status, ev),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 36),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: Icon(
                        ev?.activenessScore != null
                            ? Icons.star
                            : (ev != null && !ev.isEmpty)
                                ? Icons.sticky_note_2
                                : Icons.star_border,
                        size: 18,
                        color: ev != null && !ev.isEmpty
                            ? Colors.amber.shade800
                            : Colors.grey.shade600,
                      ),
                      label: Text(
                        ev?.activenessScore != null ? '${ev!.activenessScore}' : 'Nilai',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: ev != null && !ev.isEmpty
                              ? Colors.amber.shade900
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/* -------- Bottom sheet evaluasi per siswa (Fase 2.3) -------- */
class _EvalSheet extends ConsumerStatefulWidget {
  const _EvalSheet({
    required this.ekskulId,
    required this.student,
    required this.status,
    required this.eval,
  });

  final String ekskulId;
  final RosterStudent student;
  final AttendanceStatus status;
  final StudentEval eval;

  @override
  ConsumerState<_EvalSheet> createState() => _EvalSheetState();
}

class _EvalSheetState extends ConsumerState<_EvalSheet> {
  late AttendanceStatus _status = widget.status;
  late int? _score = widget.eval.activenessScore;
  late final _skill = TextEditingController(text: widget.eval.skillNotes);
  late final _personal = TextEditingController(text: widget.eval.personalNotes);

  @override
  void dispose() {
    _skill.dispose();
    _personal.dispose();
    super.dispose();
  }

  void _save() {
    final n = ref.read(attendanceDraftsProvider.notifier);
    n.setStatus(widget.ekskulId, widget.student.id, _status);
    n.setEval(
      widget.ekskulId,
      widget.student.id,
      activenessScore: _status == AttendanceStatus.hadir ? _score : null,
      skillNotes: _skill.text,
      personalNotes: _personal.text,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hadir = _status == AttendanceStatus.hadir;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.student.fullName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text('${widget.student.classGrade} · ${widget.student.nis}',
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            const Text('Status'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: AttendanceStatus.values
                  .map((s) => ChoiceChip(
                        label: Text(s.label),
                        selected: _status == s,
                        onSelected: (_) => setState(() => _status = s),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Nilai keaktifan (1–5)'),
                const Spacer(),
                if (_score != null)
                  TextButton(
                    onPressed: () => setState(() => _score = null),
                    child: const Text('Hapus'),
                  ),
              ],
            ),
            if (!hadir)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text('Hanya untuk siswa HADIR.',
                    style: TextStyle(color: Colors.black45, fontSize: 12)),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (i) {
                final v = i + 1;
                final on = _score == v;
                return GestureDetector(
                  onTap: hadir ? () => setState(() => _score = v) : null,
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: !hadir
                        ? Colors.grey.shade200
                        : on
                            ? const Color(0xFF1E6F5C)
                            : Colors.grey.shade300,
                    child: Text('$v',
                        style: TextStyle(
                          color: on ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        )),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _skill,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Catatan keterampilan / pencapaian',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _personal,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Catatan khusus (personal)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(onPressed: _save, child: const Text('Simpan')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/* -------- Tab Materi -------- */
class _MaterialTab extends ConsumerWidget {
  const _MaterialTab({required this.ekskulId, required this.descCtrl, required this.targetCtrl});

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
          onChanged: (v) => notifier.setMaterial(ekskulId, description: v),
          decoration: const InputDecoration(
              labelText: 'Deskripsi latihan', border: OutlineInputBorder()),
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
              child: Text('$duration',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
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
          onChanged: (v) => notifier.setMaterial(ekskulId, targetAchievement: v),
          decoration: const InputDecoration(
              labelText: 'Target capaian', border: OutlineInputBorder()),
        ),
      ],
    );
  }
}
