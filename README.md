# Monitoring Server dengan Notifikasi Telegram

Script ini digunakan untuk memantau kondisi server dan mengirimkan laporan ke Telegram secara otomatis.

## Fitur
- Menampilkan uptime server
- Menampilkan penggunaan CPU, RAM, dan Disk
- Mengecek koneksi internet
- Mengecek status layanan tertentu (`apache2`, `mysql`, `ssh`, `php`)
- Menampilkan daftar user yang sedang login
- Mengirimkan laporan ke Telegram dengan format MarkdownV2

## Persyaratan
- Linux dengan akses ke terminal
- Telegram bot token dan chat ID
- `curl` untuk mengirim pesan ke Telegram

## Instalasi
1. Clone repository ini:
   ```sh
   git clone https://github.com/username/repository.git
   cd repository
   ```
2. Buat file `.env` dan isi dengan informasi berikut:
   ```sh
   TELEGRAM_BOT_TOKEN="YOUR_TELEGRAM_BOT_TOKEN"
   TELEGRAM_CHAT_ID="YOUR_TELEGRAM_CHAT_ID"
   ```
3. Berikan izin eksekusi pada script:
   ```sh
   chmod +x monitor.sh
   ```
4. Jalankan script:
   ```sh
   ./monitor.sh
   ```

## Penjadwalan Otomatis dengan Cronjob
Untuk menjalankan script secara otomatis, tambahkan cronjob dengan perintah:
```sh
crontab -e
```
Tambahkan baris berikut agar script berjalan setiap 10 menit:
```sh
*/10 * * * * /path/to/monitor.sh
```

## Format Pesan di Telegram
Pesan yang dikirimkan ke Telegram memiliki format seperti berikut:
```
⚡ Monitoring Server [hostname]
━━━━━━━━━━━━━━━━━━
🕒 Uptime: `2 hours, 35 minutes`
🔥 CPU Usage: `4.1%`
💾 RAM Usage: `51.85%`
💿 Disk Usage: `80%`
🌍 Internet: ✅ Tersambung
━━━━━━━━━━━━━━━━━━
🛠 Status Service:
✅ `apache2` Aktif
✅ `mysql` Aktif
❌ `ssh` Mati
❌ `php` Mati
━━━━━━━━━━━━━━━━━━
👤 User Login: user1, user2
━━━━━━━━━━━━━━━━━━
```

## Lisensi
Script ini tersedia di bawah lisensi MIT. Anda bebas menggunakannya dan memodifikasinya sesuai kebutuhan.

