#!/usr/bin/env python3
"""Edita um .slx sem MATLAB.

O .slx é um pacote OPC (zip de XML). Este utilitário permite:

  * injetar um novo código no bloco MATLAB Function "MPC"
  * alterar o callback InitFcn (parâmetros do workspace)
  * alterar o valor de um bloco Constant pelo SID

Sempre escreve em um arquivo de saída novo; o original nunca é modificado.
A repacotagem preserva ordem das entradas, método de compressão, timestamps e
atributos do zip original — verificado por round-trip com conteúdo idêntico.

Uso:
  tools/slx_edit.py set-mpc  ENTRADA.slx SAIDA.slx matlab/MPC.m
  tools/slx_edit.py set-init ENTRADA.slx SAIDA.slx arquivo_com_InitFcn.txt
  tools/slx_edit.py set-const ENTRADA.slx SAIDA.slx SID VALOR
  tools/slx_edit.py get-mpc  ENTRADA.slx > matlab/MPC.m
"""
import os
import re
import shutil
import sys
import tempfile
import zipfile

CHART = "simulink/stateflow/chart_126.xml"
BD = "simulink/blockdiagram.xml"
ROOT = "simulink/systems/system_root.xml"


def xml_escape(s):
    """Mesma convenção que o Simulink usa dentro de <P>: & < > e apóstrofo."""
    return (s.replace("&", "&amp;").replace("<", "&lt;")
             .replace(">", "&gt;").replace("'", "&apos;"))


def xml_unescape(s):
    return (s.replace("&apos;", "'").replace("&quot;", '"')
             .replace("&lt;", "<").replace("&gt;", ">").replace("&amp;", "&"))


def read_member(slx, name):
    with zipfile.ZipFile(slx) as z:
        return z.read(name).decode("utf-8")


def rewrite(src, dst, edits):
    """Reescreve o .slx aplicando {nome_do_membro: novo_conteudo_str}."""
    with zipfile.ZipFile(src) as zin, zipfile.ZipFile(dst, "w") as zout:
        for info in zin.infolist():
            data = zin.read(info.filename)
            if info.filename in edits:
                data = edits[info.filename].encode("utf-8")
            ni = zipfile.ZipInfo(info.filename, date_time=info.date_time)
            ni.compress_type = info.compress_type
            ni.create_system = info.create_system
            ni.external_attr = info.external_attr
            zout.writestr(ni, data)


def _script_span(chart_xml):
    """Localiza o maior <P Name="script"> — é o código do bloco MPC."""
    matches = list(re.finditer(r'<P Name="script">(.*?)</P>', chart_xml, re.S))
    if not matches:
        sys.exit("erro: nenhum <P Name=\"script\"> encontrado em " + CHART)
    return max(matches, key=lambda m: len(m.group(1)))


def get_mpc(slx):
    m = _script_span(read_member(slx, CHART))
    return xml_unescape(m.group(1))


def set_mpc(src, dst, mfile):
    chart = read_member(src, CHART)
    m = _script_span(chart)
    new = open(mfile, encoding="utf-8").read().rstrip("\n")
    chart = chart[:m.start(1)] + xml_escape(new) + chart[m.end(1):]
    rewrite(src, dst, {CHART: chart})
    print(f"código do bloco MPC substituído por {mfile} -> {dst}")


def set_init(src, dst, txtfile):
    bd = read_member(src, BD)
    m = re.search(r'(<P Name="InitFcn">)(.*?)(</P>)', bd, re.S)
    if not m:
        sys.exit("erro: InitFcn não encontrado")
    new = open(txtfile, encoding="utf-8").read().rstrip("\n")
    bd = bd[:m.start(2)] + xml_escape(new) + bd[m.end(2):]
    rewrite(src, dst, {BD: bd})
    print(f"InitFcn substituído por {txtfile} -> {dst}")


def set_const(src, dst, sid, value):
    root = read_member(src, ROOT)
    pat = re.compile(
        r'(<Block BlockType="Constant"[^>]*SID="%s">.*?<P Name="Value">)(.*?)(</P>)'
        % re.escape(sid), re.S)
    m = pat.search(root)
    if not m:
        sys.exit(f"erro: bloco Constant com SID {sid} não encontrado")
    old = m.group(2)
    root = root[:m.start(2)] + xml_escape(value) + root[m.end(2):]
    rewrite(src, dst, {ROOT: root})
    print(f"Constant SID {sid}: {old} -> {value}  ({dst})")


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    cmd = sys.argv[1]
    if cmd == "get-mpc":
        sys.stdout.write(get_mpc(sys.argv[2]))
    elif cmd == "set-mpc":
        set_mpc(sys.argv[2], sys.argv[3], sys.argv[4])
    elif cmd == "set-init":
        set_init(sys.argv[2], sys.argv[3], sys.argv[4])
    elif cmd == "set-const":
        set_const(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
