# module "eks" {
#   source = "terraform-aws-modules/eks/aws"

#   cluster_name    = "my-eks-cluster"
#   cluster_version = "1.29"

#   cluster_endpoint_public_access = true

#   vpc_id     = module.vpc.vpc_id
#   subnet_ids = module.vpc.private_subnets

#   eks_managed_node_groups = {
#     nodes = {
#       min_size     = 1
#       max_size     = 3
#       desired_size = 2

#       instance_type = ["t2.small"]
#     }
#   }

#   tags = {
#     Environment = "dev"
#     Terraform   = "true"
#   }
# }


# resource "aws_vpc" "main" {
#   cidr_block = var.cidr_block

#   # Must be enabled for EFS
#   enable_dns_support   = true
#   enable_dns_hostnames = true

#   tags = {
#     Name = "main"
#   }
# }

# resource "aws_internet_gateway" "igw" {
#   vpc_id = aws_vpc.main.id

#   tags = {
#     Name = "igw"
#   }
# }

# resource "aws_subnet" "private-us-east-1a" {
#   vpc_id            = aws_vpc.main.id
#   cidr_block        = var.private_subnets[0]
#   availability_zone = "us-east-1a"

#   tags = {
#     "Name"                                      = "private-us-east-1a"
#     "kubernetes.io/role/internal-elb"           = "1"
#     "kubernetes.io/cluster/${var.cluster_name}" = "owned"
#   }
# }

# resource "aws_subnet" "private-us-east-1b" {
#   vpc_id            = aws_vpc.main.id
#   cidr_block        = var.private_subnets[1]
#   availability_zone = "us-east-1b"

#   tags = {
#     "Name"                                      = "private-us-east-1b"
#     "kubernetes.io/role/internal-elb"           = "1"
#     "kubernetes.io/cluster/${var.cluster_name}" = "owned"
#   }
# }

# resource "aws_subnet" "public-us-east-1a" {
#   vpc_id                  = aws_vpc.main.id
#   cidr_block              = var.public_subnets[0]
#   availability_zone       = "us-east-1a"
#   map_public_ip_on_launch = true

#   tags = {
#     "Name"                                      = "public-us-east-1a"
#     "kubernetes.io/role/elb"                    = "1"
#     "kubernetes.io/cluster/${var.cluster_name}" = "owned"
#   }
# }


# resource "aws_eip" "nat" {
#   domain   = "vpc"

#   tags = {
#     Name = "nat"
#   }
# }

# resource "aws_nat_gateway" "nat" {
#   allocation_id = aws_eip.nat.id
#   subnet_id     = aws_subnet.public-us-east-1a.id

#   tags = {
#     Name = "nat"
#   }

#   depends_on = [aws_internet_gateway.igw]
# }

# resource "aws_route_table" "private" {
#   vpc_id = aws_vpc.main.id

#   route {
#     cidr_block     = "0.0.0.0/0"
#     nat_gateway_id = aws_nat_gateway.nat.id
#   }

#   tags = {
#     Name = "private"
#   }
# }

# resource "aws_route_table" "public" {
#   vpc_id = aws_vpc.main.id

#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.igw.id
#   }

#   tags = {
#     Name = "public"
#   }
# }

# resource "aws_route_table_association" "private-us-east-1a" {
#   subnet_id      = aws_subnet.private-us-east-1a.id
#   route_table_id = aws_route_table.private.id
# }

# resource "aws_route_table_association" "private-us-east-1b" {
#   subnet_id      = aws_subnet.private-us-east-1b.id
#   route_table_id = aws_route_table.private.id
# }

# resource "aws_route_table_association" "public-us-east-1a" {
#   subnet_id      = aws_subnet.public-us-east-1a.id
#   route_table_id = aws_route_table.public.id
# }

# resource "aws_route_table_association" "public-us-east-1b" {
#   subnet_id      = aws_subnet.public-us-east-1b.id
#   route_table_id = aws_route_table.public.id
# }

