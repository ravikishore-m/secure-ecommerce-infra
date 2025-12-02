locals {
  addon_names = ["vpc-cni", "coredns", "kube-proxy", "eks-pod-identity-agent", "aws-ebs-csi-driver"]
  node_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ]
}

resource "aws_iam_role" "cluster" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume.json

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-cluster-role"
  })
}

data "aws_iam_policy_document" "cluster_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "cluster_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  ])

  policy_arn = each.value
  role       = aws_iam_role.cluster.name
}

resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Cluster control plane security group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-cluster-sg"
  })
}

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 90
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = false
    security_group_ids      = [aws_security_group.cluster.id]
  }

  kubernetes_network_config {
    ip_family = "ipv4"
  }

  dynamic "encryption_config" {
    for_each = var.kms_key_arn != "" ? [1] : []
    content {
      provider {
        key_arn = var.kms_key_arn
      }
      resources = ["secrets"]
    }
  }

  dynamic "enabled_cluster_log_types" {
    for_each = var.enable_control_plane_logs ? [1] : []
    content  = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policies,
    aws_cloudwatch_log_group.cluster
  ]

  tags = var.tags
}

resource "aws_iam_role" "node" {
  for_each = var.node_groups

  name               = "${var.cluster_name}-${each.key}-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-${each.key}-node-role"
  })
}

data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "node_policies" {
  for_each = {
    for combo in setproduct(keys(var.node_groups), local.node_policy_arns) :
    "${combo[0]}-${basename(combo[1])}" => {
      role_key   = combo[0]
      policy_arn = combo[1]
    }
  }

  role       = aws_iam_role.node[each.value.role_key].name
  policy_arn = each.value.policy_arn
}

resource "aws_eks_node_group" "this" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = each.key
  node_role_arn   = aws_iam_role.node[each.key].arn
  subnet_ids      = length(lookup(each.value, "subnets", [])) > 0 ? each.value.subnets : var.private_subnet_ids
  capacity_type   = each.value.capacity_type
  instance_types  = each.value.instance_types

  scaling_config {
    desired_size = each.value.desired_size
    min_size     = each.value.min_size
    max_size     = each.value.max_size
  }

  dynamic "taint" {
    for_each = lookup(each.value, "taints", [])
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  labels = lookup(each.value, "labels", null)

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-${each.key}"
  })

  depends_on = [
    aws_eks_cluster.this
  ]
}

resource "aws_iam_openid_connect_provider" "this" {
  count = var.enable_irsa ? 1 : 0

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da0afd10df6"]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = var.tags
}

resource "aws_eks_addon" "addons" {
  for_each     = toset(local.addon_names)
  cluster_name = aws_eks_cluster.this.name
  addon_name   = each.value

  depends_on = [aws_eks_cluster.this]
  tags       = var.tags
}

