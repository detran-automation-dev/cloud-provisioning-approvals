#!/usr/bin/env bash
# ============================================================================
# Deterministic Workload Provisioner (Post-Approval GitHub Actions Executor)
# Enforces mandatory BUDGET_BRL, TTL_MINUTES, ALERT_EMAILS_CSV, and Dual-Pinning
# Anti-Tampering Lock (GIT_TAG == GCP_DEPLOYED_VERSION && SHA == EXPECTED_COMMIT_SHA),
# reconciles Singleton Shared GCLB + DB/Redis, builds API/BFF container(s) and
# Static SPA bundle (zero container for frontend!), applies Terraform, syncs
# static SPA assets to GCS BackendBucket, registers .nip.io hostRules on GCLB,
# and schedules precision TTL workload-only teardown.
# ============================================================================
set -euo pipefail

: "${WORKLOAD_SLUG:?ERRO FATAL: WORKLOAD_SLUG obrigatorio}"
: "${GITHUB_ORG:?ERRO FATAL: GITHUB_ORG obrigatorio}"
: "${SOLUTION_REPO:?ERRO FATAL: SOLUTION_REPO obrigatorio}"
: "${GIT_TAG:?ERRO FATAL: GIT_TAG (GCP_DEPLOYED_VERSION) obrigatorio}"
: "${EXPECTED_COMMIT_SHA:?ERRO FATAL: EXPECTED_COMMIT_SHA obrigatorio}"
: "${TARGET_GCP_PROJECT:?ERRO FATAL: TARGET_GCP_PROJECT obrigatorio}"
: "${BUDGET_BRL:?ERRO FATAL: BUDGET_BRL obrigatorio}"
: "${TTL_LABEL:?ERRO FATAL: TTL_LABEL obrigatorio}"
: "${TTL_MINUTES:?ERRO FATAL: TTL_MINUTES obrigatorio}"
: "${DATABASE_TYPE:?ERRO FATAL: DATABASE_TYPE obrigatorio}"
: "${ENABLE_REDIS:?ERRO FATAL: ENABLE_REDIS obrigatorio}"
: "${ALERT_EMAILS_CSV:?ERRO FATAL: ALERT_EMAILS_CSV obrigatorio}"
: "${SLO_AVAILABILITY_GOAL:?ERRO FATAL: SLO_AVAILABILITY_GOAL obrigatorio}"
: "${SLO_LATENCY_P95_MS:?ERRO FATAL: SLO_LATENCY_P95_MS obrigatorio}"

if [[ "${TARGET_GCP_PROJECT}" != "detran-gemini" ]]; then
  echo "ERRO DE GOVERNANCA: Projeto alvo '${TARGET_GCP_PROJECT}' nao autorizado (permitido: detran-gemini)." >&2
  exit 1
fi

if [[ "${GIT_TAG}" != "GCP_DEPLOYED_VERSION" ]]; then
  echo "ERRO DE GOVERNANCA: GIT_TAG deve ser estritamente 'GCP_DEPLOYED_VERSION' (recebido: '${GIT_TAG}')." >&2
  exit 1
fi

REGION="southamerica-east1"
TF_BUCKET="detran-gemini-provisioning-tfstate"
AR_REPO="${REGION}-docker.pkg.dev/${TARGET_GCP_PROJECT}/detran-sandbox-workloads"
SHORT_SHA="${EXPECTED_COMMIT_SHA:0:8}"
APPROVALS_ROOT="$(pwd)"

echo "=== [1/7] Fetching ephemeral GitHub token from Secret Manager (${TARGET_GCP_PROJECT}) ==="
GH_PAT="$(gcloud secrets versions access latest --secret=detran-github-org-pat --project="${TARGET_GCP_PROJECT}")"
echo "::add-mask::${GH_PAT}"
AUTH_B64="$(printf 'x-access-token:%s' "${GH_PAT}" | base64 -w 0)"

SRC_DIR="$(mktemp -d /tmp/solution-src-XXXXXX)"
SPA_EXTRACT_DIR="$(mktemp -d /tmp/spa-extract-XXXXXX)"
trap 'rm -rfv "${SRC_DIR}" "${SPA_EXTRACT_DIR}" >/dev/null 2>&1 || true' EXIT

