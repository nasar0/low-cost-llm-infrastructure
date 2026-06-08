# Low-Cost Secure LLM Infrastructure (FinOps-Driven)

[![Terraform](https://img.shields.io/badge/Terraform->=1.5.0-7B42BC?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-EC2%20%7C%20VPC%20%7C%20Security%20Group-FF9900?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![Docker](https://img.shields.io/badge/Docker-Compose%20v2-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Ollama](https://img.shields.io/badge/Ollama-Gemma:2b-black?logo=ollama&logoColor=white)](https://ollama.com/)
[![Ollama](https://img.shields.io/badge/Ollama-qwen2.5:0.5b-black?logo=ollama&logoColor=white)](https://ollama.com/)

Infraestructura Cloud automatizada mediante código (**IaC**) para el despliegue de un entorno privado de Inteligencia Artificial utilizando **Gemma (Google)**. El diseño está completamente optimizado bajo la filosofía **FinOps**, permitiendo ejecutar modelos de lenguaje (LLM) en instancias de recursos muy limitados y de bajo coste (o dentro de la capa gratuita) en AWS sin comprometer la seguridad.

---

## 🎯 Características Principales

- **Despliegue 100% Zero-Touch:** Todo el entorno (redes, servidor, Docker, configuración interna y descarga de modelos) se ejecuta de forma completamente autónoma mediante un script robusto en el `user_data` de AWS. **Cero intervención manual por SSH**.
- **Arquitectura FinOps Optimizada:** Configuración automática de **3 GB de memoria Swap** persistente en disco NVMe para simular un entorno de 4 GB de RAM sobre una instancia económica `t3.micro`.
- **Seguridad Perimetral Estricta:** Creación de una VPC dedicada. El puerto SSH (`22`) está blindado y filtrado dinámicamente mediante Security Groups, permitiendo el acceso criptográfico exclusivamente a la dirección IP pública del administrador.
- **Stack de IA Contenedorizado:** Despliegue orquestado con Docker Compose que incluye **Ollama** como motor de inferencia local y **Open WebUI** como interfaz gráfica de usuario tipo ChatGPT de manera aislada y multiusuario.

---

## 🏗️ Arquitectura del Sistema

El proyecto despliega la siguiente topología de red y servicios en AWS de manera automática:

1. **Red:** VPC (`10.0.0.0/16`) + Subred pública (`10.0.1.0/24`) + Internet Gateway + Tablas de enrutamiento asociadas.
2. **Cómputo:** Instancia EC2 (`Ubuntu 24.04 LTS Noble Noble`) equipada con un volumen `gp3` optimizado de 30 GB (límite de la capa gratuita).
3. **Servicios (Docker):**
   - **Ollama Container:** Motor de ejecución encargado de alojar y procesar los pesos del modelo `gemma:2b`.
   - **Open WebUI Container:** Frontend web responsivo expuesto de forma segura en el puerto `80`.

---

## 🛠️ Requisitos Previos

Antes de desplegar, asegúrate de contar con las siguientes herramientas en tu entorno local:

- [Terraform](https://developer.hashicorp.com/terraform/downloads) instalado (Versión `>= 1.5.0`).
- Credenciales con permisos de administrador en AWS (`Access Key` y `Secret Key`).
- Tu dirección IP pública para el filtrado del Firewall.

---

## Guía de Despliegue Rápido

### 1. Clonar el repositorio y preparar variables
Copia este repositorio en tu máquina local y crea tu archivo de configuración de variables `terraform.tfvars`:

```hcl
aws_access_key = "TU_AWS_ACCESS_KEY"
aws_secret_key = "TU_AWS_SECRET_KEY"
aws_region     = "eu-west-3"               # Región opcional
instance_type  = "t3.micro"                # Instancia FinOps

```
Descomenta en `user_data.sh` el modelo que quieras usar o añada usted otro.

```bash
# echo "=== Descargando el modelo rápido Qwen2.5 (0.5B) ==="
# docker exec -i ollama ollama run qwen2.5:0.5b ""

# echo "=== Descargando el modelo pesado Gemma (2B) ==="
# docker exec -i ollama ollama run gemma:2b ""

```

### 2. Inicializar y Aplicar con Terraform

Ejecuta la secuencia estándar de comandos de Terraform en tu terminal para aprovisionar la infraestructura:

```powershell
# Inicializar los proveedores (AWS, TLS, Local)
terraform init

# Validar que la sintaxis del código sea correcta
terraform validate

# Desplegar la infraestructura de forma automática
terraform apply -auto-approve

```

### 3. Acceder a tu IA Privada

Al finalizar el comando anterior, Terraform te devolverá la dirección IP pública de tu servidor.

Dado que el servidor requiere descargar las imágenes de Docker y los **1.6 GB** del modelo de Google de manera interna, **espera entre 5 y 8 minutos**. Pasado ese tiempo, abre tu navegador web e ingresa a:

```text
http://<SERVER_PUBLIC_IP>

```

*Nota: El primer usuario en registrarse en la pantalla de bienvenida se convertirá automáticamente en el **Administrador global** del sistema.*

---

## 📂 Estructura del Código Terraform

El código se encuentra modularizado y estructurado siguiendo las mejores prácticas de la industria:

```text
├── templates/
│   └── user_data.sh      # Script de inicialización bash (Swap, Docker, Containers, Pull Model)
├── main.tf               # Definición de recursos (VPC, Subnets, EC2, Security Groups, Keys)
├── variables.tf          # Declaración y tipado de variables del sistema
├── outputs.tf            # Definición de salidas (IP Pública, Comando SSH seguro)
└── terraform.tfvars      # Credenciales e IPs privadas (Excluido de Git por seguridad)

```

---

## 🛡️ Notas de Seguridad y Mantenimiento

* **Llaves Criptográficas:** El proyecto genera de manera dinámica un par de llaves SSH asimétricas de 4096 bits (`RSA`). La llave pública se inyecta en AWS y la privada se descarga automáticamente en tu entorno local bajo el nombre de `llm-key.pem`.
* **Acceso SSH (Solo Emergencias):** Aunque el servidor es autónomo, si requieres auditarlo puedes ejecutar el comando provisto por los outputs de Terraform asegurando los permisos previos de la llave:
```powershell
icacls .\llm-key.pem /inheritance:r
icacls .\llm-key.pem /grant:r "${env:USERNAME}:(F)"
ssh -i ./llm-key.pem ubuntu@<SERVER_PUBLIC_IP>

```



---

## 🛑 Destrucción de Recursos

Para evitar costes imprevistos en tu factura de AWS cuando termines de realizar pruebas, puedes destruir por completo toda la topología de red y cómputo con un solo comando:

```powershell
terraform destroy -auto-approve

```
