# PRD — `todo-mobile` (Gestor de Tarefas Operacionais Mobile)

## 1. Visão do Produto & Contexto de Negócio

- **Aplicação**: **Gestor de Tarefas Operacionais Mobile** (`todo-mobile`)
- **Subtítulo Funcional**: Controle ágil de pendências e rotinas de fiscalização e atendimento DETRAN-SP
- **Demanda / Justificativa**: App To-Do Mobile responsivo acessível via smartphone com banco PostgreSQL (schema todo_mobile), API REST em Node.js (NestJS + Prisma) e frontend React 18 Mobile-First, com criação, atualização, conclusão e exclusão de tarefas operacionais, busca, filtros de status e prioridade, e 4 KPIs no topo.
- **Entidade Principal de Domínio**: `Tarefa` / `Tarefas`
- **Isolamento de Dados**: Cloud SQL PostgreSQL compartilhado (`detran-shared-pgsql`), database `db_todo_mobile`, schema exclusivo `todo_mobile` (zero uso de `public`).

## 2. Regras de Negócio Numeradas

- **RN-001**: Schema PostgreSQL isolado em todo_mobile gerenciado via Prisma ORM.
- **RN-002**: Endpoints RESTful: GET /tarefas com paginação mobile, filtros por status, prioridade e busca textual.
- **RN-003**: POST /tarefas com validação estrita DTO via class-validator e prefixo sequencial protocol_prefix.
- **RN-004**: PATCH /tarefas/:id/status para alternância rápida de status e toggle de conclusão direto na interface mobile.
- **RN-005**: Cálculo agregado de 4 KPIs: Total de Tarefas, Pendentes Críticas, Em Andamento e Taxa de Conclusão Diária.
- **RN-006 [LGPD & GOVERNANÇA]**: Nenhum dado pessoal sensível sem mascaramento em telas ou logs; autenticação e borda protegidas por GCLB HTTPS + Cloud Armor WAF.

## 3. Histórias de Usuário em Formato Gherkin (INVEST)

### US-001 — Consulta Operacional com Indicadores em Tempo Real e Filtros
```gherkin
Funcionalidade: Painel de Gestão de Tarefas
  Cenário: Carregamento inicial da tela com indicadores e registros do PostgreSQL
    Dado que o operador acessa o portal "Gestor de Tarefas Operacionais Mobile" via HTTPS (.nip.io)
    Quando a aplicação consulta GET /api/items e GET /api/status na mesma origem
    Então a interface exibe os 4 indicadores KPI consolidados e os 6 registros iniciais do schema "todo_mobile"
    E permite filtrar por busca textual, status (`PENDENTE` (Pendente), `EM_ANDAMENTO` (Em Andamento), `BLOQUEADO` (Bloqueado), `CONCLUIDA` (Concluída)), prioridade e categoria
```

### US-002 — Cadastro Validado de Tarefa com Persistência PostgreSQL
```gherkin
Funcionalidade: Criação de Tarefa
  Cenário: Submissão válida pelo formulário modal da aplicação
    Dado que o operador clica em "+ Novo(a) Tarefa" e preenche os campos de domínio
    Quando envia POST /api/items com título, categoria, prioridade e metadados estruturados
    Então a API valida as invariantes de negócio, gera protocolo "TARDE-XXXX", persiste em "todo_mobile.registros" e retorna HTTP 201
```

### US-003 — Conclusão em 1 Clique, Mudança de Status e Exclusão Auditada
```gherkin
Funcionalidade: Ciclo de Vida de Tarefa
  Cenário: Atualização de status ou conclusão rápida diretamente na listagem
    Dado um registro existente exibido na visão Tabela ou Cards
    Quando o operador alterna o status ou marca o item como concluído (PATCH /api/items/:id)
    Então o estado é gravado imediatamente no Cloud SQL PostgreSQL e os KPIs do topo são recalculados
```

