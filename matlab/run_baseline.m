function out = run_baseline(stopTime, tag)
%RUN_BASELINE Roda o modelo e salva os sinais de referência para comparação.
%
%   run_baseline                 % 0.2 s, tag 'baseline'
%   run_baseline(5)              % run completo
%   run_baseline(0.2, 'r2025a')  % nomeia o arquivo de saída
%
% Salva em results/<tag>_<release>_<timestamp>.mat tudo que sai do bloco MPC
% mais as medições de potência. É esse arquivo que se compara depois da
% conversão para Simscape Electrical.
%
% NÃO TESTADO neste repositório (não há MATLAB no ambiente onde foi escrito).
% Se algo falhar, o erro deve ser óbvio e local.

if nargin < 1 || isempty(stopTime), stopTime = 0.2;        end
if nargin < 2 || isempty(tag),      tag = 'baseline';      end

here     = fileparts(mfilename('fullpath'));
modelDir = fullfile(here, '..', 'model');
mdl      = 'MMC_9lvl_matriz_tri_v12_Renner';
resDir   = fullfile(here, '..', 'results');
if ~exist(resDir, 'dir'), mkdir(resDir); end

addpath(modelDir);
load_system(fullfile(modelDir, [mdl '.slx']));

% ---- dependência externa: o Signal Editor aponta para um .mat absoluto ----
se = find_system(mdl, 'LookUnderMasks', 'all', 'SourceType', 'SignalEditor');
for k = 1:numel(se)
    if strcmp(get_param(se{k}, 'Commented'), 'on'), continue; end
    f = get_param(se{k}, 'FileName');
    if exist(f, 'file')
        fprintf('Signal Editor OK: %s\n', f);
    else
        error('run_baseline:sinais', ...
              ['Signal Editor "%s" aponta para "%s", que nao existe.\n' ...
               'Corrija o caminho (ou coloque Sinais.mat em model/) antes de rodar.'], ...
              se{k}, f);
    end
end

% ---- liga o log de todas as saidas do bloco MPC ----
mpcBlk = [mdl '/MPC'];
ph = get_param(mpcBlk, 'PortHandles');
nOK = 0;
for k = 1:numel(ph.Outport)
    try
        lh = get_param(ph.Outport(k), 'Line');
        if lh ~= -1
            set_param(lh, 'DataLogging', 'on');
            nOK = nOK + 1;
        end
    catch
        % porta sem linha conectada — ignora
    end
end
fprintf('log habilitado em %d de %d saidas do bloco MPC\n', nOK, numel(ph.Outport));

set_param(mdl, 'SignalLogging', 'on', 'SignalLoggingName', 'logsout');
set_param(mdl, 'StopTime', num2str(stopTime));

fprintf('simulando %g s ...\n', stopTime);
t0 = tic;
out = sim(mdl, 'ReturnWorkspaceOutputs', 'on');
fprintf('concluido em %.1f s de relogio\n', toc(t0));

stamp = datestr(now, 'yyyymmdd_HHMMSS');                    %#ok<DATST>
fname = fullfile(resDir, sprintf('%s_%s_%s.mat', tag, version('-release'), stamp));

meta = struct('release', version('-release'), ...
              'model',   mdl, ...
              'stopTime', stopTime, ...
              'when',    stamp);

save(fname, 'out', 'meta', '-v7.3');
fprintf('salvo em %s\n', fname);
end
