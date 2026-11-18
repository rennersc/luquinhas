# Requisitos de instalação — DS-MMC 9 níveis

> ## ⚠ Leia isto antes de instalar
>
> **Não use R2026a ou posterior para abrir este modelo.** As bibliotecas
> Specialized Power Systems foram removidas do Simscape Electrical no R2026a, e
> este modelo é 100% SPS. No R2026a/b os 135 blocos elétricos ficam
> `unresolved` e o `powergui` não existe — o modelo não compila.
>
> **A release certa é a R2025b** (com update aplicado). É a única com a
> biblioteca SPS *e* o `spsConversionAssistant` ao mesmo tempo.
>
> E atenção: **a SPS não vem mais junto com o Simscape Electrical.** Desde o
> R2025b ela passou a ser distribuída pela OPAL-RT. Reinstalar o MATLAB pode
> não ser suficiente — ver §4.

---

## 1. Produtos obrigatórios

| Produto | Para que |
|---|---|
| **MATLAB** | base |
| **Simulink** | o modelo, o bloco MATLAB Function do MPC, o Signal Editor |
| **Simscape** (base) | pré-requisito do Simscape Electrical |
| **Simscape Electrical** | hospeda a biblioteca SPS |
| **Specialized Power Systems** (`sps_lib`) | **os 135 blocos elétricos e o `powergui`** |

O item crítico é o último. Sem `sps_lib` nada no circuito resolve.

## 2. Inventário de blocos — extraído do `.slx`

Contagem obtida descompactando o `.slx` e lendo as referências `SourceBlock`.
Confere com os 137 blocos registrados em `NOTAS_TECNICAS.md` §6.

| Biblioteca de origem | Bloco | Instâncias |
|---|---|---|
| `spsIGBTDiodeLib` | IGBT/Diode | 48 |
| `spsVoltageMeasurementLib` | Voltage Measurement | 34 |
| `spsSeriesRLCBranchLib` | Series RLC Branch | 33 |
| `spsCurrentMeasurementLib` | Current Measurement | 10 |
| `spsGroundLib` | Ground | 4 |
| `spsACVoltageSourceLib` | AC Voltage Source | 3 |
| `spsDCVoltageSourceLib` | DC Voltage Source | 2 |
| `spsPowerLib` | Power | 1 |
| `sps_lib` | `powergui` | 1 |
| **Subtotal SPS** | | **≈136** |
| `SignalEditorBlockLib` | Signal Editor | 2 |

Os 48 IGBT/Diode são os 2 de cada uma das 24 células Chopper. Os 33 Series RLC
Branch incluem os 24 capacitores de submódulo (4000 µF, pré-carregados em
`Vcap0 = Vsm = 125 V` via `Setx0 = on`), os 6 indutores de braço e a saída RL.

**Só 2 blocos do modelo não são SPS.** Não há caminho de "instalar menos" — ou a
SPS está disponível, ou o modelo precisa ser convertido.

## 3. Produtos que **não** são necessários

Verificado no código, não presumido:

| Produto | Por que não |
|---|---|
| **Optimization Toolbox** | `matlab/MPC.m` não usa nenhuma função de otimização (sem `fmincon`, `quadprog`, `linprog`, `lsqlin`). O FCS-MPC é enumeração exaustiva das 256 linhas da matriz `M`, em MATLAB base |
| **Model Predictive Control Toolbox** | apesar do nome, o controle é escrito à mão num bloco MATLAB Function |
| **MATLAB Coder / Simulink Coder** | só seriam necessários para gerar código para hardware — o protótipo em hardware citado em `NOTAS_TECNICAS.md` §5 é trabalho futuro |
| **Stateflow** | *provavelmente* não — ver ressalva abaixo |

**Ressalva sobre o Stateflow.** O código do MPC fica em
`simulink/stateflow/chart_126.xml` dentro do `.slx`, porque o bloco MATLAB
Function usa internamente a infraestrutura do Stateflow. Mas o MATLAB Function
é um bloco do Simulink, e o Stateflow é produto separado. O
`matlab/check_migration.m` lista Stateflow entre os alvos por precaução. **Não
consegui confirmar isso em documentação oficial** — se o MATLAB reclamar de
licença Stateflow ao abrir o modelo, é essa a origem.

## 4. A mudança de 2026: a SPS saiu da MathWorks

Três fatos que invalidam parte do roteiro em `MIGRACAO_PASSO_A_PASSO.md`:

1. **A SPS foi removida do Simscape Electrical no R2026a.** Removida de fato, não
   depreciada.
2. **A MathWorks não comercializa mais a SPS.** Ela passou para a **OPAL-RT**,
   como produto chamado *SPS Software*. O R2025b é descrito como a última release
   em que a MathWorks a manteve.
