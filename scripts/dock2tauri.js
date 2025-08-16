#!/usr/bin/env node

/**
 * Dock2Tauri Node.js Launcher
 * Transform any Docker container into a native desktop application using Tauri.
 * 
 * Usage: node dock2tauri.js <docker-image> <host-port> <container-port>
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawn, exec } = require('child_process');
const http = require('http');
const { promisify } = require('util');

// Colors for console output
const colors = {
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    reset: '\x1b[0m'
};

// Logger utility
const logger = {
    info: (msg) => console.log(`${colors.blue}ℹ️  ${msg}${colors.reset}`),
    success: (msg) => console.log(`${colors.green}✅ ${msg}${colors.reset}`),
    error: (msg) => console.log(`${colors.red}❌ ${msg}${colors.reset}`),
    warning: (msg) => console.log(`${colors.yellow}⚠️  ${msg}${colors.reset}`)
};

class Dock2Tauri {
    constructor(image, hostPort, containerPort, buildRelease = false, buildTarget = null) {
        this.image = image || 'nginx:alpine';
        this.hostPort = String(hostPort || 8088);
        this.containerPort = String(containerPort || 80);
        this.containerName = `dock2tauri-${this.image.replace(/[^a-zA-Z0-9]/g, '-')}-${this.hostPort}`;
        this.containerId = null;
        this.scriptDir = __dirname;
        this.buildRelease = buildRelease;
        this.buildTarget = buildTarget;
        this.healthUrl = null;
        this.timeout = 30;
        this.tauriConfigPath = null;
    }

    /**
     * Check if required dependencies are available
     */
    async checkDependencies() {
        logger.info('Checking dependencies...');

        try {
            // Check Docker
            await this.execCommand('docker --version');
            
            // Check if Docker daemon is running
            await this.execCommand('docker info');
            
            // Check Rust/Cargo (optional)
            try {
                await this.execCommand('cargo --version');
            } catch (e) {
                logger.warning('Rust/Cargo not found. Some features may not work.');
            }

            logger.success('Dependencies check passed');
            return true;
        } catch (error) {
            if (error.message.includes('docker')) {
                logger.error('Docker not found or not running. Please install and start Docker.');
            } else {
                logger.error(`Dependency check failed: ${error.message}`);
            }
            return false;
        }
    }

    /**
     * Execute shell command and return result
     */
    execCommand(command) {
        return new Promise((resolve, reject) => {
            exec(command, (error, stdout, stderr) => {
                if (error) {
                    reject(new Error(stderr || error.message));
                } else {
                    resolve(stdout.trim());
                }
            });
        });
    }

    /**
     * Stop existing containers using the same port
     */
    async stopExistingContainers() {
        logger.info(`Stopping existing containers on port ${this.hostPort}...`);

        try {
            // Get containers using the same port
            const result = await this.execCommand(`docker ps -q --filter "publish=${this.hostPort}"`);
            
            if (result) {
                const containerIds = result.split('\n').filter(id => id.trim());
                for (const containerId of containerIds) {
                    await this.execCommand(`docker stop ${containerId}`);
                }
                logger.success('Stopped existing containers');
            }

            // Remove old container with same name
            try {
                const containers = await this.execCommand(`docker ps -a --filter "name=${this.containerName}"`);
                if (containers.includes(this.containerName)) {
                    await this.execCommand(`docker rm ${this.containerName}`);
                    logger.success(`Removed old container: ${this.containerName}`);
                }
            } catch (e) {
                // Container doesn't exist, which is fine
            }

        } catch (error) {
            logger.warning(`Error during cleanup: ${error.message}`);
        }
    }

    /**
     * If `this.image` is a Dockerfile path, build it and set `this.image` to a local tag.
     */
    async prepareImageOrDockerfile() {
        try {
            if (this.image && fs.existsSync(this.image) && fs.statSync(this.image).isFile()) {
                const dockerfilePath = this.image;
                const ctx = path.dirname(dockerfilePath);
                const base = path.basename(dockerfilePath).toLowerCase().replace(/[^a-z0-9_.-]/g, '-');
                const tag = `dock2tauri-local-${base}-${Date.now()}`;
                logger.info(`Building Docker image from ${dockerfilePath} (context: ${ctx}) as ${tag} ...`);
                await this.execCommand(`docker build -f "${dockerfilePath}" -t "${tag}" "${ctx}"`);
                this.image = tag;
                this.containerName = `dock2tauri-${this.image.replace(/[^a-zA-Z0-9]/g, '-')}-${this.hostPort}`;
            }
        } catch (error) {
            logger.error(`Failed to build Dockerfile: ${error.message}`);
            throw error;
        }
    }

    /**
     * Launch the Docker container
     */
    async launchContainer() {
        logger.info('Launching Docker container...');
        logger.info(`Image: ${this.image}`);
        logger.info(`Host Port: ${this.hostPort}`);
        logger.info(`Container Port: ${this.containerPort}`);

        try {
            const command = [
                'docker', 'run', '-d',
                '-p', `${this.hostPort}:${this.containerPort}`,
                '--name', this.containerName,
                '--restart', 'unless-stopped',
                this.image
            ].join(' ');

            this.containerId = await this.execCommand(command);
            logger.success(`Container launched: ${this.containerId}`);
            logger.success(`Access at: http://localhost:${this.hostPort}`);
            return true;

        } catch (error) {
            logger.error('Failed to launch container');
            logger.error(`Error: ${error.message}`);
            return false;
        }
    }

    /**
     * Wait for service to be ready
     */
    async waitForService() {
        logger.info('Waiting for service to be ready...');

        const url = this.healthUrl || `http://localhost:${this.hostPort}`;
        const timeout = Number(this.timeout) || 30;
        for (let i = 0; i < timeout; i++) {
            try {
                await this.checkUrl(url);
                logger.success('Service is ready!');
                return true;
            } catch (e) {
                process.stdout.write('.');
                await this.sleep(1000);
            }
        }

        console.log(); // New line
        logger.warning('Service might not be ready yet, but continuing...');
        return false;
    }

    /**
     * Check if URL is accessible
     */
    checkUrl(url) {
        return new Promise((resolve, reject) => {
            const request = http.get(url, { timeout: 1000 }, (res) => {
                resolve(res.statusCode === 200);
            });
            
            request.on('error', reject);
            request.on('timeout', () => {
                request.destroy();
                reject(new Error('Timeout'));
            });
        });
    }

    /**
     * Sleep for specified milliseconds
     */
    sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    /**
     * Generate ephemeral Tauri configuration and store its path in this.tauriConfigPath
     */
    generateTauriConfig() {
        logger.info('Preparing Tauri configuration (ephemeral)...');

        const config = {
            "$schema": "../node_modules/@tauri-apps/cli/schema.json",
            "productName": `Dock2Tauri - ${this.image.split(':')[0].replace(/[\/\\:*?"<>|]/g, '')}`,
            "version": "1.0.0",
            "identifier": `com.dock2tauri.${this.image.replace(/[^a-zA-Z0-9]/g, '')}`,
            "build": {
                "beforeBuildCommand": "",
                "beforeDevCommand": "",
                "devUrl": `http://localhost:${this.hostPort}`,
                "frontendDist": "../app"
            },
            "app": {
                "security": {
                    "csp": null
                },
                "windows": [{
                    "title": `Dock2Tauri - ${this.image}`,
                    "width": 1200,
                    "height": 800,
                    "minWidth": 600,
                    "minHeight": 400,
                    "resizable": true,
                    "fullscreen": false
                }]
            },
            "bundle": {
                "active": true,
                "targets": ["appimage", "deb", "rpm"],
                "icon": [],
                "resources": [],
                "externalBin": [],
                "copyright": "",
                "category": "DeveloperTool",
                "shortDescription": "Docker App in Tauri",
                "longDescription": `Running ${this.image} as desktop application`
            },
            "plugins": {}
        };

        const tmpPath = path.join(os.tmpdir(), `tauri.conf.${Date.now()}.${Math.random().toString(36).slice(2)}.json`);
        try {
            fs.writeFileSync(tmpPath, JSON.stringify(config, null, 2));
            this.tauriConfigPath = tmpPath;
            logger.success(`Ephemeral Tauri configuration prepared at ${tmpPath}`);
            return true;
        } catch (error) {
            logger.error(`Failed to prepare Tauri config: ${error.message}`);
            return false;
        }
    }

    /**
     * Launch Tauri application
     */
    async launchTauri() {
        if (this.buildRelease) {
            logger.info('Building Tauri release bundles (cargo tauri build)...');
        } else {
            logger.info('Launching Tauri application (dev)...');
        }

        const tauriDir = path.join(this.scriptDir, '..', 'src-tauri');
        
        return new Promise((resolve, reject) => {
            // Change to tauri directory
            process.chdir(tauriDir);

            // Try Tauri CLI first, then cargo
            let command, args;
            
            // Check if cargo command exists
            exec('which cargo', (error) => {
                if (error) {
                    logger.error('Cargo not found. Please install Rust and Tauri CLI.');
                    logger.info(`Container is running at: http://localhost:${this.hostPort}`);
                    logger.info(`Container ID: ${this.containerId}`);
                    reject(error);
                    return;
                }

                command = 'cargo';
                if (this.buildRelease) {
                    args = ['tauri', 'build'];
                    if (this.buildTarget) {
                        args.push('--target', this.buildTarget);
                    }
                } else {
                    args = ['tauri', 'dev'];
                }

                if (this.tauriConfigPath) {
                    args.push('--config', this.tauriConfigPath);
                }

                const tauriProcess = spawn(command, args, {
                    stdio: 'inherit',
                    shell: true
                });

                tauriProcess.on('error', (error) => {
                    logger.error(`Failed to launch Tauri: ${error.message}`);
                    logger.info(`Container is running at: http://localhost:${this.hostPort}`);
                    logger.info(`Container ID: ${this.containerId}`);
                    reject(error);
                });

                tauriProcess.on('exit', (code) => {
                    if (code === 0) {
                        logger.info('Tauri application exited normally');
                        resolve(true);
                    } else {
                        logger.warning(`Tauri application exited with code ${code}`);
                        resolve(false);
                    }
                });

                // Handle Ctrl+C gracefully
                process.on('SIGINT', () => {
                    logger.info('Application interrupted by user');
                    tauriProcess.kill('SIGINT');
                    resolve(true);
                });
            });
        });
    }

    /**
     * Cleanup resources
     */
    async cleanup() {
        logger.info('Cleaning up...');

        // Stop and remove container
        if (this.containerId) {
            try {
                await this.execCommand(`docker stop ${this.containerId}`);
                await this.execCommand(`docker rm ${this.containerId}`);
                logger.success('Container stopped and removed');
            } catch (error) {
                logger.warning(`Error during container cleanup: ${error.message}`);
            }
        }

        // Remove ephemeral config
        if (this.tauriConfigPath && fs.existsSync(this.tauriConfigPath)) {
            try {
                fs.unlinkSync(this.tauriConfigPath);
                logger.success('Removed ephemeral Tauri config');
            } catch (e) {
                logger.warning(`Failed to remove ephemeral config: ${e.message}`);
            }
        }
    }

    /**
     * Main execution flow
     */
    async run() {
        console.log(`${colors.blue}🐳🦀 Dock2Tauri - Docker to Desktop Bridge${colors.reset}`);
        console.log('==================================================');

        try {
            if (!(await this.checkDependencies())) {
                return false;
            }
            await this.prepareImageOrDockerfile();
            await this.stopExistingContainers();

            if (!(await this.launchContainer())) {
                return false;
            }

            await this.waitForService();
            this.generateTauriConfig();

            // Launch Tauri (this will block until app exits)
            await this.launchTauri();

        } catch (error) {
            if (error.message === 'SIGINT') {
                logger.info('Interrupted by user');
            } else {
                logger.error(`Unexpected error: ${error.message}`);
                return false;
            }
        } finally {
            await this.cleanup();
        }

        return true;
    }
}

