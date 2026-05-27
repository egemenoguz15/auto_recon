document.addEventListener('DOMContentLoaded', () => {
    const domainInput = document.getElementById('target-domain');
    const startBtn = document.getElementById('start-btn');
    const statusCard = document.getElementById('status-card');
    const statusPhase = document.getElementById('status-phase');
    const statusMessage = document.getElementById('status-message');
    const statusTime = document.getElementById('status-time');
    const loader = document.querySelector('.loader');
    
    const resultsPanel = document.getElementById('results-panel');
    const statSubdomains = document.getElementById('stat-subdomains');
    const statLive = document.getElementById('stat-live');
    const statEyewitness = document.getElementById('stat-eyewitness');
    
    const btnViewLive = document.getElementById('btn-view-live');
    const btnViewEyewitness = document.getElementById('btn-view-eyewitness');
    const listPanel = document.getElementById('list-panel');
    const subdomainList = document.getElementById('subdomain-list');

    let pollingInterval = null;
    let currentDomain = '';

    startBtn.addEventListener('click', async () => {
        const domain = domainInput.value.trim();
        if (!domain) {
            alert('Lütfen geçerli bir domain girin.');
            return;
        }

        currentDomain = domain;
        
        // UI Reset
        statusCard.classList.remove('hidden');
        resultsPanel.classList.add('hidden');
        listPanel.classList.add('hidden');
        statusPhase.textContent = 'Başlatılıyor...';
        statusMessage.textContent = 'İstek sunucuya iletiliyor.';
        loader.style.display = 'block';
        startBtn.disabled = true;
        startBtn.style.opacity = '0.5';

        try {
            const res = await fetch('/start_recon', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ domain })
            });
            const data = await res.json();
            
            if (res.ok) {
                // Start polling status
                if (pollingInterval) clearInterval(pollingInterval);
                pollingInterval = setInterval(pollStatus, 2000);
            } else {
                showError(data.error);
            }
        } catch (error) {
            showError('Sunucuya bağlanılamadı.');
        }
    });

    async function pollStatus() {
        try {
            const res = await fetch(`/status/${currentDomain}`);
            if (res.ok) {
                const data = await res.json();
                statusPhase.textContent = data.phase;
                statusMessage.textContent = data.message;
                
                if (data.timestamp) {
                    const time = new Date(data.timestamp);
                    statusTime.textContent = time.toLocaleTimeString();
                }

                if (data.phase === 'Tamamlandı') {
                    clearInterval(pollingInterval);
                    loader.style.display = 'none';
                    startBtn.disabled = false;
                    startBtn.style.opacity = '1';
                    fetchResults();
                }
            }
        } catch (error) {
            console.error('Statü okunamadı:', error);
        }
    }

    async function fetchResults() {
        try {
            const res = await fetch(`/results/${currentDomain}`);
            if (res.ok) {
                const data = await res.json();
                
                // Show results panel
                resultsPanel.classList.remove('hidden');
                
                // Update stats
                statSubdomains.textContent = data.subdomains.length;
                statLive.textContent = data.live_subdomains.length;
                
                if (data.has_eyewitness) {
                    statEyewitness.textContent = 'Ready';
                    statEyewitness.style.color = 'var(--success)';
                    btnViewEyewitness.classList.remove('disabled');
                    btnViewEyewitness.href = `/eyewitness/${currentDomain}/report.html`;
                } else {
                    statEyewitness.textContent = 'None';
                    btnViewEyewitness.classList.add('disabled');
                    btnViewEyewitness.href = '#';
                }

                // Populate list
                subdomainList.innerHTML = '';
                data.live_subdomains.forEach(sub => {
                    const li = document.createElement('li');
                    li.textContent = sub;
                    subdomainList.appendChild(li);
                });
            }
        } catch (error) {
            console.error('Sonuçlar alınamadı:', error);
        }
    }

    btnViewLive.addEventListener('click', () => {
        listPanel.classList.toggle('hidden');
    });

    function showError(msg) {
        statusPhase.textContent = 'Hata';
        statusPhase.style.color = 'var(--danger)';
        statusMessage.textContent = msg;
        loader.style.display = 'none';
        startBtn.disabled = false;
        startBtn.style.opacity = '1';
        if (pollingInterval) clearInterval(pollingInterval);
    }
});