module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "19.21.0"

  cluster_name                   = var.cluster_name
  cluster_version                = 1.29
  cluster_endpoint_public_access = true

  cluster_addons = {
    kube-proxy = {
      resolve_conflicts        = "OVERWRITE"
    }
    vpc-cni    = {
      resolve_conflicts        = "OVERWRITE"
    }
    coredns = {
      resolve_conflicts        = "OVERWRITE"

      configuration_values = jsonencode({
        computeType = "Fargate"
      })
    }
  }

  vpc_id                   = data.aws_vpc.vpc.id
  subnet_ids               = [data.aws_subnet.public.id, data.aws_subnets.private.ids[0], data.aws_subnets.private.ids[1]]

  # Fargate profiles use the cluster primary security group so these are not utilized
  create_cluster_security_group = false
  create_node_security_group    = false

  # fargate_profile_defaults = {
  #   iam_role_additional_policies = {
  #     additional = module.ebs_csi_irsa_role.iam_role_arn
  #     additional = module.efs_csi_irsa_role.iam_role_arn
  #   }
  # }

  fargate_profiles = {
      example = {
        name = "test-profile"
        selectors = [
          {
            namespace = "kube-system"
            # labels = {
            #   Application = "backend"
            # }
          }
        ]
        # Using specific subnets instead of the subnets supplied for the cluster itself
        subnet_ids = [data.aws_subnets.private.ids[0], data.aws_subnets.private.ids[1]]
      },
      example1 = {
        name = "sample-app-profile"
        selectors = [
          {
            namespace = "argocd"
            # labels = {
            #   Application = "app-wildcard"
            # }
          }
        ]
        subnet_ids = [data.aws_subnets.private.ids[0], data.aws_subnets.private.ids[1]]
      }
    }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

# module "lb_role" {
#  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

#  role_name                              = "${var.cluster_name}-eks-lb"
#  attach_load_balancer_controller_policy = true

#  oidc_providers = {
#      main = {
#      provider_arn               = module.eks.oidc_provider_arn
#      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
#      }
#  }
#  }

# resource "kubernetes_service_account" "service-account" {
#  depends_on = [module.eks]
#  metadata {
#      name      = "aws-load-balancer-controller"
#      namespace = "kube-system"
#      labels = {
#      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
#      "app.kubernetes.io/component" = "controller"
#      }
#      annotations = {
#      "eks.amazonaws.com/role-arn"               = module.lb_role.iam_role_arn
#      "eks.amazonaws.com/sts-regional-endpoints" = "true"
#      }
#  }
#  }

#  resource "helm_release" "alb-controller" {
#  name       = "aws-load-balancer-controller"
#  repository = "https://aws.github.io/eks-charts"
#  chart      = "aws-load-balancer-controller"
#  namespace  = "kube-system"
#  depends_on = [
#      kubernetes_service_account.service-account
#  ]

#  set {
#      name  = "region"
#      value = "us-east-1"
#  }

#  set {
#      name  = "vpcId"
#      value = var.vpc_id
#  }

#  set {
#      name  = "image.repository"
#      value = "602401143452.dkr.ecr.us-east-1.amazonaws.com/amazon/aws-load-balancer-controller"
#  }

#  set {
#      name  = "serviceAccount.create"
#      value = "false"
#  }

#  set {
#      name  = "serviceAccount.name"
#      value = "aws-load-balancer-controller"
#  }

#  set {
#      name  = "clusterName"
#      value = var.cluster_name
#  }
#  }

#  resource "aws_eks_access_entry" "access-cred-entry" {
#   cluster_name      = module.eks.cluster_name
#   principal_arn     = "arn:aws:iam::594599110225:user/jomarlAdmin"
#   type              = "STANDARD"
# }

# resource "aws_eks_access_policy_association" "access-cred-entry-policy" {
#   cluster_name  = module.eks.cluster_name
#   policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
#   principal_arn = "arn:aws:iam::594599110225:user/jomarlAdmin"

#   access_scope {
#     type       = "cluster"
#   }
# }

# resource "null_resource" "install_efs_csi_driver" {
#   depends_on = [module.eks.aws_eks_cluster]

#   provisioner "local-exec" {
#     # command = "kubectl config set-cluster eks-fargate-profile --proxy-url=https://5CEF3DD36F87B98BB1ED10E4BE210225.gr7.us-east-1.eks.amazonaws.com"
#     command = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region us-east-1"
#   }
#   # provisioner "local-exec" {
#   #   command = "kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-efs-csi-driver/master/deploy/kubernetes/base/csidriver.yaml"
#   # }
#   # provisioner "local-exec" {
#   #   command = "kubectl apply -f efs.yaml"
#   # }
# }

# module "metrics_server" {
#   source  = "boeboe/metrics-server/helm"
#   version = "0.0.1"

#   metrics_server_helm_version = "3.8.2"
#   metrics_server_version      = "v0.6.1"

