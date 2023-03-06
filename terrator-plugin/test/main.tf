provider "aws" {
    region = "eu-west-3"
    access_key = "ACCESS_KEY"
    secret_key = "SECRET_KEY"
    default_tags {
        tags {
            project_tag = "orness-autoscaled-cms"
        }
    }
}

data "aws_ami" "ubuntu" {
    most_recent = true
    filter {
        name = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
    }
    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
    owners = ["099720109477"]
}

data "aws_rds_engine_version" "cms_db_version" {
    engine = "mariadb"
    default_only = true
}

data "aws_availability_zones" "available" {
    state = "available"
}

resource "aws_vpc" "cms_main_vpc" {
    cidr_block = "10.0.0.0/16"
    instance_tenancy = "default"
}

resource "aws_subnet" "cms_frontend_subnet_az1" {
    vpc_id = "cms_main_vpc"
    cidr_block = "10.0.1.0/24"
    tags {
        Name = "cms_frontend_subnet_az1"
    }
}

resource "aws_subnet" "cms_frontend_subnet_az2" {
    vpc_id = "cms_main_vpc"
    cidr_block = "10.0.2.0/24"
    tags {
        Name = "cms_frontend_subnet_az2"
    }
}

resource "aws_internet_gateway" "cms_internet_gw" {
    vpc_id = "cms_main_vpc"
    tags {
        Name = "Main CMS VPC - Internet Gateway"
    }
}

resource "aws_route_table" "cms_routing_tbl" {
    vpc_id = "cms_main_vpc"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "cms_internet_gw"
    }
    tags {
        Name = "Public Subnet Route Table"
    }
}

resource "aws_subnet" "cms_lb_subnet_az1" {
    vpc_id = "cms_main_vpc"
    cidr_block = "10.0.3.0/24"
    tags {
        Name = "cms_lb_subnet_az1"
    }
}

resource "aws_subnet" "cms_lb_subnet_az2" {
    vpc_id = "cms_main_vpc"
    cidr_block = "10.0.4.0/24"
    tags {
        Name = "cms_lb_subnet_az2"
    }
}

resource "aws_route_table_association" "cms_lb_subnet_az1_gw_assoc" {
    vpc_id = "cms_main_vpc"
    subnet_id = ["cms_lb_subnet_az1"]
    route_table_id = ["cms_routing_tbl"]
}

resource "aws_route_table_association" "cms_lb_subnet_az2_gw_assoc" {
    vpc_id = "cms_main_vpc"
    subnet_id = ["cms_lb_subnet_az2"]
    route_table_id = ["cms_routing_tbl"]
}

resource "aws_subnet" "cms_backend_subnet_az1" {
    vpc_id = "cms_main_vpc"
    cidr_block = "10.0.5.0/24"
    availability_zone = "data.aws_availability_zones.available.names[0]"
    tags {
        Name = "cms_backend_subnet_az1"
    }
}

resource "aws_subnet" "cms_backend_subnet_az2" {
    vpc_id = "cms_main_vpc"
    cidr_block = "10.0.6.0/24"
    availability_zone = "data.aws_availability_zones.available.names[1]"
    tags {
        Name = "cms_backend_subnet_az2"
    }
}

resource "aws_subnet" "cms_dmz_subnet" {
    vpc_id = "cms_main_vpc"
    cidr_block = "10.0.101.0/24"
    tags {
        Name = "cms_dmz_subnet"
    }
}

