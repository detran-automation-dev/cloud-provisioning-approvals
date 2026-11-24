# Keep Kanban DTI (`keep-kanban-dti`)

Aplicação fullstack de produtividade visual em **Material Design 3 (100% 2D)** combinando **Mural Post-It estilo Google Keep** (grade Masonry, fixação no topo, 6 cores pastel, checklists interativos e etiquetas) com **Quadro Kanban de 4 colunas sincronizado** (drag-and-drop e botões ágeis `←` / `→`).

## Arquitetura

- **Frontend (`apps/web/`)**: React 18 + TypeScript + Vite 5 + Material Design 3 (`--md-sys-color-*`), tema Claro/Escuro, tipografia Inter, `base: "./"` e resolução dinâmica de API (`window.__SDLC_API_BASE__ || "/api"`).
- **Backend (`apps/api/`)**: Node.js 22 LTS + TypeScript REST API (`http` nativo + `pg`) ouvindo em `0.0.0.0:8080`, conectado ao Cloud SQL PostgreSQL 16 via Unix Socket (`CLOUDSQL_SOCKET`) no schema dedicado `keep_kanban_dti` (com fallback seguro em memória para desenvolvimento local).
- **Banco de Dados (`sql/001_init_and_seed.sql`)**: Schema dedicado `keep_kanban_dti`, tabela `keep_kanban_dti.notes` e trilha append-only `keep_kanban_dti.trilha_auditoria` com seed idempotente de Post-Its coloridos.

## Endpoints REST

| Método | Rota | Descrição |
| --- | --- | --- |
| `GET` | `/api/health` | Healthcheck de prontidão do serviço |
| `GET` | `/api/status` | Status detalhado, contagem de notas e modo de persistência |
| `GET` | `/api/notes` | Lista Post-Its com filtros opcionais (`q`, `color`, `label`, `column`) |
| `POST` | `/api/notes` | Cria um novo Post-It com checklist, cor, etiquetas e coluna |
| `PATCH` | `/api/notes/:id` | Atualiza título, conteúdo, cor, checklist, etiquetas, fixação ou coluna |
| `DELETE` | `/api/notes/:id` | Remove um Post-It |
| `PATCH` | `/api/notes/:id/toggle-pin` | Alterna fixação (`pinned`) no topo |
| `PATCH` | `/api/notes/:id/move` | Move o Post-It entre colunas Kanban (`backlog`, `todo`, `doing`, `done`) |

## Execução Local

```bash
# Backend
cd apps/api && npm install && npm run build && npm start

# Frontend
cd apps/web && npm install && npm run dev
```


# Requisitos & Histórias Gherkin — Keep Kanban DTI

## Demanda Original
Aplicação 'keep-kanban-dti' com frontend 2D Material Design 3 promovido 1:1 do UI Staging v2 (React 18 + TypeScript + Vite 5 com Mural Post-It estilo Google Keep colorido, fixação no topo, filtro por cor e Quadro Kanban de 4 colunas sincronizado) e backend REST API em Node.js 22 + TypeScript conectado ao Cloud SQL PostgreSQL 16 (`detran-shared-pgsql`, schema dedicado `keep_kanban_dti`) expondo GET /api/health, GET /api/status, GET /api/notes, POST /api/notes, PATCH /api/notes/:id, DELETE /api/notes/:id, PATCH /api/notes/:id/toggle-pin e PATCH /api/notes/:id/move com campos {id, title, content, color, pinned, column, labels, created_at, updated_at} e seed inicial de Post-Its coloridos.

[PROMOTED FROM APPROVED UI STAGING v2]: Backend API MUST implement these exact REST endpoints expected by the staged frontend: ["GET /api/notes", "POST /api/notes", "PATCH /api/notes/:id", "DELETE /api/notes/:id", "PATCH /api/notes/:id/toggle-pin", "PATCH /api/notes/:id/move"]. UI features: ["Indicadores resumidos no topo em Material Design 3 (Total de Notas, Fixadas 📌 e Concluídas com barra de progresso)", "Chips clicáveis para filtro instantâneo por cor (Todas + bolinhas das 6 cores pastel com contador)", "Filtro combinado por busca instantânea, cor do Post-It e etiquetas com botão Limpar filtros", "Alternância sincronizada 100% 2D entre Mural Post-Its (Keep) em grade Masonry e Quadro Kanban de 4 colunas", "Compositor rápido expansível com 6 cores pastel, checklist interativo, etiquetas e fixação no topo", "Quadro Kanban com drag-and-drop, contadores por coluna e botões ágeis ← / → persistidos via API", "Chaveamento de tema Claro/Escuro com tokens Material Design 3 e tipografia Inter"].

## Requisitos Funcionais
- Indicadores resumidos no topo em MD3 (Total de Notas, Fixadas e Concluídas com barra de progresso)
- Chips clicáveis para filtro instantâneo por cor (Todas + 6 cores pastel com contador)
- Busca instantânea combinada com filtro por cor, etiquetas e botão Limpar filtros
- Alternância sincronizada 100% 2D entre Mural Post-Its (Keep) e Quadro Kanban
- Compositor rápido expansível com 6 cores pastel, checklist interativo, etiquetas e fixação no topo
- Drag-and-drop entre colunas Kanban, contadores por coluna e botões ágeis de movimentação persistidos via API
- Chaveamento de tema Claro/Escuro com tokens Material Design 3 e tipografia Inter

## Critérios de Aceite (Gherkin)
```gherkin
Funcionalidade: Keep Kanban DTI
  Cenário: Uso interativo ponta a ponta com persistência PostgreSQL
    Dado que o usuário acessa o frontend estático via HTTPS GCLB (.nip.io)
    Quando executa uma ação na interface conectada a /api/*
    Então o backend Node.js 22 LTS + TypeScript REST API + Cloud SQL PostgreSQL 16 (schema keep_kanban_dti) processa e persiste no schema keep_kanban_dti
```