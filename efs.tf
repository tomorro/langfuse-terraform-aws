# EFS File System
resource "aws_efs_file_system" "langfuse" {
  creation_token  = "${local.name}-efs"
  encrypted       = true
  throughput_mode = "elastic"

  tags = merge(local.common_tags, {
    Name = "${local.name}-efs"
  })
}

# Mount targets in each private subnet
resource "aws_efs_mount_target" "eks" {
  count           = length(local.private_subnets)
  file_system_id  = aws_efs_file_system.langfuse.id
  subnet_id       = local.private_subnets[count.index]
  security_groups = [aws_security_group.eks.id]
}

# Security group for EFS
resource "aws_security_group" "efs" {
  name        = "${local.name}-efs"
  description = "Security group for EFS"
  vpc_id      = local.vpc_id

  ingress {
    description = "NFS from VPC"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-efs"
  })
}

# EFS CSI Driver IAM Policy
resource "aws_iam_policy" "efs" {
  name = "${local.name}-efs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:DescribeAccessPoints",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeMountTargets",
          "ec2:DescribeAvailabilityZones"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:CreateAccessPoint"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:RequestTag/efs.csi.aws.com/cluster" = "true"
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = "elasticfilesystem:DeleteAccessPoint"
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:ResourceTag/efs.csi.aws.com/cluster" = "true"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name}-efs"
  })
}

# EFS CSI Driver IAM Role
resource "aws_iam_role" "efs" {
  name = "${local.name}-efs-csi"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(aws_eks_cluster.langfuse.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.langfuse.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:efs-csi-controller-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "efs" {
  policy_arn = aws_iam_policy.efs.arn
  role       = aws_iam_role.efs.name
}

resource "kubernetes_storage_class" "efs" {
  metadata {
    name = "efs"
  }
  storage_provisioner = "efs.csi.aws.com"
}
