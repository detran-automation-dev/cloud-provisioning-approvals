# Keep Kanban DTI

> Mural Post-It Material Design 3 e Quadro Kanban sincronizados com API Node.js 22 + TypeScript e Cloud SQL PostgreSQL 16

## Stack Homologada
- **Frontend / Mobile**: `React 18 + TypeScript + Vite 5 + Material Design 3 2D (Promoted from UI Staging v2)`
- **Backend / Runtime**: `Node.js 22 LTS + TypeScript REST API + Cloud SQL PostgreSQL 16 (schema keep_kanban_dti)`
- **Banco de Dados**: Cloud SQL PostgreSQL 16 (`db_keep_kanban_dti`, schema `keep_kanban_dti`)

## Telas & Componentes
- Mural Post-Its (Google Keep Masonry 2D com seção Fixadas no topo)
- Quadro Kanban de 4 Colunas (A Fazer, Em Andamento, Revisão, Concluído)
- Modal de Edição e Checklist Interativo de Post-It

## Controles Interativos
- Indicadores resumidos Material Design 3 (Total de Notas, Fixadas e Concluídas com barra de progresso)
- Chips clicáveis para filtro instantâneo por cor (Todas + 6 cores pastel com contador)
- Busca instantânea combinada com filtro por cor, etiquetas e botão Limpar filtros
- Alternância sincronizada 2D entre Mural Post-Its e Quadro Kanban
- Compositor rápido expansível com 6 cores pastel, checklist, etiquetas e fixação no topo
- Drag-and-drop e botões ágeis de transição entre colunas Kanban persistidos via API
- Chaveamento de tema Claro/Escuro com tokens Material Design 3

## Endpoints da API
- `GET /api/health`
- `GET /api/status`
- `GET /api/notes`
- `POST /api/notes`
- `GET /api/notes/:id`
- `PATCH /api/notes/:id`
- `DELETE /api/notes/:id`
- `PATCH /api/notes/:id/toggle-pin`
- `PATCH /api/notes/:id/move`


# Requisitos & Histórias Gherkin — Keep Kanban DTI

## Demanda Original
Aplicação 'keep-kanban-dti' com frontend 2D Material Design 3 promovido 1:1 do UI Staging v2 (React 18 + TypeScript + Vite 5 com Mural Post-It estilo Google Keep colorido, fixação no topo, filtro por cor e Quadro Kanban de 4 colunas sincronizado) e backend REST API em Node.js 22 + TypeScript conectado ao Cloud SQL PostgreSQL 16 (`detran-shared-pgsql`, schema dedicado `keep_kanban_dti`) expondo GET /api/health, GET /api/status, GET /api/notes, POST /api/notes, PATCH /api/notes/:id, DELETE /api/notes/:id, PATCH /api/notes/:id/toggle-pin e PATCH /api/notes/:id/move com campos {id, title, content, color, pinned, column, labels, created_at, updated_at} e seed inicial de Post-Its coloridos.

[PROMOTED FROM APPROVED UI STAGING v2]: Backend API MUST implement these exact REST endpoints expected by the staged frontend: ["GET /api/notes", "POST /api/notes", "PATCH /api/notes/:id", "DELETE /api/notes/:id", "PATCH /api/notes/:id/toggle-pin", "PATCH /api/notes/:id/move"]. UI features: ["Indicadores resumidos no topo em Material Design 3 (Total de Notas, Fixadas 📌 e Concluídas com barra de progresso)", "Chips clicáveis para filtro instantâneo por cor (Todas + bolinhas das 6 cores pastel com contador)", "Filtro combinado por busca instantânea, cor do Post-It e etiquetas com botão Limpar filtros", "Alternância sincronizada 100% 2D entre Mural Post-Its (Keep) em grade Masonry e Quadro Kanban de 4 colunas", "Compositor rápido expansível com 6 cores pastel, checklist interativo, etiquetas e fixação no topo", "Quadro Kanban com drag-and-drop, contadores por coluna e botões ágeis ← / → persistidos via API", "Chaveamento de tema Claro/Escuro com tokens Material Design 3 e tipografia Inter"].

## Requisitos Funcionais
- Indicadores resumidos Material Design 3 (Total de Notas, Fixadas e Concluídas com barra de progresso)
- Chips clicáveis para filtro instantâneo por cor (Todas + 6 cores pastel com contador)
- Busca instantânea combinada com filtro por cor, etiquetas e botão Limpar filtros
- Alternância sincronizada 2D entre Mural Post-Its e Quadro Kanban
- Compositor rápido expansível com 6 cores pastel, checklist, etiquetas e fixação no topo
- Drag-and-drop e botões ágeis de transição entre colunas Kanban persistidos via API
- Chaveamento de tema Claro/Escuro com tokens Material Design 3

## Critérios de Aceite (Gherkin)
```gherkin
Funcionalidade: Keep Kanban DTI
  Cenário: Uso interativo ponta a ponta com persistência PostgreSQL
    Dado que o usuário acessa o frontend estático via HTTPS GCLB (.nip.io)
    Quando executa uma ação na interface conectada a /api/*
    Então o backend Node.js 22 LTS + TypeScript REST API + Cloud SQL PostgreSQL 16 (schema keep_kanban_dti) processa e persiste no schema keep_kanban_dti
```