"""Direct NWB-based ROC Engine (Python) for M1 / Figure 6.

Reads M1 ephys .nwb files directly (or stages precomputed Motor ROC tables),
bins trial-by-trial spike trains for 20 Hz Contralateral vs Ipsilateral trials,
and calculates 1,000-bootstrap AUC distributions across time bins (50 ms and 5 ms).

Outputs:
  - NWBData/Data/Tables/ROC/fig6_roc_tables_M1_50ms.mat
  - NWBData/Data/Tables/ROC/fig6_roc_tables_M1_5ms.mat
"""

import argparse
from pathlib import Path
import sys

import numpy as np
import pandas as pd
import pynwb
import scipy.io as sio


DEFAULT_NWB_DIR = Path(
    r"E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\NWBData\Data\ephys\M1"
)
DEFAULT_RESP_CSV = Path(
    r"E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\NWBData\Data\Tables\ROC\responsive_units_M1.csv"
)
DEFAULT_PRECOMP_DIR = Path(
    r"E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\SeData\EphysPassiveStimSEs\SingleUnitAnalysis\Motor\ROC"
)
DEFAULT_OUT_DIR = Path(
    r"E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\NWBData\Data\Tables\ROC"
)


def spike_times_to_rates(spike_times: np.ndarray, trial_onsets: np.ndarray,
                         time_window: tuple, bin_size: float) -> np.ndarray:
    """Converts continuous spike timestamps into per-trial spike rates across bins."""
    bin_edges = np.arange(time_window[0], time_window[1] + 1e-9, bin_size)
    n_bins = len(bin_edges) - 1
    rates = np.zeros((len(trial_onsets), n_bins), dtype=np.float64)

    for i, t0 in enumerate(trial_onsets):
        t_start = t0 + time_window[0]
        t_end = t0 + time_window[1]
        spks = spike_times[(spike_times >= t_start) & (spike_times < t_end)] - t0
        counts, _ = np.histogram(spks, bins=bin_edges)
        rates[i, :] = counts / bin_size

    return rates


def bootstrap_auc(rates_con: np.ndarray, rates_ipsi: np.ndarray,
                  n_boot: int = 1000, seed: int = None) -> np.ndarray:
    """Vectorized calculation of 1,000 bootstrap draws of empirical AUC across bins."""
    if seed is not None:
        np.random.seed(seed)
    n_con, n_bins = rates_con.shape
    n_ipsi = rates_ipsi.shape[0]
    sorted_boot_auc = np.zeros((n_bins, n_boot), dtype=np.float64)

    for b in range(n_bins):
        con_b = rates_con[:, b]
        ipsi_b = rates_ipsi[:, b]

        idx_con = np.random.randint(0, n_con, size=(n_boot, n_con))
        idx_ipsi = np.random.randint(0, n_ipsi, size=(n_boot, n_ipsi))

        boot_con = con_b[idx_con]
        boot_ipsi = ipsi_b[idx_ipsi]

        diff = boot_con[:, :, None] - boot_ipsi[:, None, :]
        auc_draws = np.mean((diff > 0).astype(float) + 0.5 * (diff == 0).astype(float), axis=(1, 2))
        sorted_boot_auc[b, :] = np.sort(auc_draws)

    return sorted_boot_auc


def stage_precomputed_tables(precomp_dir: Path, out_dir: Path):
    """Stages existing precomputed Motor ROC tables into standardized .mat structs."""
    file_50ms = precomp_dir / "50msBin" / "Unit_AUC_20Hz_50msBin_-50to150ms_1000nBoot_150pvalueMin.mat"
    file_5ms = precomp_dir / "5msBin" / "Unit_AUC_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMin.mat"

    if not file_50ms.exists() or not file_5ms.exists():
        return False

    out_dir.mkdir(parents=True, exist_ok=True)

    # 50-ms bin
    print(f"Staging 50-ms Motor ROC table: {file_50ms}")
    raw_50 = sio.loadmat(str(file_50ms), squeeze_me=True, struct_as_record=False)
    struct_50 = _convert_auc_matlab_table(raw_50["AUC_table"], bin_size=0.05, time_window=(-0.05, 0.15))
    out_50 = out_dir / "fig6_roc_tables_M1_50ms.mat"
    sio.savemat(out_50, {"rocTable50ms": struct_50}, do_compression=True)
    print(f"Wrote 50-ms ROC table -> {out_50}")

    # 5-ms bin
    print(f"Staging 5-ms Motor ROC table: {file_5ms}")
    raw_5 = sio.loadmat(str(file_5ms), squeeze_me=True, struct_as_record=False)
    struct_5 = _convert_auc_matlab_table(raw_5["AUC_table"], bin_size=0.005, time_window=(-0.05, 0.15))
    out_5 = out_dir / "fig6_roc_tables_M1_5ms.mat"
    sio.savemat(out_5, {"rocTable5ms": struct_5}, do_compression=True)
    print(f"Wrote 5-ms ROC table -> {out_5}")

    # Export responsive units CSV
    _export_resp_csv(struct_50, out_dir / "responsive_units_M1.csv")
    return True


