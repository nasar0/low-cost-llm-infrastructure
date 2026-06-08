# Creación de la VPC
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "llm-vpc"
  }
}

# Subred Pública donde vivirá la EC2
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.aws_zone
  map_public_ip_on_launch = true # Asigna IP pública automáticamente

  tags = {
    Name = "llm-public-subnet"
  }
}

# Internet Gateway para permitir salida/entrada a Internet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "llm-vpc-igw"
  }
}

# Tabla de Enrutamiento Pública
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "llm-public-rt"
  }
}

# Asociación de la tabla de enrutamiento con la subred
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Grupo de Seguridad (Firewall) - ¡PUERTO 22 ELIMINADO!
resource "aws_security_group" "ec2_sg" {
  name        = "llm-security-group"
  description = "Reglas de acceso exclusivas para el proxy de seguridad web"
  vpc_id      = aws_vpc.main_vpc.id

  # Permitir tráfico web (Open WebUI) desde cualquier lugar
  ingress {
    description = "HTTP public access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  # Permitir salida a internet para descargar paquetes, Docker images, modelos, etc.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "llm-instance-sg"
  }
}

# =========================================================================
# Rol de IAM (Service Account) para el acceso seguro vía AWS SSM
# =========================================================================
resource "aws_iam_role" "ec2_ssm_role" {
  name = "llm-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Adjuntamos la política gestionada oficial de AWS para Systems Manager Core
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Creamos el perfil de instancia que necesita la EC2 para cargar el rol
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "llm-ec2-instance-profile"
  role = aws_iam_role.ec2_ssm_role.name
}


# La Instancia EC2 con el Service Account (User Data)
resource "aws_instance" "llm_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type 
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  
  # MODIFICADO: Quitamos key_name y añadimos el Perfil de IAM con SSM
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # Almacenamiento: Le damos 30 GB para que quepa el SO, Docker y el Swap
  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }

  # El script configurará el SWAP, instalará Docker y levantará todo
  user_data = file("${path.module}/templates/user_data.sh")

  tags = {
    Name = "llm-devops-infrastructure"
  }
}