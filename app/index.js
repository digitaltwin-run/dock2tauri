// Tauri API imports
const { invoke } = window.__TAURI__.tauri;
const { platform, arch, version } = window.__TAURI__.os;
const { appName, appVersion } = window.__TAURI__.app;
const { open } = window.__TAURI__.shell;

// DOM elements
const output = document.getElementById('output');
const dockerInfoBtn = document.getElementById('docker-info-btn');
const systemInfoBtn = document.getElementById('system-info-btn');
const refreshBtn = document.getElementById('refresh-btn');
const launchCustomBtn = document.getElementById('launch-custom');
const presetBtns = document.querySelectorAll('.preset-btn');
const containersList = document.getElementById('containers-list');

// Active containers store
let activeContainers = [];

// Utility functions
function updateOutput(message, type = 'info') {
    output.innerHTML = message;
    output.className = `output-${type}`;
}

function showSuccess(message) {
    updateOutput(`✅ ${message}`, 'success');
}

function showError(message) {
    updateOutput(`❌ ${message}`, 'error');
}

function showInfo(message) {
    updateOutput(`ℹ️ ${message}`, 'info');
}

// Docker container management
async function launchContainer(image, hostPort, containerPort) {
    try {
        showInfo(`Launching ${image} on port ${hostPort}...`);
        
        const result = await invoke('launch_docker_container', {
            image: image,
            hostPort: parseInt(hostPort),
            containerPort: parseInt(containerPort)
        });
        
        if (result.success) {
            showSuccess(`Container ${image} launched successfully!\nContainer ID: ${result.containerId}\nAccess at: http://localhost:${hostPort}`);
            await refreshContainers();
            
            // Auto-open in external browser after 3 seconds
            setTimeout(() => {
                open(`http://localhost:${hostPort}`);
            }, 3000);
        } else {
            showError(`Failed to launch container: ${result.error}`);
        }
    } catch (error) {
        showError(`Launch failed: ${error}`);
    }
}

async function stopContainer(containerId) {
    try {
        showInfo(`Stopping container ${containerId}...`);
        
        const result = await invoke('stop_docker_container', {
            containerId: containerId
        });
        
        if (result.success) {
            showSuccess(`Container stopped successfully!`);
            await refreshContainers();
        } else {
            showError(`Failed to stop container: ${result.error}`);
        }
    } catch (error) {
        showError(`Stop failed: ${error}`);
    }
}

async function getDockerContainers() {
    try {
        const result = await invoke('get_docker_containers');
        return result.containers || [];
    } catch (error) {
        console.error('Failed to get containers:', error);
        return [];
    }
}

async function refreshContainers() {
    try {
        activeContainers = await getDockerContainers();
        renderContainers();
    } catch (error) {
        console.error('Failed to refresh containers:', error);
    }
}

function renderContainers() {
    if (activeContainers.length === 0) {
        containersList.innerHTML = '<div class="empty-state">No active containers</div>';
        return;
    }
    
    const containersHtml = activeContainers.map(container => `
        <div class="container-card">
            <div class="container-header">
                <span class="container-name">${container.name || container.image}</span>
                <span class="container-status status-${container.status.toLowerCase()}">${container.status}</span>
            </div>
            <div class="container-info">
                <strong>Image:</strong> ${container.image}<br>
                <strong>Ports:</strong> ${container.ports}<br>
                <strong>Created:</strong> ${container.created}
            </div>
            <div class="container-actions">
                <button class="btn-small btn-stop" onclick="stopContainer('${container.id}')">
                    🛑 Stop
                </button>
                ${container.ports.includes('->') ? `
                    <button class="btn-small btn-open" onclick="openContainer('${container.ports}')">
                        🌐 Open
                    </button>
                ` : ''}
            </div>
        </div>
    `).join('');
    
    containersList.innerHTML = containersHtml;
}

async function openContainer(portsStr) {
    // Extract host port from ports string like "0.0.0.0:8088->80/tcp"
    const match = portsStr.match(/(\d+)->/);
    if (match) {
        const port = match[1];
        await open(`http://localhost:${port}`);
    }
}

// Event listeners
presetBtns.forEach(btn => {
    btn.addEventListener('click', () => {
        const image = btn.dataset.image;
        const hostPort = btn.dataset.host;
        const containerPort = btn.dataset.container;
        launchContainer(image, hostPort, containerPort);
    });
});

launchCustomBtn.addEventListener('click', () => {
    const image = document.getElementById('docker-image').value;
    const hostPort = document.getElementById('host-port').value;
    const containerPort = document.getElementById('container-port').value;
    
    if (!image || !hostPort || !containerPort) {
        showError('Please fill in all fields');
        return;
    }
    
    launchContainer(image, hostPort, containerPort);
});

dockerInfoBtn.addEventListener('click', async () => {
    try {
        showInfo('Getting Docker information...');
        const result = await invoke('get_docker_info');
        
        if (result.success) {
            const info = result.info;
            updateOutput(`
🐳 Docker System Information:
• Version: ${info.version}
• API Version: ${info.apiVersion}
• OS: ${info.os}
• Architecture: ${info.architecture}
• Total Memory: ${info.memory}
• CPUs: ${info.cpus}
• Containers Running: ${info.containersRunning}
• Containers Total: ${info.containersTotal}
• Images: ${info.images}
            `, 'success');
        } else {
            showError(`Docker info failed: ${result.error}`);
        }
    } catch (error) {
        showError(`Failed to get Docker info: ${error}`);
    }
});

systemInfoBtn.addEventListener('click', async () => {
    try {
        showInfo('Getting system information...');
        const [platformName, archName, osVersion, name, appVer] = await Promise.all([
            platform(),
            arch(),
            version(),
            appName(),
            appVersion()
        ]);
        
        updateOutput(`
💻 System Information:
• Platform: ${platformName}
• Architecture: ${archName}
• OS Version: ${osVersion}
• App Name: ${name}
• App Version: ${appVer}
• User Agent: ${navigator.userAgent}
• Screen: ${screen.width}x${screen.height}
        `, 'success');
    } catch (error) {
        showError(`Failed to get system info: ${error}`);
    }
});

refreshBtn.addEventListener('click', async () => {
    showInfo('Refreshing containers...');
    await refreshContainers();
    showSuccess('Containers refreshed!');
});

// Initialize app
document.addEventListener('DOMContentLoaded', async () => {
    showInfo('🚀 TauriDock Control Panel ready!\n\nSelect a preset or configure a custom Docker container to launch as a desktop app.');
    
    // Initial containers refresh
    await refreshContainers();
    
    // Set up periodic refresh every 30 seconds
    setInterval(refreshContainers, 30000);
});

// Make functions globally available for onclick handlers
window.stopContainer = stopContainer;
window.openContainer = openContainer;
