# Cloud Provisioning Approvals — Governança FinOps, Tag `GCP_DEPLOYED_VERSION` & TTL (`detran-gemini`)

Repositório central e auditável de aprovação humana (**Human-in-the-Loop**) para provisionamento e descomissionamento automático de *workloads* gerados ou revisados pelo **Orquestrador Agêntico DTI** no **Gemini Enterprise**.

## Regras Inegociáveis de Governança (Fase 1 — Sandbox Compartilhado)

1. **Repositório Limpo (`main` Intocada + Tag `GCP_DEPLOYED_VERSION` + Trava SHA Anti-Tampering)**:
   - O Agente pode revisar e preparar **qualquer repositório de aplicação** em `detran-automation-dev` sem duplicar repositórios (`gcp-*`).
   - As adaptações Cloud Run + Cloud SQL + Terraform (e eventuais modificações pedidas em tempo real) são gravadas na branch dedicada `gcp/sandbox` e marcadas com a tag anotada **`GCP_DEPLOYED_VERSION`**, mantendo a `main` 100% intocada e exibindo claramente no GitHub (`/compare/main...GCP_DEPLOYED_VERSION`) o diff completo e quantos commits está `ahead` ou `behind` de `main`.
   - **Pinagem Dupla Anti-Tampering (TOCTOU)**: O `approval-manifest.json` exige simultaneamente `git_tag: "GCP_DEPLOYED_VERSION"` e `expected_commit_sha`. Durante o deploy no GitHub Actions, se o SHA real da tag divergir do SHA auditado e aprovado no PR, o deploy é abortado imediatamente.
2. **Argumentos Obrigatórios Forçados (`budget_brl` e `ttl`)**:
   - Nenhum deployment é aceito pela Service Account (`detran-workload-provisioner-sa@detran-gemini.iam.gserviceaccount.com`) sem **Orçamento Máximo (`budget_brl > 0`)** e **Tempo de Vida (`ttl`, padrão `1h` = 1 hora para demonstração de autodestruição, contada a partir da validação do certificado SSL/HTTPS dos 3 hosts `.nip.io`, ou `15d` para sandbox)**.
3. **Proteção Absoluta do Projeto `detran-gemini` e do Código-Fonte**:
   - No vencimento do `ttl` (`1h` após o HTTPS validado) ou ao atingir `100%` do orçamento estipulado, a esteira executa **exclusivamente `terraform destroy` sobre os *workloads* daquela aplicação**, preservando `detran-gemini`, o faturamento do Gemini Enterprise, a branch `main` e o repositório Git.

## Desprovisionar antes do prazo ou alterar o TTL (somente aprovadores DTI)

- Os aprovadores listados em `policies/governance-policy.json` (`lifecycle_override_approvers`) podem pedir ao agente
  *DETRAN-SP — Fábrica de Software & Governança DTI*, no Gemini Enterprise, para **desprovisionar agora** um ambiente ativo
  ou **alterar o seu TTL** (entre `5m` e `24h`, contado a partir do pedido).
- A identidade vem da sessão autenticada do Gemini Enterprise (nunca de um e-mail digitado no prompt). O agente grava em
  `lifecycle-requests/` um pedido com selo **HMAC-SHA256**; o workflow `workload-lifecycle-override.yml` revalida o selo,
  o aprovador e o lease `active-leases/<slug>.json`, então:
  - `decommission`: expira o lease e cria `teardown-triggers/<slug>-<epoch>.json`, iniciando o teardown na hora;
  - `set_ttl`: move `expires_at_epoch` e reprograma o Cloud Scheduler `ttl-exp-<slug>`.
- Cada pedido processado fica em `lifecycle-requests/processed/` com o resultado (`APPLIED` ou `REJECTED`) e o histórico
  em `lifecycle_overrides` no lease.