echo "=== [2/7] Cloning ${GITHUB_ORG}/${SOLUTION_REPO} & Verifying Anti-Tampering Lock on tag ${GIT_TAG} ==="
GIT_CONFIG_COUNT=1 \
GIT_CONFIG_KEY_0="http.https://github.com/.extraheader" \
GIT_CONFIG_VALUE_0="AUTHORIZATION: basic ${AUTH_B64}" \
GIT_TERMINAL_PROMPT=0 \
git clone "https://github.com/${GITHUB_ORG}/${SOLUTION_REPO}.git" "${SRC_DIR}"

GIT_CONFIG_COUNT=1 \
GIT_CONFIG_KEY_0="http.https://github.com/.extraheader" \
GIT_CONFIG_VALUE_0="AUTHORIZATION: basic ${AUTH_B64}" \
GIT_TERMINAL_PROMPT=0 \
git -C "${SRC_DIR}" fetch --tags --force origin

TAG_COMMIT_SHA="$(git -C "${SRC_DIR}" rev-parse "refs/tags/${GIT_TAG}^{commit}")"
if [[ "${TAG_COMMIT_SHA}" != "${EXPECTED_COMMIT_SHA}"* && "${EXPECTED_COMMIT_SHA}" != "${TAG_COMMIT_SHA}"* ]]; then
  echo "ERRO FATAL DE SEGURANCA (ANTI-TAMPERING / TOCTOU): A tag '${GIT_TAG}' resolve para '${TAG_COMMIT_SHA}', divergindo do commit auditado e aprovado no PR ('${EXPECTED_COMMIT_SHA}')! Deploy abortado!" >&2
  exit 1
fi

git -C "${SRC_DIR}" checkout "refs/tags/${GIT_TAG}"
COUNTS="$(git -C "${SRC_DIR}" rev-list --left-right --count "origin/main...refs/tags/${GIT_TAG}" || echo "0	0")"
BEHIND_MAIN="$(echo "${COUNTS}" | awk '{print $1}')"
AHEAD_MAIN="$(echo "${COUNTS}" | awk '{print $2}')"
COMPARE_URL="https://github.com/${GITHUB_ORG}/${SOLUTION_REPO}/compare/main...${GIT_TAG}"
echo "Tag verificada com sucesso: ${GIT_TAG} -> ${TAG_COMMIT_SHA} (${AHEAD_MAIN} ahead, ${BEHIND_MAIN} behind main | ${COMPARE_URL})"

if [[ ! -d "${SRC_DIR}/infra/terraform" ]]; then
  echo "ERRO: A tag ${GIT_TAG} em ${SOLUTION_REPO} nao contem infra/terraform preparado para o deploy." >&2
  exit 1
fi

echo "=== [2.5/7] Enforcing Mandatory SARIF v2.1.0 Gatekeeper Report on ${GIT_TAG} ==="
if [[ ! -f "${SRC_DIR}/security/sarif-audit-report.sarif.json" ]]; then
  echo "ERRO FATAL DE SEGURANCA (SARIF GATE): O relatorio 'security/sarif-audit-report.sarif.json' nao existe na branch/tag '${GIT_TAG}' de ${SOLUTION_REPO}! Deploy bloqueado!" >&2
  exit 1
fi
python3 - "${SRC_DIR}/security/sarif-audit-report.sarif.json" <<'PY'
import json, pathlib, sys
sarif = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
if sarif.get("version") != "2.1.0":
    raise SystemExit("ERRO SARIF: version != 2.1.0")
runs = sarif.get("runs", [])
blocking = [
    r for r in (runs[0].get("results", []) if runs else [])
    if str(r.get("level", "")).lower() in ("error", "high", "critical")
]
if blocking:
    raise SystemExit(f"BLOQUEIO SARIF: {len(blocking)} vulnerabilidade(s) critica(s) na tag!")
print("[SARIF-GATE] Relatorio SARIF v2.1.0 validado na branch gcp/sandbox (0 vulnerabilidades bloqueantes).")
PY

echo "=== [3/7] Building Backend/API Container(s) & Static SPA GCS Bundle in Cloud Build ==="
API_IMAGE="${AR_REPO}/${WORKLOAD_SLUG}-api:${SHORT_SHA}"
BFF_IMAGE="${AR_REPO}/${WORKLOAD_SLUG}-bff:${SHORT_SHA}"
SPA_STAGE_GCS_URI="gs://${TF_BUCKET}/spa-artifacts/${WORKLOAD_SLUG}-${SHORT_SHA}.tar.gz"

