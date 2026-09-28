NWB-pipeline figure outputs go here (NWBData\Figures\Fig3, \FigS3, \FigS4, ...).

Run the ported Fig3 panels into this folder, e.g.:

  Python:
    python "..\FinalCodes\fig3_panels_nwb.py" ^
      --s1-dir "..\Data\ephys\S1" ^
      --out-dir "..\Figures\Fig3"

  MATLAB (matnwb on path):
    fig3_panels_nwb('..\Data\ephys\S1', '..\Figures\Fig3')

The scripts refuse to write anywhere outside an NWBData folder (pass --force /
a 'force' argument only if you really mean to). This keeps NWB-pipeline outputs
out of the hand-made manuscript figure folders (manuscripts\bodyside_S1\Fig3).
