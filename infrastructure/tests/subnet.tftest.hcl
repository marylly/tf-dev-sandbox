
variables {
  my_ip = "203.0.113.0/32"  # IP de teste (TEST-NET-3)
}

run "validate_subnet_configuration" {
  command = plan

  assert {
    condition     = aws_subnet.public.cidr_block == "10.0.1.0/24"
    error_message = "Subnet CIDR block deve ser 10.0.1.0/24"
  }

  assert {
    condition     = aws_subnet.public.map_public_ip_on_launch == true
    error_message = "Subnet deve ter map_public_ip_on_launch = true"
  }

  assert {
    condition     = aws_subnet.public.tags["Name"] == "terraform-dev-sandbox-public-subnet"
    error_message = "Subnet deve ter tag Name = terraform-dev-sandbox-public-subnet"
  }

  assert {
    condition     = aws_subnet.public.tags["Environment"] == "development"
    error_message = "Subnet deve ter tag Environment = development"
  }

  assert {
    condition     = aws_subnet.public.tags["ManagedBy"] == "terraform"
    error_message = "Subnet deve ter tag ManagedBy = terraform"
  }
}

run "validate_subnet_availability_zone" {
  command = plan

  assert {
    condition     = length(aws_subnet.public.availability_zone) > 0
    error_message = "Subnet deve estar em uma availability zone válida"
  }
}
