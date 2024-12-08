#!/bin/bash
echo "### Atualizando o sistema ###"
sudo apt update -y

echo "### Instalando o pacote boto3  ###"
pip install boto3

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

echo "########################################"
echo "### Redimensionando disco para 100Gb ###"
echo "########################################"

export CLOUD9_DISK_NEW_SIZE=100

echo "### Redimensionamento do volume EBS ###"
aws ec2 modify-volume --volume-id $CLOUD9_EC2_VOLUME_ID --size $CLOUD9_DISK_NEW_SIZE

echo "### Aguardando a finalização do redimensionamento. ###"
while [ "$(aws ec2 describe-volumes-modifications --volume-id $CLOUD9_EC2_VOLUME_ID --filters Name=modification-state,Values="optimizing","completed" | jq '.VolumesModifications | length')" != "1" ]; do
	echo "waiting volume..."
	sleep 1
done

echo "### Executando lsblk para verificar o nome do disco. ###"
lsblk

echo "### Verificando o nome do disco. ###"
export DISK_NAME=$(sudo lsblk -o NAME -n | grep '\<nvme0n1\>')
echo "### O nome do disco é: $DISK_NAME ###"

if [ -z "$DISK_NAME" ]
then
	export DISK_NAME=$(sudo lsblk -o NAME -n | grep '\<xvda\>')

	if [ -z "$DISK_NAME" ]
	then
		echo "### Não foi possível encontrar o nome do disco. O redimensionamento não terá efeito. ###"
		exit 1
	else
		echo "### O nome do disco é: $DISK_NAME ###"
		echo "### Reescrevendo a tabela de partição para uso full do espaço solicitado. ###"
		sudo growpart /dev/xvda 1

		echo "### Expandindo o tamanho da particao sistema de arquivos. ###"
		sudo resize2fs /dev/xvda1
	fi
else
	echo "### Reescrevendo a tabela de partição para uso full do espaço solicitado. ###"
	sudo growpart /dev/nvme0n1 1

	echo "### Expandindo o tamanho do sistema de arquivos. ###"
	sudo resize2fs /dev/nvme0n1p1
fi

echo "### O disco foi redimensionado com sucesso. ###"
df -h


echo "############################################################"
echo "### Incluindo regra de acesso público ao ambiente Cloud9 ###"
echo "############################################################"

aws ec2 authorize-security-group-ingress --group-id $CLOUD9_EC2_SECURITY_GROUP_ID --protocol tcp --port 8086 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $CLOUD9_EC2_SECURITY_GROUP_ID --protocol tcp --port 3000 --cidr 0.0.0.0/0

echo "### Regra de acesso público incluída com sucesso! ###"

echo "Configurações aplicadas com sucesso!"
echo "Acesse o ambiente Cloud9 em: http://$CLOUD9_EC2_PUBLIC_DNS:8086"


