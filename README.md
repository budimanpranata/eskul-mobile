# eskul_mobile

Aplikasi mobile **Guru Pembina & Orang Tua** untuk Ekosistem Presensi & Perkembangan
Ekstrakurikuler SD. Satu codebase Flutter, dua mode yang dipilih berdasarkan role
user setelah login.

Stack: **Flutter 3.29 · Riverpod · go_router · Dio · sqflite · flutter_secure_storage ·
connectivity_plus · fl_chart**.

Referensi arsitektur: `../system-design-ekosistem-ekskul-sd.md`
(bagian 5.1 alur Pembina, 5.2 alur Orang Tua, 6 strategi offline-first).

> **Status: Fase 0 (scaffolding).** Struktur clean architecture, routing dua-mode,
> dan kerangka local DB sudah terpasang. Semua halaman placeholder.
>
> **Catatan local DB:** dokumen desain menyebut `sqflite`/`drift`. Untuk sekarang
> dipakai **sqflite** karena `drift_dev` (codegen) butuh Dart ≥ 3.10 sedangkan
> Flutter yang terpasang di sini Dart 3.7.2. Evaluasi ulang ke drift bisa dilakukan
> di Fase 2.1 (kemungkinan setelah upgrade Flutter).

## Struktur folder (clean architecture)

```
lib/
├── main.dart                     # runApp(ProviderScope(EskulApp()))
├── app.dart                      # MaterialApp.router
├── core/
│   ├── config/app_config.dart    # base URL API via --dart-define
│   ├── network/dio_client.dart   # factory Dio (interceptor auth -> Fase 1)
│   ├── storage/
│   │   ├── secure_storage.dart   # token access/refresh
│   │   └── local_database.dart   # sqflite: pending_sessions, cached_rosters (Fase 2.1)
│   ├── router/app_router.dart    # go_router + redirect berbasis role
│   ├── theme/app_theme.dart
│   └── constants/user_role.dart  # PEMBINA | ORANGTUA
├── features/
│   ├── auth/
│   │   ├── data/                 # datasources + repositories (impl)
│   │   ├── domain/               # entities + repository interface
│   │   └── presentation/         # pages + providers (Riverpod)
│   ├── coach/                    # MODE PEMBINA
│   │   └── presentation/pages/   # coach_home_page, session_page (2 tab)
│   └── parent/                   # MODE ORANG TUA
│       └── presentation/pages/   # parent_home_page, link_child_page
└── shared/                       # widgets & model lintas-fitur
```

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

Di Fase 0, `LoginPage` menyediakan dua tombol simulasi role agar navigasi bisa
ditinjau tanpa backend. Simulasi ini dicabut di Fase 1.1 (diganti panggilan
`POST /auth/login`).

## Menjalankan secara lokal

### Prasyarat
- Flutter SDK 3.29.x (Dart 3.7.x) — cek dengan `flutter doctor`
- Emulator Android / perangkat fisik / simulator iOS

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

- `10.0.2.2` = alamat `localhost` mesin host dilihat dari emulator Android.
- Untuk perangkat fisik, ganti dengan IP LAN mesin yang menjalankan `eskul-backend`.
- Tanpa `--dart-define`, dipakai default di `app_config.dart`.

### Perintah lain

| Perintah | Fungsi |
|---|---|
| `flutter analyze` | Static analysis (harus "No issues found") |
| `flutter test` | Jalankan widget/unit test |
| `flutter build apk --debug` | Build APK debug |

## Definition of Done (Fase 0.1)

- [x] `flutter analyze` bersih, `flutter test` hijau
- [x] Struktur clean architecture (data/domain/presentation) terbentuk
- [x] Routing 2 mode (Pembina/Orang Tua) berdasarkan role
- [x] Local database (sqflite) di-setup sebagai kerangka offline
- [ ] `flutter run` diverifikasi di emulator (butuh emulator aktif)
