# ISI Store — Processo ETL (Trabalho Prático I)

Processo **ETL** (_Extract, Transform, Load_) desenvolvido em **Pentaho Data Integration (Kettle/Spoon)** para uma loja fictícia de informática e mobiliário de escritório, a **ISI Store**. O trabalho integra fontes heterogéneas (CSV, JSON, XML, API REST e PostgreSQL), limpa e valida os dados, executa junções e agregações, carrega um _Data Mart_ e gera exportações, alertas por correio eletrónico e um painel complementar em **Node-RED**.

Trabalho individual da Unidade Curricular de **Integração de Sistemas de Informação (ISI)**, Licenciatura em Engenharia de Sistemas Informáticos, IPCA — Escola Superior de Tecnologia, 2026/27.

## Arquitetura ETL

O processo segue as três fases obrigatórias do enunciado:

| Fase | Descrição |
|------|-----------|
| **E** — Extração | Leitura multiformato em paralelo: CSV, JSON, XML, REST (API FakeStore) e tabela SQL |
| **T** — Transformação | Limpeza (Sort, Unique, Filter, Replace, Calculator), validação por expressões regulares, anonimização, junções (Stream Lookup) e agregação (Group By) |
| **L** — Carga | Persistência em `dw_vendas`, exportação CSV/JSON, correio eletrónico, FTP e registos de log |

### Fontes de dados (entrada)

| Fonte | Formato | Step Pentaho |
|-------|---------|--------------|
| `vendas.csv` | CSV (local) | CSV File Input |
| `clientes.json` | JSON (local) | JSON Input |
| `produtos.xml` | XML (local) | Get Data from XML |
| API FakeStore | JSON REST | Generate Rows + REST Client |
| `stock` (BD PostgreSQL) | Tabela SQL | Table Input |

### Problemas tratados nos dados

- Duplicado na venda `V002`;
- Quantidade zero (`V005`) e `id_cliente` nulo (`V007`);
- Data com formato errado (`V009`, com `/` em vez de `-`);
- Correio eletrónico inválido/nulo, telemóvel com separadores e NIF não numérico;
- Registo de cliente duplicado.

### Expressões regulares aplicadas

| Campo | Expressão regular |
|-------|-------------------|
| Email | `^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$` |
| Telemóvel (após limpar `[\s-]`) | `^9[1236][0-9]{7}$` |
| NIF | `^[0-9]{9}$` |
| Data | `^\d{4}-\d{2}-\d{2}$` |

## Estrutura do repositório

```
Trabalho Prático I/
├── Dados_Entrada/        # Fontes originais (vendas.csv, clientes.json, produtos.xml, stock_novos.sql)
├── Dados_Saida/          # Resultados (vendas_limpas.csv, resumo.json)
├── FTP_remoto/           # Simula o servidor remoto (destino FTP)
├── Jobs/
│   └── J_principal.kjb   # Job de orquestração
├── NodeRED/
│   └── flows.json        # Fluxos complementares (MQTT + dashboard)
├── Transformacoes/
│   ├── E_extracao.ktr    # Fase E — extração multiformato
│   ├── T_limpeza.ktr     # Fase T — limpeza de vendas
│   ├── T_clientes.ktr    # Fase T — validação de clientes
│   ├── T_joins.ktr       # Fase T — junções e agregações
│   └── L_carga.ktr       # Fase L — carga do Data Mart
└── Relatorio/            # Relatório (LaTeX + PDF + imagens)
```

## Transformações

