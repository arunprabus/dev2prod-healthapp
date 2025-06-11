# Personal Health Profile Web Application

A comprehensive health profile management system built with Angular, Node.js, and AWS services. This application allows users to securely manage their personal health information, family details, and medical documents.

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Angular SPA   │    │  Node.js API    │    │   AWS Services  │
│                 │    │                 │    │                 │
│ • Authentication│◄──►│ • JWT Validation│◄──►│ • Cognito       │
│ • Profile Mgmt  │    │ • CRUD APIs     │    │ • RDS MySQL     │
│ • File Upload   │    │ • S3 Integration│    │ • S3 Bucket     │
│ • Responsive UI │    │ • Health Checks │    │ • EKS Cluster   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                        │                        │
        └────────────────────────┼────────────────────────┘
                                 │
                    ┌─────────────────┐
                    │  Infrastructure │
                    │                 │
                    │ • VPC & Subnets │
                    │ • Security Grps │
                    │ • Load Balancer │
                    │ • Auto Scaling  │
                    └─────────────────┘
```

## 🚀 Features

### Core Functionality
- **User Authentication**: AWS Cognito integration with signup/login flows
- **Profile Management**: Personal details, family members, medical conditions
- **Document Storage**: Secure file upload/download with S3 presigned URLs
- **Health Information**: Blood group, allergies, emergency contacts
- **Family Management**: Add and manage family member health profiles

### Technical Features
- **Responsive Design**: Mobile-first Angular application
- **Secure API**: JWT token validation and RBAC
- **File Upload**: Drag-and-drop interface with preview
- **Real-time Updates**: Live data synchronization
- **Error Handling**: Comprehensive error management
- **Health Checks**: Application monitoring endpoints

## 🛠️ Technology Stack

### Frontend
- **Angular 19**: Latest version with standalone components
- **TypeScript**: Type-safe development
- **RxJS**: Reactive programming
- **AWS Amplify**: Cognito integration
- **Responsive CSS**: Mobile-first design

### Backend
- **Node.js**: Runtime environment
- **Express.js**: Web framework
- **MySQL**: Relational database
- **AWS SDK**: Cloud service integration
- **JWT**: Token-based authentication

### Infrastructure
- **AWS EKS**: Kubernetes orchestration
- **AWS RDS**: Managed MySQL database
- **AWS S3**: Object storage
- **AWS Cognito**: User management
- **AWS ECR**: Container registry
- **CloudFormation**: Infrastructure as Code

## 📋 Prerequisites

- Node.js 18+
- Docker
- AWS CLI
- kubectl
- AWS Account with appropriate permissions

## 🚀 Quick Start

### 1. Clone Repository
```bash
git clone <repository-url>
cd health-profile-app
```

### 2. Install Dependencies
```bash
# Frontend dependencies
npm install

# Backend dependencies
cd backend
npm install
cd ..
```

### 3. Configure Environment
```bash
# Copy environment template
cp backend/.env.example backend/.env

# Update with your AWS credentials and configuration
```

### 4. Deploy Infrastructure
```bash
# Make deployment script executable
chmod +x scripts/deploy.sh

# Run deployment
./scripts/deploy.sh
```

## 🔧 Manual Setup

### AWS Infrastructure Setup

1. **Create CloudFormation Stack**
```bash
aws cloudformation create-stack \
  --stack-name health-profile-dev-infrastructure \
  --template-body file://infrastructure/cloudformation/main.yaml \
  --parameters ParameterKey=ProjectName,ParameterValue=health-profile \
               ParameterKey=Environment,ParameterValue=dev \
               ParameterKey=DBPassword,ParameterValue=YourSecurePassword123! \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

2. **Configure Cognito**
```bash
# Get User Pool details from CloudFormation outputs
aws cloudformation describe-stacks \
  --stack-name health-profile-dev-infrastructure \
  --query 'Stacks[0].Outputs'
```

3. **Update Application Configuration**
```bash
# Update Angular environment with Cognito details
# Update backend .env with RDS and S3 details
```

### Docker Build and Push

1. **Build Images**
```bash
# Backend
cd backend
docker build -t health-profile-backend .

# Frontend
cd ..
docker build -t health-profile-frontend .
```

2. **Push to ECR**
```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Tag and push
docker tag health-profile-backend:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/health-profile-backend:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/health-profile-backend:latest

docker tag health-profile-frontend:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/health-profile-frontend:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/health-profile-frontend:latest
```

