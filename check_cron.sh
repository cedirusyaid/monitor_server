#!/bin/bash
# ==============================================================================
# Script : check_cron.sh
# Fungsi : Memeriksa jadwal cron job dan waktu eksekusi skrip di server
# Penggunaan: ./check_cron.sh [nama_skrip]
# ==============================================================================

TARGET="${1:-monitor_server.sh}"

echo "=========================================================="
echo "🔍 Memeriksa Penjadwalan Cron untuk: $TARGET"
echo "=========================================================="
echo "⏰ Waktu Server Saat Ini : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

FOUND=0

# Fungsi untuk menerjemahkan format cron 5 kolom ke teks ramah
parse_cron_time() {
    local m="$1"
    local h="$2"
    local dom="$3"
    local mon="$4"
    local dow="$5"

    local desc=""

    # 1. Menit & Jam
    if [[ "$m" == *"/"* ]]; then
        local interval="${m#*/}"
        desc="Setiap $interval menit"
    elif [[ "$m" == "*" ]] && [[ "$h" == "*" ]]; then
        desc="Setiap menit"
    elif [[ "$h" == "*" ]]; then
        desc="Setiap jam pada menit ke-$m"
    elif [[ "$m" == "0" || "$m" == "00" ]]; then
        if [[ "$h" =~ ^[0-9]+$ ]]; then
            desc="Pukul $(printf "%02d:00" "$h")"
        else
            desc="Pukul $h:00"
        fi
    else
        if [[ "$h" =~ ^[0-9]+$ ]] && [[ "$m" =~ ^[0-9]+$ ]]; then
            desc="Pukul $(printf "%02d:%02d" "$h" "$m")"
        else
            desc="Pukul $h:$m"
        fi
    fi

    # 2. Hari & Bulan
    if [[ "$dom" == "*" ]] && [[ "$mon" == "*" ]] && [[ "$dow" == "*" ]]; then
        desc="$desc setiap hari"
    else
        local dom_str="$dom"
        local dow_str="$dow"
        [[ "$dom" == "*" ]] && dom_str="tiap tgl"
        [[ "$dow" == "*" ]] && dow_str="tiap hari"
        desc="$desc (Pola: Tanggal: $dom_str, Bulan: $mon, Hari: $dow_str)"
    fi

    echo "$desc"
}

