# PRD — `todo-list-app` (Gestão de Tarefas e Demandas Operacionais)

## 1. Visão do Produto & Contexto de Negócio

- **Aplicação**: **Gestão de Tarefas e Demandas Operacionais** (`todo-list-app`)
- **Subtítulo Funcional**: Painel Integrado de Controle de Atividades e Prazos Administrativos DETRAN-SP
- **Demanda / Justificativa**: App corporativo de gestão de tarefas e demandas operacionais DETRAN-SP.
Telas: Painel com 4 KPIs, filtros de status (Pendente, Em Andamento, Em Revisão, Concluída), prioridades (Alta, Média, Baixa), categorias temáticas DETRAN-SP, busca textual e alternância Tabela/Cards.
API REST: NestJS com Prisma ORM, endpoints /api/items, /api/spec, /api/health, /api/status.
Persistência: Cloud SQL PostgreSQL 16 com schema dedicado 'todo_list_app'.
Segurança: Zero-Trust, Anti-IDOR, validação rigorosa de DTOs, CSP estrito, sem uso de localStorage.
- **Entidade Principal de Domínio**: `Demanda Operacional` / `Demandas Operacionais`
- **Isolamento de Dados**: Cloud SQL PostgreSQL compartilhado (`detran-shared-pgsql`), database `db_todo_list_app`, schema exclusivo `todo_list_app` (zero uso de `public`).

## 2. Regras de Negócio Numeradas

- **RN-001**: Autenticação obrigatória via JWT institucional integrada ao schema 'todo_list_app'.
- **RN-002**: Isolamento multi-tenant lógico e controle anti-IDOR garantindo que operadores acessem apenas tarefas autorizadas pela unidade organizacional.
- **RN-003**: Persistência transacional exclusiva no schema PostgreSQL 'todo_list_app' com auditoria append-only para todas as mutações.
- **RN-004**: Validação estrita de DTOs no NestJS com Pipes globais rejeitando propriedades desconhecidas.
- **RN-005**: Imutabilidade de protocolos gerados sequencialmente com prefixo TSK-DETRAN.
- **RN-006**: Evolução incremental Day-2 preservando schema 'todo_list_app' e registros ativos: campos adicionados (Todo_list_app, Nível de Acesso à Informação).
- **RN-007 [LGPD & GOVERNANÇA]**: Nenhum dado pessoal sensível sem mascaramento em telas ou logs; autenticação e borda protegidas por GCLB HTTPS + Cloud Armor WAF.

## 3. Histórias de Usuário em Formato Gherkin (INVEST)

### US-001 — Consulta Operacional com Indicadores em Tempo Real e Filtros
```gherkin
Funcionalidade: Painel de Gestão de Demandas Operacionais
  Cenário: Carregamento inicial da tela com indicadores e registros do PostgreSQL
    Dado que o operador acessa o portal "Gestão de Tarefas e Demandas Operacionais" via HTTPS (.nip.io)
    Quando a aplicação consulta GET /api/items e GET /api/status na mesma origem
    Então a interface exibe os 4 indicadores KPI consolidados e os 7 registros iniciais do schema "todo_list_app"
    E permite filtrar por busca textual, status (`PENDENTE` (Pendente), `EM_ANDAMENTO` (Em Andamento), `EM_REVISAO` (Em Revisão Técnica), `CONCLUIDA` (Concluída)), prioridade e categoria
```

### US-002 — Cadastro Validado de Demanda Operacional com Persistência PostgreSQL
```gherkin
Funcionalidade: Criação de Demanda Operacional
  Cenário: Submissão válida pelo formulário modal da aplicação
    Dado que o operador clica em "+ Novo(a) Demanda Operacional" e preenche os campos de domínio
    Quando envia POST /api/items com título, categoria, prioridade e metadados estruturados
    Então a API valida as invariantes de negócio, gera protocolo "TSKDE-XXXX", persiste em "todo_list_app.registros" e retorna HTTP 201
```

### US-003 — Conclusão em 1 Clique, Mudança de Status e Exclusão Auditada
```gherkin
Funcionalidade: Ciclo de Vida de Demanda Operacional
  Cenário: Atualização de status ou conclusão rápida diretamente na listagem
    Dado um registro existente exibido na visão Tabela ou Cards
    Quando o operador alterna o status ou marca o item como concluído (PATCH /api/items/:id)
    Então o estado é gravado imediatamente no Cloud SQL PostgreSQL e os KPIs do topo são recalculados
```

