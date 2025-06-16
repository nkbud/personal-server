# Deploying Minimal Supabase to DigitalOcean (1GB RAM)

This guide provides step-by-step instructions for deploying a minimal Supabase backend to a 1GB RAM DigitalOcean droplet.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [DigitalOcean Droplet Setup](#digitalocean-droplet-setup)
3. [Server Preparation](#server-preparation)
4. [Supabase Configuration](#supabase-configuration)
5. [Deployment](#deployment)
6. [Verification](#verification)
7. [Memory Optimizations](#memory-optimizations)
8. [Monitoring & Troubleshooting](#monitoring--troubleshooting)
9. [Limitations & Caveats](#limitations--caveats)
10. [Maintenance](#maintenance)

## Prerequisites

- DigitalOcean account
- Domain name (optional but recommended)
- Basic familiarity with Linux command line
- SSH key pair generated on your local machine

## DigitalOcean Droplet Setup

### 1. Create a New Droplet

1. Log into your DigitalOcean account
2. Click "Create" → "Droplets"
3. Choose Ubuntu 22.04 LTS
4. **Plan**: Basic ($6/month, 1GB RAM, 1 vCPU, 25GB SSD)
5. **Datacenter region**: Choose closest to your users
6. **Authentication**: Upload your SSH public key
7. **Hostname**: Choose a meaningful name (e.g., `supabase-server`)
8. Click "Create Droplet"

### 2. Configure DNS (Optional but Recommended)

If you have a domain:
1. Go to your domain registrar's DNS settings
2. Create an A record pointing to your droplet's IP address
3. Example: `api.yourdomain.com` → `your.droplet.ip.address`

## Server Preparation

### 1. Connect to Your Droplet

```bash
ssh root@your.droplet.ip.address
```

### 2. Update the System

```bash
apt update && apt upgrade -y
```

### 3. Install Docker and Docker Compose

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Verify installation
docker --version
docker-compose --version
```

### 4. Create Swap File (Important for 1GB RAM)

```bash
# Create 2GB swap file
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

# Make swap permanent
echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab

# Optimize swap usage
echo 'vm.swappiness=10' >> /etc/sysctl.conf
echo 'vm.vfs_cache_pressure=50' >> /etc/sysctl.conf
sysctl -p
```

### 5. Configure Firewall

```bash
# Install UFW if not already installed
apt install ufw -y

# Allow SSH, HTTP, and HTTPS
ufw allow ssh
ufw allow 80
ufw allow 443
ufw allow 8000  # Kong API Gateway

# Enable firewall
ufw --force enable
```

### 6. Create Application Directory

```bash
mkdir -p /opt/supabase
cd /opt/supabase
```

## Supabase Configuration

### 1. Download Configuration Files

Clone this repository or manually create the files:

```bash
# If git is not installed
apt install git -y

# Clone the repository
git clone https://github.com/nkbud/personal-server.git .
```

Or manually create the files by copying the content from this repository.

### 2. Create Environment File

```bash
cp .env.example .env
```

### 3. Configure Environment Variables

Edit the `.env` file with your specific values:

```bash
nano .env
```

**Required changes:**

```env
# Generate a strong password for PostgreSQL
POSTGRES_PASSWORD=your-super-secure-postgres-password-here

# Generate a JWT secret (32+ characters)
JWT_SECRET=your-super-secret-jwt-token-with-at-least-32-characters-long

# Set your domain/IP
API_EXTERNAL_URL=http://your-domain.com:8000
SITE_URL=http://your-domain.com:8000

# Email configuration (if using email auth)
SMTP_ADMIN_EMAIL=admin@yourdomain.com
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password

# Disable signup if you want invite-only
DISABLE_SIGNUP=false
```

**Security Note**: Generate strong passwords and secrets:
```bash
# Generate strong passwords
openssl rand -base64 32

# Generate JWT secret
openssl rand -base64 64
```

## Deployment

### 1. Start the Services

```bash
# Pull images and start services
docker-compose pull
docker-compose up -d

# Check if all services are running
docker-compose ps
```

### 2. Check Service Health

```bash
# Check logs for any errors
docker-compose logs

# Check specific service logs
docker-compose logs db
docker-compose logs auth
docker-compose logs rest
docker-compose logs kong
```

### 3. Wait for Services to Initialize

The database initialization may take a few minutes. Monitor with:

```bash
# Watch database logs
docker-compose logs -f db

# Check if PostgREST is ready
curl http://localhost:3000/

# Check if Auth service is ready
curl http://localhost:9999/health

# Check if Kong is ready
curl http://localhost:8000/
```

## Verification

### 1. Test API Endpoints

```bash
# Test PostgREST endpoint
curl -X GET "http://localhost:8000/rest/v1/" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNjIzNzI3MjAwLCJleHAiOjE5MzkyNzEyMDB9.HhcTNY2KpFIFQ0y3sjvdBQIVLPBa4QSMPCvGiQZJ1nY"

# Test Auth endpoint
curl -X POST "http://localhost:8000/auth/v1/signup" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNjIzNzI3MjAwLCJleHAiOjE5MzkyNzEyMDB9.HhcTNY2KpFIFQ0y3sjvdBQIVLPBa4QSMPCvGiQZJ1nY" \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "password": "testpassword123"}'
```

### 2. Test from External Client

Replace `localhost` with your droplet's IP or domain:

```bash
curl -X GET "http://your-domain.com:8000/rest/v1/" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNjIzNzI3MjAwLCJleHAiOjE5MzkyNzEyMDB9.HhcTNY2KpFIFQ0y3sjvdBQIVLPBa4QSMPCvGiQZJ1nY"
```

## Memory Optimizations

### 1. Docker Resource Limits

The docker-compose.yml is already optimized for 1GB RAM with:
- PostgreSQL limited to ~256MB
- Reduced connection limits
- Optimized buffer sizes

### 2. System Optimizations

```bash
# Reduce memory usage of system services
systemctl disable snapd
systemctl mask snapd

# Clear package cache
apt autoremove -y
apt autoclean

# Optimize Docker
echo '{"log-driver": "json-file", "log-opts": {"max-size": "10m", "max-file": "3"}}' > /etc/docker/daemon.json
systemctl restart docker
```

### 3. PostgreSQL Memory Tuning

The configuration in docker-compose.yml includes:
- `shared_buffers=64MB` (small memory footprint)
- `effective_cache_size=192MB` (conservative estimate)
- `max_connections=50` (reduced from default 100)
- `maintenance_work_mem=16MB` (reduced for maintenance tasks)

## Monitoring & Troubleshooting

### 1. Resource Monitoring

```bash
# Check memory usage
free -h

# Check disk usage
df -h

# Check running processes
htop

# Monitor Docker containers
docker stats

# Check swap usage
swapon --show
```

### 2. Common Issues

**Out of Memory Errors:**
```bash
# Check dmesg for OOM killer messages
dmesg | grep -i "killed process"

# Increase swap if needed
swapoff /swapfile
fallocate -l 3G /swapfile
mkswap /swapfile
swapon /swapfile
```

**Database Connection Issues:**
```bash
# Check PostgreSQL logs
docker-compose logs db

# Restart database service
docker-compose restart db
```

**High Memory Usage:**
```bash
# Check which container is using most memory
docker stats --no-stream

# Restart all services
docker-compose down && docker-compose up -d
```

### 3. Log Management

```bash
# Rotate Docker logs
docker system prune -f

# Check log sizes
docker system df

# Set up log rotation (already configured in daemon.json above)
```

## Limitations & Caveats

### Memory Constraints
- **No Realtime subscriptions**: Disabled to save memory (~150MB)
- **No Storage service**: Disabled to save memory (~100MB)
- **Limited connections**: Max 50 PostgreSQL connections
- **Reduced caching**: Smaller buffer sizes in PostgreSQL
- **Swap dependency**: Requires swap file for stable operation

### Performance Limitations
- **CPU bottleneck**: Single vCPU limits concurrent operations
- **I/O limitations**: Network and disk I/O may be slower
- **Query complexity**: Complex queries may timeout or fail
- **Concurrent users**: Limited to ~10-20 concurrent active users

### Feature Limitations
- **Email delivery**: Requires external SMTP service
- **File uploads**: No built-in storage (use external S3-compatible service)
- **Analytics**: No built-in analytics dashboard
- **Backups**: Manual backup process required

### Security Considerations
- **JWT secrets**: Must be properly secured
- **Database passwords**: Must be strong and unique
- **Network exposure**: Only essential ports should be open
- **Updates**: Regular security updates required

## Maintenance

### 1. Regular Updates

```bash
# Update system packages
apt update && apt upgrade -y

# Update Docker images
cd /opt/supabase
docker-compose pull
docker-compose down
docker-compose up -d

# Clean up old Docker images
docker system prune -a -f
```

### 2. Backup Database

```bash
# Create backup
docker-compose exec db pg_dump -U postgres postgres > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore from backup
docker-compose exec -T db psql -U postgres postgres < backup_file.sql
```

### 3. Monitor Disk Space

```bash
# Check disk usage
df -h

# Clean up logs if needed
docker system prune -f
journalctl --vacuum-size=100M
```

### 4. Health Checks

Create a simple health check script:

```bash
#!/bin/bash
# health_check.sh

echo "Checking Supabase services..."

# Check if containers are running
if ! docker-compose ps | grep -q "Up"; then
    echo "❌ Some services are not running"
    docker-compose ps
    exit 1
fi

# Check API endpoints
if ! curl -s http://localhost:8000/ > /dev/null; then
    echo "❌ Kong API Gateway not responding"
    exit 1
fi

if ! curl -s http://localhost:3000/ > /dev/null; then
    echo "❌ PostgREST not responding"
    exit 1
fi

echo "✅ All services are healthy"
```

Make it executable and run:
```bash
chmod +x health_check.sh
./health_check.sh
```

### 5. Automated Monitoring

Set up a cron job for regular health checks:

```bash
# Edit crontab
crontab -e

# Add health check every 5 minutes
*/5 * * * * /opt/supabase/health_check.sh >> /var/log/supabase_health.log 2>&1
```

## Scaling Considerations

When you outgrow the 1GB setup:

1. **Upgrade droplet**: Move to 2GB or 4GB RAM droplet
2. **Enable Realtime**: Add realtime service back to docker-compose.yml
3. **Add Storage**: Include storage service for file uploads
4. **Load balancer**: Use DigitalOcean Load Balancer for multiple instances
5. **Managed database**: Consider DigitalOcean Managed PostgreSQL

## Support and Community

- [Supabase Documentation](https://supabase.io/docs)
- [Supabase Discord](https://discord.supabase.io/)
- [DigitalOcean Community](https://www.digitalocean.com/community)

---

**Important**: This setup is optimized for development and small production workloads. For high-traffic applications, consider using managed services or larger infrastructure.