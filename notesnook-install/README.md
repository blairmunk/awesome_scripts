# Notesnook Self-Hosted Server - One-Click Installer

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Script-blue.svg)](https://en.wikipedia.org/wiki/Shell_script)
[![Notesnook](https://img.shields.io/badge/Notesnook-Self--Hosted-green.svg)](https://github.com/streetwriters/notesnook-sync-server)

Automated installation script for deploying your own [Notesnook](https://notesnook.com/) sync server with Docker, complete SSL configuration, and web interface.

## About

This script automates the complete setup of a self-hosted Notesnook synchronization server, based on the [community guide](https://lemmy.world/post/24509570). It includes:

- **Full Docker stack** (MongoDB, MinIO, Identity Server, Sync Server, SSE Server, Monograph)
- **Automatic SSL certificate** generation with Let's Encrypt
- **Nginx reverse proxy** configuration with WebSocket support
- **Optional web interface** for easy client access
- **Management utilities** for monitoring, backup, and updates
- **One-command installation** with interactive configuration

## Quick Start

```bash
# Download and run the installer
curl -fsSL https://raw.githubusercontent.com/yourusername/notesnook-installer/main/install-notesnook.sh -o install-notesnook.sh
chmod +x install-notesnook.sh
./install-notesnook.sh
```

## Prerequisites

### System Requirements

- **Operating System**: Ubuntu 20.04+ or Debian 11+ (tested)
- **CPU**: 1+ cores (x86_64 or ARM64)
- **RAM**: 1GB minimum (2GB recommended)
- **Storage**: 20GB+ free space
- **Network**: Public IP address with internet access


## Before Running the Script

### 1. Domain and DNS Setup

You'll need a domain with the ability to create subdomains. Create the following A records pointing to your server's IP:

```
auth.yourdomain.com    A    YOUR_SERVER_IP
notes.yourdomain.com   A    YOUR_SERVER_IP
events.yourdomain.com  A    YOUR_SERVER_IP
mono.yourdomain.com    A    YOUR_SERVER_IP
files.yourdomain.com   A    YOUR_SERVER_IP
```

**Optional**: If you want a custom web interface subdomain:

```
nook.yourdomain.com    A    YOUR_SERVER_IP
```

### 2. SMTP Configuration

Prepare SMTP credentials for email functionality (required for user authentication):

- **Gmail**: Use App Passwords
- **Other providers**: Ensure SMTP settings are ready

### 3. Firewall Considerations

The script will configure UFW firewall, but ensure your cloud provider/hosting allows:

- **HTTP/HTTPS** (ports 80, 443)
- **SSH** (port 22)
- **Notesnook ports** (5264, 6264, 7264, 8264, 9009, 9090)

### 4. User Permissions

- Run as a **non-root user** with **sudo privileges**
- The script will handle Docker group permissions

## Installation Process

### Step 1: Download and Execute

```bash
wget https://raw.githubusercontent.com/yourusername/notesnook-installer/main/install-notesnook.sh
chmod +x install-notesnook.sh
./install-notesnook.sh
```