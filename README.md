# Armazenamento de Séries Temporais com InfluxDB 3

Author: Prof. Barbosa<br>
Contact: infobarbosa@gmail.com<br>
Github: [infobarbosa](https://github.com/infobarbosa)

O objetivo deste laboratório é oferecer ao aluno um ambiente de familiarização com o modelo de armazenamento de séries temporais utilizando **InfluxDB 3**.

## Introdução

[InfluxDB](https://docs.influxdata.com/influxdb3/core/) é um banco de dados de série temporal desenvolvido pela InfluxData. A versão 3 traz suporte nativo a **SQL**, tornando as consultas mais acessíveis a quem já conhece bancos de dados relacionais.<br>
> Fonte: [Wikipedia](https://en.wikipedia.org/wiki/InfluxDB)

### O motor do InfluxDB 3 (por que ele é diferente)

O InfluxDB 3 foi **reescrito em Rust** sobre o chamado *stack FDAP*, todo baseado em projetos Apache:

- **F**light — [Apache Arrow Flight](https://arrow.apache.org/docs/format/Flight.html): transporte de dados colunar de alta performance (usado, por exemplo, pelo Grafana para falar SQL com o banco).
- **D**ataFusion — [Apache DataFusion](https://datafusion.apache.org/): o motor de consulta SQL.
- **A**rrow — [Apache Arrow](https://arrow.apache.org/): o formato colunar **em memória**.
- **P**arquet — [Apache Parquet](https://parquet.apache.org/): o formato colunar **em disco**.

Na prática, isso significa que os seus dados são armazenados **exatamente no mesmo formato** (Parquet) que você encontraria em um data lake — e é por isso que, ao final deste laboratório, conseguiremos abrir os arquivos internos do banco com ferramentas de análise como o **DuckDB** ([Seção 9](#9-por-dentro-do-armazenamento-parquet--arrow-hands-on)).

### Core × Enterprise (importante para este laboratório)

Este laboratório usa a imagem gratuita e open source **InfluxDB 3 Core** (`influxdb:3-core`). Vale conhecer o principal limite dela:

> ⚠️ **Janela de consulta de ~72 horas.** O InfluxDB 3 **Core** foi otimizado para dados recentes: por padrão, uma consulta só enxerga aproximadamente as **últimas 72 horas** de dados (o planner limita o plano a ~432 arquivos Parquet de blocos de 10 min). Você **pode escrever** dados com qualquer timestamp histórico, mas **não conseguirá consultá-los** se estiverem fora dessa janela. O **InfluxDB 3 Enterprise** inclui um *compactor* que reorganiza os arquivos e **remove esse limite**, permitindo consultas sobre qualquer intervalo histórico.
>
> Isso explica um comportamento que veremos adiante: os data points de exemplo com timestamp de **2022** são aceitos na escrita, mas **não aparecem** nas consultas.

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

### Tags × Fields — o conceito mais importante

A distinção entre **tags** e **fields** é central em bancos de séries temporais e determina o desempenho das consultas:

| | **Tags** | **Fields** |
|---|---|---|
| Tipo | sempre `string` | `Float`, `Integer`, `UInteger`, `String`, `Boolean` |
| Papel | **identificam a série** (metadados / dimensões) | **as medições** (os valores que variam no tempo) |
| Uso típico | `WHERE`, `GROUP BY` | `SELECT`, agregações (`SUM`, `AVG`...) |
| Exemplo no lab | `produto`, `pais` | `quantidade`, `preco` |

> **Cardinalidade** é o número de combinações distintas de séries (measurement + conjunto de tags). Tags com muitos valores possíveis (ex.: `id_do_pedido`, IP, e-mail) causam **alta cardinalidade** — historicamente o principal gargalo de séries temporais. Regra prática: use como tag apenas o que você vai **filtrar/agrupar**; o resto é field.

> **No InfluxDB 3 isso mudou de fundo.** O armazenamento agora é **colunar (Apache Arrow em memória, Apache Parquet em disco)**. A separação tag/field continua no Line Protocol, mas fisicamente cada tag e cada field vira uma **coluna** tipada e comprimida. Por isso o v3 tolera cardinalidade muito melhor que o v1/v2 e permite **SQL padrão** sobre os dados. Vamos ver esses arquivos Parquet na [Seção 9](#9-por-dentro-do-armazenamento-parquet--arrow-hands-on).

**Exemplo**:
```
pedidos,produto=GELADEIRA quantidade=1,preco=2000 1668387574000000000
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
...
Acesse o ambiente Cloud9 em: http://ec2-34-238-49-243.compute-1.amazonaws.com:8181

```

Caso precise recuperar o URL:
```
export CLOUD9_EC2_INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data//instance-id)
export CLOUD9_EC2_PUBLIC_DNS=$(aws ec2 describe-instances --instance-id $CLOUD9_EC2_INSTANCE_ID | jq -r .Reservations[0].Instances[0].NetworkInterfaces[0].Association.PublicDnsName)
echo "DNS público: $CLOUD9_EC2_PUBLIC_DNS"

```

### 3. Docker Compose

Por simplicidade, vamos utilizar o InfluxDB em um container baseado em *Docker*.<br>
#### Baixe os arquivos necessários
```bash
wget https://raw.githubusercontent.com/infobarbosa/influxdb-docker-demo/main/compose.yaml
wget https://raw.githubusercontent.com/infobarbosa/influxdb-docker-demo/main/pedidos.sh
wget https://raw.githubusercontent.com/infobarbosa/influxdb-docker-demo/main/grafana-datasource.yaml

```

```
ls -la compose.yaml pedidos.sh grafana-datasource.yaml

```

#### Inicialização
```
docker compose up -d

```

Este comando inicializa três serviços:
- **`influxdb`**: o banco de dados InfluxDB 3, acessível na porta `8181`.
- **`influxproducer`**: produtor de dados que insere pedidos simulados continuamente no banco `ecommerce`, permitindo visualizar dados em tempo real.
- **`grafana`**: plataforma de visualização de dashboards, acessível na porta `3000`. Explorada na seção bônus ao final do laboratório.

### 4. Criando o banco de dados

No InfluxDB 3, o equivalente ao *bucket* é o **database**. Após inicializar os containers, crie o banco `ecommerce`:

```bash
docker exec -it influxdb-demo influxdb3 create database ecommerce

```

> **Nota:** O produtor de dados (`influxproducer`) ficará em loop tentando escrever automaticamente assim que o banco existir.

---

### 5. `influxdb3 write`

O comando `influxdb3 write` escreve data points no InfluxDB via entrada padrão ou argumento direto.

#### Sintaxe

```
influxdb3 write --database <nome> "<line protocol>"
``` 

Maiores informações: https://docs.influxdata.com/influxdb3/core/reference/cli/influxdb3/write/

#### Exemplo 1 — Venda de uma geladeira
```bash
docker exec -it influxdb-demo influxdb3 write \
  --database ecommerce \
  "pedidos,produto=GELADEIRA,pais=BR quantidade=1,preco=2000 1668387574000000000"

```

#### Exemplo 2 — Venda sem timestamp
> O InfluxDB usará o instante atual do servidor.
```bash
docker exec -it influxdb-demo influxdb3 write \
  --database ecommerce \
  "pedidos,produto=TV,pais=US quantidade=2,preco=5000"

```

#### Exemplo 3 — Múltiplos data points
```bash
docker exec -it influxdb-demo influxdb3 write \
  --database ecommerce \
  "pedidos,produto=FOGAO,pais=BR quantidade=1,preco=1000 1668426060000000000
pedidos,produto=GELADEIRA,pais=AU quantidade=1,preco=2000 1668426081000000000
pedidos,produto=LAVADORA,pais=BR quantidade=1,preco=1000 1668426093000000000
pedidos,produto=FILTRO,pais=US quantidade=1,preco=500 1668426100000000000
pedidos,produto=TV,pais=BR quantidade=1,preco=5000 1668426107000000000"

```

---

### 6. `influxdb3 query` — SQL

No InfluxDB 3, as consultas são feitas em **SQL padrão**. O measurement (`pedidos`) é a tabela, tags e fields são colunas, e o timestamp fica na coluna `time`.

#### Sintaxe

```
influxdb3 query --database <nome> "<SQL>"
```

#### Exemplo 4 — Recuperar tudo

```bash
docker exec -it influxdb-demo influxdb3 query \
  --database ecommerce \
  "SELECT * FROM pedidos"

```

**Onde:**
- `SELECT *` — retorna todas as colunas.
- `FROM pedidos` — especifica o measurement (tabela).

---

#### Exemplo 5 — Filtrar por produto

```bash
docker exec -it influxdb-demo influxdb3 query \
  --database ecommerce \
  "SELECT * FROM pedidos WHERE produto = 'GELADEIRA'"

```

---

#### Exemplo 6 — Selecionar colunas específicas

```bash
docker exec -it influxdb-demo influxdb3 query \
  --database ecommerce \
  "SELECT time, produto, pais, quantidade, preco FROM pedidos ORDER BY time DESC LIMIT 20"

```

---

### 7. Especificando o período

Para filtrar por intervalo de tempo, use a coluna `time` na cláusula `WHERE`.

#### Exemplo 7 — Consulta para novembro de 2022

```bash
docker exec -it influxdb-demo influxdb3 query \
  --database ecommerce \
  "SELECT * FROM pedidos
   WHERE time >= '2022-11-01T00:00:00Z'
     AND time <  '2022-12-01T00:00:00Z'"

```

> ⚠️ **Resultado esperado no Core: vazio.** Mesmo tendo inserido os pedidos de 2022 nos Exemplos 1 e 3 (a **escrita** foi aceita), esta consulta cai fora da **janela de ~72h do InfluxDB 3 Core** e não retorna linhas. Reveja a nota [Core × Enterprise](#core--enterprise-importante-para-este-laboratório). Este é um dos conceitos mais importantes do laboratório: **escrever ≠ conseguir consultar** no Core.

---

#### Exemplo 8 — Últimos 2 minutos

```bash
docker exec -it influxdb-demo influxdb3 query \
  --database ecommerce \
  "SELECT * FROM pedidos
   WHERE time >= now() - INTERVAL '2 minutes'
   ORDER BY time DESC"

```

> **Atenção:** Os data points inseridos com timestamp fixo em 2022 **não aparecerão** aqui. Apenas os inseridos sem timestamp (Exemplo 2) ou pelo produtor automático poderão aparecer.

---

#### Exemplo 9 — Últimos 2 minutos com colunas organizadas

```bash
docker exec -it influxdb-demo influxdb3 query \
  --database ecommerce \
  "SELECT time, produto, pais, quantidade, preco
   FROM pedidos
   WHERE time >= now() - INTERVAL '2 minutes'
   ORDER BY time DESC"

```

---

### 8. Agregações SQL

#### Exemplo 10 — Total de vendas por produto (últimos 30 minutos)

```bash
docker exec -it influxdb-demo influxdb3 query \
  --database ecommerce \
  "SELECT produto, SUM(quantidade) AS total_vendas
   FROM pedidos
   WHERE time >= now() - INTERVAL '30 minutes'
   GROUP BY produto
   ORDER BY total_vendas DESC"

```

---

#### Exemplo 11 — Vendas por produto e país

```bash
docker exec -it influxdb-demo influxdb3 query \
  --database ecommerce \
  "SELECT produto, pais, SUM(quantidade) AS total_vendas
   FROM pedidos
   WHERE time >= now() - INTERVAL '30 minutes'
   GROUP BY produto, pais
   ORDER BY total_vendas DESC"

```

---

#### Exemplo 12 — Janelas de tempo de 10 segundos

A função `date_bin` divide o eixo do tempo em janelas de tamanho fixo — equivalente ao `aggregateWindow` do Flux.

```bash
docker exec -it influxdb-demo influxdb3 query \
  --database ecommerce \
  "SELECT
     date_bin(INTERVAL '10 seconds', time) AS janela,
     produto,
     SUM(quantidade) AS total_vendas
   FROM pedidos
   WHERE time >= now() - INTERVAL '30 minutes'
   GROUP BY janela, produto
   ORDER BY janela"

```

---

#### Exemplo 13 — Vendas do Brasil

```bash
docker exec -it influxdb-demo influxdb3 query \
  --database ecommerce \
  "SELECT produto, SUM(quantidade) AS total_vendas
   FROM pedidos
   WHERE time >= now() - INTERVAL '30 minutes'
     AND pais = 'BR'
   GROUP BY produto
   ORDER BY total_vendas DESC"

```

---

#### Exemplo 14 — Vendas de geladeira na Austrália

```bash
docker exec -it influxdb-demo influxdb3 query \
  --database ecommerce \
  "SELECT time, quantidade, preco
   FROM pedidos
   WHERE produto = 'GELADEIRA'
     AND pais = 'AU'
     AND time >= now() - INTERVAL '30 minutes'
   ORDER BY time DESC"

```

---

#### Exemplo 15 — Janela de tempo fixa (ponto absoluto no tempo)

Até aqui filtramos com `now() - INTERVAL '...'` (janela **relativa**, que "anda" com o relógio). Muitas análises, porém, precisam de um intervalo **absoluto** — por exemplo, "o que foi vendido **das 18h às 19h**". Basta informar os instantes de início e fim na cláusula `WHERE`.

```bash
docker exec -it influxdb-demo influxdb3 query \
  --database ecommerce \
  "SELECT
     date_bin(INTERVAL '10 minutes', time) AS janela,
     produto,
     SUM(quantidade) AS total_vendas
   FROM pedidos
   WHERE time >= '2026-07-06T18:00:00-03:00'
     AND time <  '2026-07-06T19:00:00-03:00'
   GROUP BY janela, produto
   ORDER BY janela"

```

> ⏰ **Fuso horário (leia com atenção).** A coluna `time` é **sempre armazenada em UTC**. No exemplo acima usamos o sufixo `-03:00` para dizer "18h no horário de Brasília" — o InfluxDB converte para UTC automaticamente (18h em Brasília = 21h UTC). Se preferir raciocinar direto em UTC, use o sufixo `Z`: `'2026-07-06T21:00:00Z'`. Ajuste a **data** (`2026-07-06`) para o dia em que você gerou os dados.

> ⚠️ **Lembrete do Core:** a janela escolhida precisa estar dentro das **últimas ~72h** para retornar resultados (veja [Core × Enterprise](#core--enterprise-importante-para-este-laboratório)).

---

### 9. Por dentro do armazenamento: Parquet + Arrow (hands-on)

Até aqui usamos o InfluxDB como uma "caixa preta". Nesta seção vamos **abrir a caixa** e olhar como os dados ficam gravados em disco — e a boa notícia é que eles estão em **Apache Parquet**, o mesmo formato colunar dos data lakes. Vamos inclusive ler esses arquivos com o **DuckDB**, sem passar pelo InfluxDB.

#### 9.1. O caminho do dado: WAL → Parquet

Quando você escreve um data point, ele **não** vai direto para um arquivo Parquet. O fluxo é:

1. **WAL** (*Write-Ahead Log*): gravação imediata e sequencial, para durabilidade e recuperação de falhas.
2. **Buffer em memória**: os dados ficam em **Apache Arrow** (colunar, em RAM) e já podem ser consultados.
3. **Persistência (snapshot)**: periodicamente o buffer é escrito como **arquivos Parquet** imutáveis no *object store* (aqui, o disco local).

> 🧪 **Ajuste didático deste laboratório.** Por padrão, o Core só gera Parquet após acumular **600 arquivos de WAL** (~10 min). Para não esperarmos, o `compose.yaml` define `INFLUXDB3_WAL_SNAPSHOT_SIZE=10` e `INFLUXDB3_GEN1_DURATION=1m`, fazendo o Parquet aparecer em segundos. **Nunca use esses valores em produção** — eles geram muitos arquivos pequenos.

Espere ~30 segundos após o `docker compose up` e explore a árvore de arquivos do banco:

```bash
docker exec influxdb-demo find /var/lib/influxdb3 -maxdepth 3 -type d

```

Você verá três diretórios importantes dentro de `/var/lib/influxdb3/demo/` (`demo` é o `--node-id`):
- **`wal/`** — os arquivos `.wal` (log de escrita).
- **`catalog/`** — os metadados (bancos, tabelas, colunas, localização dos arquivos).
- **`dbs/`** — os **arquivos Parquet** com os dados de fato.

#### 9.2. Localizando os arquivos Parquet

```bash
docker exec influxdb-demo sh -c 'find /var/lib/influxdb3 -name "*.parquet"'

```

Repare que aparecem **vários arquivos**, e no padrão do caminho — é assim que o InfluxDB 3 **particiona** os dados fisicamente, por **data**:

```
dbs/<database>/<tabela>/<data>/<hora-minuto>/<arquivo>.parquet
```

> 🔎 Se você executou os Exemplos 1 e 3 (com timestamp de **2022**), vai notar uma partição `.../2022-11-14/...` **separada** das partições de hoje. Cada partição vira um ou mais arquivos Parquet independentes. Guarde essa ideia: **os dados estão espalhados em muitos arquivos**, não em um só.

#### 9.3. Copiando os arquivos para fora do container

Como os dados estão **espalhados em vários arquivos** (um ou mais por partição de data), não faz sentido copiar só um — vamos trazer a **árvore inteira** `dbs/` para a máquina host:

```bash
docker cp influxdb-demo:/var/lib/influxdb3/demo/dbs ./dbs
find dbs -name '*.parquet'

```

> ⚠️ **Não use `find ... | head -1`** para escolher "um arquivo". Ele pega o **primeiro** da lista, que costuma ser justamente a partição de **2022** — um arquivo com **uma única linha** (o data point do Exemplo 1). Você teria a falsa impressão de que "cada Parquet tem só um registro". A forma correta é ler **todos os arquivos de uma vez** com um *glob* recursivo, como faremos a seguir.

#### 9.4. Instalando o DuckDB

O [DuckDB](https://duckdb.org/) é um banco analítico embarcado (um único binário) que lê Parquet nativamente e roda **SQL** — perfeito para inspecionar nossos arquivos.

```bash
curl https://install.duckdb.org | sh

```

> O instalador cria um atalho em `~/.local/bin/duckdb`. Se o comando `duckdb` não for encontrado, use o caminho completo `~/.duckdb/cli/latest/duckdb` ou rode `export PATH="$HOME/.local/bin:$PATH"`.
>
> **Alternativas:** `parquet-tools` (Python: `pip install parquet-tools`) ou `pqrs` (CLI em Rust) também inspecionam Parquet, mas o DuckDB permite rodar SQL diretamente.

#### 9.5. Lendo TODOS os dados sem o InfluxDB

O `**` faz o DuckDB varrer o diretório **recursivamente**, lendo todos os Parquet de todas as partições de uma vez — exatamente como uma engine de data lake faria:

```bash
duckdb -c "SELECT COUNT(*) AS total, MIN(time) AS mais_antigo, MAX(time) AS mais_recente
           FROM read_parquet('dbs/**/*.parquet');"

```

Note que aparece de tudo — inclusive o ponto de **2022** convivendo com os dados de hoje. O DuckDB lê os arquivos diretamente: **o InfluxDB nem precisa estar rodando**. Isso ilustra o valor de um formato aberto — seus dados não ficam presos ao banco.

```bash
duckdb -c "SELECT * FROM read_parquet('dbs/**/*.parquet') ORDER BY time DESC LIMIT 10;"

```

Agora dá para entender por que "pegar um arquivo só" engana. Veja **quantas linhas há em cada arquivo**:

```bash
duckdb -c "SELECT regexp_replace(file_name, '.*/dbs/', '') AS arquivo, num_rows
           FROM parquet_file_metadata('dbs/**/*.parquet')
           ORDER BY arquivo;"

```

Você verá o arquivo da partição de **2022 com apenas 1 linha**, e os arquivos de hoje com dezenas de linhas cada. Cada arquivo cobre uma **partição de tempo** (data/janela). Muitos arquivos pequenos são o efeito do nosso ajuste didático (`WAL_SNAPSHOT_SIZE=10`); em produção, o *compactor* do InfluxDB Enterprise junta esses arquivinhos em blocos maiores — o clássico problema dos *"small files"*.

#### 9.6. O schema colunar e tipado

```bash
duckdb -c "DESCRIBE SELECT * FROM read_parquet('dbs/**/*.parquet');"

```

Note que cada tag (`produto`, `pais`) e cada field (`quantidade`, `preco`) virou uma **coluna tipada**, e o `time` é um `TIMESTAMP_NS`. Compare com o schema físico do Parquet (escolhemos um arquivo qualquer para inspecionar a estrutura interna):

```bash
duckdb -c "SELECT DISTINCT name, type, logical_type, repetition_type
           FROM parquet_schema('dbs/**/*.parquet');"

```

Você verá as tags como `BYTE_ARRAY` com `StringType()` e o `time` como `INT64` com `TimestampType(... NANOS ...)` — além de uma chave `arrow_schema`, que é o schema Apache Arrow embutido em cada arquivo.

#### 9.7. Compressão e *encoding* — o coração do colunar

Aqui está o conceito de bancos colunares em ação. Cada coluna é comprimida **independentemente**, com o *encoding* mais adequado ao seu conteúdo:

```bash
duckdb -c "
SELECT
  path_in_schema AS coluna,
  any_value(compression) AS compressao,
  any_value(encodings)   AS encodings,
  SUM(total_uncompressed_size) AS bruto,
  SUM(total_compressed_size)   AS comprimido
FROM parquet_metadata('dbs/**/*.parquet')
GROUP BY coluna;"

```

Observe:
- **`compressao = ZSTD`** em todas as colunas.
- **`RLE_DICTIONARY`** (dictionary encoding) nas tags `produto` e `pais`: como elas têm **poucos valores distintos** (baixa cardinalidade), o Parquet guarda um dicionário e substitui cada valor por um pequeno índice inteiro. É por isso que, em séries temporais, **tags de baixa cardinalidade comprimem muito bem** — e por que alta cardinalidade dói.
- **Compressão só compensa com volume.** Com os pouquíssimos dados deste laboratório, `comprimido` pode até ficar **maior** que `bruto` em algumas colunas — é o custo fixo (overhead) do ZSTD e dos dicionários em páginas minúsculas. Deixe o produtor rodar por alguns minutos, repita a consulta, e observe a razão `comprimido/bruto` **cair** conforme o volume cresce. Esse é justamente o regime em que o formato colunar brilha.

Uma visão geral, arquivo a arquivo (linhas e *row groups*):

```bash
duckdb -c "SELECT regexp_replace(file_name, '.*/dbs/', '') AS arquivo, num_rows, num_row_groups
           FROM parquet_file_metadata('dbs/**/*.parquet')
           ORDER BY arquivo;"

```

#### 9.8. Rodando análises direto no Parquet

Como é SQL, dá para agregar sobre **todos os arquivos** sem o InfluxDB:

```bash
duckdb -c "
SELECT produto, COUNT(*) AS n, SUM(quantidade) AS total, ROUND(AVG(preco),2) AS preco_medio
FROM read_parquet('dbs/**/*.parquet')
GROUP BY produto
ORDER BY total DESC;"

```

> 💡 **Desafio (para casa):** compare o tamanho de um data point em **Line Protocol** (texto, ~60 bytes) com o custo por linha no Parquet comprimido (`SUM(total_compressed_size) / SUM(num_rows)`). Discuta por que o formato colunar comprimido é a base de praticamente todos os motores analíticos modernos (InfluxDB 3, ClickHouse, DuckDB, Spark, BigQuery...).

---

## HTTP API
<br>

O InfluxDB 3 disponibiliza os endpoints `/api/v3/write_lp` (escrita) e `/api/v3/query_sql` (consulta SQL).

### Escrita

```bash
curl -XPOST "http://$(hostname):8181/api/v3/write_lp?db=ecommerce&precision=s" \
  --header "Content-Type: text/plain; charset=utf-8" \
  --data-raw 'pedidos,produto=SANDUICHEIRA,pais=BR quantidade=1,preco=200'
```

### Consulta SQL via HTTP

```bash
curl -G "http://$(hostname):8181/api/v3/query_sql" \
  --data-urlencode "db=ecommerce" \
  --data-urlencode "q=SELECT * FROM pedidos ORDER BY time DESC LIMIT 10"
```

Ou via POST com JSON:

```bash
curl -XPOST "http://$(hostname):8181/api/v3/query_sql" \
  --header "Content-Type: application/json" \
  --data '{"db": "ecommerce", "q": "SELECT produto, SUM(quantidade) AS total FROM pedidos GROUP BY produto"}'
```

---

> ℹ️ **E a interface web nativa do InfluxDB?** A imagem `influxdb:3-core` **não inclui** uma UI embutida — a porta `8181` responde apenas à API HTTP (acessar `http://localhost:8181` no navegador retorna `404 Not found`). A exploração visual de dados fica por conta do **[InfluxDB 3 Explorer](https://github.com/influxdata/influxdb3-explorer)**, distribuído como um **container à parte** (`influxdata/influxdb3-explorer`), e do **Grafana** — que já vem pronto neste laboratório e usamos no bônus a seguir.

---

## Bônus: Grafana

O Grafana é uma plataforma open source de visualização amplamente usada para criar dashboards. Ele já está disponível como parte do ambiente deste laboratório.

### Acessando o Grafana

- Abra o navegador e acesse `localhost:3000` (ou substitua `localhost` pelo endereço do ambiente Cloud9).
- Usuário: `admin` | Senha: `admin`.

### Datasource já configurado (SQL via FlightSQL)

O datasource do InfluxDB já está configurado automaticamente via provisionamento — o arquivo `grafana-datasource.yaml` é lido pelo Grafana na inicialização. Não é necessário nenhuma configuração manual na interface.

Ele está configurado no modo **SQL**, consistente com o restante do laboratório. Por baixo dos panos, o Grafana conversa com o InfluxDB 3 via **Arrow Flight (gRPC)** — o mesmo protocolo *FlightSQL* mencionado na [introdução](#o-motor-do-influxdb-3-por-que-ele-é-diferente) — recebendo os resultados já em formato colunar Arrow.

Para confirmar, acesse **Connections > Data Sources > influxdb** e clique em **Save & test**: você verá a mensagem de sucesso.

> **Curiosidade:** o InfluxDB 3 também aceita **InfluxQL** (linguagem legada do v1/v2) por compatibilidade, via `/api/v3/query_influxql`. Optamos por **SQL** aqui para manter um único dialeto no laboratório inteiro. Se um dia você vir dashboards antigos com `GROUP BY time(10s)`, isso é InfluxQL — o equivalente em SQL é o `date_bin()` que já usamos.

### Criando um painel simples

1. Clique em **+** no menu lateral > **New Dashboard > Add visualization**.
2. Selecione o data source **influxdb** (SQL).
3. Certifique-se de que o editor está no modo **SQL** e insira:

```sql
SELECT
  date_bin(INTERVAL '10 seconds', time) AS janela,
  produto,
  SUM(quantidade) AS total_vendas
FROM pedidos
WHERE $__timeFilter(time)
GROUP BY janela, produto
ORDER BY janela
```

> A macro `$__timeFilter(time)` é substituída pelo Grafana pelo intervalo de tempo selecionado no dashboard (canto superior direito).

4. Clique em **Run query** para visualizar o gráfico de vendas por produto em tempo real.

---

## Referências para aprofundamento

Sugestões para continuar os estudos, organizadas por tema.

### InfluxDB 3
- [Documentação oficial — InfluxDB 3 Core](https://docs.influxdata.com/influxdb3/core/) — ponto de partida.
- [Get started with InfluxDB 3 Core](https://docs.influxdata.com/influxdb3/core/get-started/) — escrita, consulta e configuração passo a passo.
- [Line Protocol — referência](https://docs.influxdata.com/influxdb3/core/reference/line-protocol/) — a sintaxe completa de escrita.
- [Referência de SQL do InfluxDB 3](https://docs.influxdata.com/influxdb3/core/reference/sql/) e [de InfluxQL](https://docs.influxdata.com/influxdb3/core/reference/influxql/) — os dois dialetos suportados.
- [CLI `influxdb3`](https://docs.influxdata.com/influxdb3/core/reference/cli/influxdb3/) — todos os subcomandos (`write`, `query`, `create`, `serve`...).
- [Blog — InfluxDB 3.0 System Architecture](https://www.influxdata.com/blog/influxdb-3-0-system-architecture/) — como o motor funciona por dentro (ingester, compactor, catalog, object store).
- [Diferenças entre Core e Enterprise](https://docs.influxdata.com/influxdb3/core/#core-vs-enterprise) e o [anúncio da limitação de 72h](https://www.influxdata.com/blog/influxdb3-open-source-public-alpha-jan-27/).

### O stack FDAP (Apache) e formatos colunares
- [Apache Arrow](https://arrow.apache.org/) — o formato colunar em memória.
- [Apache Parquet](https://parquet.apache.org/docs/) — o formato colunar em disco; veja em especial *encodings* e *compression*.
- [Apache DataFusion](https://datafusion.apache.org/) — o motor de consulta SQL em Rust usado pelo InfluxDB 3.
- [Apache Arrow Flight & FlightSQL](https://arrow.apache.org/docs/format/FlightSql.html) — o protocolo de transporte colunar usado pelo Grafana.
- [InfoQ — Rebuilding InfluxDB 3 in Apache Arrow and Rust](https://www.infoq.com/articles/timeseries-db-rust/) — a história técnica da reescrita.
- [DuckDB — documentação](https://duckdb.org/docs/) e o guia [Reading and Writing Parquet](https://duckdb.org/docs/data/parquet/overview).

### Séries temporais e bancos colunares (conceitos)
- Jensen, Pedersen & Thomsen — *[Time Series Management Systems: A Survey](https://arxiv.org/abs/1710.01792)* (survey acadêmico).
- Abadi et al. — *[The Design and Implementation of Modern Column-Oriented Database Systems](https://stratos.seas.harvard.edu/files/stratos/files/columnstoresfntdbs.pdf)* (leitura de referência sobre colunar).
- [Awesome Time Series Database](https://github.com/xephonhq/awesome-time-series-database) — panorama de ferramentas do ecossistema.

### Visualização e ecossistema
- [Grafana — data source oficial do InfluxDB v3](https://www.influxdata.com/blog/official-influxdb-v3-data-source-grafana-released/).
- [Grafana — documentação do data source InfluxDB](https://grafana.com/docs/grafana/latest/datasources/influxdb/).
- [Telegraf](https://docs.influxdata.com/telegraf/) — agente de coleta de métricas, o companheiro natural do InfluxDB para ingestão em produção.

---

## Parabéns!

Parabéns por concluir o laboratório de Armazenamento de Séries Temporais com InfluxDB 3! Você aprendeu como utilizar o InfluxDB 3 para armazenar e consultar dados de séries temporais usando SQL padrão. Continue praticando e explorando as funcionalidades do InfluxDB para aprimorar ainda mais seus conhecimentos.

Se tiver dúvidas ou sugestões, sinta-se à vontade para entrar em contato.

Bom trabalho e até a próxima!

Prof. Barbosa