#   metrics_server_settings = {
#     "podAnnotations.custom\\.annotation\\.io" = "test"
#     "podAnnotations.environment"              = "test"
#     "metrics.enabled"                         = "true"
#     "args[0]"                                 = "--kubelet-insecure-tls"
#     "args[1]"                                 = "--kubelet-preferred-address-types=InternalIP"
#   }
# }



# module "attach_efs_csi_role" {
#   source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

#   role_name             = "${var.cluster_name}-efs-csi"
#   attach_efs_csi_policy = true

#   oidc_providers = {
#     ex = {
#       provider_arn               = module.eks.oidc_provider_arn
#       namespace_service_accounts = ["kube-system:efs-csi-controller-sa"]
#     }
#   }
# }


# resource "helm_release" "aws_efs_csi_driver" {
#   depends_on = [module.eks]
  
#   chart      = "aws-efs-csi-driver"
#   name       = "aws-efs-csi-driver"
#   namespace  = "kube-system"
#   repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"

#   set {
#     name  = "image.repository"
#     value = "602401143452.dkr.ecr.us-east-1.amazonaws.com/eks/aws-efs-csi-driver"
#   }

#   set {
#     name  = "controller.serviceAccount.create"
#     value = true
#   }

#   set {
#     name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
#     value = module.attach_efs_csi_role.iam_role_arn
#   }

#   set {
#     name  = "controller.serviceAccount.name"
#     value = "efs-csi-controller-sa"
#   }
# }




# resource "aws_efs_file_system" "eks" {
#   creation_token = "eks"

#   performance_mode = "generalPurpose"
#   throughput_mode  = "bursting"
#   encrypted        = true

#   # lifecycle_policy {
#   #   transition_to_ia = "AFTER_30_DAYS"
#   # }

#   tags = {
#     Name = "eks"
#   }
# }

# resource "aws_efs_mount_target" "zone-a" {
#   file_system_id  = aws_efs_file_system.eks.id
#   subnet_id       = aws_subnet.private-us-east-1a.id
#   security_groups = [module.eks.cluster_primary_security_group_id]
# }

# resource "aws_efs_mount_target" "zone-b" {
#   file_system_id  = aws_efs_file_system.eks.id
#   subnet_id       = aws_subnet.private-us-east-1b.id
#   security_groups = [module.eks.cluster_primary_security_group_id]
# }



#  provider "zabbix" {
#   # Required
#   username = "Admin"
#   password = "zabbix"
#   url = "http://example.com/api_jsonrpc.php"
  
#   # Optional

#   # Disable TLS verfication (false by default)
#   tls_insecure = true

#   # Serialize Zabbix API calls (false by default)
#   # Note: race conditions have been observed, enable this if required
#   serialize = true
# }

# resource "zabbix_host" "example" {
#   host = "server.example.com"
#   name = "Friendly Name"

#   enabled = false

#   groups = [ "1234" ]
#   templates = [ "5678" ]
#   proxyid = "7890"

#   interface {
#     type = "snmp"
#     dns = "interface.dns.name"
#     ip = "interface.ip.addr"

#     main = false
#     port = 1161

#     # if zabbix version >= 5 and type is snmp
#     snmp_version = "3"
#     snmp_community = "public"
#     snmp3_authpassphrase = "supersecretpassword"
#     snmp3_authprotocol = "md5"
#     snmp3_contextname = "context"
#     snmp3_privpassphrase = "anotherpassword"
#     snmp3_privprotocol = "des"
#     snmp3_securitylevel = "noauthnopriv"
#     snmp3_securityname = "secname"
#   }

#   macro {
#     key = "{$MACROABC}"
#     value = "test_value_one"
#   }

#   inventory_mode = "manual"
#   inventory {
#     alias = "bob"
#     notes = "test note"
#   }
# }
# # provider "helm" {
# #   kubernetes {
#     host                   = module.eks.cluster_endpoint
#     cluster_ca_certificate = module.eks.cluster_certificate_authority_data
#     exec {
#       api_version = "client.authentication.k8s.io/v1beta1"
#       args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_id]
#       command     = "aws"
#     }
#   }
# }

# resource "helm_release" "metrics-server" {
#   name = "metrics-server"

#   repository = "https://kubernetes-sigs.github.io/metrics-server/"
#   chart      = "metrics-server"
#   namespace  = "kube-system"
#   version    = "3.8.2"

#   set {
#     name  = "metrics.enabled"
#     value = false
#   }

#   depends_on = [module.eks.fargate_profiles]
# }

