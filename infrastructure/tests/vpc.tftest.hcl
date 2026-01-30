
variables {
  my_ip = "203.0.113.0/32"  # IP de teste (TEST-NET-3)
}

run "validate_vpc_configuration" {
  command = plan

  assert {
    condition     = aws_vpc.main.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR block deve ser 10.0.0.0/16"
  }

  assert {
    condition     = aws_vpc.main.enable_dns_hostnames == true
    error_message = "DNS hostnames deve estar habilitado na VPC"
  }

  assert {
    condition     = aws_vpc.main.enable_dns_support == true
    error_message = "DNS support deve estar habilitado na VPC"
  }

  assert {
    condition     = aws_vpc.main.tags["Name"] == "terraform-dev-sandbox-vpc"
    error_message = "VPC deve ter tag Name = terraform-dev-sandbox-vpc"
  }

  assert {
    condition     = aws_vpc.main.tags["Environment"] == "development"
    error_message = "VPC deve ter tag Environment = development"
  }

  assert {
    condition     = aws_vpc.main.tags["ManagedBy"] == "terraform"
    error_message = "VPC deve ter tag ManagedBy = terraform"
  }
}

