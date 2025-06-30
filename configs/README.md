# ⚙️ Configuration Files

This folder contains application and tool configuration files.

## 📁 Configuration Files

### 🐳 Docker Configurations
- [docker-compose.yml](docker-compose.yml) - Production Docker setup
- [docker-compose.dev.yml](docker-compose.dev.yml) - Development Docker setup

### 🔍 Code Quality
- [qodana.yaml](qodana.yaml) - Qodana code quality configuration

## 🔧 Usage

### Docker Development
```bash
# Development environment
docker-compose -f configs/docker-compose.dev.yml up

# Production environment  
docker-compose -f configs/docker-compose.yml up
```

### Code Quality Check
```bash
# Run Qodana analysis
qodana scan --config configs/qodana.yaml
```