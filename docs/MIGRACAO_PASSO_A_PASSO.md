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

**Passo 2.4.** Leia o relatório inteiro. Ele classifica cada bloco em
**totalmente suportado**, **parcialmente suportado** e **não suportado**.
Anote a lista dos dois últimos grupos — é o seu trabalho manual.

Palpite do que deve cair em "não suportado" ou "parcial", pelo inventário
(a confirmar no relatório):

| Bloco | Qtd | Comentário |
|---|---|---|
| `powergui` | 1 | vira Solver Configuration |
| `Power` (P/Q) | 1 | medidor de potência, sem equivalente óbvio 1:1 |
| Series RLC Branch | 33 | primitivos, devem converter direto |
| IGBT/Diode | 48 | conversão provável, conferir parâmetros Ron/Rs/Cs |
| Voltage/Current Measurement | 44 | conferir se entram conversores PS-Simulink |
| AC/DC Voltage Source, Ground | 9 | primitivos |

**Passo 2.5.** Converta na mão o que sobrou. Para o medidor de potência, se não
houver equivalente, calcule P e Q em Simulink a partir de V e I — o modelo já
tem ambos medidos e roteados.

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

**Passo 3.2. Condições iniciais dos capacitores.** A doc avisa que
*"the initialization values at time 0 might be different"*. Aqui isso é premissa
do TCC: os 24 capacitores começam pré-carregados em `Vcap0 = Vsm = 125 V`
(`Setx0 = on` em cada Series RLC Branch). Confirme bloco a bloco no modelo
convertido; se tiver zerado, o arranque vai ser completamente diferente.

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
