#!/bin/bash
# ========================================================
#               Automated Reconnaissance System
# ========================================================

# ---------- Renk Tanımları ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ---------- Yardım / Parametre Kontrol ----------
if [ -z "$1" ]; then
    echo -e "${YELLOW}[!] Kullanım: $0 <hedef-domain>${NC}"
    exit 1
fi

url=$1
base_dir="$(pwd)/$url/recon"
status_file="$base_dir/status.json"

# ---------- Loglama ----------
mkdir -p "$base_dir" 2>/dev/null
exec > >(tee -a "$base_dir/recon_$(date +'%Y%m%d_%H%M%S').log") 2>&1

update_status() {
    local phase="$1"
    local message="$2"
    # Sadece basit bir JSON dosyası oluşturuyoruz ki Flask okuyabilsin
    echo "{\"phase\": \"$phase\", \"message\": \"$message\", \"timestamp\": \"$(date -Iseconds)\"}" > "$status_file"
    echo -e "${CYAN}[*] $(date +'%Y-%m-%d %H:%M:%S') – $message${NC}"
}

update_status "Başlangıç" "Recon başlatılıyor: $url"

# ---------- Araç Kontrolleri ----------
update_status "Kontrol" "Araç bağımlılıkları kontrol ediliyor..."
deps=(assetfinder amass sublist3r httprobe waybackurls whatweb subjack nmap)
for tool in "${deps[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
        echo -e "${RED}[-] $tool bulunamadı, lütfen kurun.${NC}"
        # Arayüzün çökmemesi için sadece uyarı veriyoruz, devam edilebilir.
    fi
done

# Hızlı Path Bulma (Tüm diski aramak yerine yaygın dizinlere bakıyoruz)
find_tool() {
    local tool_name=$1
    local default_paths=("/usr/share/$tool_name" "/opt/$tool_name" "$HOME/go/src/github.com/haccer/subjack" "$HOME/$tool_name")
    for path in "${default_paths[@]}"; do
        if [ -d "$path" ] || [ -f "$path" ]; then
            echo "$path"
            return
        fi
    done
    # Eğer bulunamazsa sistem genelinde hızlı bir locate (veritabanı güncelse)
    locate "$tool_name" | head -n 1 2>/dev/null
}

eyepath=$(find_tool "EyeWitness")
if [[ -n "$eyepath" && -d "$eyepath" ]]; then
    eyepath="$eyepath/Python/EyeWitness.py"
elif [[ -z "$eyepath" ]]; then
    # Son çare system-wide arama ama loglarda çok beklemesin diye iptal de edilebilir
    eyepath=$(find /usr /opt $HOME -type f -name 'EyeWitness.py' -print -quit 2>/dev/null)
fi

subjack_fingerprints=$(find_tool "fingerprints.json")
if [[ -z "$subjack_fingerprints" ]]; then
    subjack_fingerprints="$HOME/go/src/github.com/haccer/subjack/fingerprints.json"
fi


# ---------- Klasör & Dosya Yapısı ----------
mkdir -p "$base_dir/{3rd-lvls,scans,httprobe,potential_takeovers,wayback/{params,extensions},whatweb}"

touch "$base_dir/all_discovered_subdomains.txt"
touch "$base_dir/httprobe/live_subdomains.txt"
touch "$base_dir/3rd-lvls/3rd-lvl-domains.txt"

# ---------- Subdomain Toplama ----------
update_status "Subdomain" "assetfinder ile subdomain aranıyor..."
if command -v assetfinder &>/dev/null; then
    assetfinder "$url" | grep ".$url" | sort -u >> "$base_dir/all_discovered_subdomains.txt"
fi

update_status "Subdomain" "amass ile ek subdomain araması..."
if command -v amass &>/dev/null; then
    amass enum -d "$url" >> "$base_dir/all_discovered_subdomains.txt"
fi

# certspotter apisiz patlayabilir, sessizce geç
if command -v certspotter &>/dev/null; then
    certspotter "$url" 2>/dev/null >> "$base_dir/all_discovered_subdomains.txt"
fi

sort -u "$base_dir/all_discovered_subdomains.txt" -o "$base_dir/all_discovered_subdomains.txt"

# ---------- 3. Seviye Domain Tespiti ----------
update_status "Subdomain 3rd Lvl" "3. seviye domainler çıkarılıyor..."
grep -Po '(\w+\.\w+\.\w+)$' "$base_dir/all_discovered_subdomains.txt" | sort -u \
    > "$base_dir/3rd-lvls/3rd-lvl-domains.txt"

