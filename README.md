## 🔎 Recon Automation Script

Bu script, hedef bir domain için pasif ve aktif bilgi toplama işlemlerini otomatikleştirmek amacıyla hazırlanmıştır. Subdomain keşfinden canlılık kontrolüne, whatweb analizinden EyeWitness ekran görüntülerine kadar pek çok işlemi tek komutla gerçekleştirir.

### 🚀 Özellikler

* Subdomain toplama (Assetfinder, Amass, Sublist3r, certspotter)
* Canlı subdomain tespiti (httprobe)
* Subdomain takeover kontrolü (subjack)
* Web teknolojileri analizi (WhatWeb)
* Wayback Machine üzerinden geçmiş URL analizi
* Nmap port taraması
* EyeWitness ile ekran görüntüleri
* Renkli çıktılar, zaman damgaları ve log kaydı
* Dosya & klasör yapısında düzenlilik

---

### 📦 Gereken Araçlar

Script'in sorunsuz çalışabilmesi için aşağıdaki araçların kurulu olması gerekir:

| Tool          | Açıklama                          |
| ------------- | --------------------------------- |
| `assetfinder` | Subdomain keşfi                   |
| `amass`       | Gelişmiş subdomain toplama        |
| `sublist3r`   | 3. seviye domain subdomain tarama |
| `httprobe`    | Canlı domain kontrolü             |
| `waybackurls` | WaybackMachine URL arşivi         |
| `whatweb`     | Web teknolojileri tanımlayıcı     |
| `nmap`        | Port tarama                       |
| `subjack`     | Subdomain takeover kontrolü       |
| `EyeWitness`  | Ekran görüntüsü alma aracı        |

Kurulum için çoğu aracı aşağıdaki gibi yükleyebilirsin:

```bash
sudo apt install nmap whatweb

go install github.com/tomnomnom/assetfinder@latest
go install github.com/tomnomnom/httprobe@latest
go install github.com/tomnomnom/waybackurls@latest
go install github.com/haccer/subjack@latest
```

Diğerleri için:

```bash
# Amass
sudo snap install amass

# Sublist3r
git clone https://github.com/aboul3la/Sublist3r.git
cd Sublist3r && pip install -r requirements.txt

# EyeWitness
git clone https://github.com/FortyNorthSecurity/EyeWitness.git
cd EyeWitness && sudo ./setup.sh
```

---

### 🛠 Kullanım

```bash
chmod +x recon.sh
./recon.sh example.com
```

Tüm çıktı ve sonuçlar `example.com/recon/` klasörü altında kaydedilecektir.

---

### ✍️ Yazar

📌 GitHub: [egemenoguz15](https://github.com/egemenoguz15)
