#!/bin/bash

# Load konfigurasi dari file .env
if [ -f .env ]; then
    source .env
else
    echo "File .env tidak ditemukan!"
    exit 1
fi

TELEGRAM_API_URL="https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage"

# Ambil hostname dan uptime
HOSTNAME=$(hostname)
UPTIME_INFO=$(uptime -p)

# Ambil status penggunaan CPU
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')

# Ambil penggunaan RAM
MEM_USAGE=$(free | awk '/Mem/{printf("%.2f"), $3/$2 * 100}')

# Ambil penggunaan Disk
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')

# Cek koneksi internet (ping ke Google)
ping -c 1 8.8.8.8 > /dev/null 2>&1
if [ $? -eq 0 ]; then
    INTERNET_STATUS="✅ *Tersambung*"
else
    INTERNET_STATUS="❌ *Tidak tersambung*"
fi

# Cek status service tertentu
SERVICE_LIST=("apache2" "mysql" "ssh" "php")
SERVICE_STATUS=""

for SERVICE in "${SERVICE_LIST[@]}"; do
    if systemctl is-active --quiet "$SERVICE"; then
        SERVICE_STATUS+="✅ \`$SERVICE\` *Aktif*\n"
    else
        SERVICE_STATUS+="❌ \`$SERVICE\` *Mati*\n"
    fi
done

# Cek user yang sedang login
LOGGED_IN_USERS=$(who | awk '{print $1}' | sort | uniq)
if [ -z "$LOGGED_IN_USERS" ]; then
    LOGGED_IN_USERS="Tidak ada user yang login"
else
    LOGGED_IN_USERS=$(echo "$LOGGED_IN_USERS" | sed ':a;N;$!ba;s/\n/, /g')
fi

# Format pesan dengan MarkdownV2
MESSAGE="⚡ *Monitoring Server*\n"
MESSAGE+="━━━━━━━━━━━━━━━━━━\n"
MESSAGE+="🏷 *Hostname:* \`$HOSTNAME\`\n"
MESSAGE+="🕒 *Uptime:* \`$UPTIME_INFO\`\n"
MESSAGE+="━━━━━━━━━━━━━━━━━━\n"
MESSAGE+="🔥 *CPU Usage:* \`$CPU_USAGE%\`\n"
MESSAGE+="💾 *RAM Usage:* \`$MEM_USAGE%\`\n"
MESSAGE+="💿 *Disk Usage:* \`$DISK_USAGE\`\n"
MESSAGE+="🌍 *Internet:* $INTERNET_STATUS\n"
MESSAGE+="━━━━━━━━━━━━━━━━━━\n"
MESSAGE+="🛠 *Status Service:*\n"
MESSAGE+="$SERVICE_STATUS"
MESSAGE+="━━━━━━━━━━━━━━━━━━\n"
MESSAGE+="👤 *User Login:* $LOGGED_IN_USERS\n"
MESSAGE+="━━━━━━━━━━━━━━━━━━\n"

# Escape karakter spesial agar sesuai dengan MarkdownV2
MESSAGE=$(echo -e "$MESSAGE" | sed -E 's/([][_*~`>#+=|{}.!()-])/\\\1/g')

# Cek apakah pesan kosong sebelum dikirim
if [ -z "$MESSAGE" ]; then
    echo "Pesan kosong, tidak mengirim ke Telegram!"
    exit 1
fi

# Kirim pesan ke Telegram dengan MarkdownV2
curl -s -X POST "$TELEGRAM_API_URL" \
    -d chat_id="$TELEGRAM_CHAT_ID" \
    -d text="$MESSAGE" \
    -d parse_mode="MarkdownV2"
