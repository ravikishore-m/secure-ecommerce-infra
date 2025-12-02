locals {
  public_subnet_count      = length(var.public_subnet_cidrs)
  private_app_subnet_count = length(var.private_app_subnet_cidrs)
  private_data_subnet_cnt  = length(var.private_data_subnet_cidrs)
}

resource "aws_vpc" "this" {
  cidr_block                           = var.cidr_block
  enable_dns_hostnames                 = true
  enable_dns_support                   = true
  enable_network_address_usage_metrics = true

  tags = merge(var.tags, {
    Name = "${var.name}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-igw"
  })
}

resource "aws_subnet" "public" {
  for_each = { for idx, cidr in var.public_subnet_cidrs : idx => cidr }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = element(var.azs, each.key)
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name}-public-${each.key}"
    Tier = "public"
  })
}

resource "aws_subnet" "private_app" {
  for_each = { for idx, cidr in var.private_app_subnet_cidrs : idx => cidr }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = element(var.azs, each.key)

  tags = merge(var.tags, {
    Name = "${var.name}-private-app-${each.key}"
    Tier = "app"
  })
}

resource "aws_subnet" "private_data" {
  for_each = { for idx, cidr in var.private_data_subnet_cidrs : idx => cidr }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = element(var.azs, each.key)

  tags = merge(var.tags, {
    Name = "${var.name}-private-data-${each.key}"
    Tier = "data"
  })
}

resource "aws_eip" "nat" {
  for_each = aws_subnet.public

  vpc = true

  tags = merge(var.tags, {
    Name = "${var.name}-nat-${each.key}"
  })
}

resource "aws_nat_gateway" "this" {
  for_each = aws_subnet.public

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value.id

  tags = merge(var.tags, {
    Name = "${var.name}-nat-${each.key}"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-public-rt"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_app" {
  for_each = aws_subnet.private_app
  vpc_id   = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-private-app-rt-${each.key}"
  })
}

resource "aws_route" "private_app_outbound" {
  for_each               = aws_route_table.private_app
  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[each.key].id
}

resource "aws_route_table_association" "private_app" {
  for_each       = aws_subnet.private_app
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_app[each.key].id
}

resource "aws_route_table" "private_data" {
  for_each = aws_subnet.private_data
  vpc_id   = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-private-data-rt-${each.key}"
  })
}

resource "aws_route_table_association" "private_data" {
  for_each       = aws_subnet.private_data
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_data[each.key].id
}

resource "aws_flow_log" "this" {
  count                = var.enable_flow_logs && var.flow_log_destination_arn != null ? 1 : 0
  log_destination_type = "cloud-watch-logs"
  log_destination      = var.flow_log_destination_arn
  traffic_type         = var.flow_log_traffic_type
  vpc_id               = aws_vpc.this.id
}

