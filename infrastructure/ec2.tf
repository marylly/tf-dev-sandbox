data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))

  tags = {
    Name        = "${var.project_name}-key"
    Environment = "development"
    ManagedBy   = "terraform"
  }
}

resource "aws_instance" "dev" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  key_name               = aws_key_pair.main.key_name

  user_data = file("${path.module}/user-data.sh")

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name        = "${var.project_name}-root-volume"
      Environment = "development"
      ManagedBy   = "terraform"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name        = "${var.project_name}-ec2"
    Environment = "development"
    ManagedBy   = "terraform"
  }

  lifecycle {
    ignore_changes = [
      ami,
      user_data
    ]
  }
}

resource "null_resource" "instance_state" {
  triggers = {
    instance_id    = aws_instance.dev.id
    instance_state = var.instance_state
  }

  provisioner "local-exec" {
    command = <<-EOT
      if [ "${var.instance_state}" = "stopped" ]; then
        aws ec2 stop-instances --instance-ids ${aws_instance.dev.id} --region ${var.aws_region}
      else
        aws ec2 start-instances --instance-ids ${aws_instance.dev.id} --region ${var.aws_region}
      fi
    EOT
  }
}
