
variables {
  my_ip = "203.0.113.0/32"  # IP de teste (TEST-NET-3)
}

run "validate_iam_role_configuration" {
  command = plan

  assert {
    condition     = aws_iam_role.ec2.name == "terraform-dev-sandbox-ec2-role"
    error_message = "IAM Role deve ter nome terraform-dev-sandbox-ec2-role"
  }

  assert {
    condition     = can(regex("ec2.amazonaws.com", aws_iam_role.ec2.assume_role_policy))
    error_message = "IAM Role deve permitir assume role do serviço EC2"
  }

  assert {
    condition     = aws_iam_role.ec2.tags["Name"] == "terraform-dev-sandbox-ec2-role"
    error_message = "IAM Role deve ter tag Name = terraform-dev-sandbox-ec2-role"
  }

  assert {
    condition     = aws_iam_role.ec2.tags["Environment"] == "development"
    error_message = "IAM Role deve ter tag Environment = development"
  }

  assert {
    condition     = aws_iam_role.ec2.tags["ManagedBy"] == "terraform"
    error_message = "IAM Role deve ter tag ManagedBy = terraform"
  }
}

run "validate_instance_profile" {
  command = plan

  assert {
    condition     = aws_iam_instance_profile.ec2.name == "terraform-dev-sandbox-ec2-profile"
    error_message = "Instance Profile deve ter nome terraform-dev-sandbox-ec2-profile"
  }

  assert {
    condition     = aws_iam_instance_profile.ec2.tags["Name"] == "terraform-dev-sandbox-ec2-profile"
    error_message = "Instance Profile deve ter tag Name = terraform-dev-sandbox-ec2-profile"
  }

  assert {
    condition     = aws_iam_instance_profile.ec2.tags["Environment"] == "development"
    error_message = "Instance Profile deve ter tag Environment = development"
  }

  assert {
    condition     = aws_iam_instance_profile.ec2.tags["ManagedBy"] == "terraform"
    error_message = "Instance Profile deve ter tag ManagedBy = terraform"
  }
}

run "validate_iam_policy_no_wildcards" {
  command = plan

  assert {
    condition     = !can(regex("\"ec2:\\*\"", aws_iam_role_policy.ec2_terraform.policy))
    error_message = "IAM Policy não deve usar wildcards como ec2:*"
  }

  assert {
    condition     = !can(regex("\"\\*:\\*\"", aws_iam_role_policy.ec2_terraform.policy))
    error_message = "IAM Policy não deve usar wildcards como *:*"
  }

  assert {
    condition     = can(regex("ec2:Describe", aws_iam_role_policy.ec2_terraform.policy))
    error_message = "IAM Policy deve ter ações explícitas de EC2 (ex: ec2:Describe*)"
  }
}