if [[ -f "${SRC_DIR}/deploy/gcp/cloudbuild.yaml" ]]; then
  SUBS="_API_IMAGE=${API_IMAGE},_SPA_STAGE_GCS_URI=${SPA_STAGE_GCS_URI}"
  if grep -q "_BFF_IMAGE" "${SRC_DIR}/deploy/gcp/cloudbuild.yaml"; then
    SUBS="${SUBS},_BFF_IMAGE=${BFF_IMAGE}"
  fi
  gcloud builds submit "${SRC_DIR}" \
    --project="${TARGET_GCP_PROJECT}" \
    --config="${SRC_DIR}/deploy/gcp/cloudbuild.yaml" \
    --substitutions="${SUBS}" \
    --quiet
elif [[ -f "${SRC_DIR}/Dockerfile" ]]; then
  gcloud builds submit "${SRC_DIR}" \
    --project="${TARGET_GCP_PROJECT}" \
    --tag="${API_IMAGE}" \
    --quiet
else
  echo "ERRO: Nenhum deploy/gcp/cloudbuild.yaml ou Dockerfile encontrado em ${SOLUTION_REPO}@${GIT_TAG}." >&2
  exit 1
fi

echo "=== [4/7] Initializing Terraform & Reconciling Shared Singleton GCLB / DB / Redis State ==="
TF_BUNDLE="/tmp/tf-bundle-${WORKLOAD_SLUG}.tar.gz"
tar -czf "${TF_BUNDLE}" -C "${SRC_DIR}" infra/terraform functions 2>/dev/null || tar -czf "${TF_BUNDLE}" -C "${SRC_DIR}" infra/terraform
gcloud storage cp "${TF_BUNDLE}" "gs://${TF_BUCKET}/workloads/${WORKLOAD_SLUG}/tf-bundle.tar.gz" --project="${TARGET_GCP_PROJECT}" --quiet
rm -fv "${TF_BUNDLE}" >/dev/null

VARS_JSON="/tmp/tf-vars-${WORKLOAD_SLUG}.json"
NOW_PRE="$(date -u +%s)"
EXP_PRE="$((NOW_PRE + TTL_MINUTES * 60))"

python3 - "${VARS_JSON}" <<PY
import json, os, sys
emails = [e.strip() for e in os.environ["ALERT_EMAILS_CSV"].split(",") if e.strip()]
budget = float(os.environ["BUDGET_BRL"])
ttl_safe = "".join(c if c.isalnum() or c in "_-" else "-" for c in os.environ["TTL_LABEL"].lower())
payload = {
    "project_id": os.environ["TARGET_GCP_PROJECT"],
    "region": "${REGION}",
    "workload_slug": os.environ["WORKLOAD_SLUG"],
    "database_type": os.environ["DATABASE_TYPE"],
    "enable_redis": os.environ["ENABLE_REDIS"].lower() == "true",
    "shared_db_already_exists": False,
    "shared_redis_already_exists": False,
    "shared_gclb_already_exists": False,
    "budget_brl": budget,
    "budget_brl_label": str(int(round(budget))),
    "ttl_label": ttl_safe,
    "ttl_minutes": int(os.environ["TTL_MINUTES"]),
    "expires_at_epoch": "${EXP_PRE}",
    "alert_emails": emails,
    "slo_availability_goal": float(os.environ["SLO_AVAILABILITY_GOAL"]),
    "slo_latency_p95_ms": int(os.environ["SLO_LATENCY_P95_MS"]),
    "api_image": "${API_IMAGE}",
    "bff_image": "${BFF_IMAGE}",
}
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    json.dump(payload, fh, indent=2)
    fh.write("\n")
PY

terraform -chdir="${SRC_DIR}/infra/terraform" init \
  -backend-config="bucket=${TF_BUCKET}" \
  -backend-config="prefix=workloads/${WORKLOAD_SLUG}" \
  -input=false

if [[ -f "${SRC_DIR}/infra/terraform/reconcile_shared_state.sh" ]]; then
  chmod +x "${SRC_DIR}/infra/terraform/reconcile_shared_state.sh"
  "${SRC_DIR}/infra/terraform/reconcile_shared_state.sh" \
    "${TARGET_GCP_PROJECT}" \
    "${REGION}" \
    "${SRC_DIR}/infra/terraform" \
    "${VARS_JSON}"
fi

gcloud storage cp "${VARS_JSON}" "gs://${TF_BUCKET}/workloads/${WORKLOAD_SLUG}/vars.json" --project="${TARGET_GCP_PROJECT}" --quiet

echo "=== [5/7] Applying Shared Singletons + GCLB .nip.io + SPA GCS Bucket + Cloud Run v2 + Pub/Sub + SRE Terraform ==="
terraform -chdir="${SRC_DIR}/infra/terraform" apply \
  -auto-approve \
  -input=false \
  -var-file="${VARS_JSON}"

