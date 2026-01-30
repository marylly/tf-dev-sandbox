
variables {
  my_ip = "203.0.113.0/32"  # IP de teste (TEST-NET-3)
}

run "validate_internet_gateway_configuration" {
  command = plan

  assert {
    condition     = aws_internet_gateway.main.tags["Name"] == "terraform-dev-sandbox-igw"
    error_message = "Internet Gateway deve ter tag Name = terraform-dev-sandbox-igw"
  }

  assert {
    condition     = aws_internet_gateway.main.tags["Environment"] == "development"
    error_message = "Internet Gateway deve ter tag Environment = development"
  }

  assert {
    condition     = aws_internet_gateway.main.tags["ManagedBy"] == "terraform"
    error_message = "Internet Gateway deve ter tag ManagedBy = terraform"
  }
}

run "validate_route_table_configuration" {
  command = plan

  assert {
    condition     = length([for route in aws_route_table.public.route : route if route.cidr_block == "0.0.0.0/0"]) > 0
    error_message = "Route table deve ter rota para 0.0.0.0/0 (internet)"
  }

  assert {
    condition     = aws_route_table.public.tags["Name"] == "terraform-dev-sandbox-public-rt"
    error_message = "Route table deve ter tag Name = terraform-dev-sandbox-public-rt"
  }

  assert {
    condition     = aws_route_table.public.tags["Environment"] == "development"
    error_message = "Route table deve ter tag Environment = development"
  }

  assert {
    condition     = aws_route_table.public.tags["ManagedBy"] == "terraform"
    error_message = "Route table deve ter tag ManagedBy = terraform"
  }
}
