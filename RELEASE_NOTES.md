# RELEASE NOTES - MONITOR SERVER

## [v1.5.0] - 2026-06-16
### ✨ Added
- **TLP Status Monitoring**: Menambahkan pemantauan status TLP (Optimasi Baterai) untuk mendeteksi status aktif, mode operasi, dan sumber daya saat ini (AC/Battery). Status ini ditampilkan pada log terminal dan laporan Telegram.

## [v1.4.1] - 2026-06-14
### 🔄 Changed
- **Dynamic Disk Exclusion**: Memindahkan konfigurasi pemengecualian disk dari hardcoded di script ke variabel `EXCLUDE_MOUNTS` di berkas `.env` agar dinamis.

## [v1.4.0] - 2026-06-14
### ✨ Added
- **Top Processes Monitoring**: Menampilkan daftar 5 proses teratas yang menggunakan CPU tertinggi ketika terjadi alert CPU, RAM, Load, atau Suhu CPU, guna mempermudah pencarian penyebab server panas/overload.

## [v1.3.1] - 2026-06-11
### 🔄 Changed
- **Disk Exclusion**: Mengabaikan mount point `/gudang` dari monitoring alert disk usage sesuai permintaan khusus untuk host ini.

## [v1.3.0] - 2026-06-10
### ✨ Added
- **UI Redesign**: Tampilan laporan Telegram sekarang lebih estetik dan profesional, mengikuti gaya visual `monitoring_server.sh`.
- **Enhanced Info**: Menambahkan informasi Public IP dan daftar User yang sedang login ke dalam laporan.
- **Improved Formatting**: Menggunakan `MarkdownV2` untuk pesan Telegram agar tampilan lebih rapi dengan separator visual (box style).

## [v1.2.0] - 2026-06-10
### ✨ Added
- Fitur **Daily Status Report**. Script akan tetap mengirimkan laporan ke Telegram pada waktu tertentu (default 23:00) meskipun tidak ada alert/warning.
- Header pesan Telegram yang dinamis (`DAILY STATUS REPORT`, `RESOURCE ALERT`, atau `DAILY REPORT & ALERT`).

## [v1.1.0] - 2026-06-10
### ✨ Added
...

---
#### Format Label Wajib:
- ✨ Added: Fitur baru
- 🐛 Fixed: Bug fix
- 🔄 Changed: Perubahan non-bug (refactor, optimasi, dll)
- 🗑️ Deprecated: Fitur yang akan dihapus
- 🛡️ Security: Patch keamanan
