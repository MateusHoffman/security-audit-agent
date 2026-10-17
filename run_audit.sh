#!/usr/bin/env bash
set -euo pipefail

echo "=== Agente de auditoria de segurança ==="

ROOT_DIR="${ROOT_DIR:-$(pwd)}"
cd "$ROOT_DIR"

SKILL_REPO="${SKILL_REPO:-https://github.com/cloudflare/security-audit-skill}"
SKILL_REF="${SKILL_REF:-main}"
AI_MODEL="${AI_MODEL:-deepseek/deepseek-v4.1-flash}"
OPENCODE_MODEL="openrouter/${AI_MODEL}"
REPORT_FILE="${REPORT_FILE:-security-audit-report.md}"

install_opencode() {
  if command -v opencode >/dev/null 2>&1; then
    return 0
  fi
  if ! command -v npm >/dev/null 2>&1; then
    echo "Erro: Node.js/npm é necessário para instalar o OpenCode (@opencode/cli)." >&2
    exit 1
  fi
  echo "Instalando OpenCode CLI..."
  npm install -g @opencode/cli --allow-scripts=@opencode/cli
}

install_security_audit_skill() {
  local skill_dir=".agents/skills/security-audit"
  if [[ -f "${skill_dir}/SKILL.md" && -f "${skill_dir}/HUNTING.md" ]]; then
    echo "Skill security-audit já presente em ${skill_dir}"
    return 0
  fi
  echo "Baixando skill security-audit da Cloudflare..."
  mkdir -p "${skill_dir}"
  local archive="/tmp/security-audit-skill-${SKILL_REF}.tar.gz"
  local extract_dir
  extract_dir="$(mktemp -d)"
  curl -fsSL "${SKILL_REPO}/archive/refs/heads/${SKILL_REF}.tar.gz" -o "${archive}"
  tar -xzf "${archive}" -C "${extract_dir}"
  shopt -s nullglob
  local bundled=("${extract_dir}"/security-audit-skill-*/skills/security-audit)
  if [[ ${#bundled[@]} -eq 0 || ! -f "${bundled[0]}/SKILL.md" ]]; then
    echo "Erro: não foi possível localizar skills/security-audit no tarball da Cloudflare." >&2
    exit 1
  fi
  cp -a "${bundled[0]}/." "${skill_dir}/"
  rm -rf "${extract_dir}" "${archive}"
}

write_opencode_config() {
  mkdir -p .opencode
  if [[ ! -f opencode.json && ! -f .opencode/opencode.json ]]; then
    cat > opencode.json <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "bash": "allow",
    "edit": "allow",
    "read": "allow",
    "glob": "allow",
    "grep": "allow",
    "skill": {
      "*": "allow"
    }
  }
}
EOF
  fi
}

detect_pr_context() {
  PR_CONTEXT=""
  if [[ -n "${GITHUB_BASE_REF:-}" ]]; then
    PR_CONTEXT="GitHub PR: base=${GITHUB_BASE_REF}, head=${GITHUB_HEAD_REF:-HEAD}"
  elif [[ -n "${BITBUCKET_PR_ID:-}" ]]; then
    PR_CONTEXT="Bitbucket PR #${BITBUCKET_PR_ID}: ${BITBUCKET_PR_DESTINATION_BRANCH:-} <- ${BITBUCKET_BRANCH:-}"
  fi
}

build_prompt() {
  local prompt_file="${1:-prompt.txt}"
  if [[ ! -f "$prompt_file" ]]; then
    echo "Erro: arquivo de prompt não encontrado: $prompt_file" >&2
    exit 1
  fi
  local base_prompt
  base_prompt="$(cat "$prompt_file")"
  detect_pr_context
  cat <<EOF
${base_prompt}

---
Contexto de execução (CI):
- Diretório alvo (repositório): ${ROOT_DIR}
- Relatório final obrigatório: ${ROOT_DIR}/${REPORT_FILE}
- Modelo: ${OPENCODE_MODEL}
${PR_CONTEXT:+- ${PR_CONTEXT}}
- Priorize o diff do PR (merge-base com a branch base) quando houver alterações versionadas.
- Ao concluir, garanta que ${REPORT_FILE} exista na raiz do repositório com resumo executivo, achados por severidade e recomendações.
EOF
}

require_openrouter_key() {
  if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
    echo "Erro: defina o secret OPENROUTER_API_KEY (OpenRouter)." >&2
    exit 1
  fi
  export OPENROUTER_API_KEY
}

main() {
  require_openrouter_key
  install_opencode
  install_security_audit_skill
  write_opencode_config

  export OPENCODE_DISABLE_AUTOUPDATE=true
  export OPENCODE_CLIENT=security-audit-agent

  local full_prompt
  full_prompt="$(build_prompt "${PROMPT_FILE:-prompt.txt}")"

  echo "=== Executando auditoria (modelo ${OPENCODE_MODEL}) ==="

  opencode run \
    --standalone \
    --auto \
    --model "${OPENCODE_MODEL}" \
    --title "security-audit-pr" \
    "${full_prompt}"

  if [[ ! -f "${REPORT_FILE}" ]]; then
    echo "Aviso: ${REPORT_FILE} não foi gerado. Verifique os logs do OpenCode acima." >&2
    exit 1
  fi

  echo "=== Auditoria concluída: ${REPORT_FILE} ==="
}

main "$@"
