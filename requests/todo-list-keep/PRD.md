# PRD — `todo-list-keep` (Gestão de Tarefas e Entregas DTI)

## 1. Visão do Produto & Contexto de Negócio

- **Aplicação**: **Gestão de Tarefas e Entregas DTI** (`todo-list-keep`)
- **Subtítulo Funcional**: Planejamento operacional, acompanhamento de entregas técnicas, prioridades e metas de governança digital DETRAN-SP
- **Demanda / Justificativa**: Keep Tarefas e Kanban (todo-list-keep): lista de tarefas simples inspirada no Google Keep com funcionalidade de post-it (notas adesivas coloridas com cor_fundo Amarelo/Azul/Verde/Rosa/Lilás/Branco, fixar nota/pin Sim/Não, conteúdo da nota e marcadores/etiquetas) e visualização em quadro Kanban por colunas de status (PENDENTE, EM_ANDAMENTO, CONCLUIDA, ARQUIVADA) com movimentação de cartões entre colunas, além de grade de post-its e tabela, 4 KPIs em tempo real, busca textual, filtros por status/categoria/prioridade e sincronização automática de concluido=true quando status=CONCLUIDA. Persistência em PostgreSQL schema todo_list_keep.
- **Entidade Principal de Domínio**: `Tarefa` / `Tarefas`
- **Isolamento de Dados**: Cloud SQL PostgreSQL compartilhado (`detran-shared-pgsql`), database `db_todo_list_keep`, schema exclusivo `todo_list_keep` (zero uso de `public`).

## 2. Regras de Negócio Numeradas

- **RN-001**: Título obrigatório (mínimo de 3 caracteres) e sanitização server-side contra payloads inválidos.
- **RN-002**: Sincronização automática entre o flag booleano 'concluido' e o status 'CONCLUIDA'.
- **RN-003**: Persistência transacional isolada na tabela 'todo_list_keep.registros' (Cloud SQL PostgreSQL).
- **RN-004**: Cálculo em tempo real dos 4 indicadores KPI (Total, Pendentes, Em Andamento e Concluídas).
- **RN-005 [LGPD & GOVERNANÇA]**: Nenhum dado pessoal sensível sem mascaramento em telas ou logs; autenticação e borda protegidas por GCLB HTTPS + Cloud Armor WAF.

## 3. Histórias de Usuário em Formato Gherkin (INVEST)

### US-001 — Consulta Operacional com Indicadores em Tempo Real e Filtros
```gherkin
Funcionalidade: Painel de Gestão de Tarefas
  Cenário: Carregamento inicial da tela com indicadores e registros do PostgreSQL
    Dado que o operador acessa o portal "Gestão de Tarefas e Entregas DTI" via HTTPS (.nip.io)
    Quando a aplicação consulta GET /api/items e GET /api/status na mesma origem
    Então a interface exibe os 4 indicadores KPI consolidados e os 6 registros iniciais do schema "todo_list_keep"
    E permite filtrar por busca textual, status (`PENDENTE` (Pendente), `EM_ANDAMENTO` (Em Andamento), `EM_REVISAO` (Em Revisão), `CONCLUIDA` (Concluída)), prioridade e categoria
```

### US-002 — Cadastro Validado de Tarefa com Persistência PostgreSQL
```gherkin
Funcionalidade: Criação de Tarefa
  Cenário: Submissão válida pelo formulário modal da aplicação
    Dado que o operador clica em "+ Novo(a) Tarefa" e preenche os campos de domínio
    Quando envia POST /api/items com título, categoria, prioridade e metadados estruturados
    Então a API valida as invariantes de negócio, gera protocolo "TAR-XXXX", persiste em "todo_list_keep.registros" e retorna HTTP 201
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
- **Cabeçalho Executivo**: Título `Gestão de Tarefas e Entregas DTI`, badge do schema `todo_list_keep`, status da conexão PostgreSQL e botão primário **"+ Novo(a) Tarefa"**.
- **Faixa de 4 KPIs**: Total de Tarefas, Pendentes, Em Andamento e Concluídos (com destaque para itens de Alta Prioridade).
- **Barra de Filtros e Visualização**: Busca instantânea, pílulas de status, seletores de prioridade/categoria e alternância entre **Tabela** e **Cards**.

### Campos Específicos do Domínio (`detalhes` JSONB)

| Chave | Rótulo na UI | Tipo | Obrigatório |
|---|---|---|---|
| `area_solicitante` | Área Solicitante | `select` | Sim |
| `estimativa_horas` | Estimativa (horas) | `text` | Não |
| `criterio_aceite` | Critério de Aceite / Escopo | `textarea` | Sim |

## 5. Contrato de Endpoints REST da API (Node.js 22 + Cloud Run v2)

| Método & Rota | Finalidade | Resposta Principal |
|---|---|---|
| `GET /api/health` · `GET /api/status` | Saúde do container, modo `postgresql`, database `db_todo_list_keep` e schema `todo_list_keep` | `200 OK` |
| `GET /api/spec` | Contrato completo de UI, status, categorias e campos customizados | `200 OK` |
| `GET /api/items` | Lista filtrada (`?q=&status=&prioridade=&categoria=`) + objeto `kpis` | `200 OK` |
| `POST /api/items` | Valida e insere novo registro em `todo_list_keep.registros` | `201 Created` |
| `PATCH /api/items/:id` | Atualiza status, flag `concluido` ou campos do registro | `200 OK` |
| `DELETE /api/items/:id` | Remove registro por UUID | `200 OK` |

## 6. Esquema PostgreSQL & Massa Inicial (`seed` de 6 registros)

Tabela `todo_list_keep.registros` inicializada automaticamente no boot da API via `sql/001_init_and_seed.sql`:

| Protocolo | Título Inicial | Status | Prioridade | Categoria | Responsável |
|---|---|---|---|---|---|
| `TAR-1001` | Revisar regras OWASP CRS no Cloud Armor do ambiente sandbox | `CONCLUIDA` | `ALTA` | Segurança & LGPD | Segurança da Informação |
| `TAR-1002` | Validar painel de SLOs de disponibilidade (99,5%) e latência P95 | `EM_ANDAMENTO` | `ALTA` | Governança FinOps | Equipe SRE DTI |
| `TAR-1003` | Homologar isolamento de schemas dedicados no banco compartilhado | `EM_ANDAMENTO` | `ALTA` | Backend & Banco | Coordenação de Arquitetura DTI |
| `TAR-1004` | Padronizar acessibilidade e contraste nos formulários responsivos | `EM_REVISAO` | `MEDIA` | Frontend & UX | Fábrica de Software DTI |
| `TAR-1005` | Documentar contrato OpenAPI e exemplos de integração assíncrona Pub/Sub | `PENDENTE` | `MEDIA` | Arquitetura Cloud | Coordenação de Arquitetura DTI |
| `TAR-1006` | Auditar rotina de descomissionamento automático por expiração de TTL | `PENDENTE` | `BAIXA` | Governança FinOps | Governança FinOps |

## 7. Parâmetros de Governança no Sandbox (`detran-gemini`)

- **Orçamento Máximo (`budget_brl`)**: R$ 150.00
- **Tempo de Vida (`ttl`)**: `1h` (contado após validação do certificado HTTPS gerenciado)
- **Canais de Alerta SRE (`alert_emails`)**: `definido no manifesto de aprovação`