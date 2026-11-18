# Architecture Review (AS-IS -> TO-BE) — `vtr2`

- **Repositório da Aplicação**: `detran-automation-dev/zip2-detran-dti-vtr` (`main` 100% intocada)
- **Branch & Tag Preparadas pelo Agente**: `gcp/sandbox` / **`GCP_DEPLOYED_VERSION`** (`b45c0d6583fffb44cf16c814393734f790f8350b`)
- **Comparativo contra `main` (`ahead / behind`)**: [`1 commit(s) ahead`, `0 commit(s) behind` `main`](https://github.com/detran-automation-dev/zip2-detran-dti-vtr/compare/main...GCP_DEPLOYED_VERSION)
- **GCLB HTTPS + `.nip.io` + Redirect HTTP->HTTPS (`301`)**:
  - Frontend SPA (GCS `backend_bucket` + Cloud CDN, **zero container**): `https://vtr2-frontend.<gclb_ip>.nip.io`
  - BFF (Cloud Run Service v2 + Cloud Armor WAF): `https://vtr2-backend.<gclb_ip>.nip.io`
  - API (Cloud Run Service v2 + Cloud Armor WAF): `https://vtr2-api.<gclb_ip>.nip.io`
- **Mensageria Pub/Sub Isolada & Functions v2**: Tópicos `vtr2-events, vtr2-dlq` | Cloud Run Functions v2 (`GEN_2`): `Ativo`
- **Banco Singleton Compartilhado (`database_type`)**: `postgresql` -> `detran-shared-pgsql` (`db-custom-2-7680`: 2 vCPU / 7.5 GB RAM) — ação: `DYNAMIC_CHECK_AND_IMPORT_AT_APPLY_TIME`
- **Schemas Isolados**: `vtr` (zero uso de `public`)
- **Cache Redis Singleton**: `Não requerido`
- **Observabilidade SRE & Alertas**: SLO Disponibilidade `99.5%`, Latência P95 `1500 ms`, Dashboard de Troubleshooting e Alertas por E-mail para `ernanimartins@google.com`
- **Roteamento L7 GCLB `/api/*` -> API**: `reescreve /api -> / no URL Map do GCLB (API sem prefixo global)`
- **Modificação Solicitada para Validação**: `Ambiente Governado DTI — App Viaturas (vtr2)`

## Diagnóstico Determinístico AS-IS vs. Adaptação TO-BE (`detran-gemini`)

1. **AS-IS (`main` Intocada)**: Monorepo Node.js 22 (`apps/api` NestJS + Prisma ORM e `apps/web` React 18 + Vite), originalmente empacotado para execução local em Docker Compose.
2. **TO-BE em `GCP_DEPLOYED_VERSION`**:
   - **Borda GCLB (`EXTERNAL_MANAGED`) + `.nip.io` + TLS + Redirect HTTP->HTTPS**: Frontend SPA compilado estaticamente para GCS com `website` (`main_page_suffix`/`not_found_page = index.html`) servido via `google_compute_backend_bucket` + Cloud CDN (**zero container de frontend**); BFF e API servidos em Cloud Run Service v2 (`INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`) via Serverless NEGs protegidos por Cloud Armor WAF.
   - **Pub/Sub Dedicado & Cloud Run Functions v2**: Tópicos e Dead-Letter Queue exclusivos por projeto com IAM de mínimo privilégio e suporte nativo a Cloud Run Functions v2 (`GEN_2`).
   - **Zero Pré-Provisionamento Manual de Banco & Rateio FinOps**: servidor singleton `detran-shared-pgsql` criado sob demanda na 1ª aplicação ou importado (`terraform import`) nas seguintes, fracionando custos via `application_name=vtr2`, `pg_stat_database` e `pg_database_size`.
   - **Evolução GKE Autopilot Pronta (`03-optional-gke-autopilot.tf`)**: módulo parametrizado (`enable_gke_autopilot = false` hoje) com `REGULAR` Release Channel, janela automática de manutenção anti-drift e isolamento físico de nós por projeto via `ComputeClass`.
