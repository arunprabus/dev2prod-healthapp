# Local Development Guide

## 🐳 Docker Compose (Recommended)

### Production-like (API not exposed)
```bash
# Start both services - API only accessible via frontend
docker-compose up

# Access: http://localhost:3000 (frontend only)
```

### Development mode (API exposed for debugging)
```bash
# Start with API exposed for debugging
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up

# Access: 
# - Frontend: http://localhost:3000
# - API: http://localhost:8080 (for debugging)
```

## 🔧 Individual Applications

### Backend Only
```bash
cd health-api

# Method 1: Direct Node.js
npm install
npm run dev

# Method 2: Docker
npm run docker:build
npm run docker:run

# Access: http://localhost:8080
```

### Frontend Only
```bash
cd frontend

# Method 1: React dev server
npm install
npm start

# Method 2: Production build
npm run build
npm run serve

# Method 3: Docker
npm run docker:build
npm run docker:run

# Access: http://localhost:3000
```

## 🌐 Network Configuration

### Docker Compose Mode
- **Frontend**: http://localhost:3000 (public)
- **Backend**: Internal only (production-like)
- **Communication**: Frontend → Backend via internal network

### Development Mode
- **Frontend**: http://localhost:3000
- **Backend**: http://localhost:8080 (exposed for debugging)

### Individual Mode
- **Frontend**: http://localhost:3000
- **Backend**: http://localhost:8080
- **Communication**: Direct HTTP calls

## 🔄 Switching Between Modes

```bash
# Stop everything
docker-compose down

# Production-like (recommended)
docker-compose up

# Development (with API access)
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up

# Individual services
cd health-api && npm run dev
cd frontend && npm start
```

## 🛠️ Environment Variables

### Backend (.env.docker)
```bash
PORT=8080
NODE_ENV=development
DB_HOST=localhost
DB_PORT=5432
```

### Frontend (Docker Compose)
```bash
REACT_APP_API_URL=http://health-api:8080  # Internal
```

### Frontend (Individual)
```bash
REACT_APP_API_URL=http://localhost:8080   # Direct
```