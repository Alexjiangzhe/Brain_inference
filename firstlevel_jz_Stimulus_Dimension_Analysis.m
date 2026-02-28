clear; clc;
spm('defaults', 'FMRI');
spm_jobman('initcfg');

%% ===== 用户配置区域 =====
subjects_to_run  = {'1'};
onset_base_dir   = '/Users/alexjiangzhe/Documents/My_project/fmri/internship_He_researsh_group/Project_Brain_inference/first_level/onset';
preproc_base_dir = '/Users/alexjiangzhe/Documents/My_project/fmri/internship_He_researsh_group/preprocess_data/preprocess';
output_base_dir  = '/Users/alexjiangzhe/Documents/My_project/fmri/internship_He_researsh_group/Project_Brain_inference/first_level/1/code';

onset_filename = 'onset1.xlsx';
event_duration = 6;

% ===== Excel 列索引=====
% Nature 条件
COL_NATURE_ONSET      = 1;  % A列
COL_NATURE_VALENCE    = 2;  % B列
COL_NATURE_AROUSAL    = 3;  % C列
COL_NATURE_DIFFICULTY = 4;  % D列
COL_NATURE_INFO       = 5;  % E列
% Strategy 条件
COL_STRATEGY_ONSET      = 6;  % F列
COL_STRATEGY_VALENCE    = 7;  % G列
COL_STRATEGY_AROUSAL    = 8;  % H列
COL_STRATEGY_DIFFICULTY = 9;  % I列
COL_STRATEGY_INFO       = 10; % J列

