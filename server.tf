resource "aws_iam_role" "jupyter_server_role" {
  name = local.common_tags.Name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "server_s3_access" {
  name = "AllowAccessToStorageBuckets"
  role = aws_iam_role.jupyter_server_role.id
  policy = jsonencode(
    {
      Version = "2012-10-17",
      Statement = [
        {
          Effect   = "Allow",
          Action   = "s3:*",
          Resource = ["*"]
        }
      ]
    }
  )
}

# For adding SSM to the instance:
resource "aws_iam_role_policy_attachment" "server_ssm" {
  role       = aws_iam_role.jupyter_server_role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "server_instance_profile" {
  name = local.common_tags.Name
  role = aws_iam_role.jupyter_server_role.name
}

resource "aws_eip_association" "ip_assoc" {
  allocation_id = var.eip_allocation_id
  instance_id   = aws_instance.hub.id
}

resource "aws_instance" "hub" {

  # Ubuntu 22.04 LTS https://cloud-images.ubuntu.com/locator/ec2/
  ami                    = "ami-024e6efaf93d85776"
  instance_type          = "m5.xlarge"
  monitoring             = true
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.jupyter_server.id]
  ebs_optimized          = true
  iam_instance_profile   = aws_iam_instance_profile.server_instance_profile.name

  root_block_device {
    volume_type = "gp3"
    volume_size = 64
    encrypted   = true
  }
  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/provision.sh",
    {
      domain      = var.domain,
      admin_email = var.admin_email
    }
  )
}
