# Architecture Review (AS-IS -> TO-BE) — `vtr3`

- **Repositório da Aplicação**: `detran-automation-dev/zip2-detran-dti-vtr` (`main` 100% intocada)
- **Branch & Tag Preparadas pelo Agente**: `gcp/sandbox` / **`GCP_DEPLOYED_VERSION`** (`ab2cfbf004acf49d2e69cc97186f003de40b7a38`)
- **Comparativo contra `main` (`ahead / behind`)**: [`2 commit(s) ahead`, `0 commit(s) behind` `main`](https://github.com/detran-automation-dev/zip2-detran-dti-vtr/compare/main...GCP_DEPLOYED_VERSION)
- **GCLB HTTPS + `.nip.io` + Redirect HTTP->HTTPS (`301`)**:
  - Frontend SPA (GCS `backend_bucket` + Cloud CDN, **zero container**): `https://vtr3-frontend.<gclb_ip>.nip.io`
  - BFF (Cloud Run Service v2 + Cloud Armor WAF): `https://vtr3-backend.<gclb_ip>.nip.io`
  - API (Cloud Run Service v2 + Cloud Armor WAF): `https://vtr3-api.<gclb_ip>.nip.io`
- **Mensageria Pub/Sub Isolada & Functions v2**: Tópicos `vtr3-events, vtr3-dlq` | Cloud Run Functions v2 (`GEN_2`): `Ativo`
- **Banco Singleton Compartilhado (`database_type`)**: `postgresql` -> `detran-shared-pgsql` (`db-custom-2-7680`: 2 vCPU / 7.5 GB RAM) — ação: `DYNAMIC_CHECK_AND_IMPORT_AT_APPLY_TIME`
- **Schemas Isolados**: `vtr` (zero uso de `public`)
- **Cache Redis Singleton**: `Não requerido`
- **Observabilidade SRE & Alertas**: SLO Disponibilidade `99.5%`, Latência P95 `1500 ms`, Dashboard de Troubleshooting e Alertas por E-mail para `ernanimartins@google.com`
- **Roteamento L7 GCLB `/api/*` -> API**: `reescreve /api -> / no URL Map do GCLB (API sem prefixo global)`
- **Modificação Solicitada para Validação**: `Ambiente Governado DTI — App Viaturas (vtr3)`
- **Evidências na branch (`docs/gcp-sandbox/`)**: [diagrama 4K, revisão, alterações item por item, SARIF e árvore de arquivos](https://github.com/detran-automation-dev/zip2-detran-dti-vtr/tree/gcp/sandbox/docs/gcp-sandbox) — diagrama: `4k_png`

## Diagnóstico Determinístico AS-IS vs. Adaptação TO-BE (`detran-gemini`)

1. **AS-IS (`main` Intocada)**: Monorepo Node.js 22 (`apps/api` NestJS + Prisma ORM e `apps/web` React 18 + Vite), originalmente empacotado para execução local em Docker Compose.
2. **TO-BE em `GCP_DEPLOYED_VERSION`**:
   - **Borda GCLB (`EXTERNAL_MANAGED`) + `.nip.io` + TLS + Redirect HTTP->HTTPS**: Frontend SPA compilado estaticamente para GCS com `website` (`main_page_suffix`/`not_found_page = index.html`) servido via `google_compute_backend_bucket` + Cloud CDN (**zero container de frontend**); BFF e API servidos em Cloud Run Service v2 (`INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`) via Serverless NEGs protegidos por Cloud Armor WAF.
   - **Pub/Sub Dedicado & Cloud Run Functions v2**: Tópicos e Dead-Letter Queue exclusivos por projeto com IAM de mínimo privilégio e suporte nativo a Cloud Run Functions v2 (`GEN_2`).
   - **Zero Pré-Provisionamento Manual de Banco & Rateio FinOps**: servidor singleton `detran-shared-pgsql` criado sob demanda na 1ª aplicação ou importado (`terraform import`) nas seguintes, fracionando custos via `application_name=vtr3`, `pg_stat_database` e `pg_database_size`.
   - **Evolução GKE Autopilot Pronta (`03-optional-gke-autopilot.tf`)**: módulo parametrizado (`enable_gke_autopilot = false` hoje) com `REGULAR` Release Channel, janela automática de manutenção anti-drift e isolamento físico de nós por projeto via `ComputeClass`.
   - **Faixa "Ambiente Governado DTI" persistente**: injetada no `index.html` do build e fixada no topo da página (fora da árvore React, religada por `MutationObserver`), visível em todas as rotas internas (ex.: `/ficha`), após logout e sem deslocar layouts `100vh/100dvh`.

## Adequação de Links, Hostnames e Caminhos Fixos ao Sandbox (`.nip.io` + `/api` na mesma origem)

O agente varreu `apps/` em busca de hosts, portas e caminhos fixos que conflitam com o layout do sandbox (SPA na raiz `/` do host `-frontend` e API acessada pelo navegador em `/api`).

**Variáveis ajustadas automaticamente na API (Cloud Run v2):**

- `CONDUTOR_COOKIE_CAMINHO` = `/api/condutor/acesso`

| Arquivo | Linha | Tipo | Trecho | Adequação no sandbox |
|---|---|---|---|---|
| `apps/api/src/app/fotos/fotos.int-spec.ts` | 127 | fallback_localhost | `base = 'http://127.0.0.1:${(app.getHttpServer().address() as AddressInfo).port}';` | Fallback de desenvolvimento local; no sandbox o build usa VITE_API_URL=/api e VITE_BASE_PATH=/ (mesma origem .nip.io) ou o valor não é usado em AUTH_MODE=dev. |
| `apps/api/src/app/identidade/config.ts` | 66 | caminho_de_cookie_fixo | `cookieCaminho: env.CONDUTOR_COOKIE_CAMINHO?.trim() \|\| "/condutor/acesso",` | O navegador chama a API em '/api' no mesmo host; o cookie com Path '/condutor/acesso' não voltaria nas chamadas (sessão perdida ao recarregar). Sandbox: CONDUTOR_COOKIE_CAMINHO=/api/condutor/acesso. |
| `apps/web/src/auth/use-portal-auth.ts` | 3 | fallback_localhost | `const PORTAL_ORIGIN = import.meta.env.VITE_PORTAL_ORIGIN ?? "http://localhost:3000";` | Fallback de desenvolvimento local; no sandbox o build usa VITE_API_URL=/api e VITE_BASE_PATH=/ (mesma origem .nip.io) ou o valor não é usado em AUTH_MODE=dev. |
| `apps/web/vite.config.ts` | 26 | fallback_localhost | `target: process.env.VITE_PROXY_API ?? "http://localhost:3001",` | Fallback de desenvolvimento local; no sandbox o build usa VITE_API_URL=/api e VITE_BASE_PATH=/ (mesma origem .nip.io) ou o valor não é usado em AUTH_MODE=dev. |
| `apps/web/vite.config.ts` | - | base_path_de_producao | `base: process.env.VITE_BASE_PATH` | Em produção o app pode rodar sob prefixo (ex.: /<app>/); no sandbox VITE_BASE_PATH=/ e o GCS devolve index.html em rotas internas (ex.: /ficha), mantendo a faixa DTI fixa em todas as telas. Ver apps/web/src/base.ts. |

Observação: o logout de alguns apps apenas mostra a tela de login na rota atual (ex.: `/ficha`); isso é comportamento do app. A faixa DTI permanece visível nessas rotas.
