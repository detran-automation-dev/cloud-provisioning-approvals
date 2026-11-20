# PRD — `cadastro-veiculos-crlv` (Gestão de Veículos e Emissão de CRLV-e)

## 1. Visão do Produto & Contexto de Negócio

- **Aplicação**: **Gestão de Veículos e Emissão de CRLV-e** (`cadastro-veiculos-crlv`)
- **Subtítulo Funcional**: Controle cadastral, vistorias e regularização de licenciamento veicular.
- **Demanda / Justificativa**: CADASTRO DE VEÍCULOS CRLV-e COM CAMPOS SEPARADOS E TELA PRINCIPAL RESTRITA: 1. CAMPOS DEDICADOS E SEPARADOS NO FORMULÁRIO E BANCO: Placa (campo próprio), Código RENAVAM (campo próprio separado de 11 dígitos), Marca (campo próprio), Modelo (campo próprio), Chassi VIN (campo próprio), Combustível (select próprio) e Restrições Administrativas. 2. TELA PRINCIPAL (TABELA E CARDS): Listar ESTRITAMENTE Placa, Marca e Modelo como colunas/identificadores visíveis na tabela principal, acompanhados de Status Badge e Ações rápidas. Os demais campos (Renavam, Chassi, Combustível, Restrições) ficam acessíveis exclusivamente dentro do Modal de Detalhes e Edição. 3. BANCO POSTGRESQL: Cloud SQL schema cadastro_veiculos_crlv com migração aditiva sql/002_evolution_delta.sql preservando registros existentes.
- **Entidade Principal de Domínio**: `Veículo` / `Veículos`
- **Isolamento de Dados**: Cloud SQL PostgreSQL compartilhado (`detran-shared-pgsql`), database `db_cadastro_veiculos_crlv`, schema exclusivo `cadastro_veiculos_crlv` (zero uso de `public`).

## 2. Regras de Negócio Numeradas

- **RN-001**: Módulo NestJS integrado ao Prisma com schema cadastro_veiculos_crlv e chave primária UUID.
- **RN-002**: Validação rígida de formato de placa Mercosul (3 letras, 1 número, 1 letra, 2 números) e RENAVAM de 11 dígitos.
- **RN-003**: Transição para status REGULARIZADO exige ausência de impedimentos e vistoria veicular aprovada.
- **RN-004**: Endpoints REST autenticados com controle RBAC específico para o perfil servidor_interno.
- **RN-005**: Evolução incremental Day-2 preservando schema 'cadastro_veiculos_crlv' e registros ativos: campos adicionados (Cadastro_veiculos_crlv).
- **RN-006**: Evolução incremental Day-2 preservando schema 'cadastro_veiculos_crlv' e registros ativos: campos adicionados (Próprio, Próprio separado de 11 dígitos).
- **RN-007 [LGPD & GOVERNANÇA]**: Nenhum dado pessoal sensível sem mascaramento em telas ou logs; autenticação e borda protegidas por GCLB HTTPS + Cloud Armor WAF.

## 3. Histórias de Usuário em Formato Gherkin (INVEST)

### US-001 — Consulta Operacional com Indicadores em Tempo Real e Filtros
```gherkin
Funcionalidade: Painel de Gestão de Veículos
  Cenário: Carregamento inicial da tela com indicadores e registros do PostgreSQL
    Dado que o operador acessa o portal "Gestão de Veículos e Emissão de CRLV-e" via HTTPS (.nip.io)
    Quando a aplicação consulta GET /api/items e GET /api/status na mesma origem
    Então a interface exibe os 4 indicadores KPI consolidados e os 8 registros iniciais do schema "cadastro_veiculos_crlv"
    E permite filtrar por busca textual, status (`EM_ANALISE` (Em Análise Documental), `PENDENTE_VISTORIA` (Pendente de Vistoria), `REGULARIZADO` (Regularizado)), prioridade e categoria
```

### US-002 — Cadastro Validado de Veículo com Persistência PostgreSQL
```gherkin
Funcionalidade: Criação de Veículo
  Cenário: Submissão válida pelo formulário modal da aplicação
    Dado que o operador clica em "+ Novo(a) Veículo" e preenche os campos de domínio
    Quando envia POST /api/items com título, categoria, prioridade e metadados estruturados
    Então a API valida as invariantes de negócio, gera protocolo "CRLVS-XXXX", persiste em "cadastro_veiculos_crlv.registros" e retorna HTTP 201
```

### US-003 — Conclusão em 1 Clique, Mudança de Status e Exclusão Auditada
```gherkin
Funcionalidade: Ciclo de Vida de Veículo
  Cenário: Atualização de status ou conclusão rápida diretamente na listagem
    Dado um registro existente exibido na visão Tabela ou Cards
    Quando o operador alterna o status ou marca o item como concluído (PATCH /api/items/:id)
    Então o estado é gravado imediatamente no Cloud SQL PostgreSQL e os KPIs do topo são recalculados
```

