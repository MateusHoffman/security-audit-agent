# Security Runner (OpenCode + Cloudflare)

Pipeline **zero atrito** para rodar auditoria de segurança em pull requests usando [OpenCode](https://opencode.ai/), o modelo que você escolher via [OpenRouter](https://openrouter.ai/) e a skill oficial [security-audit](https://github.com/cloudflare/security-audit-skill) da Cloudflare.

O repositório do **cliente** não precisa copiar scripts nem skills: o CI baixa `run_audit.sh` e `prompt.txt` deste runner e gera o artefato `security-audit-report.md`.

---

## O que você precisa antes de começar

| Item | Descrição |
|------|-----------|
| Conta OpenRouter | [openrouter.ai](https://openrouter.ai/) — crie uma API key |
| Repositório deste runner | Publicado no GitHub (ou espelhado) com branch `main` |
| Node.js no CI | GitHub Actions e a imagem Bitbucket usadas aqui já incluem Node 20 |

**Custo:** cada execução consome créditos do OpenRouter conforme o modelo (`AI_MODEL`). Modelos mais baratos (ex.: DeepSeek) reduzem custo; modelos premium (Claude, GPT) aumentam qualidade.

---

## Passo 1 — Publicar o runner (quem mantém o harness)

1. Faça push deste repositório para o GitHub (ex.: `https://github.com/seu-usuario/security-runner`).
2. Anote a URL **raw** dos arquivos na branch padrão:

   ```text
   https://raw.githubusercontent.com/seu-usuario/security-runner/main
   ```

   Substitua `seu-usuario` e `security-runner` pelos seus valores reais. Se a branch padrão for `master`, use `master` no lugar de `main`.

---

## Passo 2 — Chave e modelo (em todo repositório auditado)

### OpenRouter

1. Acesse [OpenRouter → Keys](https://openrouter.ai/keys).
2. Crie uma chave com permissão de uso da API.
3. Guarde a chave — ela será usada apenas como secret/variável no CI, nunca no código.

### Modelo (opcional)

ID no formato OpenRouter, **sem** o prefixo `openrouter/`:

| Exemplo de `AI_MODEL` | Uso típico |
|----------------------|------------|
| `deepseek/deepseek-chat` | Default do runner; bom custo/benefício |
| `anthropic/claude-sonnet-4` | Revisões mais profundas |
| `openai/gpt-4o` | Alternativa generalista |

Se `AI_MODEL` não for definido, o runner usa `deepseek/deepseek-chat`.

---

## Implementação no GitHub Actions

### 1. Secrets do repositório auditado

No repositório **do projeto** (não no runner):

**Settings → Secrets and variables → Actions → New repository secret**

| Nome | Obrigatório | Valor |
|------|-------------|--------|
| `OPENROUTER_API_KEY` | Sim | Sua chave OpenRouter |
| `AI_MODEL` | Não | Ex.: `deepseek/deepseek-chat` |

### 2. Workflow

Crie o arquivo `.github/workflows/security-audit.yml` na raiz do projeto. Você pode copiar o template deste repo:

[`templates/github/workflows/security-audit.yml`](templates/github/workflows/security-audit.yml)

**Ajuste obrigatório:** na linha `SECURITY_RUNNER_RAW_URL`, troque `SEU_USUARIO/security-runner` pela URL raw do **seu** runner (Passo 1).

Exemplo mínimo:

```yaml
name: Zero-Friction Security Audit (OpenCode)

on:
  pull_request:
    branches: [main, master, develop]

jobs:
  security-audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: actions/setup-node@v4
        with:
          node-version: "20"

      - name: Run OpenCode Security Harness
        env:
          SECURITY_RUNNER_RAW_URL: https://raw.githubusercontent.com/seu-usuario/security-runner/main
          OPENROUTER_API_KEY: ${{ secrets.OPENROUTER_API_KEY }}
          AI_MODEL: ${{ secrets.AI_MODEL }}
        run: |
          curl -fsSL "${SECURITY_RUNNER_RAW_URL}/run_audit.sh" -o run_audit.sh
          curl -fsSL "${SECURITY_RUNNER_RAW_URL}/prompt.txt" -o prompt.txt
          chmod +x run_audit.sh
          ./run_audit.sh

      - uses: actions/upload-artifact@v4
        with:
          name: security-audit-report
          path: security-audit-report.md
```

### 3. Validar

1. Abra um pull request para `main`, `master` ou `develop`.
2. Aguarde o job **Zero-Friction Security Audit (OpenCode)**.
3. Baixe o artefato **security-audit-report** na run do Actions ou abra `security-audit-report.md` se o job commitar/comentar (por padrão só artifact).

### 4. Branches e gatilhos

Para auditar PRs em outras branches base, edite `on.pull_request.branches` no YAML.

---

## Implementação no Bitbucket Pipelines

### 1. Habilitar Pipelines

**Repository settings → Pipelines → Settings → Enable Pipelines**

### 2. Variáveis do repositório

**Repository settings → Pipelines → Repository variables**

| Nome | Secured | Valor |
|------|---------|--------|
| `OPENROUTER_API_KEY` | Sim | Sua chave OpenRouter |
| `AI_MODEL` | Não (opcional) | Ex.: `deepseek/deepseek-chat` |
| `SECURITY_RUNNER_RAW_URL` | Não (opcional) | URL raw do runner; se omitir, use o default no YAML |

Variáveis **Secured** ficam disponíveis como variáveis de ambiente nos steps (Bitbucket não exibe o valor nos logs).

### 3. `bitbucket-pipelines.yml`

Na raiz do repositório auditado, crie ou mescle o trecho abaixo em `bitbucket-pipelines.yml`. Template completo: [`templates/bitbucket-pipelines.yml`](templates/bitbucket-pipelines.yml).

**Ajuste obrigatório:** substitua `SEU_USUARIO/security-runner` na URL default ou defina `SECURITY_RUNNER_RAW_URL` nas variáveis do repositório.

```yaml
pipelines:
  pull-requests:
    "**":
      - step:
          name: Zero-Friction Security Audit (OpenCode)
          image: node:20-slim
          script:
            - apt-get update && apt-get install -y curl git
            - export SECURITY_RUNNER_RAW_URL="${SECURITY_RUNNER_RAW_URL:-https://raw.githubusercontent.com/seu-usuario/security-runner/main}"
            - curl -fsSL "${SECURITY_RUNNER_RAW_URL}/run_audit.sh" -o run_audit.sh
            - curl -fsSL "${SECURITY_RUNNER_RAW_URL}/prompt.txt" -o prompt.txt
            - chmod +x run_audit.sh
            - ./run_audit.sh
          artifacts:
            - security-audit-report.md
```

Se você já tem outros pipelines, mantenha a chave `pipelines:` única e adicione apenas o bloco `pull-requests` (ou integre este `step` na sua definição existente de PR).

### 4. Validar

1. Abra um pull request qualquer.
2. Confira o step **Zero-Friction Security Audit (OpenCode)**.
3. Baixe **Artifacts** → `security-audit-report.md`.

---

## Teste local (opcional)

Útil para depurar antes de abrir PR:

```bash
export OPENROUTER_API_KEY="sk-or-..."
export AI_MODEL="deepseek/deepseek-chat"   # opcional

cd /caminho/do/seu-repositorio
curl -fsSL "https://raw.githubusercontent.com/seu-usuario/security-runner/main/run_audit.sh" -o run_audit.sh
curl -fsSL "https://raw.githubusercontent.com/seu-usuario/security-runner/main/prompt.txt" -o prompt.txt
chmod +x run_audit.sh
./run_audit.sh
```

O relatório aparece em `./security-audit-report.md`.

---

## O que acontece em cada execução

1. Instala o CLI **OpenCode** (`@opencode/cli`) se ainda não existir no ambiente.
2. Baixa a skill **security-audit** da Cloudflare para `.agents/skills/security-audit/`.
3. Configura permissões do OpenCode para modo CI (`--standalone --auto`).
4. Envia o prompt (foco no diff do PR + skill completa).
5. Exige que `security-audit-report.md` exista na raiz; caso contrário o job falha.

Arquivos gerados localmente (`.agents/`, `opencode.json`) estão no `.gitignore` sugerido do runner; **não** é necessário commitá-los no projeto auditado.

---

## Solução de problemas

| Sintoma | O que verificar |
|---------|------------------|
| `OPENROUTER_API_KEY` ausente | Secret/variável no repo certo (projeto auditado, não só no runner) |
| Falha ao baixar `run_audit.sh` | URL raw correta; repo público ou token se privado |
| Job OK mas sem relatório | Logs do OpenCode; modelo inválido ou quota OpenRouter |
| Modelo não encontrado | Confira o ID em [OpenRouter Models](https://openrouter.ai/models); use só o sufixo em `AI_MODEL` |
| PR sem diff relevante | Comportamento esperado; o relatório pode indicar ausência de achados |

Para repositório **privado** do runner, use URL com token (GitHub fine-grained ou variável `SECURITY_RUNNER_RAW_URL` apontando para fork público) ou copie `run_audit.sh` e `prompt.txt` para um repo interno acessível pelo CI.

---

## Estrutura deste repositório

```text
.
├── run_audit.sh          # Script central executado no CI
├── prompt.txt            # Instruções do agente (pt-BR)
├── templates/
│   ├── github/workflows/security-audit.yml
│   └── bitbucket-pipelines.yml
└── README.md
```

---

## Licença e créditos

- Skill de auditoria: [Cloudflare security-audit-skill](https://github.com/cloudflare/security-audit-skill)
- Agente CLI: [OpenCode](https://opencode.ai/)
- Modelos: [OpenRouter](https://openrouter.ai/)