3. **No R2025b a SPS foi restaurada por update** (relatada como "R2025b Release
   1"). Isso responde à dúvida deixada em aberto na Fase 2 do
   `MIGRACAO_PASSO_A_PASSO.md`: **sim, o R2025b tem SPS**, desde que atualizado.

O suporte da OPAL-RT começa no R2025b. **Não há confirmação de que a OPAL-RT
ofereça SPS Software para R2026a ou R2026b** — um relato de usuário menciona um
build cobrindo 2024a–2025b, e a OPAL-RT declara a *intenção* de sincronizar com
as releases do MATLAB, sem lista de compatibilidade por release. Confirme com a
OPAL-RT (`sales@opal-rt.com` / `support@opal-rt.com`) antes de contar com isso.

## 5. Qual release instalar

### Caminho recomendado: R2025b lado a lado

O MATLAB permite múltiplas releases instaladas simultaneamente.

1. Instale **R2025b** e aplique o update.
2. Garanta a SPS — ou do update da MathWorks, ou via OPAL-RT.
3. Verifique (§6).
4. Gere o baseline no R2025b com `matlab/run_baseline.m`, **antes de converter**.
   `NOTAS_TECNICAS.md` §6 explica por que: as ressalvas de solver,
   inicialização e jitter de chaveamento mudam números, e sem ponto de
   comparação não se separa efeito da conversão de efeito de mudança no controle.
5. Rode `spsConversionAssistant('MMC_9lvl_matriz_tri_v12_Renner')` **no R2025b**.
6. O modelo convertido, agora Simscape nativo, abre no R2026b normalmente.

Ou seja: o R2026b não é desperdício — é o **destino**. O R2025b é a ponte.

### Se você só tem R2026b

O modelo original não abre, e rodar a conversão lá não resolve: o
`spsConversionAssistant` precisa das bibliotecas SPS **presentes** para ler e
substituir os blocos. Isso já foi tentado e falhou — o
`MMC_9lvl_matriz_tri_v13_Renner_simscape` gerado no R2026a manteve os 135 blocos
apontando para `sps_lib`, todos `unresolved`, e zero blocos Simscape
(`MIGRACAO_PASSO_A_PASSO.md`, aviso da Fase 2).

Opções, em ordem de custo:

| Opção | Custo | Observação |
|---|---|---|
| Instalar R2025b lado a lado | baixo | recomendado |
| Obter SPS Software da OPAL-RT para R2026b | desconhecido | compatibilidade **não confirmada**; perguntar antes |
| Add-On de conversão de terceiros (File Exchange, suporta R2024b+) | baixo | não avaliado aqui |
| Reconstruir a rede à mão em Simscape Electrical | alto | 136 blocos; perde comparabilidade com o TCC |

## 6. Como verificar a instalação

```matlab
% a biblioteca existe?
sps_lib                     % deve abrir o Library Browser na SPS
which sps_lib               % deve retornar um caminho

% licenças
license('test','Power_System_Blocks')
license('test','Simscape')

% diagnóstico completo do modelo (escrito para isto)
check_migration
```

No Add-On Explorer: **Home → Add-Ons → Manage Add-Ons**, procurar por
*OPAL-RT SPS Software*.

O `matlab/check_migration.m` responde, em ordem: a SPS está instalada e
licenciada? o `powergui` existe nesta release? quais blocos têm link não
resolvido? **Rode-o na release nova e guarde a saída** — é o que decide se a
migração é "instalar um add-on" ou "reconstruir a rede elétrica".

Depois de converter, `matlab/inspect_converted.m` mostra o estado real dos
blocos do modelo convertido.

## 7. Dependência de arquivo que não está no repositório

O bloco **Signal Editor1** referencia `/Users/renner/Downloads/Sinais.mat`, que
**não está versionado**. Sem ele o `run_baseline.m` para na checagem de
pré-requisitos. Ao remontar a máquina, recoloque o arquivo (ou em `model/`,
ajustando o caminho do bloco).

## 8. Procedência e confiança

| Afirmação | Confiança |
|---|---|
| Contagem e tipo dos blocos, bibliotecas referenciadas | **Primária** — extraída do `.slx` neste repositório |
| Ausência de funções de otimização no MPC | **Primária** — lida em `matlab/MPC.m` |
| Falha da conversão no R2026a | **Primária** — registrada em `MIGRACAO_PASSO_A_PASSO.md` |
| Remoção da SPS no R2026a | Alta — documentação MathWorks, via resumo de busca |
| SPS distribuída pela OPAL-RT; restaurada no R2025b Update 1 | Média — threads do MATLAB Answers e página da OPAL-RT, via resumo de busca |
| SPS Software para R2026a/b | **Não confirmada** |
| Necessidade de licença Stateflow | **Não confirmada** |

`mathworks.com` recusa acesso automatizado (Akamai), então os itens de
confiança média não vieram de páginas lidas na íntegra. **Confirme os termos de
licença direto com a OPAL-RT antes de comprar.**

Referências:
[spsConversionAssistant](https://www.mathworks.com/help/sps/ref/spsconversionassistant.html) ·
[Upgrade SPS Models](https://www.mathworks.com/help/sps/ug/upgrade-sps-models-to-use-simscape-blocks.html) ·
[OPAL-RT SPS Software](https://smartpowersimulationsoftware.com/)
