#!/usr/bin/env python3
"""
figS4a_histology_tables_nwb.py

Builds and validates the staged data tables for Figure S4A (wS1 CCF histology).
Extracts or validates wireframe coordinates and unit coordinates (Contra, Ipsi, Bilateral)
for WT and KO mice.

Outputs:
  - NWBData/Data/Tables/Histology/figS4a_histology_S1.mat
  - NWBData/Data/Tables/Histology/figS4a_histology_S1.json
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


def build_or_validate_s1_tables(tables_dir: Path):
    tables_dir.mkdir(parents=True, exist_ok=True)
    target_mat = tables_dir / "figS4a_histology_S1.mat"
    target_json = tables_dir / "figS4a_histology_S1.json"

    if not target_mat.exists() and not target_json.exists():
        raise FileNotFoundError(
            f"Neither {target_mat} nor {target_json} found. Run MATLAB builder first."
        )

    if target_mat.exists():
        data = sio.loadmat(str(target_mat))
        wt_contra = data["wtContra"]
        wt_ipsi = data["wtIpsi"]
        wt_both = data["wtBoth"]
        ko_contra = data["koContra"]
        ko_ipsi = data["koIpsi"]
        ko_both = data["koBoth"]
        wireframe = data["wireframe"]
        bregma = data["bregma"]

        # Ensure JSON is in sync
        s1_dict = {
            "bregma": bregma.tolist(),
            "wt_contra": wt_contra.tolist(),
            "wt_ipsi": wt_ipsi.tolist(),
            "wt_both": wt_both.tolist(),
            "ko_contra": ko_contra.tolist(),
            "ko_ipsi": ko_ipsi.tolist(),
            "ko_both": ko_both.tolist(),
            "wireframe": wireframe.tolist(),
        }
        with open(target_json, "w", encoding="utf-8") as f:
            json.dump(s1_dict, f)
    else:
        with open(target_json, "r", encoding="utf-8") as f:
            s1_dict = json.load(f)
        wt_contra = np.array(s1_dict["wt_contra"])
        wt_ipsi = np.array(s1_dict["wt_ipsi"])
        wt_both = np.array(s1_dict["wt_both"])
        ko_contra = np.array(s1_dict["ko_contra"])
        ko_ipsi = np.array(s1_dict["ko_ipsi"])
        ko_both = np.array(s1_dict["ko_both"])
        wireframe = np.array(s1_dict["wireframe"])
        bregma = np.array(s1_dict["bregma"])

        sio.savemat(
            str(target_mat),
            {
                "wtContra": wt_contra,
                "wtIpsi": wt_ipsi,
                "wtBoth": wt_both,
                "koContra": ko_contra,
                "koIpsi": ko_ipsi,
                "koBoth": ko_both,
                "wireframe": wireframe,
                "bregma": bregma,
            },
        )

    print(f"Validated Figure S4A tables in: {tables_dir}")
    print(f"  WT units: Contra={len(wt_contra)}, Ipsi={len(wt_ipsi)}, Both={len(wt_both)} (Total={len(wt_contra) + len(wt_ipsi) + len(wt_both)})")
    print(f"  KO units: Contra={len(ko_contra)}, Ipsi={len(ko_ipsi)}, Both={len(ko_both)} (Total={len(ko_contra) + len(ko_ipsi) + len(ko_both)})")
    print(f"  Wireframe points: {len(wireframe)}")
    return target_mat, target_json


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Build or validate Figure S4A histology tables."
    )
    parser.add_argument(
        "--tables-dir",
        type=Path,
        default=DEFAULT_TABLES_DIR,
        help="Target directory for histology tables.",
    )
    args = parser.parse_args(argv)
    build_or_validate_s1_tables(args.tables_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())

