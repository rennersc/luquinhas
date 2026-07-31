function fix_inductor_ic(mode, mdlC)
%FIX_INDUCTOR_IC Fixa a corrente inicial dos 9 indutores do modelo convertido.
%
%   fix_inductor_ic('inspect')   % NÃO altera nada: mostra o que existe
%   fix_inductor_ic('apply')     % fixa Current = 0 A, priority High
%   fix_inductor_ic('verify')    % relê e confere
%
% Contexto: o Conversion Assistant marcou 9 blocos como "partially supported",
% todos indutores — 6 de braço (Larm = 15 mH) e 3 do ramo RL de saída
% (L = 100 uH) — com o aviso "The inductor current might start from an
% undesired value". No modelo original os nove estão com SetiL0 = off e
% InitialCurrent = 0, ou seja, a intenção é partir com corrente zero.
%
% Rode 'inspect' PRIMEIRO. Os nomes dos parâmetros de inicialização de
% variáveis do Simscape dependem do bloco gerado pela conversão; o modo
% inspect descobre os nomes reais em vez de assumi-los.
%
% NÃO TESTADO: escrito num ambiente sem MATLAB.

if nargin < 1 || isempty(mode),  mode = 'inspect';                              end
if nargin < 2 || isempty(mdlC),  mdlC = 'MMC_9lvl_matriz_tri_v13_Renner_simscape'; end

load_system(mdlC);

% Os 9 blocos parcialmente suportados, conforme o relatório de conversão.
alvos = cell(1, 9);
for k = 1:9
    alvos{k} = sprintf('%s/Subsystem/Series RLC Branch%d', mdlC, k);
end

switch lower(mode)
    case 'inspect'
        inspecionar(alvos);
    case 'apply'
        aplicar(alvos);
    case 'verify'
        inspecionar(alvos);
    otherwise
        error('modo desconhecido: %s (use inspect | apply | verify)', mode);
end
end

% -------------------------------------------------------------------------
function inspecionar(alvos)
fprintf('\n===== INSPEÇÃO DOS 9 INDUTORES =====\n');
fprintf('(nada é alterado neste modo)\n');

for k = 1:numel(alvos)
    blk = alvos{k};
    fprintf('\n--- [%d] %s\n', k, blk);
    if isempty(find_system(bdroot(blk), 'LookUnderMasks','all','Name', get_name(blk)))
        % find_system por nome pode falhar em nomes com '/'; segue mesmo assim
    end
    try
        bt = get_param(blk, 'BlockType');
    catch
        fprintf('    NÃO ENCONTRADO neste caminho — veja nota no fim.\n');
        continue
    end
    mt = '';
    try, mt = get_param(blk, 'MaskType'); end %#ok<TRYNC>
    fprintf('    BlockType=%s  MaskType=%s\n', bt, mt);

    % Lista os parâmetros de diálogo que tenham cara de inicialização de
    % variável (prioridade, valor inicial, corrente).
    try
        dp = get_param(blk, 'DialogParameters');
    catch
        fprintf('    sem DialogParameters\n');
        continue
    end
    if isempty(dp), fprintf('    DialogParameters vazio\n'); continue, end

    nomes = fieldnames(dp);
    rel = nomes(~cellfun(@isempty, regexpi(nomes, ...
            'prio|init|start|_ic$|^ic_|current|^i_|_i$|variable')));
    if isempty(rel)
        fprintf('    nenhum parâmetro com cara de inicialização.\n');
        fprintf('    todos os parâmetros: %s\n', strjoin(nomes', ', '));
    else
        for j = 1:numel(rel)
            v = '';
            try, v = get_param(blk, rel{j}); end %#ok<TRYNC>
            if ~ischar(v), v = mat2str(v); end
            fprintf('    %-28s = %s\n', rel{j}, v);
        end
    end
end

fprintf(['\nSe algum bloco não foi encontrado, os nomes mudaram na conversão.\n' ...
         'Liste os indutores reais com:\n' ...
         '  find_system(mdlC,''LookUnderMasks'',''all'',''MaskType'',''Inductor'')\n\n']);
end

% -------------------------------------------------------------------------
function aplicar(alvos)
fprintf('\n===== APLICANDO Current = 0 A, priority High =====\n');

% Preenchidos a partir da saída de 'inspect'. Deixe vazio para o script
% tentar descobrir sozinho.
nomeValor     = '';   % ex.: 'i_ic'
nomePrioridade = '';  % ex.: 'i_priority'

ok = 0;
for k = 1:numel(alvos)
    blk = alvos{k};
    try
        [nv, np] = resolver_nomes(blk, nomeValor, nomePrioridade);
        if isempty(nv) || isempty(np)
            fprintf('  [PULADO] %s — nomes de parâmetro não resolvidos\n', blk);
            continue
        end
        set_param(blk, nv, '0');
        set_param(blk, np, 'High');
        fprintf('  [OK] %s  (%s=0, %s=High)\n', blk, nv, np);
        ok = ok + 1;
    catch ME
        fprintf('  [ERRO] %s — %s\n', blk, ME.message);
    end
end

fprintf('\n%d de %d ajustados.\n', ok, numel(alvos));
if ok == numel(alvos)
    fprintf('Salve com: save_system(''%s'')\n', bdroot(alvos{1}));
else
    fprintf(['NÃO salve ainda. Rode fix_inductor_ic(''inspect'') e preencha\n' ...
             'nomeValor/nomePrioridade no topo da subfunção aplicar().\n']);
end
end

% -------------------------------------------------------------------------
function [nv, np] = resolver_nomes(blk, nv, np)
% Descobre os nomes dos parâmetros de valor inicial e prioridade da corrente.
if ~isempty(nv) && ~isempty(np), return, end
dp = get_param(blk, 'DialogParameters');
nomes = fieldnames(dp);
if isempty(np)
    c = nomes(~cellfun(@isempty, regexpi(nomes, 'prio')));
    if isscalar(c), np = c{1}; end
end
if isempty(nv)
    c = nomes(~cellfun(@isempty, regexpi(nomes, '_ic$|^ic_|init')));
    if isscalar(c), nv = c{1}; end
end
end

% -------------------------------------------------------------------------
function n = get_name(blk)
parts = strsplit(blk, '/');
n = parts{end};
end
