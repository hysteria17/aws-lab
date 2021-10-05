provider "aws" {
    region = "eu-central-1"
}

resource "aws_vpc" "wp-test-vpc" {
  cidr_block = "10.30.0.0/16"

  tags = {
    "Name" = "wp-test-vpc"
  }
}

resource "aws_subnet" "wp-sn-1" {
    vpc_id = aws_vpc.wp-test-vpc.id
    cidr_block = "10.30.0.0/24"

    availability_zone = "eu-central-1a"

    tags = {
      "Name" = "wp-sn-1"
    }

    depends_on = [
      aws_vpc.wp-test-vpc
    ]
  
}

resource "aws_subnet" "wp-sn-2" {
    vpc_id = aws_vpc.wp-test-vpc.id
    cidr_block = "10.30.1.0/24"
    
    availability_zone =  "eu-central-1b"

    tags = {
      "Name" = "wp-sn-2"
    }

    depends_on = [
      aws_vpc.wp-test-vpc
    ]
  
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.wp-test-vpc.id

  tags = {
    Name = "wp-test-igw"
  }

  depends_on = [
      aws_vpc.wp-test-vpc
    ]
}

resource "aws_route_table" "wp-test-rt" {
    vpc_id = aws_vpc.wp-test-vpc.id


    tags = {
      "Name" = "wp-test-rt"
    }

    depends_on = [
      aws_vpc.wp-test-vpc,
      aws_internet_gateway.igw
    ]
  
}

resource "aws_route" "wp-test-route" {
    route_table_id = aws_route_table.wp-test-rt.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.wp-sn-1.id
  route_table_id = aws_route_table.wp-test-rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.wp-sn-2.id
  route_table_id = aws_route_table.wp-test-rt.id
}

resource "aws_security_group" "http-access" {
    name = "allow http"
    description = "allow http"
    vpc_id = aws_vpc.wp-test-vpc.id

    tags = {
        Name = "allow_http"
    }
  
}

resource "aws_security_group_rule" "ingress-http-rule" {
    type = "ingress"
    description      = "HTTP from anywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]

    security_group_id = aws_security_group.http-access.id
}

resource "aws_security_group_rule" "egress-allow-all" {
    type = "egress"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]

    security_group_id = aws_security_group.http-access.id
}

resource "aws_security_group" "ssh-access" {
    name = "allow ssh"
    description = "allow ssh"
    vpc_id = aws_vpc.wp-test-vpc.id

    tags = {
        Name = "allow_ssh"
    }
  
}
resource "aws_security_group_rule" "ingress-ssh-rule" {
    type = "ingress"
    description      = "SSH from anywhere"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]

    security_group_id = aws_security_group.ssh-access.id
}

resource "aws_security_group_rule" "ssh-egress-allow-all" {
    type = "egress"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]

    security_group_id = aws_security_group.ssh-access.id
}

resource "aws_security_group" "mysql-access" {
    name = "allow mysql"
    description = "allow mysql"
    vpc_id = aws_vpc.wp-test-vpc.id

    tags = {
        Name = "allow_mysql"
    }
  
}
resource "aws_security_group_rule" "ingress-mysql-rule" {
    type = "ingress"
    description      = "MySQL from anywhere"
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    cidr_blocks      = ["10.30.0.0/16"]
    # ipv6_cidr_blocks = ["::/0"]

    security_group_id = aws_security_group.mysql-access.id
}

resource "aws_security_group_rule" "mysql-egress-allow-all" {
    type = "egress"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]

    security_group_id = aws_security_group.mysql-access.id
}

data "aws_network_interface" "efs_ni1" {
    id = aws_efs_mount_target.efs_mount1.network_interface_id
}

data "aws_network_interface" "efs_ni2" {
    id = aws_efs_mount_target.efs_mount2.network_interface_id
}

data "template_file" "init1" {
  template = file("script.tpl")
  vars = {
    efs_id              = aws_efs_file_system.efs.id
    efs_mount_id        = aws_efs_mount_target.efs_mount1.id
    efs_access_point_id = aws_efs_access_point.wp_efs_access_point.id
    efs_ip = data.aws_network_interface.efs_ni1.private_ip
  }
}

data "template_file" "init2" {
  template = file("script2.tpl")
  vars = {
    efs_id              = aws_efs_file_system.efs.id
    efs_mount_id        = aws_efs_mount_target.efs_mount2.id
    efs_access_point_id = aws_efs_access_point.wp_efs_access_point.id
    efs_ip = data.aws_network_interface.efs_ni2.private_ip
  }
}

resource "aws_key_pair" "key_pair" {
    key_name = "id_ed25519.pub"
    public_key = file("id_ed25519.pub")
  
}

