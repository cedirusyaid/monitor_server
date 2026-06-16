#!/bin/bash

# =====================================================
# RESOURCE ALERT v1.5.0
# Monitoring CPU, RAM, Disk, Load dan Temperature serta TLP Status
# UI Redesign inspired by monitoring_server.sh
# =====================================================

# Mendapatkan direktori script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# Load konfigurasi
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "❌ File .env tidak ditemukan di $ENV_FILE"
    exit 1
fi

TELEGRAM_API_URL="https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage"

# =====================================================
# KONFIGURASI THRESHOLD
# =====================================================

CPU_LIMIT=80
RAM_LIMIT=90
DISK_LIMIT=90
TEMP_LIMIT=80

# Waktu laporan rutin (format HH:MM), kosongkan jika tidak ingin
DAILY_REPORT_TIME="21:20"

# Load average ideal = jumlah core CPU
LOAD_LIMIT=$(nproc)

# =====================================================
# INFORMASI SERVER
# =====================================================

HOSTNAME=$(hostname)
CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')
LOCAL_IP=$(hostname -I | awk '{print $1}')
UPTIME_INFO=$(uptime -p)

# =====================================================
# CPU USAGE
# =====================================================

CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2 + $4)}')

# =====================================================
# RAM USAGE
# =====================================================

RAM_USAGE=$(free | awk '/Mem/ {printf "%.0f",$3/$2*100}')
RAM_USED=$(free -h | awk '/Mem/ {print $3}')
RAM_TOTAL=$(free -h | awk '/Mem/ {print $2}')

# =====================================================
# LOAD AVERAGE
# =====================================================

LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1 | xargs)
LOAD_INT=$(printf "%.0f" "$LOAD_AVG")

# =====================================================
# TEMPERATURE
# =====================================================

TEMP="N/A"

if command -v sensors >/dev/null 2>&1; then
    TEMP=$(sensors 2>/dev/null | \
        grep -oP '\+\K[0-9]+(?=\.[0-9]+°C)' | \
        sort -nr | head -1)

    [ -z "$TEMP" ] && TEMP="N/A"
elif ls /sys/class/thermal/thermal_zone*/temp >/dev/null 2>&1; then
    # Fallback ke /sys/class/thermal jika sensors tidak terinstall
    RAW_TEMP=$(cat /sys/class/thermal/thermal_zone*/temp | sort -nr | head -1)
    if [ ! -z "$RAW_TEMP" ]; then
        TEMP=$((RAW_TEMP / 1000))
    fi
fi

# =====================================================
# DISK USAGE
# =====================================================

DISK_WARNING=""

while read usage mount; do

    usage_num=$(echo "$usage" | tr -d '%')

    # Abaikan mount point yang dikecualikan di .env (pisahkan dengan spasi)
    if [ ! -z "$EXCLUDE_MOUNTS" ]; then
        if [[ " $EXCLUDE_MOUNTS " == *" $mount "* ]]; then
            continue
        fi
    fi

    if [ "$usage_num" -ge "$DISK_LIMIT" ]; then
        DISK_WARNING+="💿 Disk $mount : $usage\n"
    fi

done < <(
    df -h --output=pcent,target | tail -n +2
)

# =====================================================
# TLP STATUS (BATTERY OPTIMIZATION)
# =====================================================

TLP_STATUS="N/A"
if command -v tlp-stat >/dev/null 2>&1; then
    TLP_STATE=$(tlp-stat -s | grep -i "^State" | awk -F'=' '{print $2}' | xargs)
    TLP_MODE=$(tlp-stat -s | grep -i "^Mode" | awk -F'=' '{print $2}' | xargs)
    TLP_POWER=$(tlp-stat -s | grep -i "^Power source" | awk -F'=' '{print $2}' | xargs)
    
    if [ -z "$TLP_STATE" ]; then
        TLP_STATUS="Enabled"
    else
        TLP_STATUS="$TLP_STATE ($TLP_MODE, Power: $TLP_POWER)"
    fi
elif systemctl is-active --quiet tlp >/dev/null 2>&1; then
    TLP_STATUS="Active (systemctl)"
else
    TLP_STATUS="Not Active / Not Installed"
fi

# =====================================================
# CEK ALERT
# =====================================================

ALERT=""

if [ "$CPU_USAGE" -ge "$CPU_LIMIT" ]; then
    ALERT+="🔥 CPU Usage : ${CPU_USAGE}%\n"
fi

if [ "$RAM_USAGE" -ge "$RAM_LIMIT" ]; then
    ALERT+="💾 RAM Usage : ${RAM_USAGE}% (${RAM_USED}/${RAM_TOTAL})\n"
fi

if [ "$LOAD_INT" -gt "$LOAD_LIMIT" ]; then
    ALERT+="⚡ Load Average : ${LOAD_AVG}\n"
fi

if [[ "$TEMP" != "N/A" ]]; then
    if [ "$TEMP" -ge "$TEMP_LIMIT" ]; then
        ALERT+="🌡️ CPU Temperature : ${TEMP}°C\n"
    fi
fi

if [ ! -z "$DISK_WARNING" ]; then
    ALERT+="$DISK_WARNING"
fi

