# eskul_mobile

Aplikasi mobile **Guru Pembina & Orang Tua** untuk Ekosistem Presensi & Perkembangan
Ekstrakurikuler SD. Satu codebase Flutter, dua mode yang dipilih berdasarkan role
user setelah login.

Stack: **Flutter 3.29 · Riverpod · go_router · Dio · sqflite · flutter_secure_storage ·
connectivity_plus · fl_chart**.

Referensi arsitektur: `../system-design-ekosistem-ekskul-sd.md`
(bagian 5.1 alur Pembina, 5.2 alur Orang Tua, 6 strategi offline-first).

> **Status: Fase 3.2 (bagian mobile).** Mode Pembina: presensi **offline-first** (2.1)
> + **Scan QR** (2.2) + **nilai keaktifan & catatan personal per siswa** (2.3).
> Mode Orang Tua: Dashboard + tab Notifikasi (1.4/1.5) + **tren keaktifan dengan
> toggle Mingguan/Bulanan** (3.2: agregasi backend per minggu/bulan, `fl_chart`,
> aman untuk data minim 1 titik) + **tab Tagihan** (beyond-plan: lihat tagihan
> ekskul anak, ajukan bayar transfer — unggah bukti via `image_picker` — atau
> tunai, pantau status Belum Bayar/Menunggu Verifikasi/Lunas/Dibatalkan).
> "Hubungkan ke Anak" kini juga minta **Kode Sekolah** (NIS unik per sekolah
> sejak multi-tenant, bukan global lagi).
>
> **Catatan chart:** `fl_chart` dipin ke **^0.69.0** — versi 1.x memanggil
> `Matrix4.translateByDouble`/`scaleByDouble` yang belum ada di `vector_math`
> bawaan Flutter 3.29 (gagal `flutter test`). Naikkan saat upgrade Flutter.
>
> **Catatan local DB:** dipakai **sqflite** (v2 schema: `pending_sessions` +
> `cached_rosters`). `openAppDatabase({factory, path})` di-inject untuk test
> (`sqflite_common_ffi` in-memory). drift belum dipakai karena `drift_dev`
> (codegen) butuh Dart ≥ 3.10 sedangkan
> Flutter yang terpasang di sini Dart 3.7.2. Evaluasi ulang ke drift bisa dilakukan
> di Fase 2.1 (kemungkinan setelah upgrade Flutter).

## Struktur folder (clean architecture)

```
lib/
├── main.dart                     # runApp(ProviderScope(EskulApp()))
├── app.dart                      # MaterialApp.router
├── core/
│   ├── config/app_config.dart    # base URL API via --dart-define
│   ├── network/dio_client.dart   # ✅ Dio + interceptor: Bearer + auto-refresh saat 401
│   ├── storage/
│   │   ├── secure_storage.dart   # token access/refresh + metadata sesi (id/nama/role)
│   │   └── local_database.dart   # sqflite: pending_sessions, cached_rosters (Fase 2.1)
│   ├── router/app_router.dart    # go_router + redirect berbasis role
│   ├── theme/app_theme.dart
│   └── constants/user_role.dart  # PEMBINA | ORANGTUA
├── features/
│   ├── auth/                     # ✅ login + register Orang Tua (POST /auth/login|register)
│   ├── coach/                    # ✅ MODE PEMBINA — presensi offline-first (1.3 + 2.1)
│   │   ├── data/local/          #  LocalSessionStore (pending_sessions), RosterCache (14 hari)
│   │   ├── data/submit_outcome.dart  #  interpretasi 201/409/422/5xx
│   │   ├── data/repositories/   #  CoachRepositoryImpl offline-aware (saveDraft/submit)
│   │   ├── sync/sync_engine.dart  #  auto-sync saat online + timer, backoff 1s/2s/4s ×3
│   │   └── presentation/pages/  #  coach_home (banner offline + badge pending),
│   │                            #  session_page (autosave + restore), session_history_page (badge)
│   ├── parent/                   # ✅ MODE ORANG TUA (Fase 1.4)
│   │   └── presentation/pages/   #  parent_shell (bottom nav: Dashboard + Notifikasi),
│   │                            #  parent_home_page (donut/line/timeline), link_child_page
│   └── notifications/            # ✅ inbox + unread badge (Fase 1.5)
│       ├── notifications.dart    #  repo + providers (unreadCount, list) + NotificationItem
│       └── notifications_page.dart
├── core/push/device_registration.dart  # ✅ daftar device token ke /notifications/devices saat login
└── shared/
```

### Alur Presensi Pembina (Fase 1.3)

1. **Home** — `GET /coach/today-sessions`: kartu jadwal ekskul hari ini; badge
   "Sudah disubmit" bila sesi hari itu sudah ada.
2. **Sesi** — `GET /coach/extracurriculars/:id/roster`; Tab *Presensi Cepat*:
   semua default **Hadir**, tap nama = siklus Hadir→Izin→Sakit→Alpa, long-press =
   pilih langsung. Tab *Materi*: deskripsi + durasi (stepper ±5) + target.
3. **Submit** — `POST /attendance/submit`. `client_generated_id` (UUID v4) dibuat
   **saat draft pertama dibuka** dan dipakai ulang selama sesi belum terkirim
   (`attendanceDraftsProvider`, hidup sepanjang app); di-*clear* setelah sukses.
4. Sukses → snackbar ringkasan (X hadir, Y izin, …). **422** → error ditandai per
   baris siswa + pindah ke tab Presensi. **409** → "sudah pernah disubmit".

> Persistensi `client_generated_id` lintas *restart* aplikasi butuh local DB → Fase 2.1.

Tiap fitur mengikuti pembagian `data / domain / presentation`. Fitur `auth`
sudah berisi kerangka ketiga layer sebagai contoh pola; fitur lain diisi
bertahap pada fasenya.

