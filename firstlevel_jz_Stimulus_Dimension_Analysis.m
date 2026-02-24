clear; clc;
spm('defaults', 'FMRI');
spm_jobman('initcfg');

%% ===== 用户配置区域 =====
subjects_to_run  = {'1'};
onset_base_dir   = '/Users/alexjiangzhe/Documents/My_project/internship_He_researsh_group/Stimulus_Dimension_Analysis/first_level/onset';
preproc_base_dir = '/Users/alexjiangzhe/Documents/My_project/internship_He_researsh_group/preprocess_data/preprocess';
output_base_dir  = '/Users/alexjiangzhe/Documents/My_project/internship_He_researsh_group/Stimulus_Dimension_Analysis/first_level/1/code';

% ⚠️ 改成你 Excel 文件的实际名称（每个被试文件夹里的那个 xlsx）
onset_filename = 'onset1.xlsx';

% ⚠️ 每个试次的持续时间（秒）
event_duration = 6;

% Excel 列索引（根据你的截图，A/B/C/D 列）
COL_STRATEGY_ONSET   = 1;  % A列: onset(策略)，单位：秒
COL_STRATEGY_VALENCE = 2;  % B列: 评分（策略）
COL_NATURE_ONSET     = 3;  % C列: onset(自然)，单位：秒
COL_NATURE_VALENCE   = 4;  % D列: 评分（自然）

%% ===== 主循环 =====
for i = 1:length(subjects_to_run)
    subject_number = subjects_to_run{i};
    fprintf('====== 开始处理被试: %s ======\n', subject_number);

    try
        output_dir = fullfile(output_base_dir, subject_number);

        % ===== 清空输出目录（保证结果干净）=====
        if exist(output_dir, 'dir')
            delete(fullfile(output_dir, '*.nii'));
            delete(fullfile(output_dir, '*.mat'));
            delete(fullfile(output_dir, '*.hdr'));
            delete(fullfile(output_dir, '*.img'));
            fprintf('  [已清空] 输出目录: %s\n', output_dir);
        else
            mkdir(output_dir);
        end

        %% ===== 读取 Onset 和效价数据 =====
        onset_file = fullfile(onset_base_dir, subject_number, onset_filename);
        if ~exist(onset_file, 'file')
            error('未找到 onset 文件: %s', onset_file);
        end

        % ReadVariableNames=false 避免中文表头报错，数据从第2行起
        T = readtable(onset_file, 'ReadVariableNames', false);
        raw = T{2:end, :};  % 跳过第一行表头

        % 策略
        strategy_onset   = raw(:, COL_STRATEGY_ONSET);
        strategy_valence = raw(:, COL_STRATEGY_VALENCE);
        strategy_onset   = strategy_onset(~isnan(strategy_onset))';
        strategy_valence = strategy_valence(~isnan(strategy_valence))';

        % 自然
        nature_onset   = raw(:, COL_NATURE_ONSET);
        nature_valence = raw(:, COL_NATURE_VALENCE);
        nature_onset   = nature_onset(~isnan(nature_onset))';
        nature_valence = nature_valence(~isnan(nature_valence))';

        % 验证数量匹配
        assert(numel(strategy_onset) == numel(strategy_valence), ...
               '策略条件：onset(%d)与效价(%d)数量不匹配！', ...
               numel(strategy_onset), numel(strategy_valence));
        assert(numel(nature_onset) == numel(nature_valence), ...
               '自然条件：onset(%d)与效价(%d)数量不匹配！', ...
               numel(nature_onset), numel(nature_valence));

        fprintf('  [✓] 策略: %d 个 trial，效价均值 = %.2f\n', numel(strategy_onset), mean(strategy_valence));
        fprintf('  [✓] 自然: %d 个 trial，效价均值 = %.2f\n', numel(nature_onset),   mean(nature_valence));

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
        if ~exist(swuaf_dir, 'dir'), error('未找到 swuaf 目录: %s', swuaf_dir); end

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

        % ===== 条件1：策略（含效价 PM）=====
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(1).name        = 'Strategy';
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(1).onset       = strategy_onset;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(1).duration    = event_duration;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(1).tmod        = 0;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(1).pmod(1).name  = 'Valence';
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(1).pmod(1).param = strategy_valence;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(1).pmod(1).poly  = 1;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(1).orth        = 0;

        % ===== 条件2：自然（含效价 PM）=====
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(2).name        = 'Nature';
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(2).onset       = nature_onset;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(2).duration    = event_duration;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(2).tmod        = 0;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(2).pmod(1).name  = 'Valence';
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(2).pmod(1).param = nature_valence;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(2).pmod(1).poly  = 1;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).cond(2).orth        = 0;

        % ===== 其他 Session 设置 =====
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).multi     = {''};
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).hpf       = 128;

        % 运动参数
        rp_mat = dir(fullfile(subj_pre_dir, 'art_*.mat'));
        if isempty(rp_mat), rp_mat = dir(fullfile(swuaf_dir, 'art_*.mat')); end
        rp_txt = dir(fullfile(subj_pre_dir, 'rp_*.txt'));
        if isempty(rp_txt), rp_txt = dir(fullfile(swuaf_dir, 'rp_*.txt')); end

        if     ~isempty(rp_mat), motion_file = fullfile(rp_mat(1).folder, rp_mat(1).name);
        elseif ~isempty(rp_txt), motion_file = fullfile(rp_txt(1).folder, rp_txt(1).name);
        else,  error('未找到运动文件 (art_* 或 rp_*): %s', subj_pre_dir);
        end
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).multi_reg = {motion_file};

        % 模型全局设置
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
        % 设计矩阵列顺序（SPM 自动生成）：
        %   列1: Strategy_Main
        %   列2: Strategy x Valence（效价 PM）
        %   列3: Nature_Main
        %   列4: Nature x Valence（效价 PM）
        %   列5-10: 6个运动参数
        %   列11: 常数项
        matlabbatch{3}.spm.stats.con.spmmat(1) = cfg_dep( ...
            'Model estimation: SPM.mat File', ...
            substruct('.','val','{}',{2},'.','val','{}',{1},'.','val','{}',{1}), ...
            substruct('.','spmmat'));

        cons = {
            % ===== 主效应（验证时间轴是否正确）=====
            'Strategy_Main',               [1  0  0  0];
            'Nature_Main',                 [0  0  1  0];
            'Strategy > Nature (Main)',    [1  0 -1  0];
            'Nature > Strategy (Main)',    [-1  0  1  0];
            % ===== 效价参数调制（核心科学问题）=====
            'Strategy_Valence',            [0  1  0  0];
            'Nature_Valence',              [0  0  0  1];
            'Strategy > Nature (Valence)', [0  1  0 -1];
            'Nature > Strategy (Valence)', [0 -1  0  1];
        };

        for k = 1:size(cons, 1)
            matlabbatch{3}.spm.stats.con.consess{k}.tcon.name    = cons{k,1};
            matlabbatch{3}.spm.stats.con.consess{k}.tcon.weights = cons{k,2};
            matlabbatch{3}.spm.stats.con.consess{k}.tcon.sessrep = 'replsc';
        end
        matlabbatch{3}.spm.stats.con.delete = 1;  % 清空旧 contrast

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