resource "aws_instance" "wp-instance-1" {
    ami = "ami-07df274a488ca9195"
    associate_public_ip_address = true
    instance_type = "t2.micro"

    key_name = aws_key_pair.key_pair.key_name

    tags = {
        Name = "wp-instance-1"
    }

    subnet_id = aws_subnet.wp-sn-1.id
    vpc_security_group_ids = [aws_security_group.http-access.id, aws_security_group.ssh-access.id]

    user_data = data.template_file.init1.rendered
  
}

resource "aws_instance" "wp-instance-2" {
    ami = "ami-07df274a488ca9195"
    associate_public_ip_address = true
    instance_type = "t2.micro"

    key_name = aws_key_pair.key_pair.key_name

    tags = {
        Name = "wp-instance-2"
    }

    subnet_id = aws_subnet.wp-sn-2.id
    vpc_security_group_ids = [aws_security_group.http-access.id, aws_security_group.ssh-access.id]

    user_data = data.template_file.init2.rendered

}

resource "aws_alb_target_group" "lb-target-group" {
  name     = "wp-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.wp-test-vpc.id
}

resource "aws_alb_target_group_attachment" "lb-tg-attach1" {
    target_group_arn = aws_alb_target_group.lb-target-group.arn
    target_id        = aws_instance.wp-instance-1.id
    port             = 80
}

resource "aws_alb_target_group_attachment" "lb-tg-attach2" {
    target_group_arn = aws_alb_target_group.lb-target-group.arn
    target_id        = aws_instance.wp-instance-2.id
    port             = 80
}

resource "aws_alb" "wp-lb" {
    name               = "wp-lb-tf"
    internal           = false
    load_balancer_type = "application"
    security_groups    = [aws_security_group.http-access.id]
    subnets            = [aws_subnet.wp-sn-1.id, aws_subnet.wp-sn-2.id]

    tags = {
        Name = "wp-load-balancer"
    }
  
}

resource "aws_alb_listener" "wp-lb-listener" {
    load_balancer_arn = aws_alb.wp-lb.arn
    port = 80
    protocol = "HTTP"
    default_action {
      type = "forward"
      target_group_arn = aws_alb_target_group.lb-target-group.arn

    }
  
}

module "efs_sg" {
  #* EFS Security Group
  
  source = "terraform-aws-modules/security-group/aws"

  name        = "efs-sg"
  description = "Security group for EFS"
  vpc_id      = aws_vpc.wp-test-vpc.id


  ingress_cidr_blocks = ["10.30.0.0/16"]
  ingress_rules = ["nfs-tcp"]

  egress_with_cidr_blocks = [
    {
      rule        = "all-all"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

resource "aws_efs_file_system" "efs" {
  creation_token = "wp-efs"
  encrypted      = false
  tags = {
    Name = "wp-efs"
  }
}

resource "aws_efs_mount_target" "efs_mount1" {
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = aws_subnet.wp-sn-1.id
  security_groups = [module.efs_sg.security_group_id]
}

resource "aws_efs_mount_target" "efs_mount2" {
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = aws_subnet.wp-sn-2.id
  security_groups = [module.efs_sg.security_group_id]
}

resource "aws_efs_access_point" "wp_efs_access_point" {
  file_system_id = aws_efs_file_system.efs.id
}

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 3.0"

  identifier = "demodb"

  engine            = "mysql"
  engine_version    = "8.0.23"
  instance_class    = "db.t2.micro"
  allocated_storage = 20

  name     = "demodb"
  username = "user"
  password = "MyExamplePass123"
  port     = "3306"

#   iam_database_authentication_enabled = true

  vpc_security_group_ids = [aws_security_group.mysql-access.id]

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  # Enhanced Monitoring - see example for details on how to create the role
  # by yourself, in case you don't want to create it automatically
#   monitoring_interval = "30"
#   monitoring_role_name = "MyRDSMonitoringRole"
#   create_monitoring_role = true

  tags = {
    Owner       = "user"
  }

  # DB subnet group
  subnet_ids = [aws_subnet.wp-sn-1.id, aws_subnet.wp-sn-2.id]

  # DB parameter group
  family = "mysql8.0"

  # DB option group
  major_engine_version = "8.0"

  # Database Deletion Protection
#   deletion_protection = true

  parameters = [
    {
      name = "character_set_client"
      value = "utf8mb4"
    },
    {
      name = "character_set_server"
      value = "utf8mb4"
    }
  ]

}


# SZpMfA9xJ*NzXWrIB)

# sudo docker run --name some-wordpress -p 80:80 -e WORDPRESS_DB_HOST=demodb.cdzss2jfrhfx.eu-central-1.rds.amazonaws.com:3306 -e WORDPRESS_DB_USER=user -v /efs:/var/www/html -e WORDPRESS_DB_PASSWORD=MyExamplePass\!23 -e WORDPRESS_DB_NAME=demodb -d wordpress