TF_OUT_JSON="$(terraform -chdir="${SRC_DIR}/infra/terraform" output -json)"
rm -fv "${VARS_JSON}" >/dev/null

WEB_URL="$(echo "${TF_OUT_JSON}" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("web_url",{}).get("value",""))')"
BFF_URL="$(echo "${TF_OUT_JSON}" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("bff_url",{}).get("value",""))')"
API_URL="$(echo "${TF_OUT_JSON}" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("api_url",{}).get("value",""))')"
GCLB_IP="$(echo "${TF_OUT_JSON}" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("gclb_ip",{}).get("value",""))')"
SHORT_SLUG="$(echo "${TF_OUT_JSON}" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("short_slug",{}).get("value",""))')"
SPA_BUCKET="$(echo "${TF_OUT_JSON}" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("spa_gcs_bucket",{}).get("value",""))')"
API_PREFIX_FLAG="$(echo "${TF_OUT_JSON}" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(str(d.get("api_uses_global_prefix",{}).get("value",True)).lower())')"
SEP_BFF_FLAG="$(echo "${TF_OUT_JSON}" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(str(d.get("has_separate_bff",{}).get("value",False)).lower())')"
DASHBOARD_URL="$(echo "${TF_OUT_JSON}" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("monitoring_dashboard_url",{}).get("value",""))')"
SHARED_SQL="$(echo "${TF_OUT_JSON}" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("shared_sql_instance",{}).get("value",""))')"
SHARED_REDIS="$(echo "${TF_OUT_JSON}" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("shared_redis_instance",{}).get("value",""))')"

