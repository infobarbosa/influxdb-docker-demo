# Armazenamento de Séries Temporais com InfluxDB

Author: Prof. Barbosa<br>
Contact: infobarbosa@gmail.com<br>
Github: [infobarbosa](https://github.com/infobarbosa)

O objetivo deste laboratório é oferecer ao aluno um ambiente de familiarização com o modelo de armazenamento de séries temporais utilizando **InfluxDB**.

## Introdução

[InfluxDB](https://docs.influxdata.com/influxdb/v2/get-started/) é um banco de dados de série temporal de código aberto desenvolvido pela empresa InfluxData. Ele é usado para armazenamento e recuperação de dados de séries temporais em áreas como monitoramento de operações, métricas de aplicativos, dados de sensores da Internet das Coisas e análises em tempo real.<br>
> Fonte: [Wikipedia](https://en.wikipedia.org/wiki/InfluxDB)

## Line Protocol
<br>
O protocolo de linha (line protocol) do InfluxDB é um formato simples baseado em texto adotado para escrita de data points no banco de dados.
<br>

### Sintaxe

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
    - Fields (campos) representados por pares chave-valor para o data point.<br>
    - Cada data point precisa ter pelo menos um field.<br>
    - Fields keys (chaves) devem ser do tipo `string`, field values (valores) podem ser dos tipos `Float`, `Integer`, `UInteger`, `String` e `Boolean`.

- `[<timestamp>]` é expresso em nanossegundos e não obrigatório.<br>
    > Caso não informado, o InfluxDB utiliza o timestamp interno do servidor.

**Exemplo**:
```
pedidos,produto=GELADEIRA Quantity=1,UnitPrice=2000 1668387574000000000
```

## Laboratório

### 1. Ambiente 
Este laboratório pode ser executado em qualquer estação de trabalho com docker disponível.<br>
Recomendo, porém, a execução em Linux.<br>
Caso você não tenha um à sua disposição, utilize o serviço **AWS Cloud9**. As instruções podem ser encontradas [aqui](https://github.com/infobarbosa/data-engineering-cloud9).


### 2. Setup (APENAS PARA AWS CLOUD9)
Baixe e execute o script de setup

```bash
wget https://raw.githubusercontent.com/infobarbosa/influxdb-docker-demo/main/assets/scripts/cloud9.sh

```

```bash
bash ./cloud9.sh

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
Caso você se esqueça desse URL, basta executar o seguinte comando:
```
export CLOUD9_EC2_INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data//instance-id)
export CLOUD9_EC2_PUBLIC_DNS=$(aws ec2 describe-instances --instance-id $CLOUD9_EC2_INSTANCE_ID | jq -r .Reservations[0].Instances[0].NetworkInterfaces[0].Association.PublicDnsName)
echo "O DNS público da instância EC2 do ambiente Cloud9: $CLOUD9_EC2_PUBLIC_DNS ###"

```

### 3. Docker Compose

Por simplicidade, vamos utilizar o InfluxDB em um container baseado em *Docker*.<br>
#### Baixe o script `compose.yaml`
```bash
wget https://raw.githubusercontent.com/infobarbosa/influxdb-docker-demo/main/compose.yaml

```

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

Este comando inicializa três serviços:
- **`influxdb`**: o banco de dados, acessível na porta `8086`.
- **`influxproducer`**: produtor de dados de exemplo que insere pedidos simulados continuamente no bucket `ecommerce`, permitindo visualizar dados em tempo real mais adiante.
- **`grafana`**: plataforma de visualização de dashboards, acessível na porta `3000`. Explorada na seção bônus ao final do laboratório.

### 4. `influx write`

`influx write` escreve data points no InfluxDB via entrada padrão (console) ou a partir de um arquivo de dados.
<br>

#### Sintaxe

```
influx write [flags]
influx write [command]
``` 

Maiores informações podem ser obtidas em https://docs.influxdata.com/influxdb/v2/reference/cli/influx/write/

#### Exemplo 1:
Primeiro vamos escrever um data point que representa uma venda (pedido) de uma geladeira:
```
docker exec -it influxdb-demo \
influx write --bucket ecommerce "pedidos,produto=GELADEIRA,pais=BR quantidade=1,preco=2000 1668387574000000000"

```

#### Exemplo 2:
Agora vamos escrever outro datapoint que representa a venda de duas televisões:
> Perceba que desta vez não informamos o timestamp.
```
docker exec -it influxdb-demo \
influx write --bucket ecommerce "pedidos,produto=TV,pais=US quantidade=2,preco=5000"

```

#### Exemplo 3:
Inserindo múltiplos data points
```
docker exec -it influxdb-demo \
influx write --bucket ecommerce "
pedidos,produto=FOGAO,pais=BR quantidade=1,preco=1000 1668426060401463300
pedidos,produto=GELADEIRA,pais=AU quantidade=1,preco=2000 1668426081342160900
pedidos,produto=LAVADORA,pais=BR quantidade=1,preco=1000 1668426093037252400
pedidos,produto=FILTRO,pais=US quantidade=1,preco=500 1668426100229183600
pedidos,produto=TV,pais=BR quantidade=1,preco=5000 1668426107622748900
"

```

### 5. `influx query`

Para recuperar as informações inseridas no bucket `ecommerce`, você pode utilizar o comando `influx query`.

#### Exemplo 4 - Recuperar Tudo

Este comando irá retornar todos os dados que estão no measurement "pedidos" dentro do seu bucket.

```bash
docker exec -it influxdb-demo \
influx query 'from(bucket: "ecommerce") |> range(start: 0) |> filter(fn: (r) => r._measurement == "pedidos")'

```

**Onde:**

  * `from(bucket: "ecommerce")`: Especifica de qual bucket você quer ler os dados.
  * `|> range(start: 0)`: Define o intervalo de tempo da consulta. `start: 0` significa "desde o início dos tempos", garantindo que todos os dados sejam retornados.
  * `|> filter(fn: (r) => r._measurement == "pedidos")`: Filtra os resultados para trazer apenas os que pertencem ao measurement "pedidos".

-----

#### Exemplo 5 - Adicionando critérios de busca

Se você quiser filtrar por um produto específico, como "GELADEIRA", pode adicionar outro filtro.

```bash
docker exec -it influxdb-demo \
influx query 'from(bucket: "ecommerce") |> range(start: 0) |> filter(fn: (r) => r._measurement == "pedidos" and r.produto == "GELADEIRA")'

```

**O que mudou:**

  * `and r.produto == "GELADEIRA"`: Adicionamos uma condição para que o campo (tag) "produto" seja igual a "GELADEIRA".

-----

#### Exemplo 6 - `pivot()`

Por padrão, a consulta retorna cada *field* (`quantidade`, `preco`) em uma linha separada. Se você quiser ver os dados de uma forma mais parecida com uma tabela SQL, pode usar a função `pivot()`.

```bash
docker exec -it influxdb-demo \
influx query '
from(bucket: "ecommerce")
  |> range(start: 0)
  |> filter(fn: (r) => r._measurement == "pedidos")
  |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
'

```

**Como `pivot()` funciona?**

  * `rowKey:["_time"]`: Agrupa os resultados em linhas com base no timestamp.
  * `columnKey: ["_field"]`: Transforma os nomes dos *fields* (`preco`, `quantidade`) em colunas.
  * `valueColumn: "_value"`: Preenche essas novas colunas com os seus respectivos valores.

O resultado deste último comando será algo visualmente mais organizado, parecido com:

| \_time                | \_measurement | produto   | preco | quantidade |
| -------------------- | ------------ | --------- | ----- | ---------- |
| 2022-11-14T11:41:00Z | pedidos      | FOGAO     | 1000  | 1          |
| 2022-11-14T11:41:21Z | pedidos      | GELADEIRA | 2000  | 1          |
| ...                  | ...          | ...       | ...   | ...        |

O comando sem `pivot()` é o mais direto para verificações rápidas. O comando com `pivot()` é excelente quando você quer visualizar os dados em formato tabular.

---

### 6. Especificando o período

Para filtrar os registros de um período específico, é necessário ajustar a função `range()` na nossa consulta.

Defina uma data de início (`start`) e uma data de término (`stop`).

#### Exemplo 7 - Consulta Padrão para 2022

Este comando recupera todos os campos e tags dos registros dentro do ano de 2022.

```bash
docker exec -it influxdb-demo \
influx query 'from(bucket: "ecommerce") |> range(start: 2022-01-01T00:00:00Z, stop: 2023-01-01T00:00:00Z) |> filter(fn: (r) => r._measurement == "pedidos")'

```

**O que mudou?**

  * `|> range(start: 2022-01-01T00:00:00Z, stop: 2023-01-01T00:00:00Z)`: Esta linha instrui o InfluxDB a buscar dados que foram registrados entre 1º de janeiro de 2022 à meia-noite e 1º de janeiro de 2023 à meia-noite. O `Z` no final indica o fuso horário UTC (Zulu time), que é o padrão do InfluxDB.

-----

#### Exemplo 8 - Consulta Formatada com Pivot

Se preferir a visualização em formato de tabela, mais organizada, use o comando com a função `pivot()`:

```bash
docker exec -it influxdb-demo \
influx query '
from(bucket: "ecommerce")
  |> range(start: 2022-01-01T00:00:00Z, stop: 2023-01-01T00:00:00Z)
  |> filter(fn: (r) => r._measurement == "pedidos")
  |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
'

```

#### Os últimos X horas, minutos, segundos...

O Flux permite que você use durações relativas para definir o início do seu intervalo de tempo, o que é extremamente útil para dashboards e monitoramento em tempo real.

A sintaxe é um número negativo seguido por uma unidade de tempo. Aqui estão as unidades mais comuns:

*   `s` — segundos
*   `m` — minutos
*   `h` — horas
*   `d` — dias
*   `w` — semanas

**Por exemplo:**

*   `range(start: -1h)`: Retorna dados da última hora.
*   `range(start: -30s)`: Retorna dados dos últimos 30 segundos.
*   `range(start: -7d)`: Retorna dados dos últimos 7 dias.

A seguir, vamos ver como aplicar isso para buscar os dados dos últimos 2 minutos.

---

### Exemplo 9 - Últimos 2 minutos

> **Atenção:** Este comando busca apenas registros criados nos últimos 2 minutos. Os dados inseridos com timestamp fixo nos exemplos anteriores (novembro de 2022) **não aparecerão**. Apenas o registro do Exemplo 2 — inserido sem timestamp — poderá aparecer aqui, desde que tenha sido executado há menos de 2 minutos.

```bash
docker exec -it influxdb-demo \
influx query 'from(bucket: "ecommerce") |> range(start: -2m) |> filter(fn: (r) => r._measurement == "pedidos")'

```

**O que mudou?**

  * `|> range(start: -2m)`: `-2m` é uma duração relativa que instrui o InfluxDB a definir o início do intervalo para 2 minutos no passado a partir do momento da execução. A data de término (`stop`) é, por padrão, "agora".

-----

### Exemplo 10 - Últimos 2 minutos com `pivot()`

Para uma visualização mais limpa, no estilo de tabela, use o comando com `pivot()`.

```bash
docker exec -it influxdb-demo \
influx query '
from(bucket: "ecommerce")
  |> range(start: -2m)
  |> filter(fn: (r) => r._measurement == "pedidos")
  |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
'
```

---

## InfluxDB v2 API
<br>

A API v2 HTTP do InfluxDB oferece uma interface programática para interações com o database.
Neste tópico vamos escrever data points utilizando o endpoint padrão `/api/v2/write` e line protocol. 
<br>
Para mais informações acesse https://docs.influxdata.com/influxdb/v2/write-data/developer-tools/api/

### Exemplos:
Atenção! Para fins didáticos estamos omitindo o timestamp.

##### Exemplo mínimo

Apenas o header de autenticação é obrigatório:

```bash
curl -XPOST "http://$(hostname):8086/api/v2/write?org=infobarbosa&bucket=ecommerce&precision=ns" \
  --header "Authorization: Token 3y1c3NnlmA1kA061YlROSO0gE5a1ppH_1Ig5HSMCsCX3VKF6zkrBwAtC-Hr6c_TTU8B9kwYOPphDq6hwyw5tLw==" \
  --data-raw 'pedidos,produto=SANDUICHEIRA,pais=BR quantidade=1,preco=2000'
```

##### Exemplo completo

Com todos os headers recomendados (`Content-Type` e `Accept`):

```bash
curl -XPOST "http://$(hostname):8086/api/v2/write?org=infobarbosa&bucket=ecommerce&precision=ns" \
  --header "Authorization: Token 3y1c3NnlmA1kA061YlROSO0gE5a1ppH_1Ig5HSMCsCX3VKF6zkrBwAtC-Hr6c_TTU8B9kwYOPphDq6hwyw5tLw==" \
  --header "Content-Type: text/plain; charset=utf-8" \
  --header "Accept: application/json" \
  --data-raw 'pedidos,produto=ASPIRADOR,pais=US quantidade=5,preco=600'
```

## Funções avançadas do Flux

Antes de explorar a interface gráfica, vale conhecer três funções que aparecem nas consultas a seguir:

- **`group(columns: [...])`**: Reagrupa as linhas do resultado por uma ou mais colunas. Equivalente ao `GROUP BY` do SQL, mas opera sobre as tabelas internas do Flux.
- **`aggregateWindow(every: ..., fn: ...)`**: Divide o intervalo de tempo em janelas de tamanho fixo (`every`) e aplica uma função de agregação (`fn: sum`, `fn: mean`, etc.) em cada janela. Ideal para séries temporais — permite ver, por exemplo, o total de vendas a cada 10 segundos.
- **`yield(name: "...")`**: Nomeia o resultado final da consulta. Necessário quando a consulta produz mais de uma tabela de saída; aqui é usado por convenção.

---

## InfluxDB UI
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

> **Nota:** `v.timeRangeStart`, `v.timeRangeStop` e `v.windowPeriod` são variáveis de template da interface do InfluxDB. Seus valores são preenchidos automaticamente com base no seletor de período no canto superior direito da UI — você não precisa defini-las manualmente.

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

## Bônus: Grafana

O Grafana é uma plataforma open source de visualização amplamente usada para criar dashboards. Ele já está disponível como parte do ambiente deste laboratório.

### Acessando o Grafana

- Abra o navegador e acesse `localhost:3000` (ou substitua `localhost` pelo endereço do seu ambiente Cloud9).
- Usuário: `admin` | Senha: `admin`.

### Configurando o InfluxDB como fonte de dados

1. No menu lateral, vá em **Connections > Data Sources > Add data source**.
2. Escolha **InfluxDB**.
3. Preencha os campos:
   - **Query Language**: `Flux`
   - **URL**: `http://influxdb-demo:8086`
   - **Organization**: `infobarbosa`
   - **Token**: `3y1c3NnlmA1kA061YlROSO0gE5a1ppH_1Ig5HSMCsCX3VKF6zkrBwAtC-Hr6c_TTU8B9kwYOPphDq6hwyw5tLw==`
   - **Default Bucket**: `ecommerce`
4. Clique em **Save & Test**.

### Criando um painel simples

1. Clique em **+** no menu lateral > **New Dashboard > Add visualization**.
2. Selecione o data source **InfluxDB** recém-criado.
3. No editor de query, insira:

```flux
from(bucket: "ecommerce")
  |> range(start: -30m)
  |> filter(fn: (r) => r["_measurement"] == "pedidos")
  |> filter(fn: (r) => r["_field"] == "quantidade")
  |> group(columns: ["produto"])
  |> aggregateWindow(every: 10s, fn: sum, createEmpty: false)
  |> yield(name: "sum")
```

4. Clique em **Run Query** para visualizar o gráfico de vendas por produto em tempo real.

---

## Parabéns!

Parabéns por concluir o laboratório de Armazenamento de Séries Temporais com InfluxDB! Espero que você tenha aprendido bastante sobre como utilizar o InfluxDB para armazenar e consultar dados de séries temporais. Continue praticando e explorando as funcionalidades do InfluxDB para aprimorar ainda mais seus conhecimentos.

Se tiver dúvidas ou sugestões, sinta-se à vontade para entrar em contato.

Bom trabalho e até a próxima!

Prof. Barbosa

