#!/bin/bash
echo "### Atualizando o sistema ###"
sudo apt update -y

echo "### Instalando o jq, a lightweight and flexible command-line JSON processor  ###"
sudo apt install -y jq

echo "##################################"
echo "### Obtendo infos da instância ###"
echo "##################################"

echo "### O ID da instância EC2 do ambiente Cloud9 ###"
export CLOUD9_EC2_INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data//instance-id)
echo "### O ID da instância EC2 do ambiente Cloud9: $CLOUD9_EC2_INSTANCE_ID ###"

echo "### O DNS público da instância EC2 do ambiente Cloud9 ###"
export CLOUD9_EC2_PUBLIC_DNS=$(aws ec2 describe-instances --instance-id $CLOUD9_EC2_INSTANCE_ID | jq -r .Reservations[0].Instances[0].NetworkInterfaces[0].Association.PublicDnsName)
echo "### O DNS público da instância EC2 do ambiente Cloud9: $CLOUD9_EC2_PUBLIC_DNS ###"

echo "### O ID do disco EBS associado a essa instância ###"
export CLOUD9_EC2_VOLUME_ID=$(aws ec2 describe-instances --instance-id $CLOUD9_EC2_INSTANCE_ID | jq -r .Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId)
echo "### O ID do disco EBS associado a essa instância: $CLOUD9_EC2_VOLUME_ID ###"

echo "### O ID do grupo de segurança associado a essa instância ###"
export CLOUD9_EC2_SECURITY_GROUP_ID=$(aws ec2 describe-instances --instance-id $CLOUD9_EC2_INSTANCE_ID | jq -r .Reservations[0].Instances[0].NetworkInterfaces[0].Groups[0].GroupId)
echo "### O ID do grupo de segurança associado a essa instância: $CLOUD9_EC2_SECURITY_GROUP_ID ###"

echo "############################################################"
echo "### Incluindo regra de acesso público ao ambiente Cloud9 ###"
echo "############################################################"

aws ec2 authorize-security-group-ingress --group-id $CLOUD9_EC2_SECURITY_GROUP_ID --protocol tcp --port 8086 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $CLOUD9_EC2_SECURITY_GROUP_ID --protocol tcp --port 3000 --cidr 0.0.0.0/0

echo "### Regra de acesso público incluída com sucesso! ###"

echo "Configurações aplicadas com sucesso!"
echo "Acesse o ambiente Cloud9 em: http://$CLOUD9_EC2_PUBLIC_DNS:8086"


