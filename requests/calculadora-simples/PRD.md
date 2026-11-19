# PRD — `calculadora-simples` (Calculadora Simples Administrativa)

## 1. Visão do Produto & Contexto de Negócio

- **Aplicação**: **Calculadora Simples Administrativa** (`calculadora-simples`)
- **Subtítulo Funcional**: Gestão e registro auditável de cálculos operacionais e memórias de cálculo institucionais.
- **Demanda / Justificativa**: Calculadora básica clássica com teclado numérico de 0 a 9, ponto decimal, quatro operações básicas (+, -, *, /), igual (=), limpar (C/AC), apagar (backspace), display digital interativo de expressão e resultado, suporte a teclado físico, e painel lateral simples de histórico de cálculos persistido em PostgreSQL com expressão, resultado e timestamp.
- **Entidade Principal de Domínio**: `Cálculo Institucional` / `Cálculos Institucionais`
- **Isolamento de Dados**: Cloud SQL PostgreSQL compartilhado (`detran-shared-pgsql`), database `db_calculadora_simples`, schema exclusivo `calculadora_simples` (zero uso de `public`).

## 2. Regras de Negócio Numeradas

- **RN-001**: Validação rigorosa dos operadores aritméticos (+, -, *, /) impedindo divisão por zero e injeção de caracteres inválidos.
- **RN-002**: Geração automática de protocolo sequencial prefixado com 'CALC' via trigger/service no schema isolado calculadora_simples.
- **RN-003**: Imutabilidade do registro com status 'CONSOLIDADO', admitindo edições apenas em 'RASCUNHO' e 'EM_VALIDACAO'.
- **RN-004**: Auditoria completa de logs de alteração e validação de vínculo com número de processo SEI válido via regex institucional.
- **RN-005**: Evolução incremental Day-2 preservando schema 'calculadora_simples' e registros ativos: campos adicionados (Complemento Operacional, Origem do Lançamento, Data/Hora do Registro); novos status (Arquivado).
- **RN-006 [LGPD & GOVERNANÇA]**: Nenhum dado pessoal sensível sem mascaramento em telas ou logs; autenticação e borda protegidas por GCLB HTTPS + Cloud Armor WAF.

## 3. Histórias de Usuário em Formato Gherkin (INVEST)

### US-001 — Consulta Operacional com Indicadores em Tempo Real e Filtros
```gherkin
Funcionalidade: Painel de Gestão de Cálculos Institucionais
  Cenário: Carregamento inicial da tela com indicadores e registros do PostgreSQL
    Dado que o operador acessa o portal "Calculadora Simples Administrativa" via HTTPS (.nip.io)
    Quando a aplicação consulta GET /api/items e GET /api/status na mesma origem
    Então a interface exibe os 4 indicadores KPI consolidados e os 7 registros iniciais do schema "calculadora_simples"
    E permite filtrar por busca textual, status (`RASCUNHO` (Rascunho), `EM_VALIDACAO` (Em Validação), `ARQUIVADO` (Arquivado), `CONSOLIDADO` (Consolidado)), prioridade e categoria
```

### US-002 — Cadastro Validado de Cálculo Institucional com Persistência PostgreSQL
```gherkin
Funcionalidade: Criação de Cálculo Institucional
  Cenário: Submissão válida pelo formulário modal da aplicação
    Dado que o operador clica em "+ Novo(a) Cálculo Institucional" e preenche os campos de domínio
    Quando envia POST /api/items com título, categoria, prioridade e metadados estruturados
    Então a API valida as invariantes de negócio, gera protocolo "CALC-XXXX", persiste em "calculadora_simples.registros" e retorna HTTP 201
```

### US-003 — Conclusão em 1 Clique, Mudança de Status e Exclusão Auditada
```gherkin
Funcionalidade: Ciclo de Vida de Cálculo Institucional
  Cenário: Atualização de status ou conclusão rápida diretamente na listagem
    Dado um registro existente exibido na visão Tabela ou Cards
    Quando o operador alterna o status ou marca o item como concluído (PATCH /api/items/:id)
    Então o estado é gravado imediatamente no Cloud SQL PostgreSQL e os KPIs do topo são recalculados
```

## 4. Especificação de Telas e Componentes Frontend (React 18 + TypeScript + Vite)