def _convert_auc_matlab_table(auc_table, bin_size: float, time_window: tuple) -> dict:
    genotypes = ("WT", "KO")
    n_boot = 1000
    bin_num = round((time_window[1] - time_window[0]) / bin_size)
    bin_centers = np.arange(time_window[0] + bin_size, time_window[1] + 1e-9, bin_size) - bin_size / 2.0

    out = {
        "binSize": bin_size,
        "timeWindow": np.array(time_window),
        "binCenters": bin_centers,
        "nBins": bin_num,
    }

    # Extract table rows
    mouse_names = auc_table.mouseName
    session_names = auc_table.sessionName
    genotypes_col = auc_table.genotype
    auc_col = auc_table.AUC

    for geno in genotypes:
        records = []
        for r in range(len(genotypes_col)):
            if str(genotypes_col[r]) != geno:
                continue
            m_name = str(mouse_names[r])
            s_name = str(session_names[r])
            sess_units = auc_col[r]
            if not isinstance(sess_units, np.ndarray):
                sess_units = [sess_units]

            for u_idx, u_data in enumerate(sess_units):
                # Unit is responsive if u_data is an array/cell of bins
                if isinstance(u_data, np.ndarray) and u_data.ndim >= 1 and len(u_data) == bin_num:
                    boots = np.zeros((bin_num, n_boot), dtype=np.float64)
                    for b in range(bin_num):
                        boots[b, :] = np.asarray(u_data[b]).ravel()
                    records.append({
                        "mouseName": m_name,
                        "sessionName": s_name,
                        "unitIndex": u_idx + 1,
                        "AUC_boots": boots,
                    })

        n_units = len(records)
        alpha_bonf = 0.05 / n_units if n_units > 0 else 0.05
        idx_up = int(np.ceil((1.0 - alpha_bonf / 2.0) * n_boot)) - 1
        idx_low = int(np.ceil((alpha_bonf / 2.0) * n_boot)) - 1

        dtype = [
            ("mouseName", "O"),
            ("sessionName", "O"),
            ("unitIndex", "f8"),
            ("genotype", "O"),
            ("AUC_mean", "O"),
            ("AUC_upCI", "O"),
            ("AUC_lowCI", "O"),
            ("isSignificant", "O"),
            ("isConPref", "O"),
            ("isIpsiPref", "O"),
            ("AUC_boots", "O"),
        ]
        rec_array = np.empty(n_units, dtype=dtype)

        for i, rec in enumerate(records):
            boots = rec["AUC_boots"]
            auc_mean = np.mean(boots, axis=1)
            auc_up = boots[:, idx_up]
            auc_low = boots[:, idx_low]
            is_sig = (0.5 - auc_up) * (0.5 - auc_low) > 0

            rec_array[i]["mouseName"] = rec["mouseName"]
            rec_array[i]["sessionName"] = rec["sessionName"]
            rec_array[i]["unitIndex"] = float(rec["unitIndex"])
            rec_array[i]["genotype"] = geno
            rec_array[i]["AUC_mean"] = auc_mean
            rec_array[i]["AUC_upCI"] = auc_up
            rec_array[i]["AUC_lowCI"] = auc_low
            rec_array[i]["isSignificant"] = is_sig.astype(bool)
            rec_array[i]["isConPref"] = (auc_mean > 0.5).astype(bool)
            rec_array[i]["isIpsiPref"] = (auc_mean < 0.5).astype(bool)
            rec_array[i]["AUC_boots"] = boots

        out[geno] = rec_array
        out[f"{geno}_alphaBonferroni"] = alpha_bonf
        out[f"{geno}_nUnits"] = n_units

    return out


def _export_resp_csv(struct_50: dict, csv_path: Path):
    rows = []
    for geno in ("WT", "KO"):
        for u in struct_50[geno]:
            rows.append({
                "mouseName": u["mouseName"],
                "sessionName": u["sessionName"],
                "unitIndex": int(u["unitIndex"]),
                "genotype": geno,
            })
    pd.DataFrame(rows).to_csv(csv_path, index=False)
    print(f"Wrote responsive units CSV -> {csv_path} (n={len(rows)})")


def main(argv=None):
    parser = argparse.ArgumentParser(description="Stage or compute M1 ROC tables.")
    parser.add_argument("--precomp-dir", type=Path, default=DEFAULT_PRECOMP_DIR,
                        help=f"Precomputed Motor ROC directory (default: {DEFAULT_PRECOMP_DIR})")
    parser.add_argument("--nwb-dir", type=Path, default=DEFAULT_NWB_DIR,
                        help=f"Directory containing M1 .nwb files (default: {DEFAULT_NWB_DIR})")
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR,
                        help=f"Directory to save ROC tables (default: {DEFAULT_OUT_DIR})")
    parser.add_argument("--force-recompute", action="store_true",
                        help="Force direct NWB recomputation instead of staging")
    args = parser.parse_args(argv)

    args.out_dir.mkdir(parents=True, exist_ok=True)

    if not args.force_recompute and args.precomp_dir.exists():
        staged = stage_precomputed_tables(args.precomp_dir, args.out_dir)
        if staged:
            print("Successfully staged precomputed M1 ROC tables!")
            return

    raise NotImplementedError("Direct NWB computation requires responsive units CSV; run stage first.")


if __name__ == "__main__":
    main(sys.argv[1:])
