#!/bin/bash

# EC2 User Data Script for Health App Deployment
set -e

# Log all output
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "🚀 Starting EC2 instance setup for Health App..."

# Update system
echo "📦 Updating system packages..."
apt-get update -y
apt-get upgrade -y

# Install essential packages
echo "🔧 Installing essential packages..."
apt-get install -y \
    curl \
    wget \
    unzip \
    git \
    htop \
    nginx \
    awscli \
    jq

# Install Docker
echo "🐳 Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu
systemctl enable docker
systemctl start docker

# Install Docker Compose
echo "🔧 Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Configure Nginx as reverse proxy
echo "🌐 Configuring Nginx..."
cat > /etc/nginx/sites-available/health-app << 'EOF'
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    location /health {
        proxy_pass http://localhost:8080/health;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/health-app /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

# Create application directory
echo "📁 Creating application directory..."
mkdir -p /opt/health-app
chown ubuntu:ubuntu /opt/health-app

# Create systemd service for health monitoring
echo "🔍 Setting up health monitoring..."
cat > /etc/systemd/system/health-monitor.service << 'EOF'
[Unit]
Description=Health App Monitor
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=ubuntu
ExecStart=/opt/health-app/monitor.sh
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

# Create monitoring script
cat > /opt/health-app/monitor.sh << 'EOF'
#!/bin/bash

while true; do
    # Check if health-api container is running
    if ! docker ps | grep -q health-api; then
        echo "$(date): Health API container not running, attempting restart..."
        docker start health-api 2>/dev/null || echo "$(date): Failed to start container"
    fi
    
    # Check application health
    if ! curl -f http://localhost:8080/health >/dev/null 2>&1; then
        echo "$(date): Health check failed"
    fi
    
    sleep 60
done
EOF

chmod +x /opt/health-app/monitor.sh
chown ubuntu:ubuntu /opt/health-app/monitor.sh

# Enable but don't start the monitor yet (will start after first deployment)
systemctl enable health-monitor

# Create deployment info file
echo "📝 Creating deployment info..."
cat > /opt/health-app/info.txt << EOF
EC2 Instance Setup Complete
========================
Date: $(date)
Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)
Public IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
Private IP: $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
Region: $(curl -s http://169.254.169.254/latest/meta-data/placement/region)

Services Installed:
- Docker: $(docker --version)
- Docker Compose: $(docker-compose --version)
- Nginx: $(nginx -v 2>&1)
- AWS CLI: $(aws --version)

Ready for application deployment!
EOF

chown ubuntu:ubuntu /opt/health-app/info.txt

echo "✅ EC2 instance setup completed successfully!"
echo "📋 Setup summary:"
echo "   - Docker installed and running"
echo "   - Nginx configured as reverse proxy"
echo "   - Health monitoring service created"
echo "   - Application directory: /opt/health-app"
echo "   - Ready for deployment!"