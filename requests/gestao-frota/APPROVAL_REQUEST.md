# Solicitação Formal de Aprovação de Provisionamento Cloud (`gestao-frota`)

> **ATENÇÃO APROVADOR HUMANO (GESTÃO DTI & SEGURANÇA)**:
> O merge deste Pull Request na branch `main` autoriza a execução automática do workflow
> `.github/workflows/provision-approved-workload.yml` via **Keyless GitHub OIDC Workload Identity Federation**
> assumindo a conta de serviço `detran-workload-provisioner-sa@detran-gemini.iam.gserviceaccount.com` no projeto `detran-gemini`.

## 1. Parâmetros Obrigatórios, Borda GCLB `.nip.io`, Banco Compartilhado, SRE & Trava SHA

| Parâmetro de Governança | Valor Forçado | Regra de Execução |
| :--- | :--- | :--- |
| **Workload Slug** | `gestao-frota` | Identificador isolado de GCS SPA, Cloud Run v2, Pub/Sub, DB lógico e TF State |
| **Repositório da Aplicação** | `detran-automation-dev/zip-detran-dti-hive-gestao-frota` | Branch `main` preservada 100% intocada |
| **Branch & Tag de Deploy** | `gcp/sandbox` / **`GCP_DEPLOYED_VERSION`** | Checkout estrito na tag `GCP_DEPLOYED_VERSION` |
| **Trava SHA Anti-Tampering** | `c33af11a26121e2d8757df430986cd0edc9d0cb2` | Abortará o deploy se `GCP_DEPLOYED_VERSION` divergir deste SHA |
| **Diff vs `main` (`ahead/behind`)** | [`1 ahead` / `0 behind` `main`](https://github.com/detran-automation-dev/zip-detran-dti-hive-gestao-frota/compare/main...GCP_DEPLOYED_VERSION) | Visibilidade integral das alterações do Agente contra `main` |
| **GCLB HTTPS + Redirect 301 (`.nip.io`)** | `https://gestao-frota-frontend.<gclb_ip>.nip.io` (SPA GCS BackendBucket, zero container) / `https://gestao-frota-backend.<gclb_ip>.nip.io` (BFF) / `https://gestao-frota-api.<gclb_ip>.nip.io` (API) | Redirect HTTP->HTTPS `301` + Certificado SSL Certificate Manager + Cloud Armor WAF |
| **Pub/Sub Isolado & Serverless** | `gestao-frota-events`, `gestao-frota-dlq` | Tópicos + DLQ isolados por projeto + suporte a Cloud Run Functions v2 |
| **Banco Singleton (`database_type`)** | `postgresql` -> singleton `detran-shared-pgsql` (`db-custom-2-7680`: 2 vCPU / 7.5 GB RAM) — cria se inexistente ou `terraform import` se já existir | Rateio proporcional por CPU/transações + `pg_database_size` |
| **Cache Redis Compartilhado** | Não requerido nesta carga | Zero colisão de chaves entre aplicações |
| **Observabilidade SRE & SLOs** | Disponibilidade >= `99.5%` / Latência P95 <= `1500 ms` | Dashboard de Troubleshooting + SLOs + Alertas via Terraform |
| **E-mail(s) de Alerta Monitoring** | `ernanimartins@google.com` | Canais `google_monitoring_notification_channel` provisionados |
| **Orçamento Máximo (`budget_brl`)** | **R$ 200.00** | Alertas em 50%/80% e corte determinístico em 100% |
| **Tempo de Vida (`ttl`)** | **`15m` (15 minutos)** | Autodestruição automática dos workloads ao expirar o relógio |
| **Modo de Descomissionamento** | `terraform_destroy_workload_only` | **Remove apenas os workloads e rotas GCLB da app**; preserva projeto `detran-gemini`, GCLB/DB singletons, `main` e repositório Git |
| **Veredito Gatekeeper SARIF** | `PASS` | OWASP Top 10 + 5 Regras de Segurança IA/LGPD |
| **Solicitante** | `arquiteto.dti@detran.sp.gov.br` | Registrado em `2026-11-17T21:00:50Z` |

## 2. Justificativa Executiva / Negócio

Modernização do sistema de Gestão de Frotas DTI para ambiente governado detran-gemini com GCLB HTTPS, SPA estático em GCS, Cloud Run v2 e banco compartilhado PostgreSQL

## 3. Como Aprovar ou Rejeitar

- **Para Aprovar e Provisionar**: Inspecione o [Diff contra `main`](https://github.com/detran-automation-dev/zip-detran-dti-hive-gestao-frota/compare/main...GCP_DEPLOYED_VERSION) e `ARCHITECTURE_REVIEW.md`, aprove e faça **Merge Pull Request** para `main`. As URLs HTTPS `.nip.io` (`frontend`, `backend`, `api`) e o link do Dashboard de SLOs/Troubleshooting serão publicados em `active-leases/gestao-frota.json`.
- **Para Rejeitar**: Feche o PR sem merge (ou altere `approval_status` para `"REJECTED"`).
