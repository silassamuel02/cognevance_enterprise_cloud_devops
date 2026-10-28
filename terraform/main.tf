module "network" {
  source = "./modules/network"

  project_name       = var.project_name
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
}

module "compute" {
  source = "./modules/compute"

  project_name  = var.project_name
  instance_type = var.instance_type
  vpc_id        = module.network.vpc_id
  subnet_id     = module.network.public_subnet_id
  admin_cidr    = var.admin_cidr
  key_name      = var.key_name

  depends_on = [module.network]
}
