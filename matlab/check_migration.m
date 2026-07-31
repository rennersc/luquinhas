function check_migration(modelPath)
%CHECK_MIGRATION Diagnostica a disponibilidade das bibliotecas do modelo DS-MMC.
%
%   check_migration                 usa model/MMC_9lvl_matriz_tri_v12_Renner.slx
%   check_migration('caminho.slx')
%
% Responde três perguntas, em ordem:
%   1. O produto Specialized Power Systems está instalado e licenciado?
%   2. O bloco powergui existe nesta release?  (sem ele, nenhum modelo SPS compila)
%   3. Quais blocos do modelo têm link não resolvido?
%
% Rode na release nova e guarde a saída — é o que decide se a migração é
% "instalar um add-on" ou "reconstruir a rede elétrica".

if nargin < 1
    here = fileparts(mfilename('fullpath'));
    modelPath = fullfile(here, '..', 'model', 'MMC_9lvl_matriz_tri_v12_Renner.slx');
end

fprintf('\n===== 1. AMBIENTE =====\n');
fprintf('MATLAB      : %s\n', version);
fprintf('Release     : %s\n', version('-release'));

produtos = ver;
alvo = {'Simscape', 'Simscape Electrical', 'Simulink', 'Stateflow'};
for k = 1:numel(alvo)
    idx = strcmp({produtos.Name}, alvo{k});
    if any(idx)
        p = produtos(find(idx, 1));
        fprintf('  [OK]     %-22s %s\n', p.Name, p.Version);
    else
        fprintf('  [AUSENTE] %-22s (nao instalado)\n', alvo{k});
    end
end

feats = {'Power_System_Blocks', 'Simscape', 'SimElectronics'};
for k = 1:numel(feats)
    try
        ok = license('test', feats{k});
    catch
        ok = 0;
    end
    fprintf('  licenca %-22s : %d\n', feats{k}, ok);
end

fprintf('\n===== 2. BIBLIOTECA E POWERGUI =====\n');

% A biblioteca SPS existe no path?
libFile = which('sps_lib');
if isempty(libFile)
    fprintf('  [FALHA] sps_lib nao encontrada no path.\n');
else
    fprintf('  [OK]    sps_lib -> %s\n', libFile);
end

% O bloco powergui existe dentro dela? Sem powergui, nenhum modelo SPS roda.
temPowergui = false;
try
    load_system('sps_lib');
    achou = find_system('sps_lib', 'SearchDepth', 1, 'Name', 'powergui');
    temPowergui = ~isempty(achou);
catch ME
    fprintf('  [FALHA] nao foi possivel abrir sps_lib: %s\n', ME.message);
end
if temPowergui
    fprintf('  [OK]    bloco powergui presente em sps_lib\n');
else
    fprintf('  [FALHA] bloco powergui NAO encontrado em sps_lib\n');
    fprintf('          => a rede eletrica precisa migrar para Simscape nativo\n');
    fprintf('             (powergui -> Solver Configuration)\n');
end

% Procura por qualquer bloco/funcao de nome parecido, caso tenha sido renomeado.
fprintf('  procurando nomes alternativos:\n');
for nome = {'powergui', 'power_gui', 'Solver Configuration'}
    w = which(nome{1});
    if isempty(w)
        fprintf('    %-22s : nao encontrado\n', nome{1});
    else
        fprintf('    %-22s : %s\n', nome{1}, w);
    end
end

fprintf('\n===== 3. LINKS DO MODELO =====\n');
[~, modelName] = fileparts(modelPath);
try
    load_system(modelPath);
catch ME
    fprintf('  [FALHA] o modelo nao carregou: %s\n', ME.message);
    fprintf('  (isso ja e a resposta: alguma dependencia esta faltando)\n');
    return
end

blocos = find_system(modelName, 'LookUnderMasks', 'all', ...
                     'FollowLinks', 'off', 'BlockType', 'Reference');
fprintf('  %d blocos de biblioteca no modelo\n', numel(blocos));

ruins = {};
resumo = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(blocos)
    b = blocos{k};
    try
        st  = get_param(b, 'LinkStatus');
        src = get_param(b, 'SourceBlock');
    catch
        st = 'erro'; src = '?';
    end
    chave = sprintf('%s | %s', src, st);
    if isKey(resumo, chave), resumo(chave) = resumo(chave) + 1;
    else,                    resumo(chave) = 1;
    end
    if ~strcmp(st, 'resolved')
        ruins{end+1} = sprintf('    %s  [%s]  <- %s', b, st, src); %#ok<AGROW>
    end
end

fprintf('\n  por bloco de origem:\n');
ks = keys(resumo);
for k = 1:numel(ks)
    fprintf('    %-58s %3d\n', ks{k}, resumo(ks{k}));
end

if isempty(ruins)
    fprintf('\n  [OK] todos os links resolvidos.\n');
else
    fprintf('\n  [FALHA] %d bloco(s) com link nao resolvido:\n', numel(ruins));
    fprintf('%s\n', ruins{:});
end

fprintf('\n===== FIM =====\n');
end
