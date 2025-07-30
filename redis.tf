resource "aws_security_group" "redis" {
  name        = "${local.name}-redis"
  description = "Security group for Langfuse Redis"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-redis"
  })
}

resource "aws_elasticache_parameter_group" "redis" {
  family = "redis7"
  name   = "${local.name}-redis-params"

  parameter {
    name  = "maxmemory-policy"
    value = "noeviction"
  }
}

resource "aws_cloudwatch_log_group" "redis" {
  name              = "/redis/${local.name}"
  retention_in_days = 7
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${local.name}-redis-subnet-group"
  subnet_ids = module.vpc.private_subnets
}

# Random password for Redis
# Using a alphanumeric password to avoid issues with special characters on bash entrypoint
resource "random_password" "redis_password" {
  length      = 64
  special     = false
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = local.name
  description                = "Redis cluster for Langfuse"
  node_type                  = var.cache_node_type
  port                       = 6379
  parameter_group_name       = aws_elasticache_parameter_group.redis.name
  automatic_failover_enabled = var.cache_instance_count > 1 ? true : false
  num_cache_clusters         = var.cache_instance_count
  subnet_group_name          = aws_elasticache_subnet_group.redis.name
  security_group_ids         = [aws_security_group.redis.id]
  engine                     = "redis"
  engine_version             = "7.0"
  auth_token                 = random_password.redis_password.result
  transit_encryption_enabled = true
  at_rest_encryption_enabled = var.redis_at_rest_encryption
  multi_az_enabled           = var.redis_multi_az

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-redis"
  })
}