- **Faixa Institucional Fixa**: Banner superior `"Ambiente Governado DTI (detran-gemini)"` persistente em todas as visualizações.
- **Cabeçalho Executivo**: Título `Calculadora Simples Administrativa`, badge do schema `calculadora_simples`, status da conexão PostgreSQL e botão primário **"+ Novo(a) Cálculo Institucional"**.
- **Faixa de 4 KPIs**: Total de Cálculos Institucionais, Pendentes, Em Andamento e Concluídos (com destaque para itens de Alta Prioridade).
- **Barra de Filtros e Visualização**: Busca instantânea, pílulas de status, seletores de prioridade/categoria e alternância entre **Tabela** e **Cards**.

### Campos Específicos do Domínio (`detalhes` JSONB)

| Chave | Rótulo na UI | Tipo | Obrigatório |
|---|---|---|---|
| `expressao_aritmetica` | Expressão / Operação | `text` | Sim |
| `resultado_apurado` | Resultado Apurado | `text` | Sim |
| `processo_sei` | Processo SEI Vinculado | `text` | Sim |
| `justificativa_operacao` | Justificativa da Memória | `textarea` | Não |
| `complemento_evolucao` | Complemento Operacional | `textarea` | Não |
| `origem_calculo` | Origem do Lançamento | `select` | Não |
| `timestamp_execucao` | Data/Hora do Registro | `text` | Não |

## 5. Contrato de Endpoints REST da API (Node.js 22 + Cloud Run v2)

| Método & Rota | Finalidade | Resposta Principal |
|---|---|---|
| `GET /api/health` · `GET /api/status` | Saúde do container, modo `postgresql`, database `db_calculadora_simples` e schema `calculadora_simples` | `200 OK` |
| `GET /api/spec` | Contrato completo de UI, status, categorias e campos customizados | `200 OK` |
| `GET /api/items` | Lista filtrada (`?q=&status=&prioridade=&categoria=`) + objeto `kpis` | `200 OK` |
| `POST /api/items` | Valida e insere novo registro em `calculadora_simples.registros` | `201 Created` |
| `PATCH /api/items/:id` | Atualiza status, flag `concluido` ou campos do registro | `200 OK` |
| `DELETE /api/items/:id` | Remove registro por UUID | `200 OK` |

## 6. Esquema PostgreSQL & Massa Inicial (`seed` de 7 registros)

Tabela `calculadora_simples.registros` inicializada automaticamente no boot da API via `sql/001_init_and_seed.sql`:

| Protocolo | Título Inicial | Status | Prioridade | Categoria | Responsável |
|---|---|---|---|---|---|
| `CALC-1001` | Rateio de Diárias da Operação Interior Seguro | `CONSOLIDADO` | `ALTA` | Diárias e Deslocamentos | Núcleo de Apoio Administrativo |
| `CALC-1002` | Diferencial de Taxa de Vistoria Reprovada | `EM_VALIDACAO` | `MEDIA` | Tarifas e Emolumentos | Supervisão de Veículos |
| `CALC-1003` | Contagem de Dias Corridos para Defesa Prévia | `RASCUNHO` | `BAIXA` | Prazos Processuais e Recursos | 1ª Junta JARI |
| `CALC-1004` | Saldo Residual de Bobinas de CNH | `CONSOLIDADO` | `MEDIA` | Apurador de Estoque e Suprimentos | Coordenação de Logística e Materiais |
| `CALC-1005` | Ajuste Contábil de Repasse a Municípios Conveniados | `EM_VALIDACAO` | `ALTA` | Ajuste de Arrecadação | Gerência Financeira |
| `CALC-1006` | Cálculo de Desconto em Folha por Hora Não Cumprida | `CONSOLIDADO` | `BAIXA` | Tarifas e Emolumentos | Diretoria de Recursos Humanos |
| `CALC-1007` | Entrega Incremental #7 — Complemento Operacional | `ARQUIVADO` | `ALTA` | Diárias e Deslocamentos | Coordenação de Arquitetura DTI |

## 7. Parâmetros de Governança no Sandbox (`detran-gemini`)

- **Orçamento Máximo (`budget_brl`)**: R$ 150.00
- **Tempo de Vida (`ttl`)**: `1h` (contado após validação do certificado HTTPS gerenciado)
- **Canais de Alerta SRE (`alert_emails`)**: `definido no manifesto de aprovação`