/**
 * Show help information
 */
function showHelp() {
    console.log('Dock2Tauri - Docker to Desktop Bridge');
    console.log('');
    console.log('Usage: node dock2tauri.js [IMAGE|Dockerfile] [HOST_PORT] [CONTAINER_PORT] [OPTIONS]');
    console.log('');
    console.log('Arguments:');
    console.log('  IMAGE|Dockerfile  Docker image to run OR path to Dockerfile (default: nginx:alpine)');
    console.log('  HOST_PORT       Host port to bind to (default: 8088)');
    console.log('  CONTAINER_PORT  Container port to expose (default: 80)');
    console.log('');
    console.log('Options:');
    console.log('  --build (-b)       Build Tauri release bundles instead of running dev mode');
    console.log('  --target=<triple>  Pass target triple to cargo tauri build');
    console.log('  --health-url=<url> Override readiness URL (default: http://localhost:HOST_PORT)');
    console.log('  --timeout=<seconds> Readiness timeout in seconds (default: 30)');
    console.log('');
    console.log('Examples:');
    console.log('  node dock2tauri.js nginx:alpine 8088 80');
    console.log('  node dock2tauri.js grafana/grafana 3001 3000 --build');
    console.log('  node dock2tauri.js jupyter/scipy-notebook 8888 8888 --target=x86_64-pc-windows-gnu');
    console.log('');
    console.log('Environment Variables:');
    console.log('  DOCK2TAURI_DEBUG=1    Enable debug mode');
}

