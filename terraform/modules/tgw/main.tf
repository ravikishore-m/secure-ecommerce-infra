resource "aws_ec2_transit_gateway" "this" {
  description                     = var.name
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  tags                            = merge(var.tags, { Name = var.name })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  subnet_ids         = var.subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name}-attachment"
  })
}

