"""
Fig3 (wS1) / Fig6 (wM1) ephys panels for the MSE-format Python pipeline.

Reuses the validated pyWSD ephys plotters (fig3_panels_nwb) fed the MSE-flattened
per-unit table produced by matlab_export/export_fig3.m. That flatten writes
fig3_tables_<region>.mat in the exact "fig3Table" schema pyWSD reads, so the same
plotters render the MSE-computed numbers.

Panels: FR heatmap (Fig3C / Fig6A), mean spike rate contra vs ipsi (Fig3D / Fig6B),
laterality-index distribution (Fig3E), percent contra-preferring (Fig3F).

    make_ephys_figs(tables_mat, out_dir, region='S1')   # region 'S1'->Fig3, 'M1'->Fig6
"""
from __future__ import annotations
from pathlib import Path
import argparse
import numpy as np
import scipy.io as sio
import matplotlib
matplotlib.use("Agg")
import logging
logging.getLogger("matplotlib.font_manager").setLevel(logging.ERROR)

import fig3_panels_nwb as fp   # the validated pyWSD plotters (copied into this folder)


def _ensure_region(tables_mat):
    """pyWSD's loadFlatTable needs a 'region' column; older exports only have 'recSite'.
    Add it in place if missing (writes back a patched copy next to the original)."""
    m = sio.loadmat(str(tables_mat), simplify_cells=True)
    T = m["fig3Table"]
    if "region" not in T:
        T["region"] = np.array(T.get("recSite", []), dtype=object)
        patched = Path(tables_mat).with_name(Path(tables_mat).stem + "_r.mat")
        sio.savemat(str(patched), {"fig3Table": T}, do_compression=True)
        return str(patched)
    return str(tables_mat)


# Per-region plot window + mean-FR y-limit, mirroring the MATLAB driver's ops:
#   S1 (Fig3):  ops.plotxLims = [-0.05, 0.05]
#   M1 (Fig6):  ops.plotxLims = [-0.05, 0.10],  maxFR = 17
_REGION_OPS = {
    "S1":    dict(xlims=(-0.05, 0.05), max_fr=30.0),
    "M1":    dict(xlims=(-0.05, 0.10), max_fr=17.0),
    "Motor": dict(xlims=(-0.05, 0.10), max_fr=17.0),
}


def make_ephys_figs(tables_mat, out_dir, region="S1"):
    out_dir = Path(out_dir); out_dir.mkdir(parents=True, exist_ok=True)
    ops = _REGION_OPS.get(region, _REGION_OPS["S1"])
    fp.PLOT_XLIMS = ops["xlims"]   # read as a module global by the plotters at call time
    fp.MAX_FR = ops["max_fr"]
    path = _ensure_region(tables_mat)
    records = fp.loadFlatTable(path)
    unitTable = fp.buildUnitTable(records)
    nResp = sum(1 for r in unitTable if r.get("responsive"))
    print(f"{region}: {len(unitTable)} units ({nResp} responsive)")
    fp.plotAvgTracesFRFinal(unitTable, str(out_dir))     # Fig3D / Fig6B
    fp.makeCbiasFiguresFinal(unitTable, str(out_dir))    # Fig3E / Fig3F
    fp.frHeatmapsAllFreq(unitTable, str(out_dir))        # Fig3C / Fig6A
    print(f"ephys panels ({region}) -> {out_dir}")


def main(argv=None):
    ap = argparse.ArgumentParser(description="Fig3/Fig6 ephys panels from the MSE fig3_tables export.")
    ap.add_argument("--tables", required=True, help="fig3_tables_<region>.mat from export_fig3.m")
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--region", default="S1")
    a = ap.parse_args(argv)
    make_ephys_figs(a.tables, a.out_dir, region=a.region)


if __name__ == "__main__":
    raise SystemExit(main())
