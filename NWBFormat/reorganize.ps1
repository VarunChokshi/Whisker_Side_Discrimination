<#
    reorganize.ps1  —  restructure NWBFormat into matWSD / pyWSD / conversion.

    Place this script in the NWBFormat folder and run it once from PowerShell:

        cd "C:\Users\VarunChokshi\Documents\GitHub\Whisker_Side_Discrimination\NWBFormat"
        powershell -ExecutionPolicy Bypass -File .\reorganize.ps1

    It MOVES the existing FinalCodes\ and Figures\ contents into the new layout,
    drops the fixed run scripts + generated READMEs (staged in _reorg\) into place,
    and COPIES the conversion scripts from the NWBData\Conversion folder.
    Nothing outside NWBFormat is modified except reading the conversion sources.

    Re-runnable-safe: if FinalCodes\ is already gone it reports and exits.
#>

$ErrorActionPreference = 'Stop'
$NWB = $PSScriptRoot
Write-Host "NWBFormat root: $NWB"

$fin    = Join-Path $NWB 'FinalCodes'
$figs   = Join-Path $NWB 'Figures'
$reorg  = Join-Path $NWB '_reorg'
$mat    = Join-Path $NWB 'matWSD'
$py     = Join-Path $NWB 'pyWSD'
$conv   = Join-Path $NWB 'conversion'
$convSrc = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\NWBData\Conversion'

if (-not (Test-Path $fin)) {
    Write-Host "FinalCodes\ not found - looks like this was already reorganized. Nothing to do."
    return
}
if (-not (Test-Path $reorg)) {
    throw "_reorg\ staging folder not found at $reorg. Commit the staged files first."
}

# 1. Create the target structure
foreach ($d in @($mat, (Join-Path $mat 'figures'), $py, (Join-Path $py 'figures'), $conv)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d | Out-Null }
}

# 2. Move code out of FinalCodes.  MATLAB .m -> matWSD (keep the OLD run_all_figures.m
#    behind; the fixed copy comes from _reorg).  Python .py -> pyWSD.
Get-ChildItem $fin -Filter *.m  -File | Where-Object { $_.Name -ne 'run_all_figures.m' } |
    Move-Item -Destination $mat
Get-ChildItem $fin -Filter *.py -File | Move-Item -Destination $py

# 3. Preserve the one supplementary doc worth keeping (compression notes -> pyWSD)
$nwbcomp = Join-Path $fin 'README_nwb_compression.md'
if (Test-Path $nwbcomp) { Move-Item $nwbcomp (Join-Path $py 'README_nwb_compression.md') }

# 4. Drop the fixed run scripts + generated READMEs into place (from _reorg)
Move-Item (Join-Path $reorg 'run_all_figures.m')     (Join-Path $mat  'run_all_figures.m')     -Force
Move-Item (Join-Path $reorg 'run_all_figures.ipynb') (Join-Path $py   'run_all_figures.ipynb') -Force
Move-Item (Join-Path $reorg 'matWSD_README.md')      (Join-Path $mat  'README.md')             -Force
Move-Item (Join-Path $reorg 'pyWSD_README.md')       (Join-Path $py   'README.md')             -Force
Move-Item (Join-Path $reorg 'conversion_README.md')  (Join-Path $conv 'README.md')             -Force
Move-Item (Join-Path $reorg 'NWBFormat_README.md')   (Join-Path $NWB  'README.md')             -Force

# 5. Move the figures (exclude the big vector/editable formats), then remove leftovers.
#    robocopy /MOVE copies then deletes copied sources; /XF keeps the excluded files
#    behind, which are cleaned up when we remove the old Figures\ folder below.
if (Test-Path (Join-Path $figs 'Matlab')) {
    robocopy "$figs\Matlab" "$mat\figures" /E /MOVE /XF *.svg *.fig /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy (Matlab figures) failed with code $LASTEXITCODE" }
}
if (Test-Path (Join-Path $figs 'Python')) {
    robocopy "$figs\Python" "$py\figures" /E /MOVE /XF *.svg /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy (Python figures) failed with code $LASTEXITCODE" }
}
# Preserve the shared figures note in both pipelines
$figNote = Join-Path $figs 'README_Figures.txt'
if (Test-Path $figNote) {
    Copy-Item $figNote (Join-Path $mat 'figures\README_Figures.txt') -Force
    Copy-Item $figNote (Join-Path $py  'figures\README_Figures.txt') -Force
}

# 6. Copy the conversion scripts from NWBData\Conversion (provenance)
if (Test-Path $convSrc) {
    foreach ($f in @('dump_behavior_folder.m','dump_ephys_folder.m',
                     'dump_ephys_se_to_struct.m','dump_se_to_struct.m','getPerfOverall.m',
                     'convert_bodyside_behavior.py','convert_ephys_to_nwb.py',
                     'README_behavior_conversion.md')) {
        $src = Join-Path $convSrc $f
        if (Test-Path $src) { Copy-Item $src (Join-Path $conv $f) -Force }
        else { Write-Warning "conversion source missing: $f" }
    }
} else {
    Write-Warning "Conversion source folder not found: $convSrc  (skipping conversion copy)"
}

# 7. Clean up: old FinalCodes\ (incl __pycache__ + leftover run scripts/READMEs),
#    old Figures\ (incl leftover svg/fig), and the _reorg\ staging folder.
Remove-Item $fin   -Recurse -Force
Remove-Item $figs  -Recurse -Force
Remove-Item $reorg -Recurse -Force

# 8. Summary
Write-Host ""
Write-Host "==== Reorganization complete ===="
foreach ($d in @($mat, $py, $conv)) {
    $n = (Get-ChildItem $d -Recurse -File | Measure-Object).Count
    Write-Host ("  {0,-40} {1} files" -f ($d.Substring($NWB.Length+1)), $n)
}
Write-Host ""
Write-Host "Next: review, then from the repo root run:"
Write-Host "  git add -A"
Write-Host "  git commit -m `"Reorganize NWBFormat into matWSD / pyWSD / conversion`""
Write-Host "  git push"