## 4. Especificação de Telas e Componentes Frontend (React 18 + TypeScript + Vite)

- **Faixa Institucional Fixa**: Banner superior `"Ambiente Governado DTI (detran-gemini)"` persistente em todas as visualizações.
- **Cabeçalho Executivo**: Título `Gestão de Veículos e Emissão de CRLV-e`, badge do schema `cadastro_veiculos_crlv`, status da conexão PostgreSQL e botão primário **"+ Novo(a) Veículo"**.
- **Faixa de 4 KPIs**: Total de Veículos, Pendentes, Em Andamento e Concluídos (com destaque para itens de Alta Prioridade).
- **Barra de Filtros e Visualização**: Busca instantânea, pílulas de status, seletores de prioridade/categoria e alternância entre **Tabela** e **Cards**.

### Campos Específicos do Domínio (`detalhes` JSONB)

| Chave | Rótulo na UI | Tipo | Obrigatório |
|---|---|---|---|
| `placa_renavam` | Placa e RENAVAM | `text` | Sim |
| `chassi_completo` | Número do Chassi (VIN) | `text` | Sim |
| `combustivel_propulsao` | Tipo de Combustível | `select` | Sim |
| `restricoes_administrativas` | Restrições Financeiras ou Administrativas | `textarea` | Não |
| `cadastro_veiculos_crlv` | Cadastro_veiculos_crlv | `text` | Não |
| `proprio` | Próprio | `text` | Não |
| `proprio_separado_de_11_digitos` | Próprio separado de 11 dígitos | `text` | Não |

## 5. Contrato de Endpoints REST da API (Node.js 22 + Cloud Run v2)

| Método & Rota | Finalidade | Resposta Principal |
|---|---|---|
| `GET /api/health` · `GET /api/status` | Saúde do container, modo `postgresql`, database `db_cadastro_veiculos_crlv` e schema `cadastro_veiculos_crlv` | `200 OK` |
| `GET /api/spec` | Contrato completo de UI, status, categorias e campos customizados | `200 OK` |
| `GET /api/items` | Lista filtrada (`?q=&status=&prioridade=&categoria=`) + objeto `kpis` | `200 OK` |
| `POST /api/items` | Valida e insere novo registro em `cadastro_veiculos_crlv.registros` | `201 Created` |
| `PATCH /api/items/:id` | Atualiza status, flag `concluido` ou campos do registro | `200 OK` |
| `DELETE /api/items/:id` | Remove registro por UUID | `200 OK` |

## 6. Esquema PostgreSQL & Massa Inicial (`seed` de 8 registros)

Tabela `cadastro_veiculos_crlv.registros` inicializada automaticamente no boot da API via `sql/001_init_and_seed.sql`:

| Protocolo | Título Inicial | Status | Prioridade | Categoria | Responsável |
|---|---|---|---|---|---|
| `CRLVS-1001` | VW Gol 1.0 MPI Flex - FROTA PM | `REGULARIZADO` | `ALTA` | Oficial / Governamental | Equipe de Licenciamento Governamental |
| `CRLVS-1002` | Toyota Corolla Cross XRE | `EM_ANALISE` | `MEDIA` | Particular | Núcleo de Análise Cadastral |
| `CRLVS-1003` | Mercedes-Benz Atego 2426 | `PENDENTE_VISTORIA` | `ALTA` | Transporte Coletivo / Carga | Setor de Vistoria de Veículos Pesados |
| `CRLVS-1004` | Chevrolet Onix Plus 1.0 Turbo | `REGULARIZADO` | `BAIXA` | Aluguel / Comercial | Divisão de Frotas e Locadoras |
| `CRLVS-1005` | Honda HR-V Touring 1.5 | `EM_ANALISE` | `MEDIA` | Particular | Núcleo de Análise Cadastral |
| `CRLVS-1006` | Scania R450 6x2 | `REGULARIZADO` | `ALTA` | Transporte Coletivo / Carga | Setor de Vistoria de Veículos Pesados |
| `CRLVS-1007` | Entrega Incremental #7 — Cadastro_veiculos_crlv | `PENDENTE_VISTORIA` | `ALTA` | Particular | Coordenação de Arquitetura DTI |
| `CRLVS-1008` | Entrega Incremental #8 — Próprio | `PENDENTE_VISTORIA` | `ALTA` | Particular | Coordenação de Arquitetura DTI |

## 7. Parâmetros de Governança no Sandbox (`detran-gemini`)

- **Orçamento Máximo (`budget_brl`)**: R$ 150.00
- **Tempo de Vida (`ttl`)**: `1h` (contado após validação do certificado HTTPS gerenciado)
- **Canais de Alerta SRE (`alert_emails`)**: `definido no manifesto de aprovação`