### Kubernetes Deployment

1. **Configure kubectl**
```bash
aws eks update-kubeconfig --region us-east-1 --name health-profile-dev-cluster
```

2. **Deploy Application**
```bash
# Update image URIs in deployment files
# Apply manifests
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/hpa.yaml
```

## 🔒 Security Features

- **Authentication**: AWS Cognito with MFA support
- **Authorization**: JWT token validation
- **Data Encryption**: At rest and in transit
- **Network Security**: VPC with private subnets
- **Container Security**: Non-root containers, read-only filesystems
- **API Security**: Rate limiting, input validation

## 📊 Monitoring and Logging

- **Health Checks**: Application and infrastructure monitoring
- **Logging**: Structured logging with Winston
- **Metrics**: CloudWatch integration
- **Alerting**: Automated notifications for issues

## 🔄 CI/CD Pipeline

The GitHub Actions workflow includes:

1. **Testing**: Unit tests and linting
2. **Security Scanning**: Vulnerability assessment
3. **Building**: Docker image creation
4. **Deployment**: Automated EKS deployment
5. **Verification**: Post-deployment checks

## 📝 API Documentation

### Authentication Endpoints
- `POST /api/auth/create-user` - Create user after Cognito signup
- `GET /api/auth/user/:cognitoUserId` - Get user by Cognito ID

### Profile Endpoints
- `GET /api/profile` - Get user profile
- `PUT /api/profile` - Update user profile

### Document Endpoints
- `GET /api/documents` - List user documents
- `POST /api/documents/upload-url` - Get upload URL
- `POST /api/documents` - Save document metadata
- `GET /api/documents/:id/download` - Get download URL
- `DELETE /api/documents/:id` - Delete document

## 🧪 Testing

### Frontend Tests
```bash
npm test
npm run lint
```

### Backend Tests
```bash
cd backend
npm test
```

### Integration Tests
```bash
# Run end-to-end tests
npm run e2e
```

## 🚀 Deployment Strategies

### Blue-Green Deployment
```bash
# Deploy to staging environment
kubectl apply -f k8s/ --namespace health-profile-staging

# Verify deployment
kubectl get pods -n health-profile-staging

# Switch traffic
kubectl patch service health-profile-frontend-service -n health-profile \
  -p '{"spec":{"selector":{"version":"green"}}}'
```

### Rolling Updates
```bash
# Update image tag
kubectl set image deployment/health-profile-backend \
  backend=<new-image-uri> -n health-profile

# Monitor rollout
kubectl rollout status deployment/health-profile-backend -n health-profile
```

## 🔧 Troubleshooting

### Common Issues

1. **Database Connection Issues**
```bash
# Check RDS security group
# Verify database credentials
# Test connectivity from EKS nodes
```

2. **S3 Upload Failures**
```bash
# Verify IAM permissions
# Check bucket policy
# Validate presigned URL generation
```

3. **Cognito Authentication Issues**
```bash
# Verify User Pool configuration
# Check App Client settings
# Validate JWT token format
```

### Debugging Commands
```bash
# Check pod logs
kubectl logs -f deployment/health-profile-backend -n health-profile

# Describe pod issues
kubectl describe pod <pod-name> -n health-profile

# Check service endpoints
kubectl get endpoints -n health-profile
```

## 📈 Performance Optimization

- **Horizontal Pod Autoscaling**: Automatic scaling based on CPU/memory
- **CDN Integration**: CloudFront for static assets
- **Database Optimization**: Connection pooling, query optimization
- **Caching**: Redis for session management
- **Image Optimization**: Multi-stage Docker builds

## 🔐 Security Best Practices

- **Least Privilege**: Minimal IAM permissions
- **Network Segmentation**: Private subnets for databases
- **Secrets Management**: AWS Secrets Manager integration
- **Container Security**: Distroless base images
- **Regular Updates**: Automated dependency updates

## 📚 Additional Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Angular Documentation](https://angular.io/docs)
- [Node.js Best Practices](https://nodejs.org/en/docs/guides/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For support and questions:
- Create an issue in the repository
- Contact the development team
- Check the troubleshooting guide

---

**Note**: This application is designed for educational and demonstration purposes. For production use, ensure proper security reviews and compliance with healthcare regulations like HIPAA.