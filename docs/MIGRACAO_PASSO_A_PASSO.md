# Migração do modelo DS-MMC: R2025a → R2026a/b

Procedimento para converter `MMC_9lvl_matriz_tri_v12_Renner.slx` de Specialized
Power Systems para Simscape Electrical, usando a ferramenta oficial da MathWorks.

Contexto: a partir do R2026a as bibliotecas de Specialized Power Systems foram
removidas do Simscape Electrical. Este modelo é 100% SPS — 137 blocos de
`sps_lib` mais o `powergui`.

> Nada aqui foi executado: o ambiente onde este documento foi escrito não tem
> MATLAB. Os comandos vêm da documentação da MathWorks e da inspeção do `.slx`.
> Trate como roteiro a validar, não como resultado.

---

## Fase 0 — Destravar a dependência que falta

**Passo 0.1.** O bloco `Signal Editor1` aponta para
`/Users/renner/Downloads/Sinais.mat`, que não está no repositório. Sem ele o
modelo não simula. Localize o arquivo e copie para `model/`.

**Passo 0.2.** Reaponte o bloco para o caminho relativo e salve:

```matlab
mdl = 'MMC_9lvl_matriz_tri_v12_Renner';
load_system(mdl)
se = find_system(mdl,'LookUnderMasks','all','SourceType','SignalEditor');
for k = 1:numel(se)
    disp(get_param(se{k},'FileName'))     % ver o que está lá hoje
end
set_param(se{1}, 'FileName', fullfile(pwd,'model','Sinais.mat'))
save_system(mdl)
```

**Passo 0.3.** Versione o `Sinais.mat`. Sem ele nada disso é reproduzível.

Se o arquivo tiver se perdido: ele alimenta apenas o `Qref` (`Signal 2` do
cenário). Dá para substituir por um `Signal Builder`/degrau equivalente, mas aí
os resultados deixam de ser comparáveis com as Figuras 19–22 do TCC.

---

## Fase 1 — Baseline no R2025a (antes de converter)

Este passo não é burocracia. As três ressalvas oficiais da conversão (solver,
inicialização, jitter) mexem em números. Sem baseline você não consegue separar
"a conversão mudou isso" de "o controle mudou isso".

**Passo 1.1.** Run curto para conferir que tudo carrega:

```matlab
cd <repo>
run_baseline(0.2, 'baseline')
```

**Passo 1.2.** Run completo, 5 s, o mesmo do TCC:

```matlab
run_baseline(5, 'baseline_full')
```

Sai em `results/baseline_full_R2025a_<timestamp>.mat`.

**Passo 1.3.** Guarde também as figuras que você quer poder comparar depois —
no mínimo tensão sintetizada (Fig. 12), correntes de saída vs. referência
(Fig. 14) e tensões dos capacitores da fase A (Fig. 16).

---

## Fase 2 — Conversão

> ### ⚠ Pré-requisito que invalidou a primeira tentativa
>
> `spsConversionAssistant` foi **introduzido no R2025b** e precisa que as
> bibliotecas SPS estejam **presentes na instalação** para ler os blocos e
> substituí-los. No R2026a a SPS foi removida — rodar a conversão lá produz um
> relatório plausível e **uma cópia renomeada do modelo, sem conversão nenhuma**.
>
> Foi exatamente o que aconteceu na primeira tentativa: o
> `MMC_9lvl_matriz_tri_v13_Renner_simscape` gerado no R2026a mantinha os 135
> blocos apontando para `spsIGBTDiodeLib`, `spsSeriesRLCBranchLib` e
> `sps_lib/powergui`, todos `unresolved`, e zero blocos Simscape. A licença
> `Power_System_Blocks` retornava 1 (direito de uso), mas os arquivos da
> biblioteca não existem mais na release.
>
> **Rode a conversão no R2025b**, que é a única release com a biblioteca SPS *e*
> a ferramenta ao mesmo tempo. O R2025a não serve: não tem a ferramenta.
>
> Antes de instalar outra release, vale checar no Add-On Explorer do R2026a se a
> Specialized Power Systems aparece como add-on instalável.
>
> **Validação obrigatória depois de converter** — o relatório não prova nada:
>
> ```matlab
> inspect_converted('<modelo_convertido>')
> ```
>
> A seção 5 tem que vir vazia e o `SourceBlock` dos IGBTs tem que apontar para
> uma biblioteca Simscape, não para `spsIGBTDiodeLib`. O relatório de conversão
> descreve o que a ferramenta *saberia* converter, não o que ela *converteu*.

**Passo 2.1.** Confirme o pré-requisito. A documentação exige *Simulation type* =
`Discrete` no powergui. **Este modelo já está assim** (`Discrete`, 50 µs) — só
confirme:

```matlab
pg = find_system(mdl,'LookUnderMasks','all','SourceType','PSB option menu block');
get_param(pg{1},'SimulationMode')   % esperado: Discrete
get_param(pg{1},'SampleTime')       % esperado: 0.00005
```

**Passo 2.2.** Trabalhe sobre uma cópia, e confirme permissão de escrita:

```matlab
writable = spsConversionAssistant(mdl)   % 1 = pode salvar
```

**Passo 2.3.** Converta, mandando a saída para uma pasta separada:

```matlab
spsConversionAssistant(mdl, fullfile(pwd,'model','convertido'))
```

Gera o modelo convertido **e** um relatório HTML na pasta de saída.

