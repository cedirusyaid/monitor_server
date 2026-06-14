#!/bin/bash

# ==========================================================================
# SCRIPT MONITORING SERVER v2.0
# ==========================================================================

# Mendapatkan direktori dimana script ini berada
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# Load konfigurasi dari file .env di folder yang sama dengan script
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "File .env tidak ditemukan di $ENV_FILE"
    exit 1
fi

# Konfigurasi API Dashboard (sudah diambil dari .env)
# DASHBOARD_API_URL dan DASHBOARD_API_TOKEN sudah tersedia dari source .env

TELEGRAM_API_URL="https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage"

# Ambil data sistem
HOSTNAME=$(hostname)
CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')
UPTIME_INFO=$(uptime -p)
TOTAL_CPU_CORES=$(nproc)
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')

TOTAL_RAM=$(free -h | awk '/Mem/{print $2}')
USED_RAM=$(free -h | awk '/Mem/{print $3}')
MEM_USAGE=$(free | awk '/Mem/{printf("%.2f"), $3/$2 * 100}')
MEM_DETAIL="$USED_RAM / $TOTAL_RAM"

ping -c 1 8.8.8.8 > /dev/null 2>&1
if [ $? -eq 0 ]; then
    INTERNET_STATUS="✅ Tersambung"
    INTERNET_JSON="OK"
else
    INTERNET_STATUS="❌ Tidak tersambung"
    INTERNET_JSON="FAIL"
fi

SERVICE_STATUS=""
for SERVICE in $SERVICE_LIST; do
    if systemctl is-active --quiet "$SERVICE"; then
        SERVICE_STATUS+="✅ $SERVICE Aktif\n"
    else
        SERVICE_STATUS+="❌ $SERVICE Mati\n"
    fi
done

LOGGED_IN_USERS=$(who | awk '{print $1}' | sort | uniq)
if [ -z "$LOGGED_IN_USERS" ]; then
    LOGGED_IN_USERS="Tidak ada user"
else
    LOGGED_IN_USERS=$(echo "$LOGGED_IN_USERS" | sed ':a;N;$!ba;s/\n/, /g')
fi

DISK_USAGE_JSON=$(df -h --output=source,target,size,used,pcent | awk '$1 ~ /^\/dev\// {printf "%s:%s/%s (%s), ", $2, $4, $3, $5}' | sed 's/, $//')
DISK_USAGE_INFO=$(df -h --output=source,target,size,used,pcent | awk '$1 ~ /^\/dev\// {printf "📂 %s : %s / %s (%s)\n", $2, $4, $3, $5}')

HTTP_ACCESS_COUNT=$(netstat -tnp 2>/dev/null | grep -E ':80|:443' | wc -l)
LOCAL_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -s ifconfig.me)

# --- 1. KIRIM KE TELEGRAM ---
MESSAGE="#MonitoringServer $HOSTNAME\n┃━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n📡 IP: $LOCAL_IP / $PUBLIC_IP\n┃━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n📅 Waktu: $CURRENT_TIME\n🕒 Uptime: $UPTIME_INFO\n┃━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n🔤 CPU: $CPU_USAGE% ($TOTAL_CPU_CORES core)\n💾 RAM: $MEM_USAGE% ($MEM_DETAIL)\n┃━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n💿 Disk:\n$DISK_USAGE_INFO\n┃━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n🌍 Internet: $INTERNET_STATUS\n┃━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n🛠 Status Service:\n$SERVICE_STATUS┃━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n👤 User: $LOGGED_IN_USERS\n🌐 Akses HTTP: $HTTP_ACCESS_COUNT koneksi\n┃━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
MESSAGE_ESC=$(echo -e "$MESSAGE" | sed -E 's/([][_*~`>#+=|{}.!()-])/\\\1/g')

# Eksekusi curl dan simpan response/status
TELEGRAM_RESPONSE=$(curl -s -X POST "$TELEGRAM_API_URL" \
    -d chat_id="$TELEGRAM_CHAT_ID" \
    -d text="$MESSAGE_ESC" \
    -d parse_mode="MarkdownV2")

if [ $? -ne 0 ]; then
    echo "❌ [$(date)] Error: Gagal terhubung ke server Telegram (Network Error)"
else
    # Cek apakah bot mengembalikan error JSON (misal: Token salah atau Chat ID salah)
    if [[ "$TELEGRAM_RESPONSE" != *"\"ok\":true"* ]]; then
        echo "❌ [$(date)] Error Telegram API: $TELEGRAM_RESPONSE"
    fi
fi

# Fungsi untuk meloloskan (escape) karakter yang merusak JSON
escape_json() {
    # 1. Escape backslash, then double quotes, then newlines
    echo "$1" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g'
}

# Ambil data sistem dan loloskan untuk JSON
E_HOSTNAME=$(escape_json "$HOSTNAME")
E_UPTIME=$(escape_json "$UPTIME_INFO")
E_MEM_DETAIL=$(escape_json "$MEM_DETAIL")
# Gunakan pipe (|) sebagai pemisah service agar sesuai dengan tampilan dashboard
E_SERVICE_STATUS=$(echo -e "$SERVICE_STATUS" | tr '\n' '|' | sed 's/| *$//' | sed 's/|/ | /g' | sed 's/"/\\"/g')
E_USERS=$(escape_json "$LOGGED_IN_USERS")
E_DISK=$(escape_json "$DISK_USAGE_JSON")

# --- 2. KIRIM KE API DASHBOARD ---
JSON_DATA=$(cat <<EOF
{
  "hostname": "$E_HOSTNAME",
  "local_ip": "$LOCAL_IP",
  "public_ip": "$PUBLIC_IP",
  "cpu_usage": "$CPU_USAGE",
  "mem_usage": "$MEM_USAGE",
  "mem_detail": "$E_MEM_DETAIL",
  "disk_usage": "$E_DISK",
  "service_status": "$E_SERVICE_STATUS",
  "uptime": "$E_UPTIME",
  "http_conn": "$HTTP_ACCESS_COUNT",
  "user_login": "$E_USERS",
  "internet_ok": "$INTERNET_JSON"
}
EOF
)

# Mengirim data dan menangkap HTTP status code serta response body
RESPONSE_FILE=$(mktemp)
HTTP_STATUS=$(curl -s -w "%{http_code}" -X POST "$DASHBOARD_API_URL" \
     -H "Content-Type: application/json" \
     -H "X-MONITOR-TOKEN: $DASHBOARD_API_TOKEN" \
     -d "$JSON_DATA" \
     -o "$RESPONSE_FILE")

RESPONSE_BODY=$(cat "$RESPONSE_FILE")
rm "$RESPONSE_FILE"

if [ "$HTTP_STATUS" -eq 200 ]; then
    echo "✅ [$(date)] Monitoring data sent successfully to Dashboard"
else
    echo "❌ [$(date)] Error API Dashboard: $HTTP_STATUS - $RESPONSE_BODY"
fi
echo "Monitoring data sent at $CURRENT_TIME"