# Fungsi untuk memperkirakan eksekusi berikutnya jika jadwal fixed harian/interval
estimate_next_run() {
    local m="$1"
    local h="$2"
    local dom="$3"
    local mon="$4"
    local dow="$5"

    local now=$(date +%s)

    # Pola jadwal harian tetap: misal 0 17 * * *
    if [[ "$m" =~ ^[0-9]+$ ]] && [[ "$h" =~ ^[0-9]+$ ]] && [[ "$dom" == "*" ]] && [[ "$mon" == "*" ]] && [[ "$dow" == "*" ]]; then
        local target_today=$(date -d "$(printf "%02d:%02d:00" "$h" "$m")" +%s 2>/dev/null)
        if [ -n "$target_today" ]; then
            local next_target=$target_today
            if [ "$target_today" -le "$now" ]; then
                next_target=$(date -d "tomorrow $(printf "%02d:%02d:00" "$h" "$m")" +%s 2>/dev/null)
            fi
            local diff=$((next_target - now))
            local hours=$((diff / 3600))
            local mins=$(((diff % 3600) / 60))
            echo "   ⏳ Eksekusi Berikutnya : $(date -d "@$next_target" "+%Y-%m-%d %H:%M:%S %Z") (sekitar $hours jam $mins menit lagi)"
        fi
    # Pola interval menit: misal */10 * * * *
    elif [[ "$m" =~ ^\*/[0-9]+$ ]] && [[ "$h" == "*" ]]; then
        local interval="${m#*/}"
        local cur_min=$(date +%M)
        local cur_sec=$(date +%S)
        local rem_min=$((interval - (10#$cur_min % interval)))
        local diff_sec=$(( (rem_min * 60) - 10#$cur_sec ))
        local next_target=$((now + diff_sec))
        local mins=$((diff_sec / 60))
        echo "   ⏳ Eksekusi Berikutnya : $(date -d "@$next_target" "+%Y-%m-%d %H:%M:%S %Z") (sekitar $mins menit lagi)"
    fi
}

# 1. Periksa /etc/crontab
if [ -f /etc/crontab ]; then
    MATCHES=$(grep -v '^[[:space:]]*#' /etc/crontab | grep "$TARGET")
    if [ -n "$MATCHES" ]; then
        FOUND=1
        echo "📍 Ditemukan di Sistem Crontab (/etc/crontab):"
        while IFS= read -r line; do
            read -r m h dom mon dow user cmd <<< "$line"
            HUMAN_TIME=$(parse_cron_time "$m" "$h" "$dom" "$mon" "$dow")
            echo "   ------------------------------------------------------"
            echo "   Baris Asli           : $line"
            echo "   ⏰ Jadwal Eksekusi   : $HUMAN_TIME"
            echo "   👤 Dijalankan Sebagai: $user"
            estimate_next_run "$m" "$h" "$dom" "$mon" "$dow"
        done <<< "$MATCHES"
        echo ""
    fi
fi

# 2. Periksa /etc/cron.d/
if [ -d /etc/cron.d ]; then
    for f in /etc/cron.d/*; do
        [ -f "$f" ] || continue
        MATCHES=$(grep -v '^[[:space:]]*#' "$f" 2>/dev/null | grep "$TARGET")
        if [ -n "$MATCHES" ]; then
            FOUND=1
            echo "📍 Ditemukan di /etc/cron.d/ ($(basename "$f")):"
            while IFS= read -r line; do
                read -r m h dom mon dow user cmd <<< "$line"
                HUMAN_TIME=$(parse_cron_time "$m" "$h" "$dom" "$mon" "$dow")
                echo "   ------------------------------------------------------"
                echo "   Baris Asli           : $line"
                echo "   ⏰ Jadwal Eksekusi   : $HUMAN_TIME"
                echo "   👤 Dijalankan Sebagai: $user"
                estimate_next_run "$m" "$h" "$dom" "$mon" "$dow"
            done <<< "$MATCHES"
            echo ""
        fi
    done
fi

# 3. Periksa crontab user saat ini
USER_CRON=$(crontab -l 2>/dev/null | grep -v '^[[:space:]]*#' | grep "$TARGET")
if [ -n "$USER_CRON" ]; then
    FOUND=1
    echo "📍 Ditemukan di Crontab User ($(whoami)):"
    while IFS= read -r line; do
        read -r m h dom mon dow cmd <<< "$line"
        HUMAN_TIME=$(parse_cron_time "$m" "$h" "$dom" "$mon" "$dow")
        echo "   ------------------------------------------------------"
        echo "   Baris Asli           : $line"
        echo "   ⏰ Jadwal Eksekusi   : $HUMAN_TIME"
        echo "   👤 Dijalankan Sebagai: $(whoami)"
        estimate_next_run "$m" "$h" "$dom" "$mon" "$dow"
    done <<< "$USER_CRON"
    echo ""
fi

# 4. Periksa folder /var/spool/cron/crontabs jika readable
if [ -r /var/spool/cron/crontabs ]; then
    for f in /var/spool/cron/crontabs/*; do
        [ -f "$f" ] || continue
        MATCHES=$(grep -v '^[[:space:]]*#' "$f" 2>/dev/null | grep "$TARGET")
        if [ -n "$MATCHES" ]; then
            FOUND=1
            u=$(basename "$f")
            echo "📍 Ditemukan di Crontab User spool ($u):"
            while IFS= read -r line; do
                read -r m h dom mon dow cmd <<< "$line"
                HUMAN_TIME=$(parse_cron_time "$m" "$h" "$dom" "$mon" "$dow")
                echo "   ------------------------------------------------------"
                echo "   Baris Asli           : $line"
                echo "   ⏰ Jadwal Eksekusi   : $HUMAN_TIME"
                echo "   👤 Dijalankan Sebagai: $u"
                estimate_next_run "$m" "$h" "$dom" "$mon" "$dow"
            done <<< "$MATCHES"
            echo ""
        fi
    done
fi

# 5. Periksa direktori periodik (/etc/cron.hourly, daily, etc)
for crondir in /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly; do
    if [ -d "$crondir" ]; then
        for f in "$crondir"/*; do
            [ -f "$f" ] || continue
            if grep -q "$TARGET" "$f" 2>/dev/null || [[ "$f" == *"$TARGET"* ]]; then
                FOUND=1
                echo "📍 Ditemukan di Direktori Periodik: $f"
                echo "   ⏰ Jadwal Eksekusi   : Sesuai jadwal $(basename "$crondir") sistem"
                echo ""
            fi
        done
    fi
done

# 6. Periksa Systemd Timer jika ada
SYSTEMD_CHECK=$(systemctl list-timers --all 2>/dev/null | grep "$TARGET")
if [ -n "$SYSTEMD_CHECK" ]; then
    FOUND=1
    echo "📍 Ditemukan di Systemd Timer:"
    echo "   $SYSTEMD_CHECK"
    echo ""
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_PATH="$SCRIPT_DIR/$TARGET"
[ ! -f "$TARGET_PATH" ] && TARGET_PATH="/opt/monitor_server/$TARGET"

DEFAULT_HOUR="${CRON_HOUR:-17}"
DEFAULT_MIN="${CRON_MIN:-00}"

if [ $FOUND -eq 0 ]; then
    echo "❌ Tidak ditemukan cron job untuk '$TARGET'."
    echo ""
    echo "➕ Menambahkan jadwal otomatis ke /etc/crontab (Jadwal: Setiap hari pukul $DEFAULT_HOUR:$DEFAULT_MIN)..."
    CRON_LINE="$DEFAULT_MIN $DEFAULT_HOUR * * * root $TARGET_PATH"

    if [ -w /etc/crontab ]; then
        echo "$CRON_LINE" >> /etc/crontab
        echo "✅ Berhasil menambahkan baris ke /etc/crontab:"
        echo "   $CRON_LINE"
        estimate_next_run "$DEFAULT_MIN" "$DEFAULT_HOUR" "*" "*" "*"
    elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
        echo "$CRON_LINE" | sudo tee -a /etc/crontab >/dev/null
        echo "✅ Berhasil menambahkan baris ke /etc/crontab (via sudo):"
        echo "   $CRON_LINE"
        estimate_next_run "$DEFAULT_MIN" "$DEFAULT_HOUR" "*" "*" "*"
    else
        echo "⚠️  Izin ditolak: Menulis ke /etc/crontab memerlukan hak akses root."
        echo "   Silakan jalankan script ini dengan sudo:"
        echo "   sudo $0 $TARGET"
        echo ""
        echo "   Atau tambahkan baris berikut secara manual ke /etc/crontab:"
        echo "   $CRON_LINE"
    fi
    echo ""
fi

# 7. Riwayat Eksekusi dari Log
echo "=========================================================="
echo "📜 Riwayat Eksekusi Terakhir (dari log sistem):"
echo "=========================================================="
LAST_LOG=$(grep -h "CRON.*$TARGET" /var/log/syslog* /var/log/cron* 2>/dev/null | tail -n 5)
if [ -n "$LAST_LOG" ]; then
    echo "$LAST_LOG"
else
    echo "   (Belum ada riwayat tercatat di /var/log/syslog atau log telah dirotasi)"
fi
echo "=========================================================="
