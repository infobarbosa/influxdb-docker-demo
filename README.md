# Armazenamento de Séries Temporais com InfluxDB

Author: Prof. Barbosa<br>
Contact: infobarbosa@gmail.com<br>
Github: [infobarbosa](https://github.com/infobarbosa)

O objetivo desse laboratório é oferecer ao aluno ambiente onde de familiarização com o modelo de armazenamento de séries temporais utilizando **InfluxDB**.

## InfluxDB

[InfluxDB](https://docs.influxdata.com/influxdb/v2/get-started/) é um banco de dados de série temporal de código aberto desenvolvido pela empresa InfluxData. Ele é usado para armazenamento e recuperação de dados de séries temporais em áreas como monitoramento de operações, métricas de aplicativos, dados de sensores da Internet das Coisas e análises em tempo real.<br>
> Fonte: [Wikipedia](https://en.wikipedia.org/wiki/InfluxDB)

## Line Protocol
<br>
O protocolo de linha (line protocol) do InfluxDB é um formato simples baseado em texto adotado para escrita de data points no banco de dados.
<br>

#### Sintaxe

```
<measurement>[,<tag_key>=<tag_value>[,<tag_key>=<tag_value>]] <field_key>=<field_value>[,<field_key>=<field_value>] [<timestamp>]
``` 
Onde:
- `<measurement>` (obrigatório e case-sensitive) <br>
Tipo `string` que representa o nome da medida. 

- `<tag_key>=<tag_value>` (não obrigatório, porém case-sensitive) <br>
Tags representadas por pares chave-valor para o data point.<br> 
A relação entre chave e valor é representada pelo operador `=`.<br> 
Ambos chave e valor devem ser do tipo `string`.<br>
O protocolo suporta múltiplas ocorrências de tags.

- `<field_key>=<field_value>` (obrigatório e case-sensitive) <br>
    - Fields (campos) representadas por pares chave-valor para o data point.<br>
    - Points necessitam ter pelo menos um Field.<br>
    - Fields keys (chaves) devem ser do tipo `string`, field values (valores) podem ser dos tipos `Float`, `Integer`, `UInteger`, `String` e `Boolean`.

- `[<timestamp>]` é expresso em nanossegundos e não obrigatório.<br>
**Atenção!** Caso não informado no protocolo de linha, o InfluxDB atribuirá um valor baseado no  timestamp interno do servidor.

**Exemplo**:
```
pedidos,produto=GELADEIRA Quantity=1,UnitPrice=2000 1668387574000000000
```

# Laboratório

## Ambiente
Este laborarório pode ser executado em qualquer estação de trabalho.<br>
Recomendo, porém, a execução em sistema operacional Linux.<br>
Caso você não tenha um à sua disposição, recomendo o uso do AWS Cloud9. Siga essas [instruções](Cloud9/README.md).

## Setup
Para começar, faça o clone deste repositório:
```
git clone https://github.com/infobarbosa/influxdb-docker-demo.git
```

No terminal, navegue para o diretório do repositório
```
cd influxdb-docker-demo
```

## Docker
Por simplicidade, vamos utilizar o InfluxDB em um container baseado em *Docker*.<br>
Na raiz do projeto está disponível um arquivo `compose.yaml` que contém os parâmetros de inicialização do container Docker.<br>
Embora não seja escopo deste laboratório o entendimento detalhado do Docker, recomendo o estudo do arquivo `compose.yaml`.

```
ls -la compose.yaml
```

Output esperado:
```
ls -la compose.yaml
-rw-r--r-- 1 barbosa barbosa 144 jul 16 23:20 compose.yaml
```

#### Inicialização
```
docker compose up -d
```

Para verificar se está tudo correto:
```
docker compose logs -f
```
> Para sair do comando acima, digite `Control+C`


## InfluxDB - influx write

`influx write` escreve data points no InfluxDB via entrada padrão (console) ou a partir de um arquivo de dados.
<br>

### Sintaxe

```
influx write [flags]
influx write [command]
``` 

Maiores informações podem ser obtidas em https://docs.influxdata.com/influxdb/v2.5/reference/cli/influx/write/

### Exemplos:
Primeiro vamos escrever um data point que representa uma venda (pedido) de uma geladeira:
```
docker exec -it influxdb-demo \
influx write --bucket ecommerce "pedidos,produto=GELADEIRA quantidade=1,preco=2000 1668387574000000000"
```

Agora vamos escrever outro datapoint que representa a venda de duas televisões:
> Perceba que desta vez não informamos o timestamp.
```
docker exec -it influxdb-demo \
influx write --bucket ecommerce "pedidos,produto=TV quantidade=2,preco=5000"
```

Inserindo múltiplos data points
```
docker exec -it influxdb-demo \
influx write --bucket ecommerce "
pedidos,produto=FOGAO quantidade=1,preco=1000 1668426060401463300
pedidos,produto=GELADEIRA quantidade=1,preco=2000 1668426081342160900
pedidos,produto=LAVADOURA quantidade=1,preco=1000 1668426093037252400
pedidos,produto=FILTRO quantidade=1,preco=500 1668426100229183600
pedidos,produto=TV quantidade=1,preco=5000 1668426107622748900
"
```

## InfluxDB v2 API
<br>

A API v2 HTTP do InfluxDB oferece uma interface programática para interações com o database.
Neste tópico vamos escrever data points utilizando o endpoint padrão `/api/v2/write` e line protocol. 
<br>
Para mais informações acesse https://docs.influxdata.com/influxdb/v2.5/write-data/developer-tools/api/

### Exemplos:
Atenção! Para fins didáticos estamos omitindo o timestamp.

##### Utilizando POST
```
curl --request POST \
"http://$(hostname):8086/api/v2/write?org=infobarbosa&bucket=ecommerce&precision=ns" \
  --header "Authorization: Token 3y1c3NnlmA1kA061YlROSO0gE5a1ppH_1Ig5HSMCsCX3VKF6zkrBwAtC-Hr6c_TTU8B9kwYOPphDq6hwyw5tLw==" \
  --header "Content-Type: text/plain; charset=utf-8" \
  --header "Accept: application/json" \
  --data-binary 'pedidos,produto=COMPUTADOR quantidade=1,preco=2000'
```

##### Utilizando XPOST**
```
curl -i -XPOST "http://$(hostname):8086/api/v2/write?org=infobarbosa&bucket=ecommerce&precision=ns" \
  --header 'Authorization: Token 3y1c3NnlmA1kA061YlROSO0gE5a1ppH_1Ig5HSMCsCX3VKF6zkrBwAtC-Hr6c_TTU8B9kwYOPphDq6hwyw5tLw==' \
  --data-raw 'pedidos,produto=SANDUICHEIRA quantidade=1,preco=2000'
```

##### Parâmetro header "Content-Type"
```
curl -i -XPOST "http://$(hostname):8086/api/v2/write?org=infobarbosa&bucket=ecommerce&precision=ns" \
  --header 'Authorization: Token 3y1c3NnlmA1kA061YlROSO0gE5a1ppH_1Ig5HSMCsCX3VKF6zkrBwAtC-Hr6c_TTU8B9kwYOPphDq6hwyw5tLw==' \
  --header "Content-Type: text/plain; charset=utf-8" \
  --data-raw 'pedidos,produto=LAVADORA quantidade=1,preco=6000'
```

##### Parâmetro header "Accept"
```
curl -i -XPOST "http://$(hostname):8086/api/v2/write?org=infobarbosa&bucket=ecommerce&precision=ns" \
  --header 'Authorization: Token 3y1c3NnlmA1kA061YlROSO0gE5a1ppH_1Ig5HSMCsCX3VKF6zkrBwAtC-Hr6c_TTU8B9kwYOPphDq6hwyw5tLw==' \
  --header "Content-Type: text/plain; charset=utf-8" \
  --header "Accept: application/json" \
  --data-raw 'pedidos,produto=ASPIRADOR quantidade=5,preco=600'
```

# InfluxDB UI
<br>
Vamos acessar a interface web do InfluxDB.

### Acessando a InfluxDB UI

##### Máquina local
- Abra o seu navegador e digite localhost:8086
- Na tela do InfluxDB UI informe o usuário `barbosa` e senha `mudar123`.

##### Cloud9
- No console do EC2 acesse o security group (grupo de segurança) e adicione uma regra de entrada (ingress) especificando a porta 8086 (porta do InfluxDB) aberta para 0.0.0.0/0.
- Obtenha o DNS Público da instância EC2.
- Em uma nova janela do browser informe o DNS Público com a porta 8086. 
- Na tela do InfluxDB UI informe o usuário `barbosa` e senha `mudar123`.

### `pedidos.sh`
Neste repositório incluí o script `pedidos.sh` que gera pedidos aleatórios.<br>
Dessa forma será possível visualizar de forma mais efetiva as capacidades do InfluxDB.

```
nohup sh ./assets/scripts/pedidos.sh
```

### Solução 1
- No menu Buckets busque por "ecommerce"
- No canto superior à direita ative a chave seletora "Switch do old data explorer."
- Em "From" escolha o bucket "ecommerce"
- Em "Filter" escolha a measurement "pedidos"
- No novo "Filter" que se abrir escolha "quantidade"
- Escolha o intervalo de 1 minuto ou 5 minutos para visualização
- Clique em "Submit"

### Solução 2
- No menu Buckets busque por "ecommerce"
- No canto superior à direita ative a chave seletora "Switch do old data explorer."
- Clique em "Script Editor" e informe a consulta Flux a seguir:
```
from(bucket: "ecommerce")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["_measurement"] == "pedidos")
  |> filter(fn: (r) => r["_field"] == "quantidade")
  |> group(columns: ["produto"])
  |> aggregateWindow(every: v.windowPeriod, fn: sum, createEmpty: false)
  |> yield(name: "sum")
```  
- Escolha o intervalo de 1 minuto ou 5 minutos para visualização
- Clique em "Submit"
