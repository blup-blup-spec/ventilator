%% 
%% ============================================================
%  MECHANICAL VENTILATOR CONTROL SYSTEM
%  MATLAB R2026a  |  Times New Roman  |  No block colors
%  Runs Normal + Disturbed simulations automatically
%  Shows side-by-side comparison + live interactive window
%% ============================================================
clc; clear; close all;

fprintf('================================================\n');
fprintf('  MECHANICAL VENTILATOR CONTROL SYSTEM\n');
fprintf('================================================\n\n');

%% ================================================================
%% PART 1 — BUILD SIMULINK MODEL
%% ================================================================
projectFolder = fileparts(mfilename('fullpath'));
modelName     = 'MechVentilatorSystem';
modelFile     = fullfile(projectFolder, [modelName '.slx']);
cd(projectFolder);

fprintf('[1/4] Building Simulink model...\n');
if bdIsLoaded(modelName), close_system(modelName,0); end
if exist(modelFile,'file'), delete(modelFile); end

sys = new_system(modelName);
open_system(sys);
set_param(modelName,'Location',[50 50 1600 900]);

% --- BLOCK 1: Pulse Generator ---
add_block('simulink/Sources/Pulse Generator',...
    [modelName '/Breathing Cycle Input'],...
    'Period','4','PulseWidth','50','Amplitude','20','PhaseDelay','0',...
    'Position',[60 170 130 210]);

% --- BLOCK 2: Sum ---
add_block('simulink/Math Operations/Sum',...
    [modelName '/Error Signal'],...
    'Inputs','+-','Position',[230 165 260 205]);

% --- BLOCK 3: PID Controller ---
add_block('simulink/Continuous/PID Controller',...
    [modelName '/Ventilator Controller'],...
    'P','2','I','0.5','D','0.1',...
    'Position',[340 155 470 215]);

% --- BLOCK 4: Transfer Fcn ---
add_block('simulink/Continuous/Transfer Fcn',...
    [modelName '/Patient Lung Model'],...
    'Numerator','[1]','Denominator','[0.1 1]',...
    'Position',[560 163 670 207]);

% --- BLOCK 5a: Goto ---
add_block('simulink/Signal Routing/Goto',...
    [modelName '/Goto LungPressure'],...
    'GotoTag','LungPressure','Position',[760 163 840 197]);

% --- BLOCK 5b: From ---
add_block('simulink/Signal Routing/From',...
    [modelName '/From LungPressure'],...
    'GotoTag','LungPressure','Position',[230 290 310 320]);

% --- BLOCK 6: High Alarm ---
add_block('simulink/Logic and Bit Operations/Compare To Constant',...
    [modelName '/High Pressure Alarm'],...
    'relop','>','const','25','Position',[760 260 900 300]);

% --- BLOCK 7: Low Alarm ---
add_block('simulink/Logic and Bit Operations/Compare To Constant',...
    [modelName '/Low Pressure Alarm'],...
    'relop','<','const','5','Position',[760 330 900 370]);

% --- BLOCK 8a: Scope Lung ---
add_block('simulink/Sinks/Scope',...
    [modelName '/Lung Pressure Monitor'],'Position',[760 80 800 120]);

% --- BLOCK 8b: Scope Airflow ---
add_block('simulink/Sinks/Scope',...
    [modelName '/Airflow Rate Monitor'],'Position',[560 80 600 120]);

% --- BLOCK 8c: Mux + Alarm Scope ---
add_block('simulink/Signal Routing/Mux',...
    [modelName '/Alarm Mux'],'Inputs','2','Position',[960 270 990 360]);
add_block('simulink/Sinks/Scope',...
    [modelName '/Alarm Status'],'Position',[1050 295 1090 335]);

% --- BLOCK 9: Display ---
add_block('simulink/Sinks/Display',...
    [modelName '/Current Pressure Value'],'Position',[760 400 860 440]);

