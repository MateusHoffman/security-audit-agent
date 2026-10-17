# Agente de auditoria de segurança

Guia de instalação do **security-audit-agent** no **repositório do seu projeto**. A cada pull request, o CI gera **`security-audit-report.md`** com achados de segurança no código alterado.

Você precisa de uma conta [OpenRouter](https://openrouter.ai/) (API key + créditos). O modelo de IA é configurável; o padrão é econômico e funciona sem secret extra.

---

## Checklist

- [ ] Criar API key no OpenRouter
- [ ] Cadastrar secret/variável no **repo do seu projeto**
- [ ] Colar o YAML abaixo (GitHub **ou** Bitbucket)
- [ ] Abrir um PR e baixar o artefato do relatório

---

## 1. OpenRouter

1. Crie conta em [openrouter.ai](https://openrouter.ai/).
2. Adicione créditos se pedido (cada execução do pipeline consome saldo).
3. Em [openrouter.ai/keys](https://openrouter.ai/keys), **Create Key** e copie a chave (`sk-or-...`).
4. **Não** commite a chave no código.

### Modelo (opcional)

No CI, secret/variável `AI_MODEL` = ID do modelo em [openrouter.ai/models](https://openrouter.ai/models) (copie o **Model ID**).

| Se `AI_MODEL` estiver… | Comportamento |
|------------------------|---------------|
| vazio | `deepseek/deepseek-v4.1-flash` |
| `anthropic/claude-sonnet-4` | revisão mais forte |
| `openai/gpt-4o` | alternativa generalista |

---

## 2. Escolha sua plataforma

Abra só o bloco que você usa.

<details>
<summary><strong>GitHub Actions</strong></summary>

### Secrets

No **repositório do seu projeto** no GitHub:

**Settings → Secrets and variables → Actions → New repository secret**

| Name | Obrigatório |
|------|-------------|
| `OPENROUTER_API_KEY` | Sim — cole a chave OpenRouter |
| `AI_MODEL` | Não — ex.: `deepseek/deepseek-v4.1-flash` |

### Workflow

1. Crie `.github/workflows/security-audit.yml` na raiz do projeto.
2. Cole:

```yaml
name: Agente de auditoria de segurança

on:
  pull_request:
    branches: [main, master, develop]

jobs:
  security-audit:
    name: Agente de auditoria de segurança
    runs-on: ubuntu-latest
    steps:
      - name: Checkout do repositório
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"

      - name: Executar agente de auditoria
        env:
          SECURITY_RUNNER_RAW_URL: https://raw.githubusercontent.com/MateusHoffman/security-audit-agent/main
          OPENROUTER_API_KEY: ${{ secrets.OPENROUTER_API_KEY }}
          AI_MODEL: ${{ secrets.AI_MODEL }}
        run: |
          curl -fsSL "${SECURITY_RUNNER_RAW_URL}/run_audit.sh" -o run_audit.sh
          curl -fsSL "${SECURITY_RUNNER_RAW_URL}/prompt.txt" -o prompt.txt
          chmod +x run_audit.sh
          ./run_audit.sh

      - name: Publicar relatório
        uses: actions/upload-artifact@v4
        with:
          name: security-audit-report
          path: security-audit-report.md
```

3. Commit e push (ou abra PR só com esse arquivo).

### Ver o relatório

1. Abra um **Pull Request** para `main`, `master` ou `develop`.
2. **Actions** → run **Agente de auditoria de segurança**.
3. **Artifacts** → `security-audit-report`.

Para outra branch base, altere `branches:` em `on.pull_request`.

</details>

<details>
<summary><strong>Bitbucket Pipelines</strong></summary>

### Habilitar Pipelines

**Repository settings → Pipelines → Settings → Enable Pipelines**

### Variáveis

**Repository settings → Pipelines → Repository variables**

| Name | Secured | Obrigatório |
|------|---------|-------------|
| `OPENROUTER_API_KEY` | Sim ✓ | Sim |
| `AI_MODEL` | Não | Não |

### Pipeline

1. Na raiz do projeto, crie ou edite `bitbucket-pipelines.yml`.
2. Se já existir pipeline, mescle o bloco `pull-requests` (deixe uma única chave `pipelines:` no arquivo).
3. Cole (ou integre):

```yaml
pipelines:
  pull-requests:
    "**":
      - step:
          name: Agente de auditoria de segurança
          image: node:20-slim
          script:
            - apt-get update && apt-get install -y curl git
            - export SECURITY_RUNNER_RAW_URL="https://raw.githubusercontent.com/MateusHoffman/security-audit-agent/main"
            - curl -fsSL "${SECURITY_RUNNER_RAW_URL}/run_audit.sh" -o run_audit.sh
            - curl -fsSL "${SECURITY_RUNNER_RAW_URL}/prompt.txt" -o prompt.txt
            - chmod +x run_audit.sh
            - ./run_audit.sh
          artifacts:
            - security-audit-report.md
```

4. Commit e push.

### Ver o relatório

1. Abra ou atualize um **Pull request**.
2. **Pipelines** → step **Agente de auditoria de segurança**.
3. **Artifacts** → `security-audit-report.md`.

</details>

---

## Problemas comuns

| Sintoma | Solução |
|---------|---------|
| Erro de API key | Confira `OPENROUTER_API_KEY` no repo **do projeto**, nome exato |
| Sem créditos / 401 | Saldo em [openrouter.ai](https://openrouter.ai/) |
| Modelo inválido | ID correto em [Models](https://openrouter.ai/models), secret `AI_MODEL` |
| GitHub: workflow não aparece | Arquivo em `.github/workflows/` na branch do PR |
| Bitbucket: pipeline não roda | Pipelines ligado + PR aberto + YAML válido |
| Job falhou | Abra os logs do step e leia a última mensagem de erro |
