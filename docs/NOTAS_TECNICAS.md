# DS-MMC 9 níveis com FCS-MPC — notas técnicas do modelo e do TCC

Base: TCC de Lucas de Mingo Fernandes, *"Controle Preditivo Aplicado aos Conversores
Modulares Multinível"* (UFES, ago/2025; orientador Lucas Frizera Encarnação,
coorientador Renner Sartório Camargo) e o modelo
`model/MMC_9lvl_matriz_tri_v12_Renner.slx`.

Modelo salvo em **MATLAB R2025a Update 1**, revisão 13.237, criado em 2020 por
"bernardo" e modificado por "renner" em 16/08/2025 — ou seja, o `.slx` é
**posterior à defesa** e não corresponde linha a linha ao que está escrito no TCC
(ver §4, Divergências).

---

## 1. Topologia e parâmetros

Inversor trifásico DS-MMC (dupla estrela), 4 submódulos meia-ponte (célula
Chopper) por braço → 2·Nsm+1 = **9 níveis** na saída.

| Símbolo | Variável no modelo | Valor | Observação |
|---|---|---|---|
| Elo CC total | `2*Vcc` | 500 V | duas fontes CC de `Vcc` = 250 V com ponto médio aterrado |
| Elo CC (metade) | `Vcc` | **250 V** | armadilha: no TCC "Vcc" é o total (500 V), no código é a metade |
| Nsm | — | 4 por braço | 8 por perna, 24 no total |
| V nominal do SM | `Vsm` | 125 V | `Vcc*2/4` |
| C do SM | `C` | 4000 µF | inicializado em `Vcap0 = Vsm` (pré-carregado) |
| Indutor de braço | `Larm` (l) | 15 mH | |
| R de braço | `Rarm` (r) | 0 | desprezada, como diz o TCC |
| Filtro de saída | `L` | 100 µH | ramo RL série (com C parasita de 1 µF no bloco) |
| R de saída | `R` | 5 Ω | |
| Rede | `Vsa` | 120 V pico, 60 Hz | 3 fontes CA a 0°, +120°, −120° |
| Amostragem | `TS = 1/FR` | **50 µs** (FR = 20 kHz) | |
| IGBT/Diode | — | Ron = 1e-3, Rs = 1e8, Cs = inf | snubber praticamente desligado |

Solver: `powergui` em modo **Discrete, Ts = 50 µs**, Tustin/Backward Euler.
Model solver: FixedStepAuto, `FixedStep = 5e-7`, `StopTime = 5 s`.

> **A planta é discretizada no mesmo passo do controlador (50 µs).** Não há
> oversampling do circuito em relação ao MPC. Isso mascara o efeito real do
> atraso de atuação e tende a deixar o resultado otimista. Para validar,
> baixar o `Ts` do powergui (ex.: 5 µs) mantendo o MPC em 50 µs.

## 2. Estrutura do arquivo Simulink

```
root
├── MPC                (SID 279)  bloco MATLAB Function — todo o controle
│                                 15 entradas / 33 saídas, SystemSampleTime 50 µs
├── Subsystem          (SID 389)  planta: 24 submódulos + 6 indutores de braço
│                                 + ramos RL de saída + fontes CC/CA + medições
│   └── 24 × Subsystem(N)         célula Chopper: 2 IGBT/Diode + NOT + RLC 'C'
├── Subsystem1         (SID 1598) correção empírica de Pref (2 blocos Fcn em série)
├── Subsystem2         (SID 1607) correção empírica de Qref (1 bloco Fcn)
├── Signal Editor1     (SID 1596) referência variável ← /Users/renner/Downloads/Sinais.mat
├── Constant9 = 750                fonte de Pref no diagrama atual
├── powergui, Power (P/Q), scopes, To Workspace (SinalPRef, SinalQRef, MedP, MedQ)
```

Entradas do bloco MPC:
`ioutk, Pref, Qref, Ts, R, L, l, C, Vcc, ipn, Vcap, Vsm, Vs, ICC, Varm`

Saídas: `s1a..s8a, s1b..s8b, s1c..s8c` (24 gates) + `Va,Vb,Vc, Irefa,Irefb,Irefc, Iza,Izb,Izc`.

Convenções de indexação (importantes para mexer no código):
- `Vcap(1..24)`: perna A = 1..8, B = 9..16, C = 17..24; dentro da perna,
  1..4 = braço positivo, 5..8 = braço negativo.
- `ipn(1..6)`: `[iap, ian, ibp, ibn, icp, icn]`.
- `Varm(1..6)`: `[Vap, Van, Vbp, Vbn, Vcp, Vcn]`.

## 3. Algoritmo de controle (`matlab/MPC.m`)

FCS-MPC com horizonte 1, busca exaustiva:

1. **Matriz `M`**: 256×8, todas as combinações de 8 submódulos de uma perna
   (4 do braço positivo + 4 do negativo). Reutilizada nas três fases.
