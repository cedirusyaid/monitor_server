#!/bin/bash

# Load konfigurasi dari file .env
if [ -f /opt/monitor_server/.env ]; then
    source /opt/monitor_server/.env
else
    echo "File .env tidak ditemukan!"
    exit 1
fi

TELEGRAM_API_URL="https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage"

# Ambil hostname
HOSTNAME=$(hostname)

# Ambil uptime
UPTIME_INFO=$(uptime -p)

# Ambil total core CPU
TOTAL_CPU_CORES=$(nproc)

# Ambil status penggunaan CPU
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')

# Ambil total RAM dan penggunaan RAM
TOTAL_RAM=$(free -h | awk '/Mem/{print $2}')
USED_RAM=$(free -h | awk '/Mem/{print $3}')
MEM_USAGE=$(free | awk '/Mem/{printf("%.2f"), $3/$2 * 100}')

# Cek koneksi internet
ping -c 1 8.8.8.8 > /dev/null 2>&1
if [ $? -eq 0 ]; then
    INTERNET_STATUS="✅ Tersambung"
else
    INTERNET_STATUS="❌ Tidak tersambung"
fi

# Cek status service tertentu dari .env
SERVICE_STATUS=""
for SERVICE in $SERVICE_LIST; do
    if systemctl is-active --quiet "$SERVICE"; then
        SERVICE_STATUS+="✅ $SERVICE Aktif\n"
    else
        SERVICE_STATUS+="❌ $SERVICE Mati\n"
    fi
done

# Cek user yang sedang login
LOGGED_IN_USERS=$(who | awk '{print $1}' | sort | uniq)
if [ -z "$LOGGED_IN_USERS" ]; then
    LOGGED_IN_USERS="Tidak ada user yang login"
else
    LOGGED_IN_USERS=$(echo "$LOGGED_IN_USERS" | sed ':a;N;$!ba;s/\n/, /g')
fi

# Ambil informasi disk yang hanya berasal dari /dev/
DISK_USAGE_INFO=$(df -h --output=source,target,size,used,pcent | awk '$1 ~ /^\/dev\// {printf "📂 %s : %s / %s (%s)\n", $2, $4, $3, $5}')

# Cek jika data disk kosong
if [ -z "$DISK_USAGE_INFO" ]; then
    DISK_USAGE_INFO="Tidak ada informasi disk tersedia."
fi

# Cek jumlah akses HTTP/HTTPS di Apache2
HTTP_ACCESS_COUNT=$(netstat -tnp | grep -E ':80|:443' | wc -l)

# Ambil alamat IP lokal dan publik
LOCAL_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -s ifconfig.me)

# Format pesan dengan MarkdownV2
MESSAGE="#MonitoringServer \$$HOSTNAME\n"
MESSAGE+="━━━━━━━━━━━━━━━━━━\n"
MESSAGE+="📡 IP Lokal: $LOCAL_IP\n"
MESSAGE+="🌎 IP Publik: $PUBLIC_IP\n"
MESSAGE+="━━━━━━━━━━━━━━━━━━\n"
MESSAGE+="🕒 Uptime: $UPTIME_INFO\n"
MESSAGE+="━━━━━━━━━━━━━━━━━━\n"
MESSAGE+="🔥 CPU Usage: $CPU_USAGE% dari $TOTAL_CPU_CORES core\n"
MESSAGE+="💾 RAM Usage: $MEM_USAGE% (Terpakai: $USED_RAM, Total: $TOTAL_RAM)\n"
MESSAGE+="━━━━━━━━━━━━━━━━━━\n"
MESSAGE+="💽 Disk Usage:\n"
MESSAGE+="$DISK_USAGE_INFO\n"
MESSAGE+="━━━━━━━━━━━━━━━━━━\n"
MESSAGE+="🌍 Internet: $INTERNET_STATUS\n"
MESSAGE+="━━━━━━━━━━━━━━━━━━\n"
MESSAGE+="🛠 Status Service:\n"
MESSAGE+="$SERVICE_STATUS"
MESSAGE+="━━━━━━━━━━━━━━━━━━\n"
MESSAGE+="👤 User Login: $LOGGED_IN_USERS\n"
MESSAGE+="━━━━━━━━━━━━━━━━━━\n"
MESSAGE+="🌐 Jumlah Akses HTTP/HTTPS: $HTTP_ACCESS_COUNT koneksi\n"
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
