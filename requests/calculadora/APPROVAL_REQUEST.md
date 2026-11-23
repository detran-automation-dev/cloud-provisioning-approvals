# Solicitação Formal de Aprovação de Provisionamento Cloud (`calculadora`)

> **ATENÇÃO APROVADOR HUMANO (GESTÃO DTI & SEGURANÇA)**:
> O merge deste Pull Request na branch `main` autoriza a execução automática do workflow
> `.github/workflows/provision-approved-workload.yml` via **Keyless GitHub OIDC Workload Identity Federation**
> assumindo a conta de serviço `detran-workload-provisioner-sa@detran-gemini.iam.gserviceaccount.com` no projeto `detran-gemini`.

## 1. Parâmetros Obrigatórios, Borda GCLB `.nip.io`, Banco Compartilhado, SRE & Trava SHA

| Parâmetro de Governança | Valor Forçado | Regra de Execução |
| :--- | :--- | :--- |
| **Workload Slug** | `calculadora` | Identificador isolado de GCS SPA, Cloud Run v2, Pub/Sub, DB lógico e TF State |
| **Repositório da Aplicação** | `detran-automation-dev/calculadora` | Branch `main` preservada 100% intocada |
| **Branch & Tag de Deploy** | `gcp/sandbox` / **`GCP_DEPLOYED_VERSION`** | Checkout estrito na tag `GCP_DEPLOYED_VERSION` |
| **Trava SHA Anti-Tampering** | `5dda8f2c4e2cb201d195ded0f1b8aa1296d7cd36` | Abortará o deploy se `GCP_DEPLOYED_VERSION` divergir deste SHA |
| **Diff vs `main` (`ahead/behind`)** | [`1 ahead` / `0 behind` `main`](https://github.com/detran-automation-dev/calculadora/compare/main...GCP_DEPLOYED_VERSION) | Visibilidade integral das alterações do Agente contra `main` |
| **GCLB HTTPS + Redirect 301 (`.nip.io`)** | `https://calculadora-frontend.<gclb_ip>.nip.io` (SPA GCS BackendBucket, zero container) / `https://calculadora-backend.<gclb_ip>.nip.io` (BFF) / `https://calculadora-api.<gclb_ip>.nip.io` (API) | Redirect HTTP->HTTPS `301` + Certificado SSL Certificate Manager + Cloud Armor WAF |
| **Pub/Sub Isolado & Serverless** | `calculadora-events`, `calculadora-dlq` | Tópicos + DLQ isolados por projeto + suporte a Cloud Run Functions v2 |
| **Banco Singleton (`database_type`)** | `postgresql` -> singleton `detran-shared-pgsql` (`db-custom-2-7680`: 2 vCPU / 7.5 GB RAM) — cria se inexistente ou `terraform import` se já existir | Rateio proporcional por CPU/transações + `pg_database_size` |
| **Cache Redis Compartilhado** | Não requerido nesta carga | Zero colisão de chaves entre aplicações |
| **Observabilidade SRE & SLOs** | Disponibilidade >= `99.5%` / Latência P95 <= `1500 ms` | Dashboard de Troubleshooting + SLOs + Alertas via Terraform |
| **E-mail(s) de Alerta Monitoring** | `wagner.silva@detran.sp.gov.br` | Canais `google_monitoring_notification_channel` provisionados |
| **Orçamento Máximo (`budget_brl`)** | **R$ 100.00** | Alertas em 50%/80% e corte determinístico em 100% |
| **Tempo de Vida (`ttl`)** | **`1h` (60 minutos)** | Autodestruição automática dos workloads ao expirar o relógio |
| **Modo de Descomissionamento** | `terraform_destroy_workload_only` | **Remove apenas os workloads e rotas GCLB da app**; preserva projeto `detran-gemini`, GCLB/DB singletons, `main` e repositório Git |
| **Veredito Gatekeeper SARIF** | `PASS` | OWASP Top 10 + 5 Regras de Segurança IA/LGPD |
| **Solicitante** | `wagner.silva@detran.sp.gov.br` | Registrado em `2026-11-23T16:08:13Z` |

## 2. Justificativa Executiva / Negócio

Aplicação Calculadora convencional (estilo Microsoft Windows) com histórico em PostgreSQL para demonstração controlada (TTL 1h, orçamento máximo R$ 100,00).

## 3. Modelos de LLM em Execução por Agente (Transparência DTI)

| Agente | Papel Executivo DTI | Modelo LLM Principal | Motor Especializado / Complementar |
|---|---|---|---|
| **Orquestrador Central DTI** (`detran_ref`) | Coordenação Zero-Trust & Roteamento A2A | `gemini-4-neon` | RBAC Fail-Closed + Callback Multimodal de Anexos |
| **Agente de Requisitos** (`prd_discovery_agent`) | Descoberta e requisitos | `gemini-4-neon` | Síntese estruturada PRD/Spec: gemini-4-neon |
| **Agente de Arquitetura** (`gcp_fabric_architect_agent`) | Arquiteto GCP | `gemini-4-neon` | Diagramas 4K: gemini-3.1-flash-image (fallback: gemini-2.5-flash-image) |
| **Agente de Compliance** (`github_iac_publisher_agent`) | Raio-X dos sistemas atuais | `gemini-4-neon` | Calibrated Decision Gate: gemini-decision-1 |
| **Agente de Implementação** (`antigravity_fullstack_factory_agent`) | Fábrica de aplicações | `gemini-4-neon` | Síntese Full-Stack & Evolução Day-2: gemini-4-neon |
| **Agente de Segurança** (`security_anti_slop_agent`) | Inspetor de segurança | `gemini-4-neon` | Scanners determinísticos AST/SARIF (Semgrep OSS + Trivy OSS) |


## 4. Como Aprovar ou Rejeitar

- **Para Aprovar e Provisionar**: Inspecione o [Diff contra `main`](https://github.com/detran-automation-dev/calculadora/compare/main...GCP_DEPLOYED_VERSION) e `PRD.md`, aprove e faça **Merge Pull Request** para `main`. As URLs HTTPS `.nip.io` (`frontend`, `backend`, `api`) e o link do Dashboard de SLOs/Troubleshooting serão publicados em `active-leases/calculadora.json`.
- **Para Rejeitar**: Feche o PR sem merge (ou altere `approval_status` para `"REJECTED"`).
