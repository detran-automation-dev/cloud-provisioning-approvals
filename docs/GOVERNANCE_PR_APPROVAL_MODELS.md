# Modelos de Aprovação de Pull Requests de Provisionamento (GitOps & Four-Eyes — DTI)

## Contexto do Problema (Auto-Aprovação Bloqueada pelo GitHub)

No GitHub, **uma conta de usuário nunca pode submeter um review `Approve` em um Pull Request aberto pela própria conta** (*"Reviewers cannot approve their own pull request"*).

Quando o runtime do Agente (`detran-ref`) usa um **Personal Access Token (Fine-Grained PAT)** emitido pela mesma conta humana listada em `CODEOWNERS`, o GitHub registra essa mesma pessoa como **criador do PR**. Caso a Branch Protection da `main` exija `required_approving_review_count >= 1`, o botão `Approve` aparece desabilitado (*grayed out*) quando o emissor do PAT tenta aprovar o próprio pedido.

A plataforma suporta nativamente **3 modelos arquiteturais oficiais** para resolver isso de forma limpa e auditável no ambiente governado da DTI (`detran-automation-dev`).

---

## Modelo 1 (Recomendado para Produção & Governança DTI): GitHub App Próprio da Fábrica (`[bot]`)

Neste modelo, o Agente **não usa o PAT de uma pessoa física para abrir PRs**. Ele autentica como um **GitHub App oficial da organização** (`detran-factory-bot-*[bot]`), gerando *Installation Access Tokens* efêmeros (1 hora de vida) via chave RSA privada salva no Secret Manager (`detran-github-app-credentials`).

- **Quem aparece como Criador do PR:** `detran-factory-bot-*[bot]`
- **Quem aprova o PR (`CODEOWNERS`):** aprovadores humanos da DTI ou time `@detran-automation-dev/cloud-approvers`
- **Resultado no GitHub UI:** como o criador é `detran-factory-bot-*[bot]`, o botão **`Approve`** fica **100% liberado** para qualquer aprovador humano (inclusive o próprio dono da organização), mantendo `required_approving_review_count: 1`, `require_code_owner_reviews: true` e `enforce_admins: true`!

### Ativação em 2 cliques (Assistente Automático via Cloud Run)

1. Acesse a rota autenticada do serviço Cloud Run `detran-ref`:
   `https://<DETRAN_REF_CLOUD_RUN_URL>/setup/github-app?org=detran-automation-dev`
2. Clique em **1. Criar GitHub App em detran-automation-dev** e confirme no GitHub:
   - O assistente converte o código temporário do Manifesto, grava automaticamente `{"app_id","slug","pem"}` no Secret Manager (`projects/detran-gemini/secrets/detran-github-app-credentials`) sem download manual de chave privada e redireciona para o passo 2.
3. Clique em **2. Instalar na org detran-automation-dev** marcando **All repositories**:
   - `github_cloud_gtm_pusher._resolve_github_token()` descobre automaticamente o `installation_id` via `GET /orgs/detran-automation-dev/installation` e passa a assinar commits e PRs como `detran-factory-bot-*[bot]`.
4. Habilite a proteção estrita com `required_approving_review_count: 1` e `require_code_owner_reviews: true` na branch `main` de `cloud-provisioning-approvals`:
   - **Observação para o Selo HMAC (`provision_workload.sh`):** mantenha também o segredo `detran-github-org-pat` (ou configure `MANIFEST_HMAC_SECRET`) sincronizado entre o Agente e o GitHub Actions WIF para a verificação criptográfica determinística `HMAC-SHA256` do `approval-manifest.json`.

---

## Modelo 2 (Alternativa com Conta Dedicada): *Machine User* de Automação

Quando a equipe opta por trabalhar apenas com Fine-Grained PATs sem criar GitHub App:

1. Cria-se uma conta GitHub dedicada de automação (ex.: `@detran-dti-automation-bot`) adicionada como membro da organização `detran-automation-dev` com permissão de escrita/criação de repositórios.
2. O Fine-Grained PAT salvo em `detran-github-org-pat` é gerado logado na conta `@detran-dti-automation-bot`.
3. O arquivo `.github/CODEOWNERS` lista apenas os aprovadores humanos da DTI.
4. **Resultado:** `@detran-dti-automation-bot` é o criador do PR e qualquer humano listado em `CODEOWNERS` aprova normalmente com `required_approving_review_count: 1`.

---

## Modelo 3 (Contingência Sandbox Solo-Owner): PR Obrigatório + Gate Determinístico Criptográfico (`0` Reviews Bloqueantes)

Em cenários temporários onde há apenas um único administrador usando seu próprio Fine-Grained PAT (sem GitHub App `[bot]` e sem *Machine User*):

- A Branch Protection da `main` em `cloud-provisioning-approvals` mantém:
  - **Pull Request obrigatório** (`required_pull_request_reviews` ativo com `required_approving_review_count: 0`, vedando push direto na `main`);
  - **Status Check obrigatório (`strict: true`)**: `Enforce Mandatory Budget, TTL & GCP_DEPLOYED_VERSION SHA Lock` (valida orçamento, TTL, tag imutável `GCP_DEPLOYED_VERSION`, commit SHA anti-tampering e assinatura criptográfica `HMAC-SHA256`);
  - **Bloqueio de escrita destrutiva**: `allow_force_pushes: false` e `allow_deletions: false`;
  - **Execução de deploy restrita via Keyless OIDC WIF**: somente merges reais em `refs/heads/main` de `cloud-provisioning-approvals` obtêm token STS no GCP (`detran-workload-provisioner-sa@detran-gemini.iam.gserviceaccount.com`).
- **Resultado:** assim que o check determinístico fica verde, o administrador clica em **Merge pull request** sem *deadlock* de auto-aprovação e sem desproteger a branch `main`.