# Ambil top processes jika ada alert CPU, RAM, Load, atau Temp
if [ "$CPU_USAGE" -ge "$CPU_LIMIT" ] || [ "$RAM_USAGE" -ge "$RAM_LIMIT" ] || [ "$LOAD_INT" -gt "$LOAD_LIMIT" ] || { [[ "$TEMP" != "N/A" ]] && [ "$TEMP" -ge "$TEMP_LIMIT" ]; }; then
    TOP_PROC=$(ps -eo %cpu,%mem,args --sort=-%cpu | grep -v -E "ps -eo|grep -v|%CPU" | head -n 5 | awk '{
      cpu=$1; mem=$2; $1=""; $2="";
      sub(/^[ \t]+/, "");
      cmd=substr($0, 1, 35);
      if (length($0) > 35) cmd=cmd"...";
      printf "  🔸 %s (CPU: %s%%, RAM: %s%%)\\n", cmd, cpu, mem
    }')
    ALERT+="\n📈 TOP PROCESSES (by CPU):\n$TOP_PROC\n"
fi

# =====================================================
# TAMPILKAN KE TERMINAL
# =====================================================

echo "================================================="
echo "RESOURCE MONITOR"
echo "================================================="
echo "Host         : $HOSTNAME"
echo "IP           : $LOCAL_IP"
echo "Waktu        : $CURRENT_TIME"
echo "Uptime       : $UPTIME_INFO"
echo "TLP Status   : $TLP_STATUS"
echo "-------------------------------------------------"
echo "CPU Usage    : ${CPU_USAGE}%"
echo "RAM Usage    : ${RAM_USAGE}% (${RAM_USED}/${RAM_TOTAL})"
echo "Load Average : ${LOAD_AVG}"
echo "Temperature  : ${TEMP}"
echo "-------------------------------------------------"

df -h --output=target,size,used,pcent | sed 1d

echo "-------------------------------------------------"

if [ -z "$ALERT" ]; then
    echo "✅ STATUS : NORMAL"
else
    echo -e "⚠️ STATUS : WARNING\n"
    echo -e "$ALERT"
fi

echo "================================================="

# =====================================================
# KIRIM TELEGRAM JIKA ADA WARNING ATAU JADWAL LAPORAN
# =====================================================

CURRENT_HM=$(date '+%H:%M')
IS_REPORT_TIME=false

if [ ! -z "$DAILY_REPORT_TIME" ] && [ "$CURRENT_HM" == "$DAILY_REPORT_TIME" ]; then
    IS_REPORT_TIME=true
fi

if [ ! -z "$ALERT" ] || [ "$IS_REPORT_TIME" = true ]; then

    # Ambil info tambahan untuk tampilan yang lebih lengkap
    PUBLIC_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null)
    [ -z "$PUBLIC_IP" ] && PUBLIC_IP="Tidak terdeteksi"
    LOGGED_IN_USERS=$(who | awk '{print $1}' | sort | uniq | tr '\n' ',' | sed 's/,$//')
    [ -z "$LOGGED_IN_USERS" ] && LOGGED_IN_USERS="Tidak ada user"

    STATUS_HEADER="🚨 RESOURCE ALERT"
    if [ "$IS_REPORT_TIME" = true ] && [ -z "$ALERT" ]; then
        STATUS_HEADER="✅ DAILY STATUS REPORT"
        ALERT="Semua sistem terpantau normal\."
    elif [ "$IS_REPORT_TIME" = true ] && [ ! -z "$ALERT" ]; then
        STATUS_HEADER="🚨 DAILY REPORT & ALERT"
    fi

    # Format Pesan Ala Monitoring Server
    MESSAGE="#ResourceAlert $HOSTNAME\n"
    MESSAGE+="┃━━━━━━━━━━━━━━━━━\n"
    MESSAGE+="$STATUS_HEADER\n"
    MESSAGE+="┃━━━━━━━━━━━━━━━━━\n"
    MESSAGE+="📡 IP: $LOCAL_IP / $PUBLIC_IP\n"
    MESSAGE+="📅 Waktu: $CURRENT_TIME\n"
    MESSAGE+="🕒 Uptime: $UPTIME_INFO\n"
    MESSAGE+="🔋 TLP Status: $TLP_STATUS\n"
    MESSAGE+="┃━━━━━━━━━━━━━━━━━\n"
    MESSAGE+="🔤 CPU: ${CPU_USAGE}%\n"
    MESSAGE+="💾 RAM: ${RAM_USAGE}% (${RAM_USED}/${RAM_TOTAL})\n"
    MESSAGE+="⚡ Load: ${LOAD_AVG}\n"
    MESSAGE+="🌡️ Temp: ${TEMP}°C\n"
    MESSAGE+="┃━━━━━━━━━━━━━━━━━\n"
    MESSAGE+="💿 Disk Status:\n${DISK_WARNING:-✅ Semua partisi normal}\n"
    MESSAGE+="┃━━━━━━━━━━━━━━━━━\n"
    
    if [ ! -z "$ALERT" ] && [ "$ALERT" != "Semua sistem terpantau normal\." ]; then
        MESSAGE+="⚠️ DETAIL MASALAH:\n$ALERT\n"
        MESSAGE+="┃━━━━━━━━━━━━━━━━━\n"
    fi

    MESSAGE+="👤 User: $LOGGED_IN_USERS\n"
    MESSAGE+="┃━━━━━━━━━━━━━━━━━"

    # Escape untuk MarkdownV2 Telegram
    # Kita harus berhati-hati dengan karakter yang sudah di-escape di variabel ALERT
    MESSAGE_ESC=$(echo -e "$MESSAGE" | sed -E 's/([][_*~`>#+=|{}.!()-])/\\\1/g')

    # Eksekusi curl ke Telegram
    curl -s -X POST "$TELEGRAM_API_URL" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d text="$MESSAGE_ESC" \
        -d parse_mode="MarkdownV2" \
        > /dev/null

    echo "📨 Telegram alert/report sent with new style."
fi

echo
echo "Monitoring completed at $CURRENT_TIME"