% --- WIRE all connections ---
add_line(modelName,'Breathing Cycle Input/1','Error Signal/1','autorouting','on');
add_line(modelName,'Error Signal/1','Ventilator Controller/1','autorouting','on');
add_line(modelName,'Ventilator Controller/1','Patient Lung Model/1','autorouting','on');
add_line(modelName,'Patient Lung Model/1','Goto LungPressure/1','autorouting','on');
add_line(modelName,'Patient Lung Model/1','Lung Pressure Monitor/1','autorouting','on');
add_line(modelName,'Patient Lung Model/1','Current Pressure Value/1','autorouting','on');
add_line(modelName,'Patient Lung Model/1','High Pressure Alarm/1','autorouting','on');
add_line(modelName,'Patient Lung Model/1','Low Pressure Alarm/1','autorouting','on');
add_line(modelName,'High Pressure Alarm/1','Alarm Mux/1','autorouting','on');
add_line(modelName,'Low Pressure Alarm/1','Alarm Mux/2','autorouting','on');
add_line(modelName,'Alarm Mux/1','Alarm Status/1','autorouting','on');
add_line(modelName,'From LungPressure/1','Error Signal/2','autorouting','on');
add_line(modelName,'Ventilator Controller/1','Airflow Rate Monitor/1','autorouting','on');

% --- Simulation config ---
set_param(modelName,'Solver','ode45','StopTime','30',...
    'MaxStep','0.01','StartTime','0','SolverType','Variable-step');

% --- Annotations (Times New Roman) ---
add_block('built-in/Note',[modelName '/TitleNote'],...
    'Position',[350 20 950 55],...
    'Text','MECHANICAL VENTILATOR CONTROL SYSTEM  |  MATLAB Simulink R2026a',...
    'FontName','Times New Roman','FontSize','14','FontWeight','bold');
add_block('built-in/Note',[modelName '/LoopNote'],...
    'Position',[60 130 680 152],...
    'Text','--- CLOSED-LOOP CONTROL PATH ---',...
    'FontName','Times New Roman','FontSize','9');
add_block('built-in/Note',[modelName '/FeedbackNote'],...
    'Position',[230 340 680 360],...
    'Text','--- FEEDBACK PATH (via Goto/From: LungPressure) ---',...
    'FontName','Times New Roman','FontSize','9');
add_block('built-in/Note',[modelName '/AlarmNote'],...
    'Position',[760 240 1000 258],...
    'Text','--- ALARM MONITORING ---',...
    'FontName','Times New Roman','FontSize','9');

save_system(modelName, modelFile);
fprintf('    Model saved: %s\n\n', modelFile);

%% ================================================================
%% PART 2 — RUN NORMAL SIMULATION
%% ================================================================
fprintf('[2/4] Running NORMAL simulation...\n');

t       = (0:0.01:30)';
HL      = 25;   % High alarm limit
LL      = 5;    % Low  alarm limit

% Normal parameters
N.amp  = 20;   N.period = 4;
N.P    = 2;    N.I      = 0.5;   N.D    = 0.1;
N.C    = 0.1;

ref_N   = N.amp .* double(mod(t, N.period) < N.period/2);
plant_N = tf(1,[N.C 1]);
ctrl_N  = pid(N.P, N.I, N.D);
cl_N    = feedback(ctrl_N * plant_N, 1);
lp_N    = lsim(cl_N, ref_N, t);
air_N   = ref_N - lp_N;
hiA_N   = double(lp_N > HL);
loA_N   = double(lp_N < LL);

fprintf('    Normal   | Max Pressure: %.2f cmH2O | Alarms: %d high, %d low\n',...
    max(lp_N), sum(diff(hiA_N)>0), sum(diff(loA_N)>0));

%% ================================================================
%% PART 3 — RUN DISTURBED SIMULATION
%% ================================================================
fprintf('[3/4] Running DISTURBED simulation...\n');

% Disturbed parameters (stiff lung + aggressive PID + high amplitude)
D_.amp  = 36;   D_.period = 4;
D_.P    = 12;   D_.I      = 1.8;  D_.D    = 0.8;
D_.C    = 0.65;

ref_D   = D_.amp .* double(mod(t, D_.period) < D_.period/2);
plant_D = tf(1,[D_.C 1]);
ctrl_D  = pid(D_.P, D_.I, D_.D);
cl_D    = feedback(ctrl_D * plant_D, 1);
lp_D    = lsim(cl_D, ref_D, t);
air_D   = ref_D - lp_D;
hiA_D   = double(lp_D > HL);
loA_D   = double(lp_D < LL);