/**
 * Main function
 */
async function main() {
    // Parse command line arguments
    const args = process.argv.slice(2);

    // Handle help
    if (args.includes('-h') || args.includes('--help')) {
        showHelp();
        process.exit(0);
    }

    // Handle Ctrl+C gracefully
    process.on('SIGINT', () => {
        console.log('\nReceived SIGINT, cleaning up...');
        process.exit(0);
    });

    // Parse flags
    let buildRelease = false;
    let buildTarget = null;
    let healthUrl = null;
    let timeout = 30;
    const positionalArgs = [];

    for (const arg of args) {
        if (arg === '--build' || arg === '-b') {
            buildRelease = true;
        } else if (arg.startsWith('--target=')) {
            buildTarget = arg.split('=')[1];
        } else if (arg.startsWith('--health-url=')) {
            healthUrl = arg.split('=')[1];
        } else if (arg.startsWith('--timeout=')) {
            const v = parseInt(arg.split('=')[1], 10);
            if (!Number.isNaN(v)) timeout = v;
        } else if (!arg.startsWith('-')) {
            positionalArgs.push(arg);
        }
    }

    // Extract positional arguments
    const [image, hostPort, containerPort] = positionalArgs;

    if (positionalArgs.length === 0) {
        logger.warning('No arguments provided, using defaults');
    }

    console.log(`${colors.blue}🐳🦀 Dock2Tauri - Docker to Desktop Bridge${colors.reset}`);
    console.log('==================================================');

    // Create and run Dock2Tauri instance
    const dock2tauri = new Dock2Tauri(image, hostPort, containerPort, buildRelease, buildTarget);
    if (healthUrl) dock2tauri.healthUrl = healthUrl;
    if (timeout) dock2tauri.timeout = timeout;
    
    try {
        const success = await dock2tauri.run();
        process.exit(success ? 0 : 1);
    } catch (error) {
        logger.error(`Fatal error: ${error.message}`);
        process.exit(1);
    }
}

// Run main function
if (require.main === module) {
    main().catch((error) => {
        logger.error(`Fatal error: ${error.message}`);
        process.exit(1);
    });
}

module.exports = Dock2Tauri;
