%% DUMP_FIG3_SCHEMA  Print/save the structure of the Fig3/Fig6 ephys tables.
%
% Run this ONCE in MATLAB (it loads big tables, so run it locally — not over the
% remote tool). It writes a small text file describing metadataTable / FRdataTable /
% meanFRTable so the flatten export (export_fig3.m / export_fig6.m) can be written
% to match. Point `p` at the wS1 folder for Fig3, or the wM1 folder for Fig6.

p = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\SeData\EphysPassiveStimSEs\Figures\Bodyside8\allWins\AllUnitswS12_5';   % Fig3 (wS1); wM1 = ...\AllUnitswM12_5
outFile = fullfile(p, 'fig3_schema_dump.txt');
fid = fopen(outFile, 'w');
log = @(varargin) fprintf(fid, varargin{:});

describe = @(T, name) 0;  % (defined below as a loop; placeholder for readability)

%% metadataTable
S = load(fullfile(p, 'allVars.mat'), 'metadataTable');
MT = S.metadataTable;
log('=== metadataTable: %d rows x %d cols ===\n', height(MT), width(MT));
for c = 1:width(MT)
    v = MT{1, c};
    log('  %-16s | %-10s | size [%s]\n', MT.Properties.VariableNames{c}, class(v), num2str(size(v)));
end
% show a couple of scalar-ish values
log('  sample genotype(1)=%s  cbias(1)=%s  UnitDepth(1)=%s\n', ...
    string(MT.genotype(1)), num2str(MT.cbias(1)), num2str(MT.UnitDepth(1)));
disp('metadataTable done');

%% FRdataTable  (holds the per-unit FR traces, nested per animal)
S = load(fullfile(p, 'FRdataVars.mat'), 'FRdataTable');
FT = S.FRdataTable;
log('\n=== FRdataTable: %d rows x %d cols ===\n', height(FT), width(FT));
for c = 1:width(FT)
    v = FT{1, c};
    log('  %-16s | %-10s | size [%s]\n', FT.Properties.VariableNames{c}, class(v), num2str(size(v)));
end
% unpack the meanFR nesting for the first animal / first unit
a = FT.meanFR{1};
log('\n  FRdataTable.meanFR{1}: %s size [%s]\n', class(a), num2str(size(a)));
if iscell(a)
    u = a{1};
    log('  meanFR{1}{1}: %s size [%s]\n', class(u), num2str(size(u)));
    if iscell(u)
        for k = 1:numel(u)
            log('    meanFR{1}{1}{%d}: %s size [%s]\n', k, class(u{k}), num2str(size(u{k})));
        end
    end
end
disp('FRdataTable done');

%% meanFRTable  (window mean FR)
S = load(fullfile(p, 'meanFRTable.mat'), 'meanFRTable');
MF = S.meanFRTable;
log('\n=== meanFRTable: %d rows x %d cols ===\n', height(MF), width(MF));
for c = 1:width(MF)
    v = MF{1, c};
    log('  %-16s | %-10s | size [%s]\n', MF.Properties.VariableNames{c}, class(v), num2str(size(v)));
end
b = MF.meanFR{1};
log('\n  meanFRTable.meanFR{1}: %s size [%s]\n', class(b), num2str(size(b)));
if iscell(b) && ~isempty(b)
    log('  meanFRTable.meanFR{1}{1}: %s size [%s]\n', class(b{1}), num2str(size(b{1})));
end
disp('meanFRTable done');

fclose(fid);
fprintf('\nWrote schema to: %s\n', outFile);
type(outFile);   % also echo to the command window
