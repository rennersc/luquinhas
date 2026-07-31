function inspect_converted(mdlC)
%INSPECT_CONVERTED Diagnostica o estado real dos blocos do modelo convertido.
%
%   inspect_converted                       % usa o nome padrão da conversão
%   inspect_converted('nome_do_modelo')
%
% Responde: os blocos convertidos resolveram de verdade? De qual biblioteca
% eles vieram? Se algum não resolveu, é falta de produto instalado ou é
% problema da conversão?
%
% Use quando o modelo convertido mostrar blocos vermelhos / não identificados,
% mesmo que o Conversion Assistant Report diga "fully supported". O relatório
% descreve o que a ferramenta TENTOU fazer; este script mostra o que o MATLAB
% consegue RESOLVER na máquina em que está rodando.
%
% NÃO TESTADO: escrito num ambiente sem MATLAB.

if nargin < 1 || isempty(mdlC)
    mdlC = 'MMC_9lvl_matriz_tri_v13_Renner_simscape';
end

fprintf('\n===== 1. PRODUTOS INSTALADOS =====\n');
% A distinção que importa: Simscape (base, tem R/L/C e fontes) versus
% Simscape Electrical (tem os semicondutores, incl. IGBT). Se só o primeiro
% estiver instalado, R/L/C resolvem e os IGBTs não — exatamente o sintoma
% "até os IGBTs não foram identificados".
prods = ver;
for alvo = {'Simscape', 'Simscape Electrical'}
    idx = strcmp({prods.Name}, alvo{1});
    if any(idx)
        p = prods(find(idx,1));
        fprintf('  [OK]      %-22s %s\n', p.Name, p.Version);
    else
        fprintf('  [AUSENTE] %-22s  <== suspeito principal\n', alvo{1});
    end
end
for f = {'Simscape', 'SimElectronics', 'Power_System_Blocks'}
    try, ok = license('test', f{1}); catch, ok = 0; end
    fprintf('  licenca %-22s : %d\n', f{1}, ok);
end

fprintf('\n===== 2. CARREGANDO O MODELO CONVERTIDO =====\n');
try
    load_system(mdlC);
    fprintf('  [OK] %s carregado\n', mdlC);
catch ME
    fprintf('  [FALHA] %s\n', ME.message);
    return
end

fprintf('\n===== 3. INVENTÁRIO DOS BLOCOS =====\n');
blocos = find_system(mdlC, 'LookUnderMasks', 'all', 'FollowLinks', 'off', ...
                     'Type', 'block');
fprintf('  %d blocos no total\n\n', numel(blocos));

porOrigem  = containers.Map('KeyType','char','ValueType','double');
naoResolv  = {};

for k = 1:numel(blocos)
    b = blocos{k};
    src = ''; st = ''; mt = '';
    try, src = get_param(b, 'SourceBlock');  end %#ok<TRYNC>
    try, st  = get_param(b, 'LinkStatus');   end %#ok<TRYNC>
    try, mt  = get_param(b, 'MaskType');     end %#ok<TRYNC>
    if isempty(src), continue, end           % só blocos de biblioteca

    lib = regexprep(src, '/.*$', '');        % biblioteca de origem
    chave = sprintf('%-34s %-22s %s', lib, mt, st);
    if isKey(porOrigem, chave), porOrigem(chave) = porOrigem(chave)+1;
    else,                       porOrigem(chave) = 1;
    end
    if ~isempty(st) && ~strcmp(st, 'resolved')
        naoResolv{end+1} = sprintf('    %-60s [%s] <- %s', b, st, src); %#ok<AGROW>
    end
end

fprintf('  %-34s %-22s %-12s qtd\n', 'BIBLIOTECA', 'MASKTYPE', 'LINKSTATUS');
fprintf('  %s\n', repmat('-', 1, 84));
ks = keys(porOrigem);
for k = 1:numel(ks)
    fprintf('  %s  %3d\n', ks{k}, porOrigem(ks{k}));
end

fprintf('\n===== 4. IGBTs ESPECIFICAMENTE =====\n');
igbts = {};
for k = 1:numel(blocos)
    n = get_param(blocos{k}, 'Name');
    if ~isempty(regexpi(n, 'igbt'))
        igbts{end+1} = blocos{k}; %#ok<AGROW>
    end
end
fprintf('  %d blocos com "IGBT" no nome (esperado: 48)\n', numel(igbts));
for k = 1:min(3, numel(igbts))
    b = igbts{k};
    fprintf('\n  exemplo %d: %s\n', k, b);
    for p = {'BlockType','MaskType','SourceBlock','LinkStatus','ReferenceBlock'}
        v = '';
        try, v = get_param(b, p{1}); end %#ok<TRYNC>
        if ~ischar(v), v = mat2str(v); end
        fprintf('    %-16s = %s\n', p{1}, v);
    end
end

fprintf('\n===== 5. NÃO RESOLVIDOS =====\n');
if isempty(naoResolv)
    fprintf('  nenhum — todos os links resolvidos.\n');
    fprintf('  (se ainda assim aparecem "estranhos" na tela, é aparência\n');
    fprintf('   do bloco Simscape novo, não erro.)\n');
else
    fprintf('  %d bloco(s) NÃO resolvido(s):\n', numel(naoResolv));
    fprintf('%s\n', naoResolv{:});
end

fprintf('\n===== FIM =====\n');
end
