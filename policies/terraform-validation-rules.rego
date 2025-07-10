# Terraform Validation Rules (OPA/Rego)
# Prevents resource creation accidents

package terraform.validation

# Rule 1: Only allow specific instance types (Free Tier)
deny[msg] {
    input.resource_changes[_].type == "aws_instance"
    instance := input.resource_changes[_].change.after
    not instance.instance_type in ["t2.micro", "t2.nano"]
    msg := sprintf("Instance type '%s' not allowed. Only t2.micro and t2.nano are permitted (Free Tier)", [instance.instance_type])
}

# Rule 2: Only allow specific regions
deny[msg] {
    input.configuration.provider_config.aws.expressions.region.constant_value != "ap-south-1"
    msg := "Resources can only be created in ap-south-1 region"
}

# Rule 3: Enforce required tags
deny[msg] {
    resource := input.resource_changes[_]
    resource.type in ["aws_instance", "aws_db_instance", "aws_security_group"]
    tags := resource.change.after.tags
    required_tags := ["Name", "Project", "Environment"]
    missing_tag := required_tags[_]
    not tags[missing_tag]
    msg := sprintf("Resource '%s' missing required tag: %s", [resource.address, missing_tag])
}

# Rule 4: Enforce naming convention
deny[msg] {
    resource := input.resource_changes[_]
    resource.type in ["aws_instance", "aws_key_pair", "aws_security_group"]
    name := resource.change.after.tags.Name
    not startswith(name, "health-app-")
    msg := sprintf("Resource name '%s' must start with 'health-app-'", [name])
}

# Rule 5: Prevent expensive RDS instance types
deny[msg] {
    input.resource_changes[_].type == "aws_db_instance"
    db := input.resource_changes[_].change.after
    not db.instance_class in ["db.t3.micro", "db.t2.micro"]
    msg := sprintf("RDS instance class '%s' not allowed. Only db.t3.micro and db.t2.micro are permitted", [db.instance_class])
}

# Rule 6: Limit EBS volume size
deny[msg] {
    input.resource_changes[_].type == "aws_ebs_volume"
    volume := input.resource_changes[_].change.after
    volume.size > 20
    msg := sprintf("EBS volume size %d GB exceeds limit of 20 GB", [volume.size])
}

# Rule 7: Prevent NAT Gateway creation (expensive)
deny[msg] {
    input.resource_changes[_].type == "aws_nat_gateway"
    msg := "NAT Gateway creation is prohibited (cost optimization)"
}

# Rule 8: Prevent Load Balancer creation
deny[msg] {
    input.resource_changes[_].type in ["aws_lb", "aws_alb", "aws_elb"]
    msg := "Load Balancer creation is prohibited (cost optimization)"
}