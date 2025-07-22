terraform {
  backend "s3" {
    bucket = "terraform-state-deonibus-stage"
    key    = "state/eks/deonibus-vpc-eks-cluster.tfstate"
    region = "us-east-1"
  }
}