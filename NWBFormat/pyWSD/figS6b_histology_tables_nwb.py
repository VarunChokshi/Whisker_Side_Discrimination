#!/usr/bin/env python3
"""
figS6b_histology_tables_nwb.py

Builds and validates the staged data tables for Figure S6B (wM1 probe entry stereotaxic points).
Extracts or validates probe shank entry points for WT and KO mice relative to Bregma,
along with the stepped dorsal skull grid coordinates.

Outputs:
  - NWBData/Data/Tables/Histology/figS6b_histology_M1.mat
  - NWBData/Data/Tables/Histology/figS6b_histology_M1.json
"""

import argparse
import json
from pathlib import Path
import sys
import numpy as np
import scipy.io as sio

DEFAULT_TABLES_DIR = (
    Path(__file__).resolve().parent.parent / "Data" / "Tables" / "Histology"
)


def build_or_validate_m1_tables(tables_dir: Path):
    tables_dir.mkdir(parents=True, exist_ok=True)
    target_mat = tables_dir / "figS6b_histology_M1.mat"
    target_json = tables_dir / "figS6b_histology_M1.json"

    if not target_mat.exists() and not target_json.exists():
        raise FileNotFoundError(
            f"Neither {target_mat} nor {target_json} found. Run MATLAB builder first."
        )

    if target_mat.exists():
        data = sio.loadmat(str(target_mat))
        wt_ap = data["wt_ap"]
        wt_ml = data["wt_ml"]
        ko_ap = data["ko_ap"]
        ko_ml = data["ko_ml"]
        grid_lines = data["grid_lines"]

        m1_dict = {
            "wt_ap": wt_ap.flatten().tolist(),
            "wt_ml": wt_ml.flatten().tolist(),
            "ko_ap": ko_ap.flatten().tolist(),
            "ko_ml": ko_ml.flatten().tolist(),
            "grid_lines": grid_lines.tolist(),
        }
        with open(target_json, "w", encoding="utf-8") as f:
            json.dump(m1_dict, f)
    else:
        with open(target_json, "r", encoding="utf-8") as f:
            m1_dict = json.load(f)
        wt_ap = np.array(m1_dict["wt_ap"]).reshape(-1, 1)
        wt_ml = np.array(m1_dict["wt_ml"]).reshape(-1, 1)
        ko_ap = np.array(m1_dict["ko_ap"]).reshape(-1, 1)
        ko_ml = np.array(m1_dict["ko_ml"]).reshape(-1, 1)
        grid_lines = np.array(m1_dict["grid_lines"])

        sio.savemat(
            str(target_mat),
            {
                "wt_ap": wt_ap,
                "wt_ml": wt_ml,
                "ko_ap": ko_ap,
                "ko_ml": ko_ml,
                "grid_lines": grid_lines,
            },
        )

    print(f"Validated Figure S6B tables in: {tables_dir}")
    print(f"  WT probe shank points: {len(wt_ap)}")
    print(f"  KO probe shank points: {len(ko_ap)}")
    print(f"  Grid lines: {len(grid_lines)}")
    return target_mat, target_json


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Build or validate Figure S6B histology tables."
    )
    parser.add_argument(
        "--tables-dir",
        type=Path,
        default=DEFAULT_TABLES_DIR,
        help="Target directory for histology tables.",
    )
    args = parser.parse_args(argv)
    build_or_validate_m1_tables(args.tables_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())

