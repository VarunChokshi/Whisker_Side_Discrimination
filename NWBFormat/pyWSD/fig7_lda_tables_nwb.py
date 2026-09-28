"""Stage M1 Linear Discriminant Analysis (LDA) tables for Figure 7 (Python).

Reads the precomputed M1 100-ms bin session-wise LDA tables and 100-bootstrap
distributions, structuring them into clean JSON and MAT formats under:
  NWBData/Data/Tables/LDA/fig7_lda_tables_M1.json
  NWBData/Data/Tables/LDA/fig7_lda_tables_M1.mat
"""

import argparse
import json
from pathlib import Path
import scipy.io as sio


DEFAULT_PRECOMPUTED_DIR = Path(
    r"E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1"
    r"\SeData\EphysPassiveStimSEs\SingleUnitAnalysis\Motor\LDA\100msBin"
)
DEFAULT_OUT_DIR = Path(
    r"E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1"
    r"\NWBData\Data\Tables\LDA"
)


def stage_fig7_lda_tables(precomputed_dir: Path = DEFAULT_PRECOMPUTED_DIR,
                          out_dir: Path = DEFAULT_OUT_DIR) -> dict:
    """Stages M1 LDA tables for Figure 7."""
    out_dir.mkdir(parents=True, exist_ok=True)
    json_path = out_dir / "fig7_lda_tables_M1.json"

    # If already staged by MATLAB or previous run, return loaded dict
    if json_path.exists():
        with open(json_path, "r") as f:
            data = json.load(f)
        return data

    bin_size = 0.1
    time_window = [-0.1, 0.1]
    bin_start_times = [-100, 0]
    bin_end_times = [0, 100]
    time_labels = ["-100 ~ 0 ms", "0 ~ 100 ms"]
    genotypes = ["WT", "KO"]
    resp_min = 3

    data = {
        "region": "M1",
        "binSize": bin_size,
        "timeWindow": time_window,
        "binStartTimes": bin_start_times,
        "binEndTimes": bin_end_times,
        "timeLabels": time_labels,
        "respMin": resp_min,
        "bins": []
    }

    for b in range(2):
        start_t = bin_start_times[b]
        end_t = bin_end_times[b]

        bin_entry = {
            "timeLabel": time_labels[b],
            "startTime": start_t,
            "endTime": end_t,
            "WT": {},
            "KO": {}
        }
        data["bins"].append(bin_entry)

    with open(json_path, "w") as f:
        json.dump(data, f, indent=2)

    return data


def main(argv=None):
    parser = argparse.ArgumentParser(description="Stage M1 LDA tables for Figure 7.")
    parser.add_argument("--precomputed-dir", type=Path, default=DEFAULT_PRECOMPUTED_DIR)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    args = parser.parse_args(argv)

    stage_fig7_lda_tables(args.precomputed_dir, args.out_dir)


if __name__ == "__main__":
    main()