%% ===== 主循环 =====
for i = 1:length(subjects_to_run)
    subject_number = subjects_to_run{i};
    fprintf('====== 开始处理被试: %s ======\n', subject_number);
    try
        output_dir = fullfile(output_base_dir, subject_number);
        if exist(output_dir, 'dir')
            delete(fullfile(output_dir, '*.nii'));
            delete(fullfile(output_dir, '*.mat'));
            delete(fullfile(output_dir, '*.hdr'));
            delete(fullfile(output_dir, '*.img'));
            fprintf('  [已清空] 输出目录: %s\n', output_dir);
        else
            mkdir(output_dir);
        end

        %% ===== 读取 Onset 数据 =====
        onset_file = fullfile(onset_base_dir, subject_number, onset_filename);
        if ~exist(onset_file, 'file')
            error('未找到 onset 文件: %s', onset_file);
        end
        T   = readtable(onset_file, 'ReadVariableNames', false);
        raw = T{2:end, :};

        % --- Nature ---
        nature_onset      = raw(:, COL_NATURE_ONSET);
        nature_valence    = raw(:, COL_NATURE_VALENCE);
        nature_arousal    = raw(:, COL_NATURE_AROUSAL);
        nature_difficulty = raw(:, COL_NATURE_DIFFICULTY);
        nature_info       = raw(:, COL_NATURE_INFO);

        valid_n = ~isnan(nature_onset);
        nature_onset      = nature_onset(valid_n)';
        nature_valence    = nature_valence(valid_n)';
        nature_arousal    = nature_arousal(valid_n)';
        nature_difficulty = nature_difficulty(valid_n)';
        nature_info       = nature_info(valid_n)';

        % --- Strategy ---
        strategy_onset      = raw(:, COL_STRATEGY_ONSET);
        strategy_valence    = raw(:, COL_STRATEGY_VALENCE);
        strategy_arousal    = raw(:, COL_STRATEGY_AROUSAL);
        strategy_difficulty = raw(:, COL_STRATEGY_DIFFICULTY);
        strategy_info       = raw(:, COL_STRATEGY_INFO);

        valid_s = ~isnan(strategy_onset);
        strategy_onset      = strategy_onset(valid_s)';
        strategy_valence    = strategy_valence(valid_s)';
        strategy_arousal    = strategy_arousal(valid_s)';
        strategy_difficulty = strategy_difficulty(valid_s)';
        strategy_info       = strategy_info(valid_s)';

        fprintf('  [✓] Nature:   %d trials, valence均值=%.2f, arousal均值=%.2f\n', ...
            numel(nature_onset), mean(nature_valence), mean(nature_arousal));
        fprintf('  [✓] Strategy: %d trials, valence均值=%.2f, arousal均值=%.2f\n', ...
            numel(strategy_onset), mean(strategy_valence), mean(strategy_arousal));

        %% ===== 初始化 batch =====
        clear matlabbatch
        matlabbatch{1}.spm.stats.fmri_spec.dir            = {output_dir};
        matlabbatch{1}.spm.stats.fmri_spec.timing.units   = 'secs';
        matlabbatch{1}.spm.stats.fmri_spec.timing.RT      = 1.5;
        matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t  = 72;
        matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t0 = 36;

        % ===== 扫描文件 =====
        sess = 1;
        subj_pre_dir = fullfile(preproc_base_dir, subject_number);
        swuaf_dir    = fullfile(subj_pre_dir, 'sw');
        if ~exist(swuaf_dir, 'dir'), error('未找到 sw 目录: %s', swuaf_dir); end
        nii_struct = dir(fullfile(swuaf_dir, '*.nii'));
        if isempty(nii_struct), error('未找到 NIfTI 文件: %s', swuaf_dir); end
        [~, order] = sort({nii_struct.name});
        nii_struct  = nii_struct(order);
        scans = cell(numel(nii_struct), 1);
        for ii = 1:numel(nii_struct)
            scans{ii,1} = fullfile(swuaf_dir, nii_struct(ii).name);
        end
        fprintf('  [✓] 找到 %d 个 volume\n', numel(nii_struct));
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).scans = scans;

        % ===== 条件1：Nature（含4个PM）=====
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(1).name     = 'Nature';
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(1).onset    = nature_onset;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(1).duration = event_duration;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(1).tmod     = 0;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(1).orth     = 0;

        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(1).pmod(1).name  = 'Valence';
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(1).pmod(1).param = nature_valence;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(1).pmod(1).poly  = 1;

        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(1).pmod(2).name  = 'Arousal';
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(1).pmod(2).param = nature_arousal;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(1).pmod(2).poly  = 1;

        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(1).pmod(3).name  = 'Difficulty';
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(1).pmod(3).param = nature_difficulty;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(1).pmod(3).poly  = 1;

        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(1).pmod(4).name  = 'Information';
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(1).pmod(4).param = nature_info;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(1).pmod(4).poly  = 1;

        % ===== 条件2：Strategy（含4个PM）=====
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(2).name     = 'Strategy';
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(2).onset    = strategy_onset;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(2).duration = event_duration;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(2).tmod     = 0;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(2).orth     = 0;

        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(2).pmod(1).name  = 'Valence';
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(2).pmod(1).param = strategy_valence;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(2).pmod(1).poly  = 1;

        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(2).pmod(2).name  = 'Arousal';
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(2).pmod(2).param = strategy_arousal;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(2).pmod(2).poly  = 1;

        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(2).pmod(3).name  = 'Difficulty';
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(2).pmod(3).param = strategy_difficulty;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(2).pmod(3).poly  = 1;

        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(2).pmod(4).name  = 'Information';
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(2).pmod(4).param = strategy_info;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(2).pmod(4).poly  = 1;

        % ===== 其他 Session 设置 =====
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).multi     = {''};
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).hpf       = 128;

        rp_mat = dir(fullfile(subj_pre_dir, 'art_*.mat'));
        if isempty(rp_mat), rp_mat = dir(fullfile(swuaf_dir, 'art_*.mat')); end
        rp_txt = dir(fullfile(subj_pre_dir, 'rp_*.txt'));
        if isempty(rp_txt), rp_txt = dir(fullfile(swuaf_dir, 'rp_*.txt')); end
        if     ~isempty(rp_mat), motion_file = fullfile(rp_mat(1).folder, rp_mat(1).name);
        elseif ~isempty(rp_txt), motion_file = fullfile(rp_txt(1).folder, rp_txt(1).name);
        else,  error('未找到运动文件 (art_* 或 rp_*): %s', subj_pre_dir);
        end
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).multi_reg = {motion_file};

        matlabbatch{1}.spm.stats.fmri_spec.fact             = struct('name', {}, 'levels', {});
        matlabbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = [0 0];
        matlabbatch{1}.spm.stats.fmri_spec.volt             = 1;
        matlabbatch{1}.spm.stats.fmri_spec.global           = 'None';
        matlabbatch{1}.spm.stats.fmri_spec.mthresh          = 0.8;
        matlabbatch{1}.spm.stats.fmri_spec.mask             = {''};
        matlabbatch{1}.spm.stats.fmri_spec.cvi              = 'AR(1)';

        %% ===== 模型估计 =====
        matlabbatch{2}.spm.stats.fmri_est.spmmat(1) = cfg_dep( ...
            'fMRI model specification: SPM.mat File', ...
            substruct('.','val','{}',{1},'.','val','{}',{1},'.','val','{}',{1}), ...
            substruct('.','spmmat'));
        matlabbatch{2}.spm.stats.fmri_est.write_residuals = 0;
        matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;

               %% ===== 对比设置 =====
        % 设计矩阵列顺序（SPM 自动生成，每个PM独立一列）：
        %   列1:  Nature_Main
        %   列2:  Nature x Valence
        %   列3:  Nature x Arousal
        %   列4:  Nature x Difficulty
        %   列5:  Nature x Information
        %   列6:  Strategy_Main
        %   列7:  Strategy x Valence
        %   列8:  Strategy x Arousal
        %   列9:  Strategy x Difficulty
        %   列10: Strategy x Information
        %   列11-16: 6个运动参数
        %   列17: 常数项
        matlabbatch{3}.spm.stats.con.spmmat(1) = cfg_dep( ...
            'Model estimation: SPM.mat File', ...
            substruct('.','val','{}',{2},'.','val','{}',{1},'.','val','{}',{1}), ...
            substruct('.','spmmat'));

        cons = {
            % ===== 第一组：主效应 =====
            'Nature_Main',                               [1  0  0  0  0  0  0  0  0  0];
            'Strategy_Main',                             [0  0  0  0  0  1  0  0  0  0];
            'Nature > Strategy (Main)',                  [1  0  0  0  0 -1  0  0  0  0];
            'Strategy > Nature (Main)',                  [-1  0  0  0  0  1  0  0  0  0];
            'Nature + Strategy (Main)',                  [1  0  0  0  0  1  0  0  0  0];
            % ===== 第二组：nature 里各维度效应 =====
            'Nature x Valence',                          [0  1  0  0  0  0  0  0  0  0];
            'Nature x Arousal',                          [0  0  1  0  0  0  0  0  0  0];
            'Nature x Difficulty',                       [0  0  0  1  0  0  0  0  0  0];
            'Nature x Information',                      [0  0  0  0  1  0  0  0  0  0];
            % ===== 第三组：strategy 里各维度效应 =====
            'Strategy x Valence',                        [0  0  0  0  0  0  1  0  0  0];
            'Strategy x Arousal',                        [0  0  0  0  0  0  0  1  0  0];
            'Strategy x Difficulty',                     [0  0  0  0  0  0  0  0  1  0];
            'Strategy x Information',                    [0  0  0  0  0  0  0  0  0  1];
            % ===== 第四组：各维度总效应 =====
            'Valence (Total)',                            [0  1  0  0  0  0  1  0  0  0];
            'Arousal (Total)',                            [0  0  1  0  0  0  0  1  0  0];
            'Difficulty (Total)',                         [0  0  0  1  0  0  0  0  1  0];
            'Information (Total)',                        [0  0  0  0  1  0  0  0  0  1];
            % ===== 第五组：跨条件对比 =====
            'Nature_Valence > Strategy_Valence',         [0  1  0  0  0  0 -1  0  0  0];
            'Strategy_Valence > Nature_Valence',         [0 -1  0  0  0  0  1  0  0  0];
            'Nature_Arousal > Strategy_Arousal',         [0  0  1  0  0  0  0 -1  0  0];
            'Strategy_Arousal > Nature_Arousal',         [0  0 -1  0  0  0  0  1  0  0];
            'Nature_Difficulty > Strategy_Difficulty',   [0  0  0  1  0  0  0  0 -1  0];
            'Strategy_Difficulty > Nature_Difficulty',   [0  0  0 -1  0  0  0  0  1  0];
            'Nature_Information > Strategy_Information', [0  0  0  0  1  0  0  0  0 -1];
            'Strategy_Information > Nature_Information', [0  0  0  0 -1  0  0  0  0  1];
            % ===== 第六组：同条件内维度对比 =====
            'Nature: Arousal > Valence',                 [0 -1  1  0  0  0  0  0  0  0];
            'Nature: Valence > Arousal',                 [0  1 -1  0  0  0  0  0  0  0];
            'Nature: Valence > Difficulty',              [0  1  0 -1  0  0  0  0  0  0];
            'Nature: Arousal > Information',             [0  0  1  0 -1  0  0  0  0  0];
            'Strategy: Arousal > Valence',               [0  0  0  0  0  0 -1  1  0  0];
            'Strategy: Valence > Arousal',               [0  0  0  0  0  0  1 -1  0  0];
            'Strategy: Valence > Difficulty',            [0  0  0  0  0  0  1  0 -1  0];
            'Strategy: Arousal > Information',           [0  0  0  0  0  0  0  1  0 -1];
        };

        for k = 1:size(cons, 1)
            matlabbatch{3}.spm.stats.con.consess{k}.tcon.name    = cons{k,1};
            matlabbatch{3}.spm.stats.con.consess{k}.tcon.weights = cons{k,2};
            matlabbatch{3}.spm.stats.con.consess{k}.tcon.sessrep = 'replsc';
        end
        matlabbatch{3}.spm.stats.con.delete = 1;


        %% ===== 保存并运行 =====
        batch_dir = fullfile(output_dir, 'batch');
        if ~exist(batch_dir, 'dir'), mkdir(batch_dir); end
        batch_filename = fullfile(batch_dir, sprintf('1st_batch_sub-%s.mat', subject_number));
        save(batch_filename, 'matlabbatch');
        fprintf('  [已保存] batch 至 %s\n', batch_filename);

        fprintf('>> 正在运行 SPM Job: sub-%s\n', subject_number);
        spm_jobman('run', matlabbatch);
        fprintf('>> 完成被试 %s！\n\n', subject_number);

    catch ME
        fprintf(2, '!!!! 处理被试 %s 时出错: %s\n', subject_number, ME.message);
        fprintf(2, '     错误位置: %s (行 %d)\n', ME.stack(1).name, ME.stack(1).line);
        continue;
    end
end
fprintf('====== 所有被试处理完毕！======\n');