**Passo 2.4.** Leia o relatório. A primeira execução (no R2026a, portanto
inválida — ver aviso acima) está em `docs/Conversion_Assistant_Report.html`.
Os números abaixo indicam o que a ferramenta *saberia* converter; espera-se que
se repitam quando ela rodar no R2025b, aí sim com substituição real:

| Status | Qtd |
|---|---|
| Não suportado | **0** |
| Parcialmente suportado | 9 |
| Totalmente suportado | 126 |

Detalhe por tipo:

| Bloco | Qtd | Status |
|---|---|---|
| IGBT/Diode | 48 | totalmente suportado |
| Voltage Measurement | 34 | totalmente suportado |
| Series RLC Branch (capacitores dos SMs) | 24 | totalmente suportado |
| Current Measurement | 10 | totalmente suportado |
| Ground | 4 | totalmente suportado |
| AC Voltage Source | 3 | totalmente suportado |
| DC Voltage Source | 2 | totalmente suportado |
| Power (P/Q) | 1 | totalmente suportado |
| **Series RLC Branch (indutores)** | **9** | **parcialmente suportado** |

Os 135 fecham com o inventário: 137 blocos de biblioteca menos o `powergui`
(tratado à parte, vira Solver Configuration) e o `Signal Editor` (Simulink, não SPS).

**Passo 2.5.** Segundo o relatório, nada a converter à mão — zero blocos não
suportados, incluindo o medidor de potência `Power`. A confirmar na conversão real.

### O que importa nesse resultado

**Os 24 capacitores dos submódulos são "totalmente suportados".** Se isso se
confirmar na conversão real, o `Vcap0 = Vsm = 125 V` (`Setx0 = on`) atravessa —
era a preocupação principal, porque é premissa explícita do TCC. Confirme no
Passo 3.2.

---

## Fase 3 — Ajustes obrigatórios pós-conversão

**Passo 3.1. Solver.** A MathWorks recomenda `ode23t` ou `daessc` no modelo
convertido:

```matlab
set_param(mdlConv, 'SolverName', 'ode23t')
```

Note que isso troca o solver discreto de 50 µs por passo variável na planta. O
bloco MPC continua discreto a 50 µs (`SystemSampleTime` próprio) — isso não muda.
Na prática você passa a ter, pela primeira vez, planta e controlador em taxas
separadas, que é justamente o que eu apontei como limitação do modelo original.

**Passo 3.2. Condições iniciais dos capacitores.** Os 24 vieram como totalmente
suportados, então o `Vcap0 = 125 V` deve ter passado. Confirme mesmo assim:

```matlab
mdlC = 'MMC_9lvl_matriz_tri_v13_Renner_simscape';
load_system(mdlC)
caps = find_system(mdlC,'LookUnderMasks','all','MaskType','Capacitor');
fprintf('%d capacitores\n', numel(caps));   % esperado: 24
```

**Passo 3.2b. Corrente inicial dos 9 indutores — a única pendência real.**

Os 9 blocos "parcialmente suportados" são exatamente os indutores: os **6 de
braço** (`Larm = 15 mH`) e os **3 do ramo RL de saída** (`L = 100 µH`). O aviso
do relatório:

> "The inductor current might start from an undesired value. Adjustment of model
> initial conditions might be required."
> "Review the block 'Variables' section or select the 'Start simulation from
> steady state' parameter in the corresponding 'Solver Configuration' block."

No modelo original os nove estão com `SetiL0 = off`, `InitialCurrent = 0` — ou
seja, a intenção é **partir com corrente zero**.

**Das duas saídas sugeridas, use a primeira.** Vá na aba *Variables* de cada
indutor e fixe `Current = 0 A` com **priority = High**.

**Não use "Start simulation from steady state".** Ela resolve o regime permanente
em t = 0, o que contradiz a partida a frio que o TCC descreve — capacitores no
nominal, correntes zeradas, MPC começando do repouso. Ligar isso muda o
transitório inicial e invalida a comparação com as figuras do trabalho.

Se o solver reclamar de sobre-especificação ao fixar os nove: os três indutores
de saída são dependentes dos de braço (`iout = ip - in`). Baixe a prioridade
desses três para *None* e deixe apenas os seis de braço em *High*.

**Passo 3.3. Jitter de chaveamento.** A doc menciona jitter em eventos de
chaveamento, citando PWM. Nosso caso é mais exposto: FCS-MPC comuta a cada 50 µs
sem modulador. Sobreponha a tensão sintetizada antes/depois — se aparecerem
degraus espúrios ou níveis intermediários, é isso.

---

## Fase 4 — Validação

**Passo 4.1.** Rode o convertido com o mesmo `StopTime` do baseline.

**Passo 4.2.** Compare, nesta ordem de sensibilidade:

1. **Tensões dos capacitores** — o que mais denuncia problema de inicialização.
2. **Tensão sintetizada** — 9 níveis limpos? degraus espúrios = jitter.
3. **Correntes de saída vs. referência** — amplitude e fase.
4. **Correntes circulantes** — amplitude.
5. **P e Q medidos** — lembrando que passam pelas curvas empíricas de correção.

**Passo 4.3.** Só declare a migração concluída quando as 5 baterem dentro de uma
tolerância que você aceite. Diferença pequena é esperada (solver diferente);
diferença qualitativa não é.

---

## Fase 5 — Depois, não antes

Só com o modelo convertido validado é que faz sentido mexer no controle: o
sorting desativado, o índice `I(2*j-1)`, o expoente do custo. Ver
`docs/NOTAS_TECNICAS.md` seção 4.

Misturar migração e mudança de controle no mesmo passo é a forma mais rápida de
gerar um resultado que ninguém consegue explicar.