echo "=== [6/7] Publishing Static SPA Assets to GCS BackendBucket & Registering .nip.io Routes on GCLB ==="
if [[ -n "${SPA_BUCKET}" ]]; then
  SPA_TAR="/tmp/spa-${WORKLOAD_SLUG}.tar.gz"
  if gcloud storage cp "${SPA_STAGE_GCS_URI}" "${SPA_TAR}" --project="${TARGET_GCP_PROJECT}" --quiet 2>/dev/null; then
    tar -xzf "${SPA_TAR}" -C "${SPA_EXTRACT_DIR}"
    rm -fv "${SPA_TAR}" >/dev/null
    gcloud storage cp --recursive --cache-control="public, max-age=31536000, immutable" "${SPA_EXTRACT_DIR}"/* "gs://${SPA_BUCKET}/" --project="${TARGET_GCP_PROJECT}" --quiet
    if [[ -f "${SPA_EXTRACT_DIR}/index.html" ]]; then
      gcloud storage cp --cache-control="no-cache, no-store, must-revalidate" "${SPA_EXTRACT_DIR}/index.html" "gs://${SPA_BUCKET}/index.html" --project="${TARGET_GCP_PROJECT}" --quiet
    fi
  fi
fi

if [[ -n "${GCLB_IP}" && -n "${SHORT_SLUG}" ]]; then
  python3 "${APPROVALS_ROOT}/scripts/reconcile_shared_gclb_routes.py" upsert \
    --project="${TARGET_GCP_PROJECT}" \
    --short-slug="${SHORT_SLUG}" \
    --gclb-ip="${GCLB_IP}" \
    --api-uses-global-prefix="${API_PREFIX_FLAG}" \
    --has-separate-bff="${SEP_BFF_FLAG}"
fi

echo "=== [7/7] Recording Active Lease & Exact TTL Timer (${TTL_LABEL}) ==="
mkdir -p "${APPROVALS_ROOT}/active-leases"
DEPLOYED_EPOCH="$(date -u +%s)"
DEPLOYED_AT_UTC="$(date -u -d "@${DEPLOYED_EPOCH}" +"%Y-%m-%dT%H:%M:%SZ")"
EXPIRES_AT_EPOCH="$((DEPLOYED_EPOCH + TTL_MINUTES * 60))"
EXPIRES_AT_UTC="$(date -u -d "@${EXPIRES_AT_EPOCH}" +"%Y-%m-%dT%H:%M:%SZ")"
cat <<EOF > "${APPROVALS_ROOT}/active-leases/${WORKLOAD_SLUG}.json"
{
  "workload_slug": "${WORKLOAD_SLUG}",
  "short_slug": "${SHORT_SLUG}",
  "status": "ACTIVE",
  "target_gcp_project": "${TARGET_GCP_PROJECT}",
  "region": "${REGION}",
  "github_org": "${GITHUB_ORG}",
  "solution_repo": "${SOLUTION_REPO}",
  "git_tag": "${GIT_TAG}",
  "deployed_commit_sha": "${TAG_COMMIT_SHA}",
  "commits_ahead_of_main": ${AHEAD_MAIN},
  "commits_behind_main": ${BEHIND_MAIN},
  "compare_against_main_url": "${COMPARE_URL}",
  "gclb_ip": "${GCLB_IP}",
  "spa_gcs_bucket": "${SPA_BUCKET}",
  "database_type": "${DATABASE_TYPE}",
  "shared_sql_instance": "${SHARED_SQL}",
  "shared_redis_instance": "${SHARED_REDIS}",
  "alert_emails": "${ALERT_EMAILS_CSV}",
  "monitoring_dashboard_url": "${DASHBOARD_URL}",
  "budget_brl": ${BUDGET_BRL},
  "ttl": "${TTL_LABEL}",
  "ttl_minutes": ${TTL_MINUTES},
  "deployed_at_utc": "${DEPLOYED_AT_UTC}",
  "expires_at_utc": "${EXPIRES_AT_UTC}",
  "expires_at_epoch": ${EXPIRES_AT_EPOCH},
  "web_url": "${WEB_URL}",
  "bff_url": "${BFF_URL}",
  "api_url": "${API_URL}",
  "teardown_mode": "terraform_destroy_workload_only",
  "terraform_state_uri": "gs://${TF_BUCKET}/workloads/${WORKLOAD_SLUG}"
}
EOF

CRON_EXPR="$(python3 - "${EXPIRES_AT_EPOCH}" <<'PY'
import datetime, sys
dt = datetime.datetime.fromtimestamp(int(sys.argv[1]) + 60, tz=datetime.timezone.utc)
print(f"{dt.minute} {dt.hour} {dt.day} {dt.month} *")
PY
)"
SCHED_JOB="ttl-exp-${WORKLOAD_SLUG}"
TRIGGER_URI="https://api.github.com/repos/${GITHUB_ORG}/cloud-provisioning-approvals/contents/teardown-triggers/${WORKLOAD_SLUG}-${EXPIRES_AT_EPOCH}.json"
TRIGGER_CONTENT_B64="$(printf '{"workload_slug":"%s","expires_at_utc":"%s","ttl":"%s"}\n' "${WORKLOAD_SLUG}" "${EXPIRES_AT_UTC}" "${TTL_LABEL}" | base64 -w 0)"
TRIGGER_BODY="$(printf '{"message":"chore(ttl-trigger): auto-expire %s after %s","branch":"main","content":"%s"}' "${WORKLOAD_SLUG}" "${TTL_LABEL}" "${TRIGGER_CONTENT_B64}")"

gcloud scheduler jobs delete "${SCHED_JOB}" --location="${REGION}" --project="${TARGET_GCP_PROJECT}" --quiet >/dev/null 2>&1 || true
gcloud scheduler jobs create http "${SCHED_JOB}" \
  --location="${REGION}" \
  --project="${TARGET_GCP_PROJECT}" \
  --schedule="${CRON_EXPR}" \
  --time-zone="Etc/UTC" \
  --uri="${TRIGGER_URI}" \
  --http-method=PUT \
  --headers="Authorization=Bearer ${GH_PAT},Accept=application/vnd.github+json,Content-Type=application/json,X-GitHub-Api-Version=2022-11-28,User-Agent=detran-ttl-scheduler" \
  --message-body="${TRIGGER_BODY}" \
  --quiet || echo "Aviso: Cloud Scheduler secundario nao criado; o cron do GitHub Actions cobrira o TTL."

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "web_url=${WEB_URL}"
    echo "bff_url=${BFF_URL}"
    echo "api_url=${API_URL}"
    echo "dashboard_url=${DASHBOARD_URL}"
    echo "shared_sql_instance=${SHARED_SQL}"
    echo "deployed_at_utc=${DEPLOYED_AT_UTC}"
    echo "expires_at_utc=${EXPIRES_AT_UTC}"
    echo "compare_url=${COMPARE_URL}"
    echo "ahead_main=${AHEAD_MAIN}"
    echo "behind_main=${BEHIND_MAIN}"
  } >> "${GITHUB_OUTPUT}"
fi

echo "DEPLOY CONCLUIDO: web=${WEB_URL} | bff=${BFF_URL} | api=${API_URL} | dashboard=${DASHBOARD_URL} | TTL=${TTL_LABEL} (expira em ${EXPIRES_AT_UTC})"
