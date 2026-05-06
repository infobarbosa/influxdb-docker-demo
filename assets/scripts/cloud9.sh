#!/bin/bash

# --- 1. Preparação do Sistema ---
echo "### Atualizando o sistema e instalando dependências ###"
sudo apt update -y && sudo apt install -y jq openssl

# --- 2. Coleta de Metadados da Instância ---
echo "### Obtendo informações da infraestrutura ###"
export INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
export VPC_ID=$(aws ec2 describe-instances --instance-id $INSTANCE_ID --query 'Reservations[0].Instances[0].NetworkInterfaces[0].VpcId' --output text)
export SG_ID=$(aws ec2 describe-instances --instance-id $INSTANCE_ID --query 'Reservations[0].Instances[0].NetworkInterfaces[0].Groups[0].GroupId' --output text)
export INSTANCE_SUBNET=$(aws ec2 describe-instances --instance-id $INSTANCE_ID --query 'Reservations[0].Instances[0].SubnetId' --output text)
export INSTANCE_AZ=$(aws ec2 describe-subnets --subnet-ids $INSTANCE_SUBNET --query 'Subnets[0].AvailabilityZone' --output text)

echo "Instância: $INSTANCE_ID na zona $INSTANCE_AZ"

# --- 3. Configuração de Segurança (Firewall) ---
echo "### Liberando portas no Security Group da Instância ###"
# Porta 8086 para o Influx e 3000 para Grafana (se houver)
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 8086 --cidr 0.0.0.0/0 2>/dev/null
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 3000 --cidr 0.0.0.0/0 2>/dev/null

# --- 4. Lógica Multi-AZ para o Load Balancer ---
echo "### Selecionando Subnets para o Load Balancer ###"
# O ALB exige duas subnets em Availability Zones diferentes
export OTHER_SUBNET=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[?AvailabilityZone!='$INSTANCE_AZ'].SubnetId" --output text | awk '{print $1}')
export SUBNETS_ALB="$INSTANCE_SUBNET $OTHER_SUBNET"

# --- 5. Criação do Target Group ---
echo "### Criando Target Group e registrando instância ###"
export TG_NAME="tg-influx-$(date +%s)"
export TG_ARN=$(aws elbv2 create-target-group \
    --name $TG_NAME \
    --protocol HTTP \
    --port 8086 \
    --vpc-id $VPC_ID \
    --health-check-path /health \
    --target-type instance | jq -r .TargetGroups[0].TargetGroupArn)

aws elbv2 register-targets --target-group-arn $TG_ARN --targets Id=$INSTANCE_ID

# --- 6. Configuração do Certificado SSL (ACM) ---
echo "### Gerando certificado SSL autoassinado ###"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout private.key -out certificate.crt \
    -subj "/C=BR/ST=SP/L=SaoPaulo/O=FIAP/CN=influxdb.local" 2>/dev/null

export CERT_ARN=$(aws acm import-certificate --certificate fileb://certificate.crt --private-key fileb://private.key | jq -r .CertificateArn)

# --- 7. Criação do Application Load Balancer (ALB) ---
echo "### Provisionando o Load Balancer (HTTPS) ###"
export ALB_NAME="alb-influx-$(date +%s)"

# Criando SG para o ALB (Porta 443 pública)
export ALB_SG_ID=$(aws ec2 create-security-group --group-name "sg-$ALB_NAME" --description "SG para ALB HTTPS" --vpc-id $VPC_ID | jq -r .GroupId)
aws ec2 authorize-security-group-ingress --group-id $ALB_SG_ID --protocol tcp --port 443 --cidr 0.0.0.0/0

# Criando o Load Balancer
export ALB_JSON=$(aws elbv2 create-load-balancer --name $ALB_NAME --subnets $SUBNETS_ALB --security-groups $ALB_SG_ID)
export ALB_DNS=$(echo $ALB_JSON | jq -r .LoadBalancers[0].DNSName)
export ALB_ARN=$(echo $ALB_JSON | jq -r .LoadBalancers[0].LoadBalancerArn)

# Criando o Listener HTTPS na porta 443
aws elbv2 create-listener --load-balancer-arn $ALB_ARN --protocol HTTPS --port 443 --certificates CertificateArn=$CERT_ARN --default-actions Type=forward,TargetGroupArn=$TG_ARN > /dev/null

# --- 8. Finalização ---
echo "############################################################"
echo "### CONFIGURAÇÃO CONCLUÍDA COM SUCESSO! ###"
echo "############################################################"
echo ""
echo "Aguarde cerca de 3 minutos para o Load Balancer ficar 'Active'."
echo "Acesse o InfluxDB via HTTPS (Obrigatório):"
echo ""
echo "👉 https://$ALB_DNS"
echo ""
echo "DICA PARA A AULA:"
echo "Como o certificado é autoassinado, o navegador exibirá um alerta."
echo "Peça aos alunos para clicarem em 'Avançado' e 'Prosseguir para o site'."
echo "############################################################"