### Routing dua-mode

`core/router/app_router.dart` — setelah `authSessionProvider` terisi, `redirect`
mengarahkan:

| Role | Root route |
|---|---|
| `PEMBINA` | `/coach` |
| `ORANGTUA` | `/parent` |
| belum login | `/login` |

`LoginPage` memanggil `POST /auth/login` sungguhan (identifier + password).
Sesi (token + id/nama/role) disimpan di `flutter_secure_storage` dan dipulihkan
saat aplikasi dibuka (`sessionRestoreProvider`). Backend menegakkan RBAC per role.

## Menjalankan secara lokal

### Prasyarat
- Flutter SDK 3.29.x (Dart 3.7.x) — cek dengan `flutter doctor`
- Emulator Android / perangkat fisik / simulator iOS

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3100/api/v1
```

- `10.0.2.2` = alamat `localhost` mesin host dilihat dari emulator Android.
- Backend dev berjalan di port **3100** (lihat `backend/.env.example`).
- Untuk perangkat fisik, ganti dengan IP LAN mesin yang menjalankan `eskul-backend`.
- Tanpa `--dart-define`, dipakai default di `app_config.dart`.

### Perintah lain

| Perintah | Fungsi |
|---|---|
| `flutter analyze` | Static analysis (harus "No issues found") |
| `flutter test` | Jalankan widget/unit test |
| `flutter build apk --debug` | Build APK debug |

## Definition of Done

### Fase 0.1
- [x] `flutter analyze` bersih, `flutter test` hijau
- [x] Struktur clean architecture (data/domain/presentation) terbentuk
- [x] Routing 2 mode (Pembina/Orang Tua) berdasarkan role
- [x] Local database (sqflite) di-setup sebagai kerangka offline

### Fase 1.3
- [x] `client_generated_id` konsisten dipakai ulang saat sesi draft dibuka ulang;
      id baru hanya setelah `clear` (submit sukses) — **unit test**
- [x] Error validasi backend ditandai **per baris siswa** (parse `attendances[i]`),
      bukan pesan generik; auto-pindah ke tab Presensi — **implemented**
- [x] UI presensi cepat: default Hadir, 1-tap cycle, long-press pilih; tombol besar

### Fase 1.4
- [x] "Hubungkan ke Anak" → `POST /parent/link-request` → "Menunggu persetujuan admin"
- [x] Selector anak: ganti anak hanya update provider — **tanpa reload aplikasi**
- [x] Donut/line/timeline dari `GET /parent/child-progress/{id}` (fl_chart)
- [x] 403 → state informatif; ekskul tanpa sesi → pesan jelas — **unit test**

### Fase 1.5
- [x] Registrasi device token saat login/register/restore (`POST /notifications/devices`);
      token stub disimpan di secure storage (seam untuk `firebase_messaging`)
- [x] Tab Notifikasi (`parent_shell` bottom nav) dengan **badge unread**; tap notifikasi
      → `POST /notifications/read`; tombol "Tandai semua dibaca"

### Fase 2.1
- [x] Presensi diinput & disimpan penuh tanpa koneksi (draft autosave ke SQLite) — **unit test**
- [x] Data tidak hilang saat app di-kill saat PENDING_SYNC: row persisten di SQLite,
      dibuka ulang → `client_generated_id` yang sama diadopsi — **unit test**
- [x] Sync ulang tak menghasilkan duplikat di server: retry pakai `client_generated_id`
      yang sama, 409 → SYNCED tanpa error — **unit test** (backend UNIQUE terverifikasi di Fase 1.3)
- [x] Cache roster lokal terhapus otomatis setelah 14 hari (`RosterCache.get`/`purgeExpired`) — **unit test**
- [x] Badge status Draft/Pending Sync/Synced di layar Riwayat Sesi

### Fase 2.2
- [x] Tombol floating "Scan QR" di layar Presensi → kamera (`mobile_scanner`)
- [x] Scan valid → `POST /coach/students/qr-scan` → set **HADIR** di draft +
      HapticFeedback + SystemSound + overlay hijau (dominasi latensi = jaringan) — **unit test resolveQr**
- [x] `qr_token` tidak valid / bukan anggota → overlay merah + haptic, **bukan silent fail** — **unit test**
- [x] Izin kamera: AndroidManifest `CAMERA`, iOS `NSCameraUsageDescription`

### Fase 2.3
- [x] Long-press nama siswa → bottom sheet: status + skor keaktifan 1–5 + `skill_notes` + `personal_notes`
- [x] Input keaktifan **opsional** (tidak wajib per siswa) — tap tetap cycle status, alur utama tak melambat
- [x] Skor dinonaktifkan bila status ≠ HADIR; payload hanya kirim `activeness_score` saat HADIR (cegah 422)
- [x] Rata-rata keaktifan sesi di layar Riwayat Sesi (dihitung dari payload lokal)
- [x] `flutter analyze` bersih (0 issue), `flutter test` hijau (25 test)
- [ ] `flutter run` di emulator terhadap backend nyata (butuh emulator aktif)

### Fase 3.2 (bagian mobile — Orang Tua)
- [x] Dashboard: `SegmentedButton` **Mingguan / Bulanan** → mengganti param `period`
      pada `childProgressProvider((studentId, period))` sehingga refetch
- [x] `_ActivenessCard` menggambar `activeness_trend` hasil agregasi backend
      (`{ bucket, label, avg_score, sessions }`), sumbu-X pakai `label`, kurva
      dimatikan bila < 3 titik agar tetap terbaca
- [x] Edge case data minim: 1 titik pun tidak error (fl_chart tetap menggambar dot)
- [x] `flutter analyze` bersih, `flutter test` hijau (25 test)
