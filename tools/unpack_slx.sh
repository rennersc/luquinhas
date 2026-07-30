#!/usr/bin/env bash
# Descompacta um .slx (que é um zip OPC) para inspeção/diff em texto.
# Uso: tools/unpack_slx.sh model/MMC_9lvl_matriz_tri_v12_Renner.slx build/slx
set -euo pipefail
SRC="${1:?uso: unpack_slx.sh <arquivo.slx> [destino]}"
DST="${2:-build/slx}"
rm -rf "$DST"
mkdir -p "$DST"
unzip -q "$SRC" -d "$DST"

# Pontos de interesse:
#   simulink/blockdiagram.xml            -> InitFcn (parâmetros do workspace)
#   simulink/stateflow/chart_126.xml     -> código do bloco MATLAB Function "MPC"
#   simulink/systems/system_root.xml     -> diagrama de topo
#   simulink/systems/system_389.xml      -> circuito de potência (planta)
#   simulink/systems/system_279.xml      -> invólucro do bloco MPC
#   simulink/configSet0.xml              -> solver
echo "extraído em $DST"
