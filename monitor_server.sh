#!/bin/bash

# ==========================================================================
# SCRIPT MONITORING SERVER v2.1
# ==========================================================================

# Mendapatkan direktori dimana script ini berada
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# Load konfigurasi dari file .env di folder yang sama dengan script
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "❌ File .env tidak ditemukan di $ENV_FILE"
    exit 1
fi

# Konfigurasi API Dashboard (diambil dari .env)
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

# Cek status service dengan dukungan wildcard
SERVICE_STATUS=""
for SERVICE in $SERVICE_LIST; do
    if [[ "$SERVICE" == *\** ]]; then
        PATTERN="${SERVICE//\*/.*}"
        for MATCHED_SERVICE in $(systemctl list-units --all --type=service --no-legend 2>/dev/null | awk '{print $1}' | grep "^${PATTERN}" | sed 's/\.service$//'); do
            if systemctl is-active --quiet "$MATCHED_SERVICE" 2>/dev/null; then
                SERVICE_STATUS+="✅ $MATCHED_SERVICE Aktif\n"
            else
                SERVICE_STATUS+="❌ $MATCHED_SERVICE Mati\n"
            fi
        done
    else
        if systemctl is-active --quiet "$SERVICE" 2>/dev/null; then
            SERVICE_STATUS+="✅ $SERVICE Aktif\n"
        else
            SERVICE_STATUS+="❌ $SERVICE Mati\n"
        fi
    fi
done

# Hapus newline terakhir jika ada
SERVICE_STATUS=$(echo -e "$SERVICE_STATUS" | sed '/^$/d')

LOGGED_IN_USERS=$(who | awk '{print $1}' | sort | uniq | tr '\n' ',' | sed 's/,$//')
[ -z "$LOGGED_IN_USERS" ] && LOGGED_IN_USERS="Tidak ada user"

DISK_USAGE_JSON=$(df -h --output=source,target,size,used,pcent 2>/dev/null | awk '$1 ~ /^\/dev\// {printf "%s:%s/%s (%s), ", $2, $4, $3, $5}' | sed 's/, $//')
DISK_USAGE_INFO=$(df -h --output=source,target,size,used,pcent 2>/dev/null | awk '$1 ~ /^\/dev\// {printf "📂 %s : %s / %s (%s)\n", $2, $4, $3, $5}')

HTTP_ACCESS_COUNT=$(ss -tnp 2>/dev/null | grep -E ':80|:443' | wc -l)
if [ $HTTP_ACCESS_COUNT -eq 0 ]; then
    HTTP_ACCESS_COUNT=$(netstat -tnp 2>/dev/null | grep -E ':80|:443' | wc -l)
fi

LOCAL_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null)
[ -z "$PUBLIC_IP" ] && PUBLIC_IP="Tidak terdeteksi"

# --- 1. KIRIM KE TELEGRAM ---
MESSAGE="#MonitoringServer $HOSTNAME\n┃━━━━━━━━━━━━━━━━━\n📡 IP: $LOCAL_IP / $PUBLIC_IP\n┃━━━━━━━━━━━━━━━━━\n📅 Waktu: $CURRENT_TIME\n🕒 Uptime: $UPTIME_INFO\n┃━━━━━━━━━━━━━━━━━\n🔤 CPU: $CPU_USAGE% ($TOTAL_CPU_CORES core)\n💾 RAM: $MEM_USAGE% ($MEM_DETAIL)\n┃━━━━━━━━━━━━━━━━━\n💿 Disk:\n$DISK_USAGE_INFO\n┃━━━━━━━━━━━━━━━━━\n🌍 Internet: $INTERNET_STATUS\n┃━━━━━━━━━━━━━━━━━\n🛠 Status Service:\n$SERVICE_STATUS\n┃━━━━━━━━━━━━━━━━━\n👤 User: $LOGGED_IN_USERS\n🌐 Akses HTTP: $HTTP_ACCESS_COUNT koneksi\n┃━━━━━━━━━━━━━━━━━"

# Escape untuk MarkdownV2 Telegram
MESSAGE_ESC=$(echo -e "$MESSAGE" | sed -E 's/([][_*~`>#+=|{}.!()-])/\\\1/g')

# Eksekusi curl ke Telegram
curl -s -X POST "$TELEGRAM_API_URL" -d chat_id="$TELEGRAM_CHAT_ID" -d text="$MESSAGE_ESC" -d parse_mode="MarkdownV2" > /dev/null

# --- 2. KIRIM KE API DASHBOARD ---
# Fungsi untuk meloloskan (escape) karakter yang merusak JSON
escape_json() {
    echo "$1" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g'
}

# Format Service Status khusus untuk Dashboard (Pipe separated)
DASH_SERVICE=$(echo -e "$SERVICE_STATUS" | tr '\n' '|' | sed 's/| *$//' | sed 's/|/ | /g')

JSON_DATA=$(cat <<EOF
{
  "hostname": "$(escape_json "$HOSTNAME")",
  "local_ip": "$LOCAL_IP",
  "public_ip": "$PUBLIC_IP",
  "cpu_usage": "$CPU_USAGE",
  "mem_usage": "$MEM_USAGE",
  "mem_detail": "$(escape_json "$MEM_DETAIL")",
  "disk_usage": "$(escape_json "$DISK_USAGE_JSON")",
  "service_status": "$(escape_json "$DASH_SERVICE")",
  "uptime": "$(escape_json "$UPTIME_INFO")",
  "http_conn": "$HTTP_ACCESS_COUNT",
  "user_login": "$(escape_json "$LOGGED_IN_USERS")",
  "internet_ok": "$INTERNET_JSON"
}
EOF
)

# Mengirim data ke Dashboard
HTTP_STATUS=$(curl -s -w "%{http_code}" -X POST "$DASHBOARD_API_URL" \
     -H "Content-Type: application/json" \
     -H "X-MONITOR-TOKEN: $DASHBOARD_API_TOKEN" \
     -d "$JSON_DATA" -o /dev/null)

if [ "$HTTP_STATUS" -eq 200 ]; then
    echo "✅ [$(date)] Monitoring data sent successfully to Dashboard"
else
    echo "❌ [$(date)] Error API Dashboard: HTTP $HTTP_STATUS"
fi

echo "Monitoring completed at $CURRENT_TIME"
echo "=========================================="
