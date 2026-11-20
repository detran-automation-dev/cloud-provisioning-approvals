# Architecture Review (AS-IS -> TO-BE) — `calculadora-simples`

- **Repositório da Aplicação**: `detran-automation-dev/calculadora-simples` (`main` 100% intocada)
- **Branch & Tag Preparadas pelo Agente**: `gcp/sandbox` / **`GCP_DEPLOYED_VERSION`** (`b013e907363cdd323f9e6601e6f8846f3963560b`)
- **Comparativo contra `main` (`ahead / behind`)**: [`1 commit(s) ahead`, `0 commit(s) behind` `main`](https://github.com/detran-automation-dev/calculadora-simples/compare/main...GCP_DEPLOYED_VERSION)
- **GCLB HTTPS + `.nip.io` + Redirect HTTP->HTTPS (`301`)**:
  - Frontend SPA (GCS `backend_bucket` + Cloud CDN, **zero container**): `https://calculadora-simples-frontend.<gclb_ip>.nip.io`
  - BFF (Cloud Run Service v2 + Cloud Armor WAF): `https://calculadora-simples-backend.<gclb_ip>.nip.io`
  - API (Cloud Run Service v2 + Cloud Armor WAF): `https://calculadora-simples-api.<gclb_ip>.nip.io`
- **Mensageria Pub/Sub Isolada & Functions v2**: Tópicos `calculadora-simples-events, calculadora-simples-dlq` | Cloud Run Functions v2 (`GEN_2`): `Pronto sob demanda (enable_cloud_functions)`
- **Banco Singleton Compartilhado (`database_type`)**: `postgresql` -> `detran-shared-pgsql` (`db-custom-2-7680`: 2 vCPU / 7.5 GB RAM) — ação: `DYNAMIC_CHECK_AND_IMPORT_AT_APPLY_TIME`
- **Schemas Isolados**: `calculadora_simples` (zero uso de `public`)
- **Cache Redis Singleton**: `Não requerido`
- **Observabilidade SRE & Alertas**: SLO Disponibilidade `99.5%`, Latência P95 `1500 ms`, Dashboard de Troubleshooting e Alertas por E-mail para `wagner.silva@detran.sp.gov.br`
- **Roteamento L7 GCLB `/api/*` -> API**: `preserva /api (setGlobalPrefix detectado)`
- **Modificação Solicitada para Validação**: `Baseline Cloud-Native inicial sem alteração funcional`
- **Evidências na branch (`docs/gcp-sandbox/`)**: [diagrama 4K, revisão, alterações item por item, SARIF e árvore de arquivos](https://github.com/detran-automation-dev/calculadora-simples/tree/gcp/sandbox/docs/gcp-sandbox) — diagrama: `4k_png`

## Diagnóstico Determinístico AS-IS vs. Adaptação TO-BE (`detran-gemini`)

1. **AS-IS (`main` Intocada)**: Monorepo Node.js 22 (`apps/api` NestJS + Prisma ORM e `apps/web` React 18 + Vite), originalmente empacotado para execução local em Docker Compose.
2. **TO-BE em `GCP_DEPLOYED_VERSION`**:
   - **Borda GCLB (`EXTERNAL_MANAGED`) + `.nip.io` + TLS + Redirect HTTP->HTTPS**: Frontend SPA compilado estaticamente para GCS com `website` (`main_page_suffix`/`not_found_page = index.html`) servido via `google_compute_backend_bucket` + Cloud CDN (**zero container de frontend**); BFF e API servidos em Cloud Run Service v2 (`INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`) via Serverless NEGs protegidos por Cloud Armor WAF.
   - **Pub/Sub Dedicado & Cloud Run Functions v2**: Tópicos e Dead-Letter Queue exclusivos por projeto com IAM de mínimo privilégio e suporte nativo a Cloud Run Functions v2 (`GEN_2`).
   - **Zero Pré-Provisionamento Manual de Banco & Rateio FinOps**: servidor singleton `detran-shared-pgsql` criado sob demanda na 1ª aplicação ou importado (`terraform import`) nas seguintes, fracionando custos via `application_name=calculadora-simples`, `pg_stat_database` e `pg_database_size`.
   - **Evolução GKE Autopilot Pronta (`03-optional-gke-autopilot.tf`)**: módulo parametrizado (`enable_gke_autopilot = false` hoje) com `REGULAR` Release Channel, janela automática de manutenção anti-drift e isolamento físico de nós por projeto via `ComputeClass`.
   - **Faixa "Ambiente Governado DTI" persistente**: injetada no `index.html` do build e fixada no topo da página (fora da árvore React, religada por `MutationObserver`), visível em todas as rotas internas (ex.: `/ficha`), após logout e sem deslocar layouts `100vh/100dvh`.

## Adequação de Links, Hostnames e Caminhos Fixos ao Sandbox (`.nip.io` + `/api` na mesma origem)

O agente varreu `apps/` em busca de hosts, portas e caminhos fixos que conflitam com o layout do sandbox (SPA na raiz `/` do host `-frontend` e API acessada pelo navegador em `/api`).

| Arquivo | Linha | Tipo | Trecho | Adequação no sandbox |
|---|---|---|---|---|
| `apps/api/src/routes.ts` | 52 | fallback_localhost | `const parsedUrl = new URL(rawUrl, "http://127.0.0.1");` | Fallback de desenvolvimento local; no sandbox o build usa VITE_API_URL=/api e VITE_BASE_PATH=/ (mesma origem .nip.io) ou o valor não é usado em AUTH_MODE=dev. |
| `apps/web/vite.config.ts` | - | base_path_de_producao | `base: process.env.VITE_BASE_PATH` | Em produção o app pode rodar sob prefixo (ex.: /<app>/); no sandbox VITE_BASE_PATH=/ e o GCS devolve index.html em rotas internas (ex.: /ficha), mantendo a faixa DTI fixa em todas as telas. |

Observação: o logout de alguns apps apenas mostra a tela de login na rota atual (ex.: `/ficha`); isso é comportamento do app. A faixa DTI permanece visível nessas rotas.
