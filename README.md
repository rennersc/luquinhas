# luquinhas — DS-MMC 9 níveis com controle preditivo (FCS-MPC)

Base de trabalho a partir do TCC de Lucas de Mingo Fernandes (UFES, ago/2025) e do
modelo Simulink que gerou os resultados do texto.

```
docs/NOTAS_TECNICAS.md   leitura obrigatória: parâmetros, algoritmo e as
                         divergências entre o .slx e o texto do TCC
docs/MIGRACAO_PASSO_A_PASSO.md   roteiro R2025a -> R2026a/b (conversão pendente:
                         precisa rodar no R2025b, ver aviso na Fase 2)
docs/Conversion_Assistant_Report.html   relatório oficial da conversão
docs/tcc_lucas_de_mingo.pdf
model/MMC_9lvl_matriz_tri_v12_Renner.slx    modelo original (R2025a)
matlab/MPC.m             código do bloco MATLAB Function, extraído do .slx
matlab/params_init.m     parâmetros do InitFcn, para rodar fora do modelo
matlab/check_migration.m diagnóstico de disponibilidade das bibliotecas
matlab/run_baseline.m    roda e salva os sinais em results/, para comparação
matlab/fix_inductor_ic.m corrige a corrente inicial dos 9 indutores do
                         modelo convertido (inspect / apply / verify)
matlab/inspect_converted.m  estado real dos blocos do modelo convertido:
                         resolvem? de qual biblioteca? falta produto?
tools/unpack_slx.sh      descompacta o .slx para inspeção em texto
tools/slx_edit.py        lê/edita o .slx (código do MPC, InitFcn, constantes)
                         sem precisar de MATLAB
```

## Resumo em uma tela

Inversor trifásico DS-MMC em dupla estrela, 4 células Chopper por braço
(9 níveis), elo CC de 500 V (2 × 250 V com ponto médio), capacitores de 4000 µF a
125 V, indutor de braço de 15 mH, saída RL (5 Ω / 100 µH) contra uma rede de
120 V pico / 60 Hz. Controle FCS-MPC de horizonte 1 num único bloco MATLAB
Function a 20 kHz (Ts = 50 µs), varrendo 256 combinações de chaveamento por fase
e minimizando um custo de três termos: erro de corrente de saída, corrente
circulante e desvio da tensão média dos capacitores da perna.

## Antes de rodar

1. O modelo depende de `Sinais.mat` (referenciado como
   `/Users/renner/Downloads/Sinais.mat` pelo bloco Signal Editor1) — **esse
   arquivo não está no repositório**.
2. Requer Simscape Electrical / Specialized Power Systems.
3. Os parâmetros vêm do `InitFcn` do próprio modelo; `matlab/params_init.m` é uma
   cópia versionada deles.

## Pontos de atenção já mapeados

O `.slx` foi modificado depois da defesa e **não** executa exatamente o que o TCC
descreve. Em particular: o balanceamento por sorting está sobrescrito (código
morto), o expoente do termo de corrente no custo é 4 e não 2, e há uma correção
empírica de `Pref`/`Qref` que não aparece no texto. Detalhes e como reverter cada
ponto em `docs/NOTAS_TECNICAS.md`, seção 4.
