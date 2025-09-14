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
curl -fsSL https://raw.githubusercontent.com/blairmunk/awesome_scripts/refs/heads/main/notesnook-install/install-notesnook.sh -o install-notesnook.sh
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
wget https://github.com/blairmunk/awesome_scripts/blob/main/notesnook-install/install-notesnook.sh
chmod +x install-notesnook.sh
./install-notesnook.sh
```

### Step 2: Follow Interactive Setup

The script will guide you through:

1. Domain Configuration
    - Main domain (e.g., `yourdomain.com`)
    - Optional web app subdomain
2. Instance Settings
    - Instance name
    - User registration policy
3. SMTP Configuration
    - Email server settings
    - Credentials
4. MinIO Setup
    - File storage configuration
    - Auto-generated credentials

### Step 3: DNS Verification

The script will:

- Verify all DNS records are properly configured
- Test HTTP accessibility before SSL generation

### Step 4: SSL Certificate Generation

Automatic SSL certificate generation using Let's Encrypt:

- Certificates for all subdomains
- Nginx configuration updates
- HTTPS redirection setup

## After Installation

### Client Configuration

#### 1. Mobile/Desktop Apps:

- Download from notesnook.com/downloads
- Go to Settings → Sync Server
- Enter: https://notes.yourdomain.com
- Create account or sign in

#### 2. Web Interface (if configured):
        
- Visit: https://nook.yourdomain.com (or your chosen subdomain)
- Follow setup instructions on the page

### Service Endpoints

Your server will provide:

    Authentication: https://auth.yourdomain.com
    API/Sync: https://notes.yourdomain.com
    Events: https://events.yourdomain.com
    Public Notes: https://mono.yourdomain.com
    File Storage: https://files.yourdomain.com
    MinIO Console: https://files.yourdomain.com (admin interface)

## Management

The installer creates several utility scripts in `/srv/Files/Notesnook/setup/`:

### Daily Operations

```bash
cd /srv/Files/Notesnook/setup

# Monitor system status
./monitor.sh

# Create backup
./backup.sh

# Update services
./update.sh

# Renew SSL certificates
./renew-ssl.sh

# Fix Docker permissions (if needed)
./fix-docker-permissions.sh
```

### Docker Management

```bash
# View logs
docker compose logs

# Restart specific service
docker compose restart notesnook-server

# Stop all services
docker compose down

# Start all services
docker compose up -d
```

## 🛡️ Security & Maintenance

### Automatic SSL Renewal

Set up automatic certificate renewal:

```bash
sudo crontab -e
# Add this line:
0 12 * * * /srv/Files/Notesnook/setup/renew-ssl.sh

### Regular Backups

Schedule automatic backups:

```bash
sudo crontab -e
# Add this line for daily backups at 2 AM:
0 2 * * * /srv/Files/Notesnook/setup/backup.sh
```

### Important Files to Backup

* `/srv/Files/Notesnook/db/` (Database)
* `/srv/Files/Notesnook/s3/` (File storage)
* `/srv/Files/Notesnook/setup/.env` (Configuration)

### Security Best Practices

* **Change default passwords** in `.env` file
* **Keep services updated with** `./update.sh`
* **Monitor logs regularly with** `./monitor.sh`
* **Firewall configuration** - only expose necessary ports
* **Regular backups** are essential


## 🔧 Troubleshooting

### Common Issues

#### Installation Fails

```bash
# Check logs
./monitor.sh

# Fix Docker permissions
./fix-docker-permissions.sh

# Restart services
docker compose restart
```

#### SSL Certificate Issues

```bash
# Manually renew certificates
sudo certbot --nginx -d auth.yourdomain.com -d notes.yourdomain.com

# Check certificate status
sudo certbot certificates
```


#### Service Not Accessible

1. **Check DNS**: Ensure A records point to correct IP
2. **Check Firewall**: Verify ports 80/443 are open
3. **Check Nginx**: `sudo nginx -t && sudo systemctl status nginx`
4. **Check Docker**: `docker compose ps`

#### Email Not Working

1. **Verify SMTP settings** in `.env` file
2. **Check identity-server logs**: `docker compose logs identity-server`
3. **Test SMTP connectivity**: `telnet smtp.yourprovider.com 587`

### Getting Help

- **Check logs**: `docker compose logs [service-name]`
- **System status**: `./monitor.sh`
- **Notesnook Community**: [Discord](https://discord.gg/5davZnhw3V)
- **Report Issues**: [GitHub Issues](https://github.com/yourusername/notesnook-installer/issues)

## 📊 System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 1 core | 2+ cores |
| RAM | 1 GB | 2+ GB |
| Storage | 20 GB | 50+ GB |
| Network | 1 Mbps | 10+ Mbps |

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Test thoroughly
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Notesnook Team](https://github.com/streetwriters/notesnook) for the excellent note-taking app
- [Community Guide](https://lemmy.world/post/24509570) that inspired this installer
- [Docker](https://docker.com) and [Let's Encrypt](https://letsencrypt.org) for making self-hosting easier

## ⭐ Support

If this installer helped you, please consider:
- ⭐ Starring the repository
- 🐛 Reporting bugs
- 💡 Suggesting improvements
- 📖 Improving documentation

---

**Made with ❤️ for the self-hosting community**
