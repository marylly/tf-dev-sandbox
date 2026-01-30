resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-ec2-role"
    Environment = "development"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy" "ec2_terraform" {
  name = "${var.project_name}-terraform-policy"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2ReadOnly"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeImages",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumeStatus",
          "ec2:DescribeSnapshots",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSecurityGroupRules",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeRouteTables",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeNatGateways",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeRegions",
          "ec2:DescribeTags",
          "ec2:GetConsoleOutput"
        ]
        Resource = "*"
      },
      {
        Sid    = "VPCReadOnly"
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeRouteTables",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcEndpoints",
          "ec2:DescribeVpcPeeringConnections",
          "ec2:DescribeNetworkAcls",
          "ec2:DescribeVpcAttribute"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3ReadOnly"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:ListAllMyBuckets",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:GetBucketPolicy",
          "s3:GetBucketAcl",
          "s3:GetBucketCors",
          "s3:GetBucketWebsite",
          "s3:GetBucketLogging",
          "s3:GetBucketTagging",
          "s3:GetEncryptionConfiguration",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetObjectAcl"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMReadOnly"
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:GetUser",
          "iam:GetUserPolicy",
          "iam:GetGroup",
          "iam:GetGroupPolicy",
          "iam:GetInstanceProfile",
          "iam:ListRoles",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:ListPolicies",
          "iam:ListUsers",
          "iam:ListGroups",
          "iam:ListInstanceProfiles"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchReadOnly"
        Effect = "Allow"
        Action = [
          "cloudwatch:DescribeAlarms",
          "cloudwatch:DescribeAlarmsForMetric",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "cloudwatch:ListDashboards"
        ]
        Resource = "*"
      },
      {
        Sid    = "LogsReadOnly"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:DescribeMetricFilters",
          "logs:DescribeSubscriptionFilters",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:ListTagsLogGroup"
        ]
        Resource = "*"
      },
      {
        Sid    = "RDSReadOnly"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters",
          "rds:DescribeDBSnapshots",
          "rds:DescribeDBSubnetGroups",
          "rds:DescribeDBParameterGroups",
          "rds:DescribeDBSecurityGroups",
          "rds:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "LambdaReadOnly"
        Effect = "Allow"
        Action = [
          "lambda:ListFunctions",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:ListVersionsByFunction",
          "lambda:ListAliases",
          "lambda:ListEventSourceMappings",
          "lambda:GetPolicy"
        ]
        Resource = "*"
      },
      {
        Sid    = "ELBReadOnly"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "AutoScalingReadOnly"
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribePolicies",
          "autoscaling:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}


resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2.name

  tags = {
    Name        = "${var.project_name}-ec2-profile"
    Environment = "development"
    ManagedBy   = "terraform"
  }
}
