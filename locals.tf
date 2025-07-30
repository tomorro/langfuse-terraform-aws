locals {
  name = lower(local.name) == "langfuse" ? "langfuse-${var.env}" : "langfuse-${local.name}-${var.env}"
  common_tags = merge(var.common_tags, {
    env = var.env
  })
}