fprintf('    Disturbed | Max Pressure: %.2f cmH2O | Alarms: %d high, %d low\n\n',...
    max(lp_D), sum(diff(hiA_D)>0), sum(diff(loA_D)>0));

%% ================================================================
%% PART 4 — COMPARISON FIGURE: Normal (Left) vs Disturbed (Right)
%% ================================================================
fprintf('[4/4] Plotting Normal vs Disturbed comparison...\n');

fig = figure('Name','Ventilator: Normal vs Disturbed Comparison',...
    'Color',[1 1 1],'Position',[40 40 1380 760],...
    'NumberTitle','off');

% Shared axis font settings
FN = 'Times New Roman';

%% ---- Column headers ----
annotation(fig,'textbox',[0.05 0.95 0.42 0.04],...
    'String','NORMAL CONDITION',...
    'FontName',FN,'FontSize',14,'FontWeight','bold',...
    'HorizontalAlignment','center','EdgeColor','none',...
    'Color',[0 0.45 0]);

annotation(fig,'textbox',[0.53 0.95 0.44 0.04],...
    'String','DISTURBED CONDITION',...
    'FontName',FN,'FontSize',14,'FontWeight','bold',...
    'HorizontalAlignment','center','EdgeColor','none',...
    'Color',[0.75 0 0]);

annotation(fig,'textbox',[0.0 0.99 1 0.01],...
    'String','MECHANICAL VENTILATOR CONTROL SYSTEM — Simulation Results',...
    'FontName',FN,'FontSize',13,'FontWeight','bold',...
    'HorizontalAlignment','center','EdgeColor','none',...
    'Color',[0 0 0]);

%% ---- Row 1: Lung Pressure ----
ax11 = subplot(3,2,1);
plot(t, ref_N,'--k','LineWidth',1,'DisplayName','Reference'); hold on;
plot(t, lp_N, '-k','LineWidth',2,'DisplayName','Lung Pressure');
yline(HL,'-.','High Alarm = 25','Color',[0.4 0.4 0.4],...
    'LabelHorizontalAlignment','left','FontName',FN,'FontSize',8,'LineWidth',1);
yline(LL,':','Low Alarm = 5','Color',[0.4 0.4 0.4],...
    'LabelHorizontalAlignment','left','FontName',FN,'FontSize',8,'LineWidth',1);
ylabel('Pressure (cmH_{2}O)','FontName',FN,'FontSize',11);
title('Lung Pressure vs Reference','FontName',FN,'FontSize',12,'FontWeight','bold');
legend('FontName',FN,'FontSize',9,'Location','northeast');
ylim([-3 35]); grid on; box on;
set(ax11,'FontName',FN,'FontSize',10,'GridAlpha',0.25);

ax12 = subplot(3,2,2);
plot(t, ref_D,'--k','LineWidth',1,'DisplayName','Reference'); hold on;
p1=plot(t, lp_D, '-k','LineWidth',2,'DisplayName','Lung Pressure');
% Shade alarm regions
fill_hi = lp_D; fill_hi(lp_D <= HL) = HL;
fill([t;flipud(t)],[fill_hi;HL*ones(size(t))],...
    [0.9 0.7 0.7],'EdgeColor','none','FaceAlpha',0.6,'DisplayName','HIGH Alarm zone');
yline(HL,'-.','High Alarm = 25','Color',[0.5 0 0],...
    'LabelHorizontalAlignment','left','FontName',FN,'FontSize',8,'LineWidth',1.2);
yline(LL,':','Low Alarm = 5','Color',[0.5 0 0],...
    'LabelHorizontalAlignment','left','FontName',FN,'FontSize',8,'LineWidth',1.2);
ylabel('Pressure (cmH_{2}O)','FontName',FN,'FontSize',11);
title('Lung Pressure vs Reference','FontName',FN,'FontSize',12,'FontWeight','bold');
legend('FontName',FN,'FontSize',9,'Location','northeast');
ylim([-3 50]); grid on; box on;
set(ax12,'FontName',FN,'FontSize',10,'GridAlpha',0.25);