- **`E_extracao.ktr`** — 6 _steps_ de leitura paralela com _schemas_ preservados: vendas (13), clientes (6), produtos (158), REST (1) e _stock_ (158).
- **`T_limpeza.ktr`** — _Sort Rows_ + _Unique Rows_ remove o duplicado `V002` (13→12); _Filter Rows_ (`quantidade>0 AND id_cliente IS NOT NULL`) remove `V005` e `V007` (12→10); _Replace_ corrige a data de `V009`; _Calculator_ (BigNumber, precisão 2, _locale_ `Decimal=.` sem agrupamento) calcula `total_linha` (V001 = 1799.98).
- **`T_clientes.ktr`** — _Replace_ por regex `[\s-]` normaliza o telemóvel; três avaliações _Regex_ em série validam email, telemóvel e NIF; filtro `Y/Y/Y` mantém 2 clientes válidos (C001, C003); aplica-se anonimização (RGPD).
- **`T_joins.ktr`** — dois _Stream Lookup_ (vendas+clientes por `id_cliente`; resultado+produtos por `id_produto`) e _Group By_ por cidade: **nulo 429/5**, **Braga 2072/3**, **Porto 948/2**.
- **`L_carga.ktr`** — _Table Output_ (`dw_vendas`, 10 linhas), _Text File Output_ (`vendas_limpas.csv`, delimitador `;`) e _JSON Output_ (`resumo.json`).

## Job de orquestração

`J_principal.kjb` executa a sequência:

```
START → E_extracao → T_joins → L_carga → FTP_csv → FTP_json → Mail → Write to Log
```

- **Transformation entries** para E, T e L;
- **Send Mail** — alerta com os totais por cidade (2072/948/429);
- **FTP Put** — um _step_ por ficheiro (a versão 10.2 limita a um _wildcard_ por _step_), para servidor local `127.0.0.1:21`;
- **Write to Log** — registo de sucesso.

## Ferramenta complementar — Node-RED

- _Broker_ **Mosquitto** em `localhost:1883`;
- Fluxo de _streaming_ publica mensagens `STREAM-` no tópico `isi/vendas`;
- Painel (`/ui`) com os totais e gráfico de barras por cidade.

## Contagens de validação

| Métrica | Valor |
|---------|-------|
| vendas.csv | 13 linhas |
| clientes.json | 6 objetos |
| produtos.xml | 158 produtos |
| tabela `stock` | 158 linhas |
| vendas limpas | 10 linhas |
| clientes válidos | 2 registos |
| `dw_vendas` | 10 linhas |
| _Group By_ | 3 linhas |

## Tecnologias

Pentaho Data Integration 10.2 (Spoon) · PostgreSQL · DBeaver · Node-RED (node-red-dashboard) · Eclipse Mosquitto · LaTeX (relatório).

## Como executar

1. **Pré-requisitos:** Pentaho Data Integration 10.2, PostgreSQL com a base de dados `isi_store` (tabelas `dw_vendas` e `stock`) e, opcionalmente, Node-RED + Mosquitto.
2. Criar a base de dados e as tabelas:

   ```sql
   CREATE TABLE dw_vendas (
     id_venda VARCHAR(10) PRIMARY KEY,
     id_cliente VARCHAR(10),
     id_produto VARCHAR(10),
     data DATE,
     quantidade INT,
     preco_unit NUMERIC(10,2),
     total_linha NUMERIC(10,2)
   );
   CREATE TABLE stock (
     id_produto VARCHAR(10) PRIMARY KEY,
     stock_atual INT
   );
   ```

3. Importar os dados de `stock` a partir de `Dados_Entrada/stock_novos.sql`.
4. Abrir `Jobs/J_principal.kjb` no Spoon e executar (Run). O _job_ percorre E → T → L → FTP → Mail → Log.
5. (Opcional) Importar `NodeRED/flows.json` no Node-RED e arrancar o Mosquitto para o painel em `/ui`.

## Resultados

- 13 vendas → **10 linhas** limpas;
- 6 clientes → **2 válidos**;
- **158 produtos** e **158** linhas de _stock_ integrados;
- **10 linhas** carregadas em `dw_vendas`;
- Agregação por cidade: **Braga 2072/3**, **Porto 948/2**, **nulo 429/5**;
- Exportações `vendas_limpas.csv` e `resumo.json` transferidas para `FTP_remoto/`.

## Referências

- Ferreira, L. e Ribeiro, Ó. (2026). _Enunciado do Trabalho Prático I de ISI_. IPCA.
- Hitachi Vantara (2026). _Pentaho Data Integration Documentation_. https://www.hitachivantara.com/
- Node-RED (2026). https://nodered.org/
- Eclipse Mosquitto (2026). https://mosquitto.org/
- PostgreSQL (2026). https://www.postgresql.org/
- FakeStore API (2026). https://fakestoreapi.com/
