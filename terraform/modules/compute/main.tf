data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_caller_identity" "current" {}

locals {
  join_token_name = "/${var.project_name}/swarm/worker-join-token"
  join_token_arn  = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${local.join_token_name}"
}

resource "aws_security_group" "manager" {
  name_prefix = "${var.project_name}-cluster-"
  description = "Security group for Docker Swarm nodes"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP application traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Swarm manager control traffic between cluster nodes"
    from_port   = 2377
    to_port     = 2377
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Swarm node discovery TCP"
    from_port   = 7946
    to_port     = 7946
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Swarm node discovery UDP"
    from_port   = 7946
    to_port     = 7946
    protocol    = "udp"
    self        = true
  }

  ingress {
    description = "Swarm overlay network traffic"
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    self        = true
  }

  dynamic "ingress" {
    for_each = var.admin_cidr == null ? [] : [var.admin_cidr]

    content {
      description = "Optional restricted SSH access"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    description = "Outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-cluster-sg"
  }
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "manager" {
  name_prefix        = "${var.project_name}-manager-"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role" "worker" {
  name_prefix        = "${var.project_name}-worker-"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "manager_ssm" {
  role       = aws_iam_role.manager.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "worker_ssm" {
  role       = aws_iam_role.worker.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "manager_join_token" {
  name = "publish-swarm-worker-token"
  role = aws_iam_role.manager.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:PutParameter"]
        Resource = local.join_token_arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Encrypt", "kms:GenerateDataKey"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService"                      = "ssm.${var.aws_region}.amazonaws.com"
            "kms:EncryptionContext:PARAMETER_ARN" = local.join_token_arn
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "worker_join_token" {
  name = "read-swarm-worker-token"
  role = aws_iam_role.worker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = local.join_token_arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService"                      = "ssm.${var.aws_region}.amazonaws.com"
            "kms:EncryptionContext:PARAMETER_ARN" = local.join_token_arn
          }
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "manager" {
  name_prefix = "${var.project_name}-manager-"
  role        = aws_iam_role.manager.name
}

resource "aws_iam_instance_profile" "worker" {
  name_prefix = "${var.project_name}-worker-"
  role        = aws_iam_role.worker.name
}

resource "aws_instance" "manager" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.manager.id]
  iam_instance_profile   = aws_iam_instance_profile.manager.name
  key_name               = var.key_name

  user_data = <<-USERDATA
    #!/bin/bash
    set -euxo pipefail
    dnf install -y docker
    if ! command -v aws >/dev/null 2>&1; then
      dnf install -y awscli-2 || dnf install -y awscli
    fi
    systemctl enable --now docker

    PRIVATE_IP=$(hostname -I | awk '{print $1}')
    docker swarm init --advertise-addr "$PRIVATE_IP"

    TOKEN=$(docker swarm join-token -q worker)
    for attempt in $(seq 1 20); do
      if aws ssm put-parameter \
        --name "${local.join_token_name}" \
        --type SecureString \
        --value "$TOKEN" \
        --overwrite \
        --region "${var.aws_region}"; then
        break
      fi
      sleep 10
    done
  USERDATA

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "${var.project_name}-manager"
    Role = "docker-manager"
  }

  depends_on = [
    aws_iam_role_policy_attachment.manager_ssm,
    aws_iam_role_policy.manager_join_token
  ]
}

resource "aws_instance" "worker" {
  count = var.worker_count

  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.manager.id]
  iam_instance_profile   = aws_iam_instance_profile.worker.name
  key_name               = var.key_name

  user_data = <<-USERDATA
    #!/bin/bash
    set -euxo pipefail
    dnf install -y docker
    if ! command -v aws >/dev/null 2>&1; then
      dnf install -y awscli-2 || dnf install -y awscli
    fi
    systemctl enable --now docker

    TOKEN=""
    for attempt in $(seq 1 60); do
      TOKEN=$(aws ssm get-parameter \
        --name "${local.join_token_name}" \
        --with-decryption \
        --query Parameter.Value \
        --output text \
        --region "${var.aws_region}" 2>/dev/null || true)

      if [ -n "$TOKEN" ] && [ "$TOKEN" != "None" ]; then
        break
      fi
      sleep 10
    done

    if [ -z "$TOKEN" ] || [ "$TOKEN" = "None" ]; then
      echo "Could not retrieve the Swarm join token" >&2
      exit 1
    fi

    docker swarm join --token "$TOKEN" "${aws_instance.manager.private_ip}:2377"
  USERDATA

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "${var.project_name}-worker-$${count.index + 1}"
    Role = "docker-worker"
  }

  depends_on = [
    aws_instance.manager,
    aws_iam_role_policy_attachment.worker_ssm,
    aws_iam_role_policy.worker_join_token
  ]
}