resource "aws_security_group" "cms_frontend_secgroup_http" {
    name = "cms_frontend_secgroup_http"
    description = "HTTP Rules for the CMS Front-End servers"
    vpc_id = "cms_main_vpc"
    ingress {
        description = "HTTP from VPC"
        from_port = 8000
        to_port = 8000
        protocol = "tcp"
        cidr_blocks = ["10.0.0.0/16"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
    }
}

resource "aws_security_group" "cms_frontend_secgroup_nfs" {
    name = "cms_frontend_secgroup_nfs"
    description = "NFS Rules for the CMS Front-End servers"
    vpc_id = "cms_main_vpc"
    ingress {
        description = "NFS from VPC"
        from_port = 2049
        to_port = 2049
        protocol = "tcp"
        cidr_blocks = ["10.0.0.0/16"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
    }
}

resource "aws_security_group" "cms_frontend_secgroup_ssh" {
    name = "cms_frontend_secgroup_ssh"
    description = "SSH Rules for the CMS Front-End servers"
    vpc_id = "cms_main_vpc"
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["176.136.249.31/32"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
    }
}

resource "aws_security_group" "cms_backend_secgroup" {
    name = "cms_backend_secgroup"
    description = "Default Rules for the CMS Back-End servers"
    vpc_id = "cms_main_vpc"
    ingress {
        description = "MySQL from VPC"
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        cidr_blocks = ["10.0.0.0/16"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
    }
}

resource "aws_security_group" "cms_lb_secgroup_https" {
    name = "cms_lb_secgroup_https"
    description = "HTTPS Rules for the CMS LoadBalancer"
    vpc_id = "cms_main_vpc"
    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["176.136.249.31/32"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "cms_lb_secgroup_http" {
    name = "cms_lb_secgroup_http"
    description = "HTTP Rules for the CMS LoadBalancer"
    vpc_id = "cms_main_vpc"
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["176.136.249.31/32"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_s3_bucket" "cms_lb_logs_bucket" {
    bucket = "cmslblogsbucket"
}

resource "aws_s3_bucket_acl" "cms_lb_logs_bucket_acl" {
    bucket = ["cms_lb_logs_bucket"]
    acl = "private"
}

resource "aws_lb" "cms_frontend_lb" {
    name = "cms-frontend-lb"
    internal = false
    load_balancer_type = "application"
    security_groups = ["cms_lb_secgroup_https","cms_lb_secgroup_http"]
    subnets = ["cms_lb_subnet_az1","cms_lb_subnet_az2"]
    enable_deletion_protection = true
    access_logs {
        bucket = ["cms_lb_logs_bucket"]
        prefix = "lb-logs-"
        enabled = false
    }
}

resource "aws_lb_target_group" "cms_lb_target" {
    name = "cmslbtarget"
    target_type = "instance"
    port = 8000
    protocol = "HTTP"
    vpc_id = ["cms_main_vpc"]
}

resource "aws_launch_configuration" "cms_launch_conf" {
    name_prefix = "web-"
    image_id = ["ubuntu"]
    instance_type = "t3.micro"
    security_groups = ["cms_frontend_secgroup"]
    user_data = "<<EOF #!/bin/bash cd /tmp/ echo \\This is bad, it's not elegant, but it kind of gets the picture across\\. > index.html python3 -m http.server EOF"
}

resource "aws_autoscaling_group" "cms_asg" {
    name = "cms-asg"
    min_size = 1
    desired_capacity = 1
    max_size = 2
    health_check_type = "ELB"
    target_group_arns = ["cms_lb_target"]
    launch_configuration = "cms_launch_conf"
    vpc_zone_identifier = ["cms_frontend_subnet_az1","cms_frontend_subnet_az2"]
    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_autoscaling_policy" "cms_policy_up" {
    name = "web_policy_up"
    scaling_adjustment = "-1"
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = ["cms_asg"]
}

resource "aws_cloudwatch_metric_alarm" "cms_cpu_alarm_up" {
    alarm_name = "cms_cpu_alarm_up"
    comparison_operator = "GreaterThanOrEqualToThreshold"
    evaluation_periods = "2"
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = "120"
    statistic = "Average"
    threshold = "85"
    dimensions {
        AutoScalingGroupName = ["cms_asg"]
    }
    alarm_description = "This metric monitor EC2 instance CPU utilization"
    alarm_actions = [".cms_policy_up"]
}

resource "aws_autoscaling_policy" "cms_policy_down" {
    name = "cms_policy_down"
    scaling_adjustment = "-1"
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = ["cms_asg"]
}

resource "aws_cloudwatch_metric_alarm" "cms_cpu_alarm_down" {
    alarm_name = "cms_cpu_alarm_down"
    comparison_operator = "LessThanOrEqualToThreshold"
    evaluation_periods = "2"
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = "120"
    statistic = "Average"
    threshold = "30"
    dimensions {
        AutoScalingGroupName = ["cms_asg"]
    }
    alarm_description = "This metric monitor EC2 instance CPU utilization"
    alarm_actions = ["cms_policy_down"]
}

resource "aws_efs_file_system" "cms_fileshare" {
    tags {
        Name = "cms_fileshare"
    }
}

resource "aws_lb_listener" "cms_lb_listener" {
    load_balancer_arn = ["cms_frontend_lb"]
    port = "80"
    protocol = "HTTP"
    default_action {
        type = "forward"
        target_group_arn = ["cms_lb_target"]
    }
}

resource "aws_efs_mount_target" "cms_fileshare_mount" {
    file_system_id = ["cms_fileshare"]
    subnet_id = ["cms_frontend_subnet_az1"]
}

resource "aws_db_subnet_group" "cms_db_subnets" {
    name = "cms-db-main-subnets"
    subnet_ids = ["cms_backend_subnet_az1","cms_backend_subnet_az2"]
}

resource "aws_db_instance" "cms_db" {
    allocated_storage = 10
    db_name = "cmsdbmain"
    engine = ["mariadb"]
    vpc_security_group_ids = ["cms_backend_secgroup"]
    engine_version = ["8.0.27"]
    instance_class = "db.t3.micro"
    db_subnet_group_name = ["cms-db-main-subnets"]
    username = "toto"
    password = "tata"
    skip_final_snapshot = true
    publicly_accessible = false
}