%% ---- Row 2: Airflow (PID output) ----
ax21 = subplot(3,2,3);
plot(t, air_N,'-k','LineWidth',2);
ylabel('Airflow (L/min)','FontName',FN,'FontSize',11);
title('PID Output — Airflow Rate','FontName',FN,'FontSize',12,'FontWeight','bold');
grid on; box on;
set(ax21,'FontName',FN,'FontSize',10,'GridAlpha',0.25);

ax22 = subplot(3,2,4);
plot(t, air_D,'-k','LineWidth',2);
ylabel('Airflow (L/min)','FontName',FN,'FontSize',11);
title('PID Output — Airflow Rate','FontName',FN,'FontSize',12,'FontWeight','bold');
grid on; box on;
set(ax22,'FontName',FN,'FontSize',10,'GridAlpha',0.25);

%% ---- Row 3: Alarm Status ----
ax31 = subplot(3,2,5);
area(t, hiA_N,'FaceColor',[0.8 0.8 0.8],'EdgeColor','k','LineWidth',1.2,...
    'DisplayName','High Alarm (>25)'); hold on;
plot(t, loA_N,'--k','LineWidth',1.5,'DisplayName','Low Alarm (<5)');
ylim([-0.2 1.6]);
yticks([0 1]); yticklabels({'OFF','ON'});
ylabel('Alarm State','FontName',FN,'FontSize',11);
xlabel('Time (seconds)','FontName',FN,'FontSize',11);
title('Alarm Status','FontName',FN,'FontSize',12,'FontWeight','bold');
legend('FontName',FN,'FontSize',9,'Location','northeast');
grid on; box on;
set(ax31,'FontName',FN,'FontSize',10,'GridAlpha',0.25);
text(1,1.35,'No alarms triggered','FontName',FN,'FontSize',10,...
    'Color',[0 0.45 0],'FontWeight','bold');

ax32 = subplot(3,2,6);
area(t, hiA_D,'FaceColor',[0.75 0.75 0.75],'EdgeColor','k','LineWidth',1.2,...
    'DisplayName','High Alarm (>25)'); hold on;
plot(t, loA_D,'--k','LineWidth',1.5,'DisplayName','Low Alarm (<5)');
ylim([-0.2 1.6]);
yticks([0 1]); yticklabels({'OFF','ON'});
ylabel('Alarm State','FontName',FN,'FontSize',11);
xlabel('Time (seconds)','FontName',FN,'FontSize',11);
title('Alarm Status','FontName',FN,'FontSize',12,'FontWeight','bold');
legend('FontName',FN,'FontSize',9,'Location','northeast');
grid on; box on;
set(ax32,'FontName',FN,'FontSize',10,'GridAlpha',0.25);
nHi = sum(diff(hiA_D)>0);
text(1,1.35,sprintf('HIGH alarm triggered %d times!',nHi),...
    'FontName',FN,'FontSize',10,'Color',[0.75 0 0],'FontWeight','bold');

% Vertical separator line between columns
annotation(fig,'line',[0.5 0.5],[0.02 0.97],...
    'Color',[0.6 0.6 0.6],'LineStyle','--','LineWidth',1.5);

fprintf('\n  Launching interactive demo window...\n');
fprintf('  Move sliders or press DISTURB to trigger alarms live.\n\n');
launchVentilatorDemo();

