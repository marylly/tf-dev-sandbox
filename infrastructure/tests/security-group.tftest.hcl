
variables {
  my_ip = "203.0.113.0/32"  # IP de teste (TEST-NET-3)
}

run "validate_security_group_ingress_rules" {
  command = plan

  assert {
    condition     = length([for rule in aws_security_group.ec2.ingress : rule if rule.from_port == 22 && rule.to_port == 22]) > 0
    error_message = "Security Group deve ter regra de ingress para porta 22 (SSH)"
  }

  assert {
    condition     = length([for rule in aws_security_group.ec2.ingress : rule if rule.from_port == 22 && contains(rule.cidr_blocks, "0.0.0.0/0")]) == 0
    error_message = "Security Group não deve permitir SSH de 0.0.0.0/0"
  }

  assert {
    condition     = length([for rule in aws_security_group.ec2.ingress : rule if rule.from_port == 22 && contains(rule.cidr_blocks, var.my_ip)]) > 0
    error_message = "Security Group deve permitir SSH apenas do IP configurado em my_ip"
  }
}

run "validate_security_group_egress_rules" {
  command = plan

  assert {
    condition     = length([for rule in aws_security_group.ec2.egress : rule if rule.from_port == 443 && rule.to_port == 443]) > 0
    error_message = "Security Group deve ter regra de egress para porta 443 (HTTPS)"
  }

  assert {
    condition     = length([for rule in aws_security_group.ec2.egress : rule if rule.from_port == 80 && rule.to_port == 80]) > 0
    error_message = "Security Group deve ter regra de egress para porta 80 (HTTP)"
  }

  assert {
    condition     = length([for rule in aws_security_group.ec2.egress : rule if rule.from_port == 53 && rule.to_port == 53 && rule.protocol == "udp"]) > 0
    error_message = "Security Group deve ter regra de egress para porta 53 UDP (DNS)"
  }
}

run "validate_security_group_tags" {
  command = plan

  assert {
    condition     = aws_security_group.ec2.tags["Name"] == "terraform-dev-sandbox-ec2-sg"
    error_message = "Security Group deve ter tag Name = terraform-dev-sandbox-ec2-sg"
  }

  assert {
    condition     = aws_security_group.ec2.tags["Environment"] == "development"
    error_message = "Security Group deve ter tag Environment = development"
  }

  assert {
    condition     = aws_security_group.ec2.tags["ManagedBy"] == "terraform"
    error_message = "Security Group deve ter tag ManagedBy = terraform"
  }
}
