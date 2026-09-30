function export_lda(mainDir, recSite, binMs, wins, outRoot)
%EXPORT_LDA  Flatten the LDA result tables into python-safe -v7 structs.
%
%   export_lda(mainDir, recSite, binMs, wins, outRoot)
%
% The MSessionExplorer-format Python figure pipeline cannot read MATLAB
% `table` objects (they load as MatlabOpaque in scipy). This flattens the
% per-time-window LDA tables into plain structs (numeric arrays + cellstr,
% never `table`/`string`) saved -v7, which scipy.io.loadmat reads directly.
%
%   mainDir : ...\SingleUnitAnalysis         (holds <recSite>\LDA\<bin>msBin\)
%   recSite : 'S1' (Fig5) or 'Motor' (Fig7)
%   binMs   : LDA bin in ms (S1: 50, Motor: 100)
%   wins    : cellstr of window tokens, e.g. {'-50to0','0to50'}
%   outRoot : export root; files go to <outRoot>\<recSite>\LDA\<bin>msBin\
%
% Produces, per window w:
%   LDA_point_<w>.mat  : mouseName, genotype, sessionName (cellstr);
%                        N_respUnit, LDA_true, LDA_shuffle (double vectors)
%   LDA_boot_<w>.mat   : genotype (cellstr 2x1); true, shuffle (2 x nBoot double)

    srcDir = fullfile(mainDir, recSite, 'LDA', sprintf('%dmsBin', binMs));
    outDir = fullfile(outRoot, recSite, 'LDA', sprintf('%dmsBin', binMs));
    if ~exist(outDir, 'dir'); mkdir(outDir); end

    for i = 1:numel(wins)
        w = wins{i};

        % --- point-estimate table (one row per session) ---
        L = load(fullfile(srcDir, sprintf('LDA_20Hz_%dmsBin_%s.mat', binMs, w)));
        T = L.LDA_table;
        s = struct( ...
            'mouseName',   {cellstr(T.mouseName)}, ...
            'genotype',    {cellstr(T.genotype)}, ...
            'sessionName', {cellstr(T.sessionName)}, ...
            'N_respUnit',  double(T.N_respUnit), ...
            'LDA_true',    double(T.LDA_true), ...
            'LDA_shuffle', double(T.LDA_shuffle));
        save(fullfile(outDir, sprintf('LDA_point_%s.mat', w)), '-struct', 's', '-v7');

        % --- bootstrap table (one row per genotype; each cell 1 x nBoot) ---
        B = load(fullfile(srcDir, sprintf('LDA_100nBoot_20Hz_%dmsBin_%s.mat', binMs, w)));
        C = B.ca_table;
        b = struct( ...
            'genotype', {cellstr(C.genotype)}, ...
            'true',     double(C{:,2}), ...
            'shuffle',  double(C{:,3}));
        save(fullfile(outDir, sprintf('LDA_boot_%s.mat', w)), '-struct', 'b', '-v7');
    end
    fprintf('export_lda: wrote %d windows to %s\n', numel(wins), outDir);
end
