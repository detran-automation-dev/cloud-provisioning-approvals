# PRD — `calculadora-simples`

## Demanda de Negócio
Calculadora simples com operações matemáticas básicas (adição, subtração, multiplicação e divisão), teclado numérico interativo de 0 a 9, vírgula, botões de ação C/AC e igual, visor digital de duas linhas (expressão e resultado), suporte a digitação por teclado físico e histórico auditável persistido em banco de dados PostgreSQL.

## Regras de Negócio & Histórias Gherkin
```json
{
  "status": "success",
  "sistema": "calculadora-simples",
  "demanda_original": "Calculadora simples com operações matemáticas básicas (adição, subtração, multiplicação e divisão), teclado numérico interativo de 0 a 9, vírgula, botões de ação C/AC e igual, visor digital de duas linhas (expressão e resultado), suporte a digitação por teclado físico e histórico auditável persistido em banco de dados PostgreSQL.",
  "publico_alvo": "servidor_interno",
  "escopo_unidades_regionais": true,
  "schema_postgres_sugerido": "calculadora_simples",
  "entidade_principal_pascal": "OperacaoCalculo",
  "provedor_identidade": "Keycloak DETRAN-SP / IAM Corporativo",
  "integracoes_corporativas": [
    "Barramento de Autenticação Corporativa DETRAN-SP",
    "Sistema Integrado de Gestão de Atendimento das Unidades (SIGA-SP)",
    "Repositório Central de Auditoria e Conformidade"
  ],
  "personas_rbac": [
    "OPERADOR_UNIDADE",
    "SUPERVISOR_REGIONAL",
    "AUDITOR_SISTEMA"
  ],
  "opcoes_solucao_agil": [
    {
      "opcao": "SPA Web responsivo com persistência direta síncrona via API REST",
      "custo_relativo": "Baixo",
      "velocidade_entrega": "Alta",
      "vantagem": "Desenvolvimento acelerado com interface intuitiva em duas linhas e gravação direta no schema PostgreSQL"
    },
    {
      "opcao": "SPA com cache local em IndexedDB e sincronização resiliente em lote",
      "custo_relativo": "Médio",
      "velocidade_entrega": "Média",
      "vantagem": "Permite continuidade da digitação durante oscilações de rede com posterior envio das operações"
    },
    {
      "opcao": "Arquitetura de microsserviço isolado em Cloud Run com persistência desacoplada",
      "custo_relativo": "Alto",
      "velocidade_entrega": "Baixa",
      "vantagem": "Isolamento estrito de recursos e capacidade de escala para alto volume de requisições simultâneas"
    }
  ],
  "regras_negocio_canonicas": [
    "RN-001 [BANCO]: Divisão por zero deve ser bloqueada de forma determinística, impedindo inserção de resultado inválido e retornando código padronizado de erro matemático.",
    "RN-002 [SERVIDOR]: A expressão de cálculo submetida deve aceitar apenas dígitos de 0 a 9, vírgula decimal e operadores aritméticos básicos (+, -, *, /), rejeitando qualquer injeção de caracteres externos.",
    "RN-003 [GUARD RBAC]: Apenas operadores e supervisores autenticados e vinculados à respectiva Unidade de Atendimento possuem permissão para executar operações e registrar auditoria.",
    "RN-004 [BANCO]: Toda transação concluída com acionamento da tecla igual deve persistir identificador do servidor, código da unidade regional, timestamp UTC, expressão computada e resultado final.",
    "RN-005 [SERVIDOR]: As ações de limpeza C (Clear Entry) e AC (All Clear) atuam estritamente no estado do visor em memória e não geram chamadas de persistência no banco de dados.",
    "RN-006 [GUARD RBAC]: A visualização do histórico de cálculos é restrita à unidade regional de lotação do usuário, permitindo acesso global exclusivamente ao AUDITOR_SISTEMA."
  ],
  "politica_tradeoff_esforco_waf": {
    "limite_solucao_provisoria_horas": 8,
    "limiar_integracao_definitiva_horas": 40,
    "regra_decisao": "Soluções provisórias descartáveis só são autorizadas se o tempo de entrega for menor ou igual a 8 horas (1 dia). Para demandas que exijam 40 horas ou mais, prioriza-se obrigatoriamente a implementação definitiva com persistência estruturada e integração corporativa, alinhando-se aos pilares de Cost Optimization e Operational Excellence do WAF para prevenir retrabalho.",
    "pilares_waf_associados": [
      "Cost Optimization",
      "Operational Excellence",
      "Reliability",
      "Security"
    ]
  },
  "decisao_assincronicidade": {
    "needs_pubsub_events": false,
    "pubsub_rationale": "A persistência de cálculos simples não demanda desacoplamento via mensageria, sendo tratada via transações síncronas de baixa latência.",
    "needs_cloud_tasks_queue": false,
    "cloud_tasks_rationale": "O fluxo de processamento de operações matemáticas básicas possui tempo de resposta imediato, não necessitando de fila assíncrona de trabalho.",
    "needs_scheduled_jobs": true,
    "scheduled_jobs_rationale": "Necessidade de job programado mensal no Cloud Run Jobs para expurgo ou arquivamento de histórico auditável que ultrapasse a janela legal de retenção de dados."
  },
  "user_stories_gherkin": [
    {
      "id": "US-001",
      "titulo": "Execução de cálculo aritmético com auditoria",
      "gherkin": "Dado que o operador está autenticado na unidade Poupatempo Leste Quando insere '120' seguido de '+' e '80' e clica no botão '=' Então a linha superior exibe a expressão '120 + 80 =' E a linha inferior exibe '200' E o cálculo é gravado no PostgreSQL com identificador da unidade Leste"
    },
    {
      "id": "US-002",
      "titulo": "Tratamento de divisão por zero via teclado numérico",
      "gherkin": "Dado que o visor da calculadora contém o valor '50' Quando o operador aciona a tecla de divisão '/' digita '0' e pressiona 'Enter' no teclado físico Então o visor inferior exibe 'Erro: Divisão por Zero' E nenhuma entrada com valor inconsistente é persistida no banco"
    },
    {
      "id": "US-003",
      "titulo": "Isolamento regional na consulta do histórico auditável",
      "gherkin": "Dado que um supervisor da unidade Campinas acessa a aba de histórico de cálculos Quando solicita a listagem dos registros recentes Então o sistema exibe apenas cálculos associados à unidade Campinas E não apresenta registros de operadores vinculados a outras unidades regionais"
    }
  ]
}
```