## 4. Especificação de Telas e Componentes Frontend (React 18 + TypeScript + Vite)

- **Faixa Institucional Fixa**: Banner superior `"Ambiente Governado DTI (detran-gemini)"` persistente em todas as visualizações.
- **Cabeçalho Executivo**: Título `Gestor de Tarefas Operacionais Mobile`, badge do schema `todo_mobile`, status da conexão PostgreSQL e botão primário **"+ Novo(a) Tarefa"**.
- **Faixa de 4 KPIs**: Total de Tarefas, Pendentes, Em Andamento e Concluídos (com destaque para itens de Alta Prioridade).
- **Barra de Filtros e Visualização**: Busca instantânea, pílulas de status, seletores de prioridade/categoria e alternância entre **Tabela** e **Cards**.

### Campos Específicos do Domínio (`detalhes` JSONB)

| Chave | Rótulo na UI | Tipo | Obrigatório |
|---|---|---|---|
| `unidade_lotacao` | Unidade / Posto | `select` | Sim |
| `dispositivo_coleta` | Origem do Registro Mobile | `select` | Sim |
| `observacao_campo` | Anotações Operacionais de Campo | `textarea` | Não |

## 5. Contrato de Endpoints REST da API (Node.js 22 + Cloud Run v2)

| Método & Rota | Finalidade | Resposta Principal |
|---|---|---|
| `GET /api/health` · `GET /api/status` | Saúde do container, modo `postgresql`, database `db_todo_mobile` e schema `todo_mobile` | `200 OK` |
| `GET /api/spec` | Contrato completo de UI, status, categorias e campos customizados | `200 OK` |
| `GET /api/items` | Lista filtrada (`?q=&status=&prioridade=&categoria=`) + objeto `kpis` | `200 OK` |
| `POST /api/items` | Valida e insere novo registro em `todo_mobile.registros` | `201 Created` |
| `PATCH /api/items/:id` | Atualiza status, flag `concluido` ou campos do registro | `200 OK` |
| `DELETE /api/items/:id` | Remove registro por UUID | `200 OK` |

## 6. Esquema PostgreSQL & Massa Inicial (`seed` de 6 registros)

Tabela `todo_mobile.registros` inicializada automaticamente no boot da API via `sql/001_init_and_seed.sql`:

| Protocolo | Título Inicial | Status | Prioridade | Categoria | Responsável |
|---|---|---|---|---|---|
| `TARDE-1001` | Sincronização de talões eletrônicos de fiscalização | `EM_ANDAMENTO` | `ALTA` | Fiscalização de Trânsito | Equipe de Fiscalização Noturna |
| `TARDE-1002` | Auditoria de biometria facial para renovação de CNH | `PENDENTE` | `ALTA` | Processamento de CNH | Núcleo de Habilitação Regional |
| `TARDE-1003` | Calibração dos leitores de OCR para vistoria móvel | `CONCLUIDA` | `MEDIA` | Vistoria Veicular | Supervisão Técnica de Vistorias |
| `TARDE-1004` | Substituição emergencial de bobinas de senha rápida | `CONCLUIDA` | `BAIXA` | Atendimento ao Cidadão | Apoio Operacional de Triagem |
| `TARDE-1005` | Verificação de conectividade do gateway de pagamentos PIX | `BLOQUEADO` | `ALTA` | Suporte Operacional DTI | Plantão de Infraestrutura DTI |
| `TARDE-1006` | Revalidação de formulários de vistoria de transferência | `PENDENTE` | `MEDIA` | Vistoria Veicular | Equipe de Fiscalização Noturna |

## 7. Parâmetros de Governança no Sandbox (`detran-gemini`)

- **Orçamento Máximo (`budget_brl`)**: R$ 150.00
- **Tempo de Vida (`ttl`)**: `1h` (contado após validação do certificado HTTPS gerenciado)
- **Canais de Alerta SRE (`alert_emails`)**: `definido no manifesto de aprovação`