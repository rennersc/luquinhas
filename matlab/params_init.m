% params_init.m
% Parâmetros do modelo MMC_9lvl_matriz_tri_v12_Renner.slx
% Extraídos do callback InitFcn do modelo (blockdiagram.xml). Rodar antes da
% simulação reproduz exatamente o workspace usado pelo TCC.

C     = 4000e-6;   % [F]  capacitância de cada submódulo
Larm  = 15e-3;     % [H]  indutor buffer de braço  (l no TCC)
Rarm  = 0;         % [ohm] resistência intrínseca de braço (r) — desprezada
R     = 5;         % [ohm] resistência do ramo CA de saída
L     = 100e-6;    % [H]  filtro indutivo de saída
Vcc   = 250;       % [V]  ATENÇÃO: é a METADE do elo. Elo total = 2*Vcc = 500 V
Vsm   = Vcc*2/4;   % [V]  = 125 V, tensão nominal de cada capacitor (Nsm = 4)
Vcap0 = Vsm;       % [V]  condição inicial dos capacitores (pré-carregados)
FR    = 20000;     % [Hz] taxa do controle
TS    = 1/FR;      % [s]  = 50 us, período de amostragem do MPC e do powergui
Vsa   = 120;       % [V]  amplitude das fontes senoidais da rede (60 Hz)
Pref  = 3000;      % [W]  sobrescrito no diagrama pelo Constant9 = 750
Qref  = 0;         % [var]
