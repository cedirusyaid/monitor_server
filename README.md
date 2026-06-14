# 🖥️ Monitor Server

[![Version](https://img.shields.io/badge/version-v1.4.0-blue.svg)](RELEASE_NOTES.md)
[![Shell](https://img.shields.io/badge/shell-bash-green.svg)](#)
[![Platform](https://img.shields.io/badge/platform-linux-lightgrey.svg)](#)
[![Standard](https://img.shields.io/badge/standard-PSR--12-orange.svg)](#)

Koleksi script monitoring sistem mandiri yang digunakan untuk memantau kesehatan server secara *real-time*, memantau suhu perangkat keras, serta mengirimkan notifikasi instan ke Telegram dan integrasi ke Dashboard API internal.

---

## 📂 Struktur Berkas & Kegunaan

Berikut adalah berkas-berkas yang berada di dalam direktori `/opt/monitor_server/`:

| Berkas | Jenis | Deskripsi |
| :--- | :--- | :--- |
| 🛡️ [resource_alert.sh](resource_alert.sh) | Bash Script | **Sistem Deteksi Dini (Alerting)**. Memeriksa parameter kritis seperti CPU, RAM, Disk, Load Average, dan Suhu CPU setiap 10 menit. Jika terdeteksi melebihi batas aman (*threshold*), ia akan melampirkan daftar **5 proses teratas** yang memakan CPU tertinggi dan mengirimkan notifikasi peringatan ke Telegram. |
| 📡 [monitor_server.sh](monitor_server.sh) | Bash Script | **Monitoring Rutin**. Mengumpulkan informasi statik & dinamis server, mengecek status layanan (*services*), jumlah koneksi HTTP, lalu mengirimkan laporan rangkuman ke Telegram & Dashboard API setiap pukul 23:01 malam. |
| 🚀 [push.sh](push.sh) | Bash Script | **Git Automation Helper**. Script pembantu untuk standarisasi Git push sesuai standar format commit (`YYMMDD - [Tipe]: Deskripsi`). |
| 📝 [RELEASE_NOTES.md](RELEASE_NOTES.md) | Markdown | Catatan rilis dan dokumentasi riwayat versi aplikasi. |
| ⚙️ [.env.example](.env.example) | Configuration | Template file konfigurasi untuk mendefinisikan Token Telegram, ID Grup, serta daftar Service yang dimonitor. |
| 💾 [monitoring_server1.sh](monitoring_server1.sh) | Bash Script | *Legacy Script* (v2.0) yang sebelumnya terintegrasi dengan Dashboard API alternatif (disimpan sebagai cadangan). |

---

## ⚙️ Batas Aman Alerting (Threshold)

Di dalam [resource_alert.sh](resource_alert.sh), batas toleransi sumber daya diatur sebagai berikut (bisa disesuaikan langsung di dalam script):

*   **Batas CPU (`CPU_LIMIT`)**: `80%`
*   **Batas RAM (`RAM_LIMIT`)**: `90%`
*   **Batas Disk (`DISK_LIMIT`)**: `90%` (mengabaikan mount point `/gudang`)
*   **Batas Suhu (`TEMP_LIMIT`)**: `80°C`
*   **Batas Load (`LOAD_LIMIT`)**: Dinamis sesuai jumlah core CPU (`nproc`)

---

## 🚀 Instalasi & Cara Penggunaan

### 1. Inisialisasi Berkas Konfigurasi
Salin berkas template `.env.example` menjadi `.env` lokal:
```bash
cp /opt/monitor_server/.env.example /opt/monitor_server/.env
```
Sunting berkas `.env` dan masukkan kredensial rahasia yang sesuai:
```ini
TELEGRAM_BOT_TOKEN="your_bot_token"
TELEGRAM_CHAT_ID="your_group_chat_id"
SERVICE_LIST="apache2 mysql ssh php8*"
DASHBOARD_API_URL="https://your-dashboard.com/api/server_monitor"
DASHBOARD_API_TOKEN="your_dashboard_token"
```
> [!IMPORTANT]
> Berkas `.env` telah didaftarkan pada `.gitignore` agar kredensial rahasia tidak terunggah ke repositori publik di GitHub.

### 2. Berikan Izin Eksekusi
Pastikan seluruh script utama memiliki izin eksekusi (*executable*):
```bash
chmod +x /opt/monitor_server/*.sh
```

### 3. Penjadwalan Otomatis (Cron Job)
Tambahkan entri berikut ke dalam berkas sistem-wide crontab di **`/etc/crontab`** menggunakan akses root:
```cron
# Memantau batas aman resource server setiap 10 menit
*/10 *   * * * root    /opt/monitor_server/resource_alert.sh

# Mengirimkan laporan rutin harian setiap jam 23:01 malam
1  23   * * * root    /opt/monitor_server/monitor_server.sh
```

---

## 🛡️ Alur Git & Standar Pesan Commit
Untuk mempermudah manajemen kode, repositori ini wajib menggunakan format pesan commit sebagai berikut:
`YYMMDD - [Tipe]: Deskripsi`

### Menggunakan push.sh
Boss cukup menjalankan perintah berikut untuk commit dan push secara otomatis:
```bash
./push.sh
```
Pilih tipe perubahan dan masukkan pesan deskripsi yang sesuai saat diminta oleh sistem.

---

## 🏷️ Keywords & Topics
`bash-script` · `server-monitoring` · `telegram-bot` · `cpu-temperature` · `alert-system` · `sysadmin` · `linux-monitoring` · `cron-job` · `server-administration`
