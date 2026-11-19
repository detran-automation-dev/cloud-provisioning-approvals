# PRD — `todo-list-app` (Gestor de Tarefas Operacionais DETRAN-SP)

## 1. Visão do Produto & Contexto de Negócio

- **Aplicação**: **Gestor de Tarefas Operacionais DETRAN-SP** (`todo-list-app`)
- **Subtítulo Funcional**: Gestão e controle de produtividade das demandas operacionais e tecnológicas da DTI.
- **Demanda / Justificativa**: Gestor de Tarefas e Produtividade Operacional padrão de mercado. Painel com 4 KPIs, busca, filtros de status (A Iniciar, Em Andamento, Em Revisão, Concluída), prioridades (Alta, Média, Baixa), categorias, alternância Tabela/Cards, ações em 1 clique (concluir, editar, excluir). Endpoints REST /api/items, /api/status, /api/spec. Banco Cloud SQL PostgreSQL 16 schema dedicado 'todo_list_app'. 6 registros iniciais de seed na UI.
- **Entidade Principal de Domínio**: `Tarefa` / `Tarefas`
- **Isolamento de Dados**: Cloud SQL PostgreSQL compartilhado (`detran-shared-pgsql`), database `db_todo_list_app`, schema exclusivo `todo_list_app` (zero uso de `public`).

## 2. Regras de Negócio Numeradas

- **RN-001**: GET /api/items: Retorna listagem com paginação, ordenação e filtros de status, categoria, prioridade e busca textual.
- **RN-002**: POST /api/items: Cria nova tarefa com identificador protocolar sequencial gerado automaticamente no padrão TSK-YYYY-XXXX.
- **RN-003**: PUT /api/items/:id: Atualiza informações cadastrais e atributos específicos da tarefa no schema todo_list_app.
- **RN-004**: PATCH /api/items/:id/concluir: Altera status de conclusão em 1 clique mantendo registro de auditoria do servidor.
- **RN-005**: DELETE /api/items/:id: Exclusão lógica com controle de consistência referencial no Cloud SQL PostgreSQL 16.
- **RN-006 [LGPD & GOVERNANÇA]**: Nenhum dado pessoal sensível sem mascaramento em telas ou logs; autenticação e borda protegidas por GCLB HTTPS + Cloud Armor WAF.

## 3. Histórias de Usuário em Formato Gherkin (INVEST)

### US-001 — Consulta Operacional com Indicadores em Tempo Real e Filtros
```gherkin
Funcionalidade: Painel de Gestão de Tarefas
  Cenário: Carregamento inicial da tela com indicadores e registros do PostgreSQL
    Dado que o operador acessa o portal "Gestor de Tarefas Operacionais DETRAN-SP" via HTTPS (.nip.io)
    Quando a aplicação consulta GET /api/items e GET /api/status na mesma origem
    Então a interface exibe os 4 indicadores KPI consolidados e os 6 registros iniciais do schema "todo_list_app"
    E permite filtrar por busca textual, status (`A_INICIAR` (A Iniciar), `EM_ANDAMENTO` (Em Andamento), `EM_REVISAO` (Em Revisão), `CONCLUIDA` (Concluída)), prioridade e categoria
```

### US-002 — Cadastro Validado de Tarefa com Persistência PostgreSQL
```gherkin
Funcionalidade: Criação de Tarefa
  Cenário: Submissão válida pelo formulário modal da aplicação
    Dado que o operador clica em "+ Novo(a) Tarefa" e preenche os campos de domínio
    Quando envia POST /api/items com título, categoria, prioridade e metadados estruturados
    Então a API valida as invariantes de negócio, gera protocolo "TSK-XXXX", persiste em "todo_list_app.registros" e retorna HTTP 201
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
- **Cabeçalho Executivo**: Título `Gestor de Tarefas Operacionais DETRAN-SP`, badge do schema `todo_list_app`, status da conexão PostgreSQL e botão primário **"+ Novo(a) Tarefa"**.
- **Faixa de 4 KPIs**: Total de Tarefas, Pendentes, Em Andamento e Concluídos (com destaque para itens de Alta Prioridade).
- **Barra de Filtros e Visualização**: Busca instantânea, pílulas de status, seletores de prioridade/categoria e alternância entre **Tabela** e **Cards**.

### Campos Específicos do Domínio (`detalhes` JSONB)

| Chave | Rótulo na UI | Tipo | Obrigatório |
|---|---|---|---|
| `sistema_impactado` | Sistema Impactado | `select` | Sim |
| `impacto_operacional` | Impacto Operacional | `select` | Não |
| `data_homologacao` | Previsão de Homologação | `date` | Não |
| `observacoes_tecnicas` | Observações Técnicas | `textarea` | Não |

## 5. Contrato de Endpoints REST da API (Node.js 22 + Cloud Run v2)

| Método & Rota | Finalidade | Resposta Principal |
|---|---|---|
| `GET /api/health` · `GET /api/status` | Saúde do container, modo `postgresql`, database `db_todo_list_app` e schema `todo_list_app` | `200 OK` |
| `GET /api/spec` | Contrato completo de UI, status, categorias e campos customizados | `200 OK` |
| `GET /api/items` | Lista filtrada (`?q=&status=&prioridade=&categoria=`) + objeto `kpis` | `200 OK` |
| `POST /api/items` | Valida e insere novo registro em `todo_list_app.registros` | `201 Created` |
| `PATCH /api/items/:id` | Atualiza status, flag `concluido` ou campos do registro | `200 OK` |
| `DELETE /api/items/:id` | Remove registro por UUID | `200 OK` |

## 6. Esquema PostgreSQL & Massa Inicial (`seed` de 6 registros)

Tabela `todo_list_app.registros` inicializada automaticamente no boot da API via `sql/001_init_and_seed.sql`:

| Protocolo | Título Inicial | Status | Prioridade | Categoria | Responsável |
|---|---|---|---|---|---|
| `TSK-1001` | Renovação dos certificados digitais do portal de autenticação e-CNHsp | `CONCLUIDA` | `ALTA` | Segurança da Informação | Equipe de Segurança da Informação |
| `TSK-1002` | Mapeamento dos gargalos de fila na integração Poupatempo | `EM_ANDAMENTO` | `ALTA` | Atendimento e Processos | Coordenação de Atendimento Integrado |
| `TSK-1003` | Auditoria e parametrização de permissões de acesso ao SIAV | `EM_REVISAO` | `ALTA` | Sistemas e Sustentação | Gerência de Sustentação de Sistemas |
| `TSK-1004` | Adequação dos relatórios gerenciais de produtividade DTI | `A_INICIAR` | `MEDIA` | Governança e Projetos | Escritório de Processos e Governança |
| `TSK-1005` | Implementação do plano de contingência para switches de borda | `CONCLUIDA` | `MEDIA` | Infraestrutura e Redes | Núcleo de Redes e Infraestrutura DTI |
| `TSK-1006` | Otimização de índices nos módulos de consulta de multas e pontuação | `EM_ANDAMENTO` | `BAIXA` | Sistemas e Sustentação | Equipe de Banco de Dados DTI |

## 7. Parâmetros de Governança no Sandbox (`detran-gemini`)

- **Orçamento Máximo (`budget_brl`)**: R$ 150.00
- **Tempo de Vida (`ttl`)**: `1h` (contado após validação do certificado HTTPS gerenciado)
- **Canais de Alerta SRE (`alert_emails`)**: `definido no manifesto de aprovação`