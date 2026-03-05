% =========================================================
% 批量输出脑激活图脚本
% 功能：读取SPM.mat，批量跑con1~con25，保存脑图PNG
% 修复1：thresDesc二次调用报错
% 修复2：spm_results_ui只画glass brain，需手动调用spm_list补全统计表
% 修复3：gin_dlabels需从base workspace读取xSPM/hReg
% 修复4：每次循环重建Graphics窗口，防止布局污染
% =========================================================

% 定义主路径
baseDirs = {
    '/Users/alexjiangzhe/Documents/My_project/fmri/internship_He_researsh_group/Project_Brain_inference/first_level/1'
};

% 定义被试文件夹名称（多被试时在下面列表里依次添加）
mainFolders = {'hand'};
% 多被试示例（取消注释即可）：
% mainFolders = {'sub1_1st','sub2_1st','sub3_1st'};

% 初始化SPM默认设置
spm('defaults', 'fMRI');
spm_jobman('initcfg');

% 遍历每个主路径
for iBaseDir = 1:length(baseDirs)
    baseDir = baseDirs{iBaseDir};

    % 遍历每个被试文件夹
    for iMainFolder = 1:length(mainFolders)
        mainFolderPath = fullfile(baseDir, mainFolders{iMainFolder});
        spmMatPath     = fullfile(mainFolderPath, 'SPM.mat');

        % 检查SPM.mat是否存在
        if ~exist(spmMatPath, 'file')
            fprintf('SPM.mat not found: %s. Skipping.\n', mainFolderPath);
            continue;
        end

        % 加载SPM.mat（只加载SPM变量，避免污染workspace）
        load(spmMatPath, 'SPM');

        % 检查是否已有contrast（xCon字段）
        if ~isfield(SPM, 'xCon') || isempty(SPM.xCon)
            fprintf('No xCon in %s. Skipping.\n', mainFolderPath);
            continue;
        end

        numCons = min(25, numel(SPM.xCon));

        for con = 1:numCons
            fprintf('--- Contrast %d/%d: %s ---\n', con, numCons, mainFolderPath);

            % ─────────────────────────────────────────────────────────────
            % 每次循环关闭旧窗口重建，防止上一轮gin_dlabels改坏布局
            % ─────────────────────────────────────────────────────────────
            F = spm_figure('FindWin', 'Graphics');
            if ~isempty(F) && ishandle(F)
                close(F);
            end
            Fgraph = spm_figure('GetWin', 'Graphics');

            % ─────────────────────────────────────────────────────────────
            % 第一次 spm_getSPM：传入完整配置结构体，实现非交互式批处理
            % 注：spm_getSPM内部会把 thresDesc='none' 改写为显示字符串
            %     因此第二次调用前必须重置（见下方核心修复）
            % ─────────────────────────────────────────────────────────────
            xSPM_cfg           = struct();
            xSPM_cfg.swd       = mainFolderPath; % SPM.mat所在目录
            xSPM_cfg.Ic        = con;            % contrast编号
            xSPM_cfg.u         = 0.001;          % p<0.001阈值（不做FWE/FDR校正）
            xSPM_cfg.thresDesc = 'none';         % 无校正
            xSPM_cfg.k         = 0;              % 不限制cluster大小
            xSPM_cfg.Im        = [];             % 全脑，不用mask
            xSPM_cfg.pm        = [];
            xSPM_cfg.Ex        = [];
            xSPM_cfg.title     = '';

            try
                [~, xSPM] = spm_getSPM(xSPM_cfg);
            catch ME
                warning('spm_getSPM failed (con %d): %s', con, ME.message);
                continue;
            end

            % 检查是否有存活体素
            if isempty(xSPM.Z)
                fprintf('No voxels survived (con %d). Skipping.\n', con);
                continue;
            end

            % ─────────────────────────────────────────────────────────────
            % ★ 核心修复1：重置 thresDesc，防止 spm_results_ui 内部
            %   再次调用 spm_getSPM 时报 unknown control method 错误
            % ─────────────────────────────────────────────────────────────
            xSPM.thresDesc = 'none';

            % 调用 spm_results_ui 绘制上半部分（glass brain + 设计矩阵）
            try
                [hReg, xSPM, ~] = spm_results_ui('Setup', xSPM);
            catch ME
                warning('spm_results_ui failed (con %d): %s', con, ME.message);
                continue;
            end

            % ─────────────────────────────────────────────────────────────
            % ★ 核心修复2：手动调用 spm_list 补全下半部分统计表
            %   spm_results_ui('Setup') 只画glass brain，不画统计表
            %   spm_list('List') 相当于手动点击 Results 界面的 whole brain 按钮
            % ─────────────────────────────────────────────────────────────
            TabDat = spm_list('List', xSPM, hReg);
            drawnow;

            % 保存完整脑激活图（含glass brain + 统计表）
            pngPath = fullfile(mainFolderPath, sprintf('contrast%d.png', con));
            try
                exportgraphics(Fgraph, pngPath, 'Resolution', 150);
            catch
                print(Fgraph, '-dpng', '-r150', pngPath);
            end
            fprintf('Saved: %s\n', pngPath);

            % ─────────────────────────────────────────────────────────────
            % 运行AAL3脑区标注并保存带标注的脑图
            % 注：必须先将 xSPM/hReg 写入 base workspace，
            %     gin_dlabels.m 内部用 evalin('base',...) 读取这两个变量
            % ─────────────────────────────────────────────────────────────
            try
                assignin('base', 'xSPM', xSPM);
                assignin('base', 'hReg', hReg);
                gin_dlabels();
                frame   = getframe(Fgraph);
                roiPath = fullfile(mainFolderPath, sprintf('contrast%d_roi.png', con));
                imwrite(frame.cdata, roiPath);
                fprintf('Saved ROI: %s\n', roiPath);
            catch ME
                fprintf('gin_dlabels skipped (con %d): %s\n', con, ME.message);
            end

        end % con循环
    end % 被试文件夹循环
end % 主路径循环
