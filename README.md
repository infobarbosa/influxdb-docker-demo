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
    - Tipo `string` que representa o nome da medida. 

- `<tag_key>=<tag_value>` (não obrigatório, porém case-sensitive) <br>
    - Tags representadas por pares chave-valor para o data point.<br> 
    - A relação entre chave e valor é representada pelo operador `=`.<br> 
    - Ambos chave e valor devem ser do tipo `string`.<br>
    - O protocolo suporta múltiplas ocorrências de tags.

- `<field_key>=<field_value>` (obrigatório e case-sensitive) <br>
    - Fields (campos) representadas por pares chave-valor para o data point.<br>
    - Points necessitam ter pelo menos um Field.<br>
    - Fields keys (chaves) devem ser do tipo `string`, field values (valores) podem ser dos tipos `Float`, `Integer`, `UInteger`, `String` e `Boolean`.

- `[<timestamp>]` é expresso em nanossegundos e não obrigatório.<br>
    > Caso não informado, o InfluxDB utiliza o timestamp interno do servidor.

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

##### Cloud9
Caso você esteja utilizando o AWS Cloud9 nesse laboratório será necessário executar o seguinte script para prosseguirmos:

```
bash ./assets/scripts/cloud9.sh

```

**Atenção!** <br>
Ao final da execução do script será disponibilizado um URL. Copie e guarde-o porque vamos utilizá-lo mais tarde neste laboratório.

Output esperado:
```
### Atualizando o sistema ###
Get:1 http://us-east-1.ec2.archive.ubuntu.com/ubuntu jammy InRelease [270 kB]
Get:2 http://us-east-1.ec2.archive.ubuntu.com/ubuntu jammy-updates InRelease [128 kB]   
...
...
Acesse o ambiente Cloud9 em: http://ec2-34-238-49-243.compute-1.amazonaws.com:8086

```

Perceba que ao final da execução será disponibilizado um URL, endereço para o InfluxDB UI.<br>

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

- Abra o seu navegador e digite o endereço do influxdb:
  Se você estiver utilizando o AWS Cloud9 então o endereço foi disponibilizado na sessão de configuração do Cloud9 acima.<br>
  Caso esteja utilizando sua máquina local então o endereço será `localhost:8086`.
- Na tela do InfluxDB UI informe o usuário `barbosa` e senha `mudar123`.

### Opção 1 (Visual)
- No menu Buckets busque por "ecommerce"
- No canto superior à direita ative a chave seletora "Switch do old data explorer."
- Em "From" escolha o bucket "ecommerce"
- Em "Filter" escolha a measurement "pedidos"
- No novo "Filter" que se abrir escolha "quantidade"
- Escolha o intervalo de 1 minuto ou 5 minutos para visualização
- Clique em "Submit"

### Opção 2 (Linguagem Flux)
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

Outra consulta de exemplo:

1. Vendas agrupadas por produto
```
from(bucket: "ecommerce")
  |> range(start: -30m)
  |> filter(fn: (r) => r["_measurement"] == "pedidos")
  |> filter(fn: (r) => r["_field"] == "quantidade")
  |> group(columns: ["produto"])
  |> aggregateWindow(every: v.windowPeriod, fn: sum, createEmpty: false)
  |> yield(name: "sum")

```
2. Ajustando a janela para 10 segundos
```
from(bucket: "ecommerce")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["_measurement"] == "pedidos")
  |> filter(fn: (r) => r["_field"] == "quantidade")
  |> group(columns: ["_measurement", "_field", "pais"])
  |> aggregateWindow(every: 10s, fn: sum, createEmpty: false)
  |> yield(name: "sum")

```

3. Ajustando a janela para 1 minuto
```
from(bucket: "ecommerce")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["_measurement"] == "pedidos")
  |> filter(fn: (r) => r["_field"] == "quantidade")
  |> group(columns: ["_measurement", "_field", "pais"])
  |> aggregateWindow(every: 1m, fn: sum, createEmpty: false)
  |> yield(name: "sum")

```

4. Vendas agrupadas por país
```
from(bucket: "ecommerce")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["_measurement"] == "pedidos")
  |> filter(fn: (r) => r["_field"] == "quantidade")
  |> group(columns: ["_measurement", "_field", "pais"])
  |> aggregateWindow(every: v.windowPeriod, fn: sum, createEmpty: false)
  |> yield(name: "sum")

```

5. Vendas de celular 
```
from(bucket: "ecommerce")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["_measurement"] == "pedidos")
  |> filter(fn: (r) => r["_field"] == "quantidade")
  |> filter(fn: (r) => r["produto"] == "CELULAR")
  |> aggregateWindow(every: v.windowPeriod, fn: sum, createEmpty: false)
  |> yield(name: "sum")

```

6. Vendas do Brasil
```
from(bucket: "ecommerce")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["_measurement"] == "pedidos")
  |> filter(fn: (r) => r["_field"] == "quantidade")
  |> filter(fn: (r) => r["pais"] == "BR")
  |> aggregateWindow(every: v.windowPeriod, fn: sum, createEmpty: false)
  |> yield(name: "sum")

```

7. Vendas de geladeira na Austrália
```
from(bucket: "ecommerce")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["_measurement"] == "pedidos")
  |> filter(fn: (r) => r["_field"] == "quantidade")
  |> filter(fn: (r) => r["produto"] == "GELADEIRA")
  |> filter(fn: (r) => r["pais"] == "AU")
  |> aggregateWindow(every: v.windowPeriod, fn: sum, createEmpty: false)
  |> yield(name: "sum")

```

## Parabéns!

Parabéns por concluir o laboratório de Armazenamento de Séries Temporais com InfluxDB! Espero que você tenha aprendido bastante sobre como utilizar o InfluxDB para armazenar e consultar dados de séries temporais. Continue praticando e explorando as funcionalidades do InfluxDB para aprimorar ainda mais seus conhecimentos.

Se tiver dúvidas ou sugestões, sinta-se à vontade para entrar em contato.

Bom trabalho e até a próxima!

Prof. Barbosa

