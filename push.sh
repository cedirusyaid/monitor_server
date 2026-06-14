#!/bin/bash

# ==========================================================================
# GIT PUSH HELPER SCRIPT
# Format Commit: YYMMDD - [Tipe]: Deskripsi
# ==========================================================================

# 1. Pastikan ini adalah repository Git
if [ ! -d .git ]; then
    echo "❌ Error: Ini bukan repository Git!"
    exit 1
fi

# 2. Deteksi branch aktif
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -z "$BRANCH" ]; then
    BRANCH="main"
fi

# 3. Format Tanggal YYMMDD
DATE=$(date '+%y%m%d')

# 4. Ambil argumen tipe commit atau minta input
TYPE_INPUT=""
DESC=""

if [ ! -z "$1" ] && [ ! -z "$2" ]; then
    # Jika dipanggil non-interaktif: ./push.sh "Added" "Deskripsi komit"
    TYPE_INPUT="$1"
    DESC="$2"
else
    # Jika dipanggil interaktif
    echo "=============================================="
    echo "🚀 GIT PUSH HELPER"
    echo "=============================================="
    echo "Pilih Tipe Commit:"
    echo "1) ✨ Added (Fitur baru)"
    echo "2) 🐛 Fixed (Perbaikan bug)"
    echo "3) 🔄 Changed (Refactoring / optimasi)"
    echo "4) 🛡️ Security (Patch keamanan)"
    read -p "Masukkan pilihan (1-4) [3]: " CHOICE
    
    case $CHOICE in
        1) TYPE_INPUT="Added" ;;
        2) TYPE_INPUT="Fixed" ;;
        4) TYPE_INPUT="Security" ;;
        *) TYPE_INPUT="Changed" ;;
    esac
    
    read -p "Masukkan deskripsi perubahan: " DESC
fi

# Format tipe commit dengan tanda kurung siku
TYPE="[$TYPE_INPUT]"

# 5. Gabungkan pesan commit
COMMIT_MSG="$DATE - $TYPE: $DESC"

echo "----------------------------------------------"
echo "📝 Pesan Commit: '$COMMIT_MSG'"
echo "🌿 Branch Tujuan: '$BRANCH'"
echo "----------------------------------------------"

# Jalankan git commit & push
git add .
git commit -m "$COMMIT_MSG"
git push origin "$BRANCH"

echo "----------------------------------------------"
echo "✅ Push selesai dilakukan!"
