locals {
  tag_name = lower(var.name) == "langfuse" ? "langfuse-${var.env}" : "langfuse-${var.name}-${var.env}"
  common_tags = merge(var.common_tags, {
    env = var.env
  })
}
