#!/bin/bash
# ========================================================
#               GitHub: https://github.com/egemenoguz15
# ========================================================

# ---------- Renk Tanımları ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ---------- Yardım / Parametre Kontrol ----------
if [ -z "$1" ]; then
    echo -e "${YELLOW}[!] Kullanım: $0 <hedef-domain>${NC}"
    exit 1
fi

url=$1

# ---------- Loglama ----------
mkdir -p "$url/recon" 2>/dev/null
exec > >(tee -a "$url/recon/recon_$(date +'%Y%m%d_%H%M%S').log") 2>&1

echo -e "${CYAN}[*] $(date +'%Y-%m-%d %H:%M:%S') – Recon başlatılıyor...${NC}"

# ---------- Araç Kontrolleri ----------
deps=(assetfinder amass sublist3r httprobe waybackurls whatweb)
for tool in "${deps[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
        echo -e "${RED}[-] $tool bulunamadı, kurulumu yapmadan devam edilemez.${NC}"
        exit 1
    fi
done
if ! find / -type f -name 'EyeWitness.py' -print -quit 2>/dev/null | grep -q .; then
    echo -e "${RED}[-] EyeWitness bulunamadı, kurulumu yapmadan devam edilemez.${NC}"
    exit 1
fi

# ---------- Klasör & Dosya Yapısı ----------
mkdir -p "$url/recon/{3rd-lvls,scans,httprobe,potential_takeovers,wayback/{params,extensions},whatweb}"

touch "$url/recon/all_discovered_subdomains.txt"      # eski final.txt
touch "$url/recon/httprobe/live_subdomains.txt"       # eski alive.txt
touch "$url/recon/3rd-lvls/3rd-lvl-domains.txt"

# ---------- Subdomain Toplama ----------
echo -e "${GREEN}[+] $(date +'%H:%M:%S') – assetfinder ile subdomain aranıyor...${NC}"
assetfinder "$url" | grep ".$url" | sort -u >> "$url/recon/all_discovered_subdomains.txt"

echo -e "${GREEN}[+] $(date +'%H:%M:%S') – amass ile ek subdomain araması...${NC}"
amass enum -d "$url" >> "$url/recon/all_discovered_subdomains.txt"

echo -e "${GREEN}[+] $(date +'%H:%M:%S') – certspotter (API) ile kontrol...${NC}"
certspotter >> "$url/recon/all_discovered_subdomains.txt"

sort -u "$url/recon/all_discovered_subdomains.txt" -o "$url/recon/all_discovered_subdomains.txt"

# ---------- 3. Seviye Domain Tespiti ----------
echo -e "${GREEN}[+] 3. seviye domainler çıkarılıyor...${NC}"
grep -Po '(\w+\.\w+\.\w+)$' "$url/recon/all_discovered_subdomains.txt" | sort -u \
    > "$url/recon/3rd-lvls/3rd-lvl-domains.txt"

echo -e "${GREEN}[+] 3. seviye domainlerde sublist3r çalıştırılıyor...${NC}"
while read -r domain; do
    sublist3r -d "$domain" -o "$url/recon/3rd-lvls/$domain.txt"
    cat "$url/recon/3rd-lvls/$domain.txt" >> "$url/recon/all_discovered_subdomains.txt"
done < "$url/recon/3rd-lvls/3rd-lvl-domains.txt"
sort -u "$url/recon/all_discovered_subdomains.txt" -o "$url/recon/all_discovered_subdomains.txt"

# ---------- Canlı Domainler ----------
echo -e "${GREEN}[+] httprobe ile aktif domainler kontrol ediliyor...${NC}"
cat "$url/recon/all_discovered_subdomains.txt" | httprobe -s -p https:443 \
    | sed 's/https\?:\/\///;s/:443//' | sort -u > "$url/recon/httprobe/live_subdomains.txt"

# ---------- Subdomain Takeover ----------
echo -e "${GREEN}[+] Olası subdomain takeover tespiti...${NC}"
subjack -w "$url/recon/httprobe/live_subdomains.txt" -t 100 -timeout 30 -ssl \
    -c ~/go/src/github.com/haccer/subjack/fingerprints.json -v 3 \
    > "$url/recon/potential_takeovers/potential_takeovers.txt"

# ---------- WhatWeb ----------
echo -e "${GREEN}[+] WhatWeb taraması başlıyor...${NC}"
while read -r domain; do
    out_dir="$url/recon/whatweb/$domain"
    mkdir -p "$out_dir"
    whatweb --info-plugins -t 50 -v "$domain" \
        > "$out_dir/detected_plugins.txt"
    whatweb -t 50 -v "$domain" \
        > "$out_dir/output.txt"
done < "$url/recon/httprobe/live_subdomains.txt"

# ---------- Wayback ----------
echo -e "${GREEN}[+] Wayback Machine verileri indiriliyor...${NC}"
wayback_file="$url/recon/wayback/archived_urls.txt"
cat "$url/recon/all_discovered_subdomains.txt" | waybackurls | sort -u > "$wayback_file"

echo -e "${GREEN}[+] URL parametreleri ayrıştırılıyor...${NC}"
grep '?.*=' "$wayback_file" | cut -d '=' -f1 | sort -u \
    > "$url/recon/wayback/params/wayback_params.txt"

echo -e "${GREEN}[+] Belirli uzantılara göre ayırma...${NC}"
while read -r line; do
    ext="${line##*.}"
    case "$ext" in
        js)   echo "$line" >> "$url/recon/wayback/extensions/js.txt"   ;;
        html) echo "$line" >> "$url/recon/wayback/extensions/jsp.txt"  ;;
        json) echo "$line" >> "$url/recon/wayback/extensions/json.txt" ;;
        php)  echo "$line" >> "$url/recon/wayback/extensions/php.txt"  ;;
        aspx) echo "$line" >> "$url/recon/wayback/extensions/aspx.txt" ;;
    esac
done < "$wayback_file"

# ---------- Nmap ----------
echo -e "${GREEN}[+] nmap ile port taraması...${NC}"
nmap -iL "$url/recon/httprobe/live_subdomains.txt" -T4 \
    -oA "$url/recon/scans/ports"

# ---------- EyeWitness ----------
echo -e "${GREEN}[+] EyeWitness ile ekran görüntüsü alınıyor...${NC}"
eyepath=$(find / -type f -name 'EyeWitness.py' -print -quit 2>/dev/null)
python3 "$eyepath" --web -f "$url/recon/httprobe/live_subdomains.txt" \
        -d "$url/recon/eyewitness" --resolve --no-prompt

echo -e "${CYAN}[*] $(date +'%Y-%m-%d %H:%M:%S') – Recon tamamlandı.${NC}"