if command -v sublist3r &>/dev/null; then
    update_status "Subdomain 3rd Lvl" "sublist3r çalıştırılıyor..."
    while read -r domain; do
        sublist3r -d "$domain" -o "$base_dir/3rd-lvls/$domain.txt"
        cat "$base_dir/3rd-lvls/$domain.txt" >> "$base_dir/all_discovered_subdomains.txt"
    done < "$base_dir/3rd-lvls/3rd-lvl-domains.txt"
fi
sort -u "$base_dir/all_discovered_subdomains.txt" -o "$base_dir/all_discovered_subdomains.txt"

# ---------- Canlı Domainler ----------
update_status "Canlı Domainler" "httprobe ile aktif domainler kontrol ediliyor..."
if command -v httprobe &>/dev/null; then
    cat "$base_dir/all_discovered_subdomains.txt" | httprobe -s -p https:443 -p http:80 \
        | sed 's/https\?:\/\///;s/:443//;s/:80//' | sort -u > "$base_dir/httprobe/live_subdomains.txt"
else
    cp "$base_dir/all_discovered_subdomains.txt" "$base_dir/httprobe/live_subdomains.txt"
fi

# ---------- Subdomain Takeover ----------
update_status "Takeover" "Olası subdomain takeover tespiti..."
if command -v subjack &>/dev/null && [ -f "$subjack_fingerprints" ]; then
    subjack -w "$base_dir/httprobe/live_subdomains.txt" -t 100 -timeout 30 -ssl \
        -c "$subjack_fingerprints" -v 3 \
        > "$base_dir/potential_takeovers/potential_takeovers.txt"
fi

# ---------- WhatWeb ----------
update_status "WhatWeb" "WhatWeb taraması başlıyor..."
if command -v whatweb &>/dev/null; then
    while read -r domain; do
        out_dir="$base_dir/whatweb/$domain"
        mkdir -p "$out_dir"
        whatweb --info-plugins -t 50 -v "$domain" > "$out_dir/detected_plugins.txt" 2>/dev/null
        whatweb -t 50 -v "$domain" > "$out_dir/output.txt" 2>/dev/null
    done < "$base_dir/httprobe/live_subdomains.txt"
fi

# ---------- Wayback ----------
update_status "Wayback" "Wayback Machine verileri indiriliyor..."
if command -v waybackurls &>/dev/null; then
    wayback_file="$base_dir/wayback/archived_urls.txt"
    cat "$base_dir/all_discovered_subdomains.txt" | waybackurls | sort -u > "$wayback_file"

    update_status "Wayback" "URL parametreleri ayrıştırılıyor..."
    grep '?.*=' "$wayback_file" | cut -d '=' -f1 | sort -u \
        > "$base_dir/wayback/params/wayback_params.txt"

    update_status "Wayback" "Belirli uzantılara göre ayırma..."
    while read -r line; do
        ext="${line##*.}"
        case "$ext" in
            js)   echo "$line" >> "$base_dir/wayback/extensions/js.txt"   ;;
            html) echo "$line" >> "$base_dir/wayback/extensions/jsp.txt"  ;;
            json) echo "$line" >> "$base_dir/wayback/extensions/json.txt" ;;
            php)  echo "$line" >> "$base_dir/wayback/extensions/php.txt"  ;;
            aspx) echo "$line" >> "$base_dir/wayback/extensions/aspx.txt" ;;
        esac
    done < "$wayback_file"
fi

# ---------- Nmap ----------
update_status "Port Taraması" "nmap ile hızlı port taraması..."
if command -v nmap &>/dev/null; then
    nmap -iL "$base_dir/httprobe/live_subdomains.txt" -T4 --top-ports 100 \
        -oA "$base_dir/scans/ports"
fi

# ---------- EyeWitness ----------
update_status "Ekran Görüntüleri" "EyeWitness ile ekran görüntüsü alınıyor..."
if [[ -n "$eyepath" && -f "$eyepath" ]]; then
    python3 "$eyepath" --web -f "$base_dir/httprobe/live_subdomains.txt" \
            -d "$base_dir/eyewitness" --resolve --no-prompt
else
    echo -e "${YELLOW}[!] EyeWitness.py bulunamadı, ekran görüntüsü alınamıyor.${NC}"
fi

update_status "Tamamlandı" "Recon işlemi başarıyla bitirildi."
echo -e "${CYAN}[*] $(date +'%Y-%m-%d %H:%M:%S') – Recon tamamlandı.${NC}"

