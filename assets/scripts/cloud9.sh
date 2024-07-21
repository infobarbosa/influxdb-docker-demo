#!/bin/bash
echo "### Atualizando o sistema ###"
sudo apt update -y

echo "### Instalando o pacote boto3  ###"
pip install boto3

echo "### Instalando o jq, a lightweight and flexible command-line JSON processor  ###"
sudo apt install -y jq

echo "### O ID da instância EC2 do ambiente Cloud9 ###"
export CLOUD9_EC2_INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data//instance-id)

export CLOUD9_EC2_PUBLIC_DNS=$(aws ec2 describe-instances --instance-id $CLOUD9_EC2_INSTANCE_ID | jq -r .Reservations[0].Instances[0].NetworkInterfaces[0].Association.PublicDnsName)

export CLOUD9_EC2_SECURITY_GROUP_ID=$(aws ec2 describe-instances --instance-id $CLOUD9_EC2_INSTANCE_ID | jq -r .Reservations[0].Instances[0].NetworkInterfaces[0].Groups[0].GroupId)

aws ec2 authorize-security-group-ingress --group-id $CLOUD9_EC2_SECURITY_GROUP_ID --protocol tcp --port 8086 --cidr 0.0.0.0/0

echo "Configurações aplicadas com sucesso!"
echo "Acesse o ambiente Cloud9 em: https://$CLOUD9_EC2_PUBLIC_DNS:8086"
