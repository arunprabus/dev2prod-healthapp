# Dev2Prod Health App - Orchestration

This repository contains the orchestration setup for the Health Profile Management microservices application.

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Backend API   │    │   AWS Services  │
│                 │    │                 │    │                 │
│ • React SPA     │◄──►│ • Node.js API   │◄──►│ • S3 Storage    │
│ • Runtime Config│    │ • Profile CRUD  │    │ • RDS MySQL     │
│ • File Upload   │    │ • File Upload   │    │ • EKS Cluster   │
│ • Nginx         │    │ • Validation    │    │ • Load Balancer │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Services

### Frontend (frontend-config-app)
- **Repository**: `ghcr.io/arunprabus/frontend-config-app`
- **Port**: 8080
- **Technology**: React + TypeScript + Nginx
- **Features**: Runtime configuration, responsive UI, file upload

### Backend (health-api)
- **Repository**: `ghcr.io/arunprabus/health-api`
- **Port**: 3001
- **Technology**: Node.js + Express
- **Features**: Profile CRUD, PDF upload, validation

### Database
- **Technology**: MySQL 8.0
- **Port**: 3306
- **Features**: Profile storage, audit logging

### Cache
- **Technology**: Redis 7
- **Port**: 6379
- **Features**: Session storage, caching

## Quick Start

### Prerequisites
- Docker 20.10+
- Docker Compose 2.0+

### Local Development
```bash
# Clone the orchestration repo
git clone https://github.com/arunprabus/dev2prod-healthapp.git
cd dev2prod-healthapp

# Copy environment file
cp .env.example .env

# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Check service status
docker-compose ps
```

### Access Points
- **Frontend**: http://localhost:8080
- **Backend API**: http://localhost:3001
- **API Health**: http://localhost:3001/health
- **Database**: localhost:3306
- **Redis**: localhost:6379

## Environment Configuration

Create a `.env` file with the following variables:

```env
# Frontend
API_URL=http://localhost:3001/api
APP_NAME=Health Profile Management

# Backend
AWS_ACCESS_KEY_ID=your_aws_key
AWS_SECRET_ACCESS_KEY=your_aws_secret
S3_BUCKET=your-s3-bucket

# Database
DB_ROOT_PASSWORD=secure_password
DB_USER=health_user
DB_PASSWORD=secure_password
```

## Production Deployment

### Terraform Infrastructure
```bash
cd terraform/
terraform init
terraform plan
terraform apply
```

### GitHub Actions CI/CD
The pipeline automatically:
1. Builds and tests both services
2. Pushes images to GitHub Container Registry
3. Deploys to EKS using Terraform
4. Runs health checks and integration tests

## Monitoring

### Health Checks
- Frontend: `curl http://localhost:8080/health`
- Backend: `curl http://localhost:3001/health`
- Database: Built-in MySQL health check

### Logs
```bash
# All services
docker-compose logs

# Specific service
docker-compose logs frontend
docker-compose logs backend
```

## Development Workflow

1. **Frontend Changes**: Push to `frontend-config-app` repo
2. **Backend Changes**: Push to `health-api` repo
3. **Infrastructure Changes**: Update this repo's Terraform configs
4. **Local Testing**: Use `docker-compose up` to test integration

## API Documentation

### Profile Endpoints
- `GET /api/profile` - List all profiles
- `POST /api/profile` - Create profile
- `GET /api/profile/:id` - Get profile by ID
- `DELETE /api/profile/:id` - Delete profile

### Upload Endpoints
- `POST /api/upload` - Upload PDF file

### Example Profile Creation
```bash
curl -X POST http://localhost:3001/api/profile \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "bloodGroup": "O+",
    "insurance": "Blue Cross",
    "email": "john@example.com",
    "idProof": "DL123456789"
  }'
```

## Contributing

1. Make changes in respective service repositories
2. Update orchestration configs here if needed
3. Test locally with `docker-compose`
4. Submit pull requests to individual repos

## License

MIT License - see individual service repositories for details.