
variables {
  my_ip = "203.0.113.0/32"
}

run "validate_ec2_configuration" {
  command = plan

  assert {
    condition     = aws_instance.dev.instance_type == "t3.small"
    error_message = "EC2 instance type deve ser t3.small"
  }

  assert {
    condition     = length(aws_instance.dev.user_data) > 0
    error_message = "EC2 deve ter user-data script configurado"
  }
}

run "validate_ec2_ami" {
  command = plan

  assert {
    condition     = can(regex("al2023", data.aws_ami.amazon_linux_2023.name))
    error_message = "EC2 deve usar AMI Amazon Linux 2023"
  }

  assert {
    condition     = data.aws_ami.amazon_linux_2023.architecture == "x86_64"
    error_message = "AMI deve ser x86_64"
  }
}

run "validate_ec2_iam" {
  command = plan

  assert {
    condition     = aws_instance.dev.iam_instance_profile == aws_iam_instance_profile.ec2.name
    error_message = "EC2 deve ter IAM instance profile anexado"
  }
}

run "validate_ec2_tags" {
  command = plan

  assert {
    condition     = aws_instance.dev.tags["Name"] == "terraform-dev-sandbox-ec2"
    error_message = "EC2 deve ter tag Name = terraform-dev-sandbox-ec2"
  }

  assert {
    condition     = aws_instance.dev.tags["Environment"] == "development"
    error_message = "EC2 deve ter tag Environment = development"
  }

  assert {
    condition     = aws_instance.dev.tags["ManagedBy"] == "terraform"
    error_message = "EC2 deve ter tag ManagedBy = terraform"
  }
}