2. **Referência (Teoria pq)**: `Vs` → αβ → `Iref_αβ` a partir de `Pref/Qref` →
   volta para abc (`Igref(1..3)`).
3. **Loop** `j = 1..3` (fases) × `i = 1..256` (chaveamentos), `k = (j-1)*8`:
   - `Vpk1`, `Vnk1` = soma das tensões dos capacitores inseridos;
   - corrente de saída prevista (Backward Euler):
     `ik1 = ((Vnk1-Vpk1)/2 - Vs + iout*(L+l/2)/Ts) / (R + (L+l/2)/Ts)`
     — note que `r/2` foi omitido do denominador (Rarm = 0, então é indiferente);
   - circulante prevista:
     `izk1 = (ip+in)/2 - (iap+ibp+icp)/3 + Ts/(2l)*(2*Vcc - Vnk1 - Vpk1)`
     — usa a soma das 3 correntes de braço positivo como estimador de `Icc`
     em vez do `ICC` medido (a linha com `ICC` está comentada);
   - tensões dos capacitores previstas: `Vcap1 = Vcap + (Ts/C)*i_braço*M(i,·)`;
   - **custo**: `g = ki*(Igref-ik1)^4 + kz*izk1^2 + kc*(Vsm - mean(Vcap1 da perna))^2`
     com `ki = 5`, `kz = 1`, `kc = 1`.
4. **Balanceamento (sorting)**: conta quantos SMs ligar por braço (`nsm(1..6)`)
   e escolhe *quais* pelo semiciclo da corrente — ascendente se `I(j) >= 0`,
   descendente caso contrário.
5. Emite os 24 sinais binários `s*`.

## 4. Divergências entre o `.slx` e o texto do TCC

Estas são as diferenças reais entre o que está escrito e o que o arquivo executa.
Nenhuma é ambígua — todas foram lidas direto do XML do modelo.

### 4.1 O balanceamento por sorting está desativado (código morto) — crítico

O TCC (§3.3.5) descreve o sorting como um resultado central e a §4.4 credita a
ele o equilíbrio dos capacitores. No arquivo, logo **depois** do laço de sorting,
o vetor `S` é sobrescrito inteiro:

```matlab
for j = 1:6           % ... calcula S por ordenação de Vcap1 ...
    S(selec_idx + k) = 1;
end

S(1)=M(esc(1),1);     % <-- sobrescreve tudo que o laço acima produziu
...
S(24)=M(esc(3),8);
```

Ou seja, a versão v12 aplica **diretamente a linha vencedora de `M`**, sem rodízio
de capacitores. Para reativar o balanceamento descrito no texto, basta remover (ou
comentar) o bloco `S(1)=...S(24)=`.

### 4.2 Bug de indexação em `I(j)` — só aparece quando o sorting é reativado

Dentro do laço de custo:

```matlab
I(j)   = ik1(j);
I(j+1) = ik1(j);
```

`I` tem 6 posições (uma por braço) e é consumido no sorting como `I(1..6)`.
Com `j = 1,2,3` isso escreve em `I(1),I(2)` / `I(2),I(3)` / `I(3),I(4)`:
`I(5)` e `I(6)` (fase C) **nunca são escritos** e ficam em zero, e as fases se
sobrescrevem entre si. O correto seria `I(2*j-1) = ik1(j); I(2*j) = ik1(j);`.

Há ainda uma questão física acima disso: o critério de semiciclo usa a mesma
corrente para os dois braços, mas `Ip` desce e `In` sobe pelo braço — o sinal que
determina carga/descarga do capacitor não é o mesmo nos dois. Vale conferir contra
`ipn(1..6)` medido em vez de usar `ik1`.

### 4.3 Função de custo: expoente 4, não 2

O TCC (§3.3.4) escreve `ki*(Igref - ik1)^2`. O arquivo usa **`^4`**:

```matlab
g = ki*(Igref(j)-ik1(j))^4 + kz*(izk1(j))^2 + kc*(Vsm - mean_Vcap)^2;
```

Com `ki = 5` isso muda drasticamente a ponderação relativa (o termo de corrente
domina fora da vizinhança do zero e some perto dela). Duas variantes alternativas
do custo estão comentadas no código — uma com erro por capacitor individual (`^2`)
e outra com `^4` por capacitor. Isso explica em parte o erro de regime permanente na
tensão média dos capacitores discutido na §4.6 do TCC.

### 4.4 Correção empírica de Pref/Qref não documentada

`Pref` e `Qref` **não** vão direto ao bloco MPC. Passam por blocos `Fcn`:

- Pref (`Subsystem1`, dois em série):
  `((44.38019/sqrt(u)) + 0.75116)*u` → `((29.2367/u) - (1.520184/sqrt(u)) + 1.0009)*u`
