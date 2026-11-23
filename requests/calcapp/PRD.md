# PRD — `calcapp` (Calculadora Simples)

## 1. Visão do Produto

- **Aplicação**: **Calculadora Simples** (`calcapp`) — calculadora interativa
- **Subtítulo**: Operações básicas com histórico
- **Demanda**: CalcApp — Calculadora Simples estilo Windows com as 4 operações principais (+, −, ×, ÷), além de % e ±, visor digital de 2 linhas (expressão digitada e resultado com prévia), teclado 4x5 (C, ⌫, %, ÷, 7-9 ×, 4-6 −, 1-3 +, ± 0 , =), atalhos completos de teclado físico (0-9, +-*/, %, (), Enter/=, Backspace, Esc, vírgula/ponto), avaliador matemático seguro no servidor em POST /api/calcular (tokenizador + shunting-yard sem eval/Function, até 200 caracteres, arredondado a 12 dígitos significativos, HTTP 400 para divisão por zero ou expressão inválida), e painel de histórico com os últimos 20 resultados persistidos em PostgreSQL no schema dedicado calcapp.calculos (iniciando vazio, sem seeds fictícios, clique reutiliza resultado, remoção individual e botão Limpar).
- **Operações**: `+` `−` `×` `÷` `%` `±`
- **Isolamento de Dados**: Cloud SQL PostgreSQL compartilhado (`detran-shared-pgsql`), database `db_calcapp`, schema `calcapp`, tabela `calcapp.calculos`.

## 2. Regras de Negócio

- **RN-001**: Expressão reavaliada no servidor por tokenizador e algoritmo shunting-yard próprios, sem execução dinâmica de código.
- **RN-002**: Aceita apenas dígitos, separador decimal (vírgula ou ponto), + − × ÷, %, parênteses e sinal negativo, com até 200 caracteres.
- **RN-003**: Divisão por zero, caracteres inválidos ou expressão incompleta retornam HTTP 400 com mensagem clara em português.
- **RN-004**: Resultado arredondado a 12 dígitos significativos (ex.: 0,1 + 0,2 = 0,3).
- **RN-005**: Histórico persistido em 'calcapp.calculos', exibido do mais recente para o mais antigo (últimos 20).

## 3. Histórias de Usuário (Gherkin)

### US-001 — Cálculo Básico
```gherkin
Funcionalidade: Calculadora
  Cenário: Operação com precedência
    Dado que o usuário digita "2 + 3 × 4"
    Quando pressiona "=" (tela ou Enter)
    Então o visor mostra o resultado "14" e o cálculo entra no histórico
```

### US-002 — Erro Claro
```gherkin
Funcionalidade: Validação
  Cenário: Divisão por zero
    Dado que o usuário digita "10 ÷ 0"
    Quando pressiona "="
    Então o visor exibe "Divisão por zero não é permitida."
```

### US-003 — Histórico
```gherkin
Funcionalidade: Histórico
  Cenário: Reutilizar resultado
    Dado um cálculo anterior no histórico
    Quando o usuário clica no item
    Então o resultado volta ao visor para continuar a conta
```

## 4. Telas e Componentes (React 18 + TypeScript + Vite)

- **Faixa Institucional Fixa**: `"Ambiente Governado DTI (detran-gemini)"`.
- **Cabeçalho**: título `Calculadora Simples` e indicador do modo de armazenamento.
- **Visor de 2 linhas**: expressão + resultado (prévia enquanto digita).
- **Teclado**: `0`–`9`, `,`, `+` `−` `×` `÷` `%` `±`, `C`, `⌫`, `=` + atalhos do teclado físico.
- **Histórico**: últimos 20 resultados, clique para reutilizar, `×` remove, `Limpar` apaga tudo.

## 5. Contrato REST (Node.js 22 + Cloud Run v2)

| Método | Rota | Descrição | Códigos HTTP |
|---|---|---|---|
| `GET` | `/api/health · /api/status` | Saúde do serviço, modo de armazenamento, database e schema | `200` |
| `GET` | `/api/spec` | Contrato da aplicação (título, operações e limite do histórico) | `200` |
| `POST` | `/api/calcular` | Valida e reavalia `{expressao}` no servidor e grava no histórico | `201, 400, 413` |
| `GET` | `/api/calculos?limit=` | Histórico do mais recente para o mais antigo | `200` |
| `DELETE` | `/api/calculos/:id` | Remove um cálculo do histórico | `200, 400, 404` |
| `DELETE` | `/api/calculos` | Limpa todo o histórico | `200` |

## 6. Dados

- Tabela `calcapp.calculos` criada por `sql/001_init_and_seed.sql`; **histórico inicia vazio**.

## 7. Parâmetros de Governança no Sandbox (`detran-gemini`)

- **Orçamento Máximo (`budget_brl`)**: R$ 150.00
- **Tempo de Vida (`ttl`)**: `1h` (contado após validação do certificado HTTPS gerenciado)
- **Canais de Alerta SRE (`alert_emails`)**: `definido no manifesto de aprovação`