## 4. Especificação de Telas e Componentes Frontend (React 18 + TypeScript + Vite)

- **Faixa Institucional Fixa**: Banner superior `"Ambiente Governado DTI (detran-gemini)"` persistente em todas as visualizações.
- **Cabeçalho Executivo**: Título `Gestão de Tarefas e Demandas Operacionais`, badge do schema `todo_list_app`, status da conexão PostgreSQL e botão primário **"+ Novo(a) Demanda Operacional"**.
- **Faixa de 4 KPIs**: Total de Demandas Operacionais, Pendentes, Em Andamento e Concluídos (com destaque para itens de Alta Prioridade).
- **Barra de Filtros e Visualização**: Busca instantânea, pílulas de status, seletores de prioridade/categoria e alternância entre **Tabela** e **Cards**.

### Campos Específicos do Domínio (`detalhes` JSONB)

| Chave | Rótulo na UI | Tipo | Obrigatório |
|---|---|---|---|
| `processo_sei` | Número do Processo SEI | `text` | Sim |
| `unidade_lotacao` | Unidade de Lotação / Posto | `select` | Sim |
| `despacho_instrucao` | Despacho ou Instrução Normativa | `textarea` | Não |
| `data_conferencia` | Data Limite de Conferência | `date` | Sim |
| `todo_list_app` | Todo_list_app | `text` | Não |
| `nivel_sigilo` | Nível de Acesso à Informação | `select` | Sim |

## 5. Contrato de Endpoints REST da API (Node.js 22 + Cloud Run v2)

| Método & Rota | Finalidade | Resposta Principal |
|---|---|---|
| `GET /api/health` · `GET /api/status` | Saúde do container, modo `postgresql`, database `db_todo_list_app` e schema `todo_list_app` | `200 OK` |
| `GET /api/spec` | Contrato completo de UI, status, categorias e campos customizados | `200 OK` |
| `GET /api/items` | Lista filtrada (`?q=&status=&prioridade=&categoria=`) + objeto `kpis` | `200 OK` |
| `POST /api/items` | Valida e insere novo registro em `todo_list_app.registros` | `201 Created` |
| `PATCH /api/items/:id` | Atualiza status, flag `concluido` ou campos do registro | `200 OK` |
| `DELETE /api/items/:id` | Remove registro por UUID | `200 OK` |

## 6. Esquema PostgreSQL & Massa Inicial (`seed` de 7 registros)

Tabela `todo_list_app.registros` inicializada automaticamente no boot da API via `sql/001_init_and_seed.sql`:

| Protocolo | Título Inicial | Status | Prioridade | Categoria | Responsável |
|---|---|---|---|---|---|
| `TSKDE-1001` | Auditoria de Lotes de Renovação CNH - Período Especial | `EM_ANDAMENTO` | `ALTA` | Habilitação e Condutores | Núcleo de Exames de Trânsito |
| `TSKDE-1002` | Saneamento de Inconsistências no Renavam de Frota Oficial | `PENDENTE` | `MEDIA` | Registro e Licenciamento Veicular | Equipe Técnica de Cadastro Veicular |
| `TSKDE-1003` | Julgamento de Recursos de Suspensão de CNH - Pauta 42 | `EM_REVISAO` | `ALTA` | Infrações e Recursos JARI | 1ª Junta JARI |
| `TSKDE-1004` | Calibração dos Radares Móveis de Fiscalização Integrada | `CONCLUIDA` | `ALTA` | Fiscalização de Trânsito | Equipe de Fiscalização |
| `TSKDE-1005` | Atualização das Tabelas de Taxas de Emplacamento 2025 | `CONCLUIDA` | `MEDIA` | Sistemas e Tecnologia DTI | Coordenação DTI |
| `TSKDE-1006` | Digitalização e Triagem de Prontuários Históricos | `PENDENTE` | `BAIXA` | Habilitação e Condutores | Serviço de Protocolo e Arquivo |
| `TSKDE-1007` | Entrega Incremental #7 — Todo_list_app | `EM_REVISAO` | `ALTA` | Habilitação e Condutores | Coordenação de Arquitetura DTI |

## 7. Parâmetros de Governança no Sandbox (`detran-gemini`)

- **Orçamento Máximo (`budget_brl`)**: R$ 150.00
- **Tempo de Vida (`ttl`)**: `1h` (contado após validação do certificado HTTPS gerenciado)
- **Canais de Alerta SRE (`alert_emails`)**: `definido no manifesto de aprovação`