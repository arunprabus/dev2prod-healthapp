# PowerShell script to analyze Terraform files and predict required AWS permissions
# Usage: .\terraform-permissions-analyzer.ps1

Write-Host "# Terraform AWS Permissions Analyzer" -ForegroundColor Green
Write-Host "# Analyzing Terraform files for required AWS permissions..." -ForegroundColor Yellow

$permissions = @()

# Scan all Terraform files
Get-ChildItem -Path "infra" -Recurse -Filter "*.tf" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    
    # Extract AWS resource types
    $resources = [regex]::Matches($content, 'resource\s+"(aws_[^"]+)"') | ForEach-Object { $_.Groups[1].Value }
    $dataSources = [regex]::Matches($content, 'data\s+"(aws_[^"]+)"') | ForEach-Object { $_.Groups[1].Value }
    
    foreach ($resource in $resources) {
        switch -Regex ($resource) {
            "aws_vpc" { $permissions += @("ec2:CreateVpc", "ec2:DeleteVpc", "ec2:DescribeVpcs", "ec2:ModifyVpcAttribute", "ec2:DescribeVpcAttribute") }
            "aws_subnet" { $permissions += @("ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:DescribeSubnets") }
            "aws_internet_gateway" { $permissions += @("ec2:CreateInternetGateway", "ec2:DeleteInternetGateway", "ec2:AttachInternetGateway", "ec2:DetachInternetGateway") }
            "aws_route_table" { $permissions += @("ec2:CreateRouteTable", "ec2:DeleteRouteTable", "ec2:DescribeRouteTables", "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable") }
            "aws_route" { $permissions += @("ec2:CreateRoute", "ec2:DeleteRoute") }
            "aws_security_group" { $permissions += @("ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup", "ec2:DescribeSecurityGroups", "ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress", "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress") }
            "aws_instance" { $permissions += @("ec2:RunInstances", "ec2:TerminateInstances", "ec2:DescribeInstances", "ec2:DescribeInstanceAttribute", "ec2:ModifyInstanceAttribute") }
            "aws_key_pair" { $permissions += @("ec2:ImportKeyPair", "ec2:DeleteKeyPair", "ec2:DescribeKeyPairs") }
            "aws_db_instance" { $permissions += @("rds:CreateDBInstance", "rds:DeleteDBInstance", "rds:DescribeDBInstances", "rds:ModifyDBInstance", "rds:StartDBInstance", "rds:StopDBInstance") }
            "aws_db_subnet_group" { $permissions += @("rds:CreateDBSubnetGroup", "rds:DeleteDBSubnetGroup", "rds:DescribeDBSubnetGroups") }
            "aws_db_parameter_group" { $permissions += @("rds:CreateDBParameterGroup", "rds:DeleteDBParameterGroup", "rds:DescribeDBParameterGroups") }
            "aws_iam_role" { $permissions += @("iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:ListRoles", "iam:TagRole", "iam:UntagRole", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole") }
            "aws_iam_role_policy" { $permissions += @("iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy") }
            "aws_iam_role_policy_attachment" { $permissions += @("iam:AttachRolePolicy", "iam:DetachRolePolicy") }
            "aws_kms_key" { $permissions += @("kms:CreateKey", "kms:DeleteKey", "kms:DescribeKey", "kms:GetKeyPolicy", "kms:PutKeyPolicy", "kms:TagResource", "kms:UntagResource", "kms:ListResourceTags") }
            "aws_kms_alias" { $permissions += @("kms:CreateAlias", "kms:DeleteAlias", "kms:ListAliases") }
            "aws_lambda_function" { $permissions += @("lambda:CreateFunction", "lambda:DeleteFunction", "lambda:GetFunction", "lambda:UpdateFunctionCode", "lambda:UpdateFunctionConfiguration", "lambda:TagResource", "lambda:UntagResource") }
            "aws_lambda_permission" { $permissions += @("lambda:AddPermission", "lambda:RemovePermission", "lambda:GetPolicy") }
            "aws_cloudwatch_event_rule" { $permissions += @("events:PutRule", "events:DeleteRule", "events:DescribeRule", "events:TagResource", "events:UntagResource") }
            "aws_cloudwatch_event_target" { $permissions += @("events:PutTargets", "events:RemoveTargets", "events:ListTargetsByRule") }
            "aws_cloudwatch_log_group" { $permissions += @("logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:DescribeLogGroups", "logs:TagLogGroup", "logs:UntagLogGroup") }
        }
    }
}

# Remove duplicates and sort
$uniquePermissions = $permissions | Sort-Object -Unique

Write-Host "`n# Complete IAM Policy for Terraform Deployment:" -ForegroundColor Green
Write-Host "{"
Write-Host '    "Version": "2012-10-17",'
Write-Host '    "Statement": ['
Write-Host '        {'
Write-Host '            "Effect": "Allow",'
Write-Host '            "Action": ['

$count = 0
foreach ($perm in $uniquePermissions) {
    $count++
    $comma = if ($count -eq $uniquePermissions.Count) { "" } else { "," }
    Write-Host "                `"$perm`"$comma"
}

Write-Host '            ],'
Write-Host '            "Resource": "*"'
Write-Host '        }'
Write-Host '    ]'
Write-Host '}'

Write-Host "`n# Total permissions required: $($uniquePermissions.Count)" -ForegroundColor Yellow
Write-Host "# This policy should cover all Terraform operations for your infrastructure." -ForegroundColor Green