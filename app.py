from flask import Flask, render_template, request, jsonify, send_from_directory
import subprocess
import os
import json
import psutil

app = Flask(__name__)

# Base directory for the recon script
BASE_DIR = os.path.dirname(os.path.abspath(__name__))
SCRIPT_PATH = os.path.join(BASE_DIR, "automation_enum.sh")

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/start_recon', methods=['POST'])
def start_recon():
    data = request.json
    domain = data.get('domain')
    
    if not domain:
        return jsonify({"error": "Lütfen geçerli bir domain girin."}), 400
        
    try:
        # Start bash script in background
        process = subprocess.Popen(['bash', SCRIPT_PATH, domain], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return jsonify({"message": f"Tarama başlatıldı: {domain}", "pid": process.pid}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/status/<domain>', methods=['GET'])
def get_status(domain):
    status_file = os.path.join(BASE_DIR, domain, 'recon', 'status.json')
    if os.path.exists(status_file):
        try:
            with open(status_file, 'r') as f:
                data = json.load(f)
                return jsonify(data)
        except Exception:
            return jsonify({"phase": "Bilinmiyor", "message": "Statü dosyası okunamadı."})
    return jsonify({"phase": "Bekleniyor", "message": "Henüz veri yok."})

@app.route('/results/<domain>', methods=['GET'])
def get_results(domain):
    recon_dir = os.path.join(BASE_DIR, domain, 'recon')
    
    if not os.path.exists(recon_dir):
        return jsonify({"error": "Sonuç bulunamadı."}), 404
        
    results = {
        "subdomains": [],
        "live_subdomains": [],
        "ports": []
    }
    
    subdomains_file = os.path.join(recon_dir, 'all_discovered_subdomains.txt')
    if os.path.exists(subdomains_file):
        with open(subdomains_file, 'r') as f:
            results['subdomains'] = [line.strip() for line in f.readlines() if line.strip()]
            
    live_file = os.path.join(recon_dir, 'httprobe', 'live_subdomains.txt')
    if os.path.exists(live_file):
        with open(live_file, 'r') as f:
            results['live_subdomains'] = [line.strip() for line in f.readlines() if line.strip()]
            
    # EyeWitness screenshots are available as an HTML report
    # We can serve it directly
    eyewitness_dir = os.path.join(recon_dir, 'eyewitness')
    has_eyewitness = os.path.exists(eyewitness_dir)
    results['has_eyewitness'] = has_eyewitness
            
    return jsonify(results)

@app.route('/eyewitness/<domain>/<path:filename>')
def serve_eyewitness(domain, filename):
    eyewitness_dir = os.path.join(BASE_DIR, domain, 'recon', 'eyewitness')
    return send_from_directory(eyewitness_dir, filename)

if __name__ == '__main__':
    # Make script executable
    if os.path.exists(SCRIPT_PATH):
        os.chmod(SCRIPT_PATH, 0o755)
    app.run(host='0.0.0.0', port=5000, debug=True)