- Qref (`Subsystem2`): `((-931.5321/u) + (67.9151/sqrt(u)) + 0.8719)*u`

São curvas ajustadas empiricamente para compensar o erro de regime permanente do
rastreamento de potência. Não aparecem em lugar nenhum do TCC, e é isso que faz
as Figuras 21/22 baterem tão bem. **Atenção**: `1/u` e `1/sqrt(u)` explodem em
`u → 0` e são inválidos para `u < 0` — qualquer varredura de referência que passe
por zero ou por potência negativa quebra aqui.

### 4.5 Ponto de operação do arquivo ≠ ponto de operação do texto

O `InitFcn` define `Pref = 3000`, mas o diagrama sobrepõe isso: um `Constant9 = 750`
alimenta o `Goto` de tag `Pref`, e o `Signal Editor1` (sinal "Signal 2") alimenta
`Qref`. Os resultados de 3000 W / 25 A do TCC (§4.2) não saem de um `run` direto
deste arquivo sem ajustar isso.

### 4.6 Dependência externa ausente

`Signal Editor1` aponta para `/Users/renner/Downloads/Sinais.mat`, que não está no
repositório. Sem esse arquivo o modelo não abre/roda como está. Precisamos
recuperá-lo ou substituir o Signal Editor por uma fonte gerada em script.

## 5. Próximos passos sugeridos

Ordem que faz sentido antes de qualquer extensão:

1. Recuperar (ou recriar) `Sinais.mat` e versioná-lo em `model/`.
2. Rodar o baseline como está e guardar os `.mat` de saída — precisamos de um
   ponto de comparação antes de mudar qualquer coisa.
3. Decidir sobre §4.1: reativar o sorting (corrigindo §4.2 junto) e medir o
   impacto no ripple e no espalhamento das tensões de capacitor.
4. Decidir sobre §4.3: alinhar o expoente com o texto ou documentar o `^4`.
5. Substituir a compensação empírica (§4.4) por algo defensável — o próprio TCC
   sugere, nas pesquisas futuras, um termo integral no custo dos capacitores ou
   controle em cascata.
6. Reduzir o `Ts` do powergui para separar planta e controlador.
7. Custo computacional: 3 × 256 = 768 avaliações por passo de 50 µs. As sugestões
   de "lógica mais direta" do TCC (reduzir o conjunto de candidatos usando o
   número de SMs em vez da tabela completa) derrubam isso para ~9 candidatos por
   perna, o que é o caminho para um protótipo em hardware.

## 6. Como inspecionar e editar o `.slx` sem MATLAB

`tools/unpack_slx.sh` descompacta o modelo (é um zip OPC). O código do bloco MPC
fica em `simulink/stateflow/chart_126.xml`, dentro de um `<P Name="script">`;
`matlab/MPC.m` é esse script já extraído e des-escapado.

`tools/slx_edit.py` faz a edição sem MATLAB, sempre gerando um arquivo novo:

```bash
tools/slx_edit.py get-mpc   model/orig.slx > matlab/MPC.m      # extrai o código
tools/slx_edit.py set-mpc   model/orig.slx model/v13.slx matlab/MPC.m
tools/slx_edit.py set-init  model/orig.slx model/v13.slx init.txt
tools/slx_edit.py set-const model/orig.slx model/v13.slx 1603 3000
```

Validação feita: repacotar o modelo sem alterações produz um zip com a mesma
lista, ordem e conteúdo de membros do original, e o ciclo
`get-mpc` → `set-mpc` é idempotente byte a byte em todos os 55 membros.

### O que é seguro editar assim, e o que não é

Seguro — texto dentro de `<P>`, sem efeito em checksum:

- código do bloco MATLAB Function (`chart_126.xml`);
- `InitFcn` e valores de blocos `Constant`, `Gain`, `Fcn`;
- parâmetros de bloco já existentes (`SampleTime` do powergui, `StopTime`,
  ganhos, valores de R/L/C que são expressões de workspace).

Requer cuidado ou MATLAB:

- **adicionar/remover blocos ou linhas** — exige criar SIDs coerentes, portas,
  `Line`/`Branch` e atualizar `graphicalInterface.json`. Dá pra fazer, mas o
  custo/risco sobe muito; melhor na GUI;
- `blockdiagram.xml` tem `PhysicalModelingChecksum` e
  `PhysicalModelingParameterChecksum` (rede Simscape/SPS). Mexer na topologia
  elétrica invalida esses valores. Alterar só o código do MPC não toca neles;
- `Signal Editor` guarda dados em `simulink/bdmxdata/UserData_*.mxarray`
  (formato MAT binário) — não editar à mão.

**Limite fundamental:** daqui não há como *rodar* a simulação. Toda edição feita
por esta via precisa de uma abertura no MATLAB para confirmar que o modelo carrega
e compila. Por isso o original em `model/` nunca é sobrescrito.