%% ================================================================
%% LOCAL FUNCTION — Interactive Demo Window
%% ================================================================
function launchVentilatorDemo()

    HL = 25;  LL = 5;
    DEF.amp=20; DEF.period=4; DEF.P=2; DEF.I=0.5; DEF.D=0.1; DEF.C=0.1;
    FN = 'Times New Roman';

    fig = uifigure('Name','Ventilator — Live Interactive Demo',...
        'Position',[30 30 1380 740],'Color',[1 1 1],'Resize','on');

    gl = uigridlayout(fig,[1 2]);
    gl.ColumnWidth   = {'1x','3x'};
    gl.Padding       = [10 10 10 10];
    gl.ColumnSpacing = 12;

    %% ---- LEFT PANEL ----
    LP = uipanel(gl,'Title','Parameters','FontName',FN,'FontSize',13,...
        'FontWeight','bold','BackgroundColor',[1 1 1]);
    LP.Layout.Column = 1;

    lgL = uigridlayout(LP,[24 2]);
    lgL.RowHeight   = repmat({'1x'},1,24);
    lgL.ColumnWidth = {'2x','3x'};
    lgL.Padding     = [8 8 8 8];

    % Status bar
    statusLbl = uilabel(lgL,'Text','STATUS:  NORMAL  ✓',...
        'FontName',FN,'FontSize',15,'FontWeight','bold',...
        'FontColor',[0 0.50 0],'HorizontalAlignment','center',...
        'BackgroundColor',[0.9 0.97 0.9]);
    statusLbl.Layout.Row=[1 2]; statusLbl.Layout.Column=[1 2];

    % Pressure readout
    pressLbl = uilabel(lgL,'Text','Pressure:  --  cmH2O',...
        'FontName',FN,'FontSize',11,'HorizontalAlignment','center');
    pressLbl.Layout.Row=[3 4]; pressLbl.Layout.Column=[1 2];

    % Slider helper
    function [sl,vl] = mkSlider(parent,row,lbl,mn,mx,val,fmt)
        l = uilabel(parent,'Text',lbl,'FontName',FN,'FontSize',10,...
            'HorizontalAlignment','right');
        l.Layout.Row=row; l.Layout.Column=1;
        sl = uislider(parent,'Limits',[mn mx],'Value',val,...
            'FontName',FN,'FontSize',8);
        sl.Layout.Row=row; sl.Layout.Column=2;
        vl = uilabel(parent,'Text',sprintf(fmt,val),...
            'FontName',FN,'FontSize',10,'HorizontalAlignment','center');
        vl.Layout.Row=row+1; vl.Layout.Column=2;
    end

    [slAmp,lAmp] = mkSlider(lgL, 5,'Amplitude',     5, 40, DEF.amp,    '%.0f cmH2O');
    [slPer,lPer] = mkSlider(lgL, 7,'Breath Period',  2, 10, DEF.period, '%.1f s');
    [slP,  lP  ] = mkSlider(lgL, 9,'P Gain',         0, 15, DEF.P,      '%.1f');
    [slI,  lI  ] = mkSlider(lgL,11,'I Gain',         0,  2, DEF.I,      '%.2f');
    [slD,  lD  ] = mkSlider(lgL,13,'D Gain',         0,  1, DEF.D,      '%.2f');
    [slC,  lC  ] = mkSlider(lgL,15,'Lung Compliance',0.02,0.8,DEF.C,    '%.3f');

    % Alarm indicator labels
    hiLbl = uilabel(lgL,'Text','HIGH PRESSURE  > 25  cmH2O',...
        'FontName',FN,'FontSize',10,'FontWeight','bold',...
        'FontColor',[0.6 0.6 0.6],'HorizontalAlignment','center',...
        'BackgroundColor',[0.95 0.95 0.95]);
    hiLbl.Layout.Row=17; hiLbl.Layout.Column=[1 2];

    loLbl = uilabel(lgL,'Text','LOW PRESSURE   < 5   cmH2O',...
        'FontName',FN,'FontSize',10,'FontWeight','bold',...
        'FontColor',[0.6 0.6 0.6],'HorizontalAlignment','center',...
        'BackgroundColor',[0.95 0.95 0.95]);
    loLbl.Layout.Row=18; loLbl.Layout.Column=[1 2];

    % Buttons
    bDis = uibutton(lgL,'push','Text','DISTURB SYSTEM',...
        'FontName',FN,'FontSize',11,'FontWeight','bold',...
        'BackgroundColor',[0.80 0.10 0.10],'FontColor',[1 1 1],...
        'ButtonPushedFcn',@(~,~) doDisturb());
    bDis.Layout.Row=[20 22]; bDis.Layout.Column=1;

    bRes = uibutton(lgL,'push','Text','RESET TO NORMAL',...
        'FontName',FN,'FontSize',11,'FontWeight','bold',...
        'BackgroundColor',[0.08 0.40 0.08],'FontColor',[1 1 1],...
        'ButtonPushedFcn',@(~,~) doReset());
    bRes.Layout.Row=[20 22]; bRes.Layout.Column=2;

    % Slider label updaters
    slAmp.ValueChangingFcn = @(s,~) set(lAmp,'Text',sprintf('%.0f cmH2O',s.Value));
    slPer.ValueChangingFcn = @(s,~) set(lPer,'Text',sprintf('%.1f s',s.Value));
    slP.ValueChangingFcn   = @(s,~) set(lP,  'Text',sprintf('%.1f',s.Value));
    slI.ValueChangingFcn   = @(s,~) set(lI,  'Text',sprintf('%.2f',s.Value));
    slD.ValueChangingFcn   = @(s,~) set(lD,  'Text',sprintf('%.2f',s.Value));
    slC.ValueChangingFcn   = @(s,~) set(lC,  'Text',sprintf('%.3f',s.Value));

    function doDisturb()
        slAmp.Value=36; set(lAmp,'Text','36 cmH2O');
        slP.Value=12;   set(lP,  'Text','12.0');
        slI.Value=1.8;  set(lI,  'Text','1.80');
        slD.Value=0.8;  set(lD,  'Text','0.80');
        slC.Value=0.65; set(lC,  'Text','0.650');
    end
    function doReset()
        slAmp.Value=DEF.amp;    set(lAmp,'Text',sprintf('%.0f cmH2O',DEF.amp));
        slPer.Value=DEF.period; set(lPer,'Text',sprintf('%.1f s',DEF.period));
        slP.Value=DEF.P;        set(lP,  'Text',sprintf('%.1f',DEF.P));
        slI.Value=DEF.I;        set(lI,  'Text',sprintf('%.2f',DEF.I));
        slD.Value=DEF.D;        set(lD,  'Text',sprintf('%.2f',DEF.D));
        slC.Value=DEF.C;        set(lC,  'Text',sprintf('%.3f',DEF.C));
    end

    %% ---- RIGHT PANEL — 3 live plots ----
    RP = uipanel(gl,'Title','Real-Time Signal Monitor',...
        'FontName',FN,'FontSize',13,'FontWeight','bold',...
        'BackgroundColor',[1 1 1]);
    RP.Layout.Column = 2;

    rpGL = uigridlayout(RP,[3 1]);
    rpGL.RowHeight = {'1x','1x','1x'};
    rpGL.Padding   = [8 8 8 8];

    ax1 = uiaxes(rpGL); ax1.Layout.Row=1;
    ax2 = uiaxes(rpGL); ax2.Layout.Row=2;
    ax3 = uiaxes(rpGL); ax3.Layout.Row=3;

    for ax = [ax1 ax2 ax3]
        ax.FontName='Times New Roman'; ax.FontSize=10;
        ax.XGrid='on'; ax.YGrid='on'; ax.Box='on';
        ax.GridColor=[0.82 0.82 0.82]; ax.Color=[1 1 1];
        hold(ax,'on');
    end

    title(ax1,'Lung Pressure vs. Reference','FontName',FN,'FontSize',12,'FontWeight','bold');
    ylabel(ax1,'Pressure (cmH2O)','FontName',FN,'FontSize',10);
    xlabel(ax1,'Time (s)','FontName',FN,'FontSize',10);

    title(ax2,'PID Output — Airflow Rate','FontName',FN,'FontSize',12,'FontWeight','bold');
    ylabel(ax2,'Airflow (L/min)','FontName',FN,'FontSize',10);
    xlabel(ax2,'Time (s)','FontName',FN,'FontSize',10);

    title(ax3,'Alarm Status','FontName',FN,'FontSize',12,'FontWeight','bold');
    ylabel(ax3,'State','FontName',FN,'FontSize',10);
    xlabel(ax3,'Time (s)','FontName',FN,'FontSize',10);
    yticks(ax3,[0 1]); yticklabels(ax3,{'OFF','ON'});

    yline(ax1,HL,'-.k','High = 25','LabelHorizontalAlignment','left',...
        'FontName',FN,'FontSize',8,'LineWidth',1);
    yline(ax1,LL,':k', 'Low = 5', 'LabelHorizontalAlignment','left',...
        'FontName',FN,'FontSize',8,'LineWidth',1);

    xlim(ax1,[0 30]); ylim(ax1,[-3 50]);
    xlim(ax2,[0 30]);
    xlim(ax3,[0 30]); ylim(ax3,[-0.3 1.6]);

    hRef  = animatedline(ax1,'LineStyle','--','Color',[0.5 0.5 0.5],'LineWidth',1,'DisplayName','Reference');
    hPres = animatedline(ax1,'LineStyle','-', 'Color',[0 0 0],      'LineWidth',2,'DisplayName','Lung Pressure');
    hAir  = animatedline(ax2,'LineStyle','-', 'Color',[0 0 0],      'LineWidth',2);
    hHi   = animatedline(ax3,'LineStyle','-', 'Color',[0 0 0],      'LineWidth',2,'DisplayName','High Alarm');
    hLo   = animatedline(ax3,'LineStyle','--','Color',[0.4 0.4 0.4],'LineWidth',2,'DisplayName','Low Alarm');
    legend(ax1,'FontName',FN,'FontSize',9,'Location','northeast');
    legend(ax3,'FontName',FN,'FontSize',9,'Location','northeast');

    %% ---- Animation loop ----
    dt = 0.05;  WIN = 30;  t_now = 0;

    while ishandle(fig)
        amp  = slAmp.Value;  period = slPer.Value;
        P    = slP.Value;    I      = slI.Value;
        D    = slD.Value;    C      = slC.Value;

        tc = (0:0.005:dt)';
        rc = amp .* double(mod(t_now + tc, period) < period/2);

        plant = tf(1,[C 1]);
        ctrl  = pid(P,I,D);
        cl    = feedback(ctrl*plant,1);
        lp_c  = lsim(cl, rc, tc);

        lp_end  = lp_c(end);
        ref_end = rc(end);
        air_end = ref_end - lp_end;

        addpoints(hRef,  t_now, ref_end);
        addpoints(hPres, t_now, lp_end);
        addpoints(hAir,  t_now, air_end);
        addpoints(hHi,   t_now, double(lp_end > HL));
        addpoints(hLo,   t_now, double(lp_end < LL));

        if t_now > WIN
            xlim(ax1,[t_now-WIN t_now]);
            xlim(ax2,[t_now-WIN t_now]);
            xlim(ax3,[t_now-WIN t_now]);
        end
        ylim(ax2,[min(-2,air_end-3), max(amp+5,air_end+3)]);

        % Status update
        if lp_end > HL
            set(statusLbl,'Text','STATUS:  HIGH PRESSURE ALARM  !!',...
                'FontColor',[0.80 0 0],'BackgroundColor',[1 0.88 0.88]);
            set(hiLbl,'FontColor',[0.80 0 0],'BackgroundColor',[1 0.82 0.82]);
            set(loLbl,'FontColor',[0.6 0.6 0.6],'BackgroundColor',[0.95 0.95 0.95]);
        elseif lp_end < LL
            set(statusLbl,'Text','STATUS:  LOW PRESSURE ALARM  !!',...
                'FontColor',[0.50 0 0.60],'BackgroundColor',[0.96 0.90 1.00]);
            set(loLbl,'FontColor',[0.50 0 0.60],'BackgroundColor',[0.93 0.88 1.00]);
            set(hiLbl,'FontColor',[0.6 0.6 0.6],'BackgroundColor',[0.95 0.95 0.95]);
        else
            set(statusLbl,'Text','STATUS:  NORMAL  OK',...
                'FontColor',[0 0.50 0],'BackgroundColor',[0.9 0.97 0.9]);
            set(hiLbl,'FontColor',[0.6 0.6 0.6],'BackgroundColor',[0.95 0.95 0.95]);
            set(loLbl,'FontColor',[0.6 0.6 0.6],'BackgroundColor',[0.95 0.95 0.95]);
        end
        set(pressLbl,'Text',sprintf('Pressure:  %.2f  cmH2O', lp_end));

        t_now = t_now + dt;
        drawnow limitrate;
        pause(0.04);
    end
end

