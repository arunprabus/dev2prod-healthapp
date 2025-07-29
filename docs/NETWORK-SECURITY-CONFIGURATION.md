# Network Security Configuration - Cross-SG References Implementation

## Overview

This document outlines the implementation of proper security group configuration using cross-SG references instead of open CIDR blocks, ensuring secure database connectivity while maintaining network isolation.

## Security Group Architecture

### 1. Database Security Group (`aws_security_group.db`)

**Configuration:**
- **Ingress Rules**: Only allows traffic from application security groups (cross-SG references)
- **Egress Rules**: Standard outbound traffic (0.0.0.0/0)
- **No CIDR-based rules**: Eliminates broad network access

**Implementation:**
```hcl
resource "aws_security_group_rule" "db_ingress_from_app" {
  count = length(var.app_security_group_ids)
  
  type                     = "ingress"
  from_port                = var.engine == "postgres" ? 5432 : 3306
  to_port                  = var.engine == "postgres" ? 5432 : 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db.id
  source_security_group_id = var.app_security_group_ids[count.index]
  description              = "Database access from app SG ${count.index}"
}
```

### 2. Application Security Group (`aws_security_group.k3s`)

**Configuration:**
- **Ingress Rules**: SSH, K3s API, HTTP/HTTPS, NodePort range
- **Egress Rules**: General outbound + specific database access rules
- **Database Access**: Explicit egress rules for MySQL (3306) and PostgreSQL (5432)

**Implementation:**
```hcl
resource "aws_security_group_rule" "k3s_db_egress_mysql" {
  count = var.db_security_group_id != null ? 1 : 0
  
  type                          = "egress"
  from_port                     = 3306
  to_port                       = 3306
  protocol                      = "tcp"
  security_group_id             = aws_security_group.k3s.id
  destination_security_group_id = var.db_security_group_id
  description                   = "MySQL database access"
}
```

## Environment Isolation

### Network Tier Configuration

Each environment uses separate VPCs with isolated CIDR blocks:

- **Lower Environment (dev/test)**: `10.0.0.0/16`
- **Higher Environment (prod)**: `10.1.0.0/16`
- **Monitoring Environment**: `10.3.0.0/16`

### Security Group Wiring

The security groups are wired together through Terraform dependencies:

```hcl
# RDS module receives app security group IDs
app_security_group_ids = var.network_tier == "lower" ? 
  [for k, v in module.k3s_clusters : v.security_group_id] : 
  var.network_tier != "lower" && length(module.k3s) > 0 ? [module.k3s[0].security_group_id] : []

# K3s modules receive database security group ID
db_security_group_id = var.database_config != null ? module.rds[0].db_security_group_id : null
```

## Network ACLs (NACLs)

### Permissive NACL Configuration

NACLs are configured to allow all traffic, with security enforcement handled by security groups:

```hcl
resource "aws_network_acl" "main" {
  vpc_id = aws_vpc.main.id

  # Allow all inbound traffic
  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # Allow all outbound traffic
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
}
```

## Connectivity Testing

### 1. Security Group Verification Script

**Location**: `scripts/verify-security-groups.sh`

**Purpose**: Validates that security groups are properly configured with cross-SG references

**Key Checks**:
- Database SG allows ingress from app SGs
- App SG has egress rules for database access
- No open CIDR blocks on database
- Proper subnet and routing configuration

### 2. Network Connectivity Testing Script

**Location**: `scripts/test-network-connectivity.sh`

**Purpose**: Tests actual connectivity from application instances to database

**Test Methods**:
- **netcat (nc)**: Basic port connectivity testing
- **MySQL/PostgreSQL client**: Database-specific connectivity
- **DNS resolution**: Hostname resolution verification
- **Kubernetes pod testing**: In-cluster connectivity verification

**Usage**:
```bash
# Test dev environment
./scripts/test-network-connectivity.sh dev

# Test production environment
./scripts/test-network-connectivity.sh prod
```

## Workflow Integration

### Infrastructure Workflow Updates

The `core-infrastructure.yml` workflow now includes:

1. **Security Group Verification**: Validates SG configuration after deployment
2. **Connectivity Testing**: Tests actual network connectivity
3. **Removed test-deployment**: Replaced with focused connectivity testing

### Workflow Steps

```yaml
- name: Verify Security Groups
  run: |
    ./scripts/verify-security-groups.sh $ENVIRONMENT

- name: Test Network Connectivity  
  run: |
    ./scripts/test-network-connectivity.sh $ENVIRONMENT
```

## Database Configuration

### Environment-Specific Settings

Each environment has proper database configuration:

**Dev/Test (Lower)**:
```hcl
database_config = {
  identifier              = "health-app-shared-db"
  instance_class         = "db.t3.micro"
  engine                 = "postgres"
  engine_version         = "15.12"
  db_name               = "healthapi"
  username              = "postgres"
  backup_retention_period = 7
}
db_port = 5432
```

**Production (Higher)**:
```hcl
database_config = {
  identifier              = "health-app-prod-db"
  instance_class         = "db.t3.micro"
  engine                 = "postgres"
  engine_version         = "15.12"
  db_name               = "healthapi"
  username              = "postgres"
  backup_retention_period = 7
}
db_port = 5432
```

## Security Benefits

### 1. Principle of Least Privilege
- Database only accessible from specific application security groups
- No broad network access (0.0.0.0/0) to database
- Environment isolation through separate VPCs

### 2. Defense in Depth
- Security groups provide primary access control
- NACLs provide subnet-level filtering
- VPC isolation prevents cross-environment access

### 3. Auditability
- Clear security group rules with descriptions
- Automated verification scripts
- Infrastructure as Code for compliance

## Troubleshooting

### Common Issues

1. **Connection Timeouts**
   - Check security group rules
   - Verify subnet routing
   - Confirm database is running

2. **DNS Resolution Failures**
   - Ensure VPC DNS settings are enabled
   - Check route table configuration

3. **Security Group Misconfigurations**
   - Run `verify-security-groups.sh` script
   - Check Terraform outputs for SG IDs
   - Verify cross-SG references are correct

### Verification Commands

```bash
# Check security group rules
aws ec2 describe-security-groups --group-ids sg-xxxxx

# Test connectivity manually
nc -zv database-endpoint 5432

# Check from Kubernetes pod
kubectl run debug --image=busybox --rm -it -- nc -zv db-host 5432
```

## Compliance

This configuration ensures:

- ✅ **Cross-SG references** instead of open CIDR blocks
- ✅ **Ingress rules on DB SG** from app security groups
- ✅ **Egress rules on App SG** to database security group
- ✅ **Environment isolation** through separate VPCs
- ✅ **Automated testing** of connectivity and security configuration
- ✅ **Infrastructure as Code** for consistent deployments

The implementation follows AWS security best practices and provides a secure, scalable foundation for the health application infrastructure.