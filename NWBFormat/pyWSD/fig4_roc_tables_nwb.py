"""Direct NWB-based ROC Engine (Python).

Reads S1 ephys .nwb files directly, bins trial-by-trial spike trains for 20 Hz
Contralateral vs Ipsilateral trials, and calculates 1,000-bootstrap AUC
distributions across time bins (50 ms and 5 ms).
Outputs:
  - NWBData/Data/Tables/ROC/fig4_roc_tables_S1_50ms.mat
  - NWBData/Data/Tables/ROC/fig4_roc_tables_S1_5ms.mat
"""

import argparse
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import pynwb
import scipy.io as sio


DEFAULT_NWB_DIR = Path(
    r"E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\NWBData\Data\ephys\S1"
)
DEFAULT_RESP_CSV = Path(
    r"E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\NWBData\Data\Tables\ROC\responsive_units_S1.csv"
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

        boot_con = con_b[idx_con]   # shape (n_boot, n_con)
        boot_ipsi = ipsi_b[idx_ipsi] # shape (n_boot, n_ipsi)

        # Pairwise comparison: (n_boot, n_con, 1) - (n_boot, 1, n_ipsi)
        diff = boot_con[:, :, None] - boot_ipsi[:, None, :]
        auc_draws = np.mean((diff > 0).astype(float) + 0.5 * (diff == 0).astype(float), axis=(1, 2))
        sorted_boot_auc[b, :] = np.sort(auc_draws)

    return sorted_boot_auc


def compute_roc_for_bin_size(df_resp: pd.DataFrame, nwb_dir: Path,
                             bin_size: float, time_window: tuple,
                             n_boot: int = 1000) -> dict:
    """Computes full ROC AUC data structure for either 50ms or 5ms bins."""
    genotypes = ("WT", "KO")
    alpha_val = 0.05
    n_bins = int(round((time_window[1] - time_window[0]) / bin_size))
    bin_centers = (np.arange(time_window[0] + bin_size, time_window[1] + 1e-9, bin_size) - bin_size / 2.0)

    out_struct = {
        "binSize": bin_size,
        "timeWindow": np.array(time_window, dtype=np.float64),
        "binCenters": bin_centers,
        "nBins": n_bins,
    }

    # Group units by session for efficient single-pass NWB reading
    sessions_group = df_resp.groupby(["mouseName", "sessionName", "genotype"])

    unit_records_by_geno = {g: [] for g in genotypes}

    print(f"Processing {len(df_resp)} units across {len(sessions_group)} sessions (binSize = {bin_size}s)...")

    for (m_name, s_name, geno), group in sessions_group:
        # Construct NWB filename: VC030107_2022-11-15a.nwb
        s_date = f"20{s_name[:2]}-{s_name[2:4]}-{s_name[4:6]}{s_name[6:]}"
        nwb_file = nwb_dir / f"{m_name}_{s_date}.nwb"

        if not nwb_file.exists():
            # Try alternate pattern
            matches = list(nwb_dir.glob(f"{m_name}*{s_name}*.nwb"))
            if matches:
                nwb_file = matches[0]
            else:
                print(f"Warning: NWB file not found for {m_name} {s_name} at {nwb_file}")
                continue

        with pynwb.NWBHDF5IO(str(nwb_file), "r") as io:
            nwb = io.read()
            trials = nwb.trials.to_dataframe()

            # 20 Hz stimulus trials
            is_20 = (trials["rightStimType"].str.contains("20", na=False) |
                     trials["leftStimType"].str.contains("20", na=False))

            # Contra vs Ipsi based on recording site
            rec_site = ""
            try:
                rec_site = str(nwb.lab_meta_data["session_info"].recSite)
            except Exception:
                rec_site = str(nwb.session_description or "")

            is_left = "Left" in rec_site

            if is_left:
                con_trials = is_20 & (trials["rightOnset"] == 0)
                ipsi_trials = is_20 & (trials["leftOnset"] == 0)
            else:
                con_trials = is_20 & (trials["leftOnset"] == 0)
                ipsi_trials = is_20 & (trials["rightOnset"] == 0)

            con_t0 = trials.loc[con_trials, "reference_time"].values
            ipsi_t0 = trials.loc[ipsi_trials, "reference_time"].values

            if len(con_t0) == 0 or len(ipsi_t0) == 0:
                print(f"Warning: Missing contra/ipsi trials in {nwb_file.name}")
                continue

            for _, row in group.iterrows():
                u_idx = int(row["unitIndex"])
                spike_times = nwb.units[u_idx - 1]["spike_times"].values[0]

                rates_con = spike_times_to_rates(spike_times, con_t0, time_window, bin_size)
                rates_ipsi = spike_times_to_rates(spike_times, ipsi_t0, time_window, bin_size)

                # 1,000 bootstrap draws
                sorted_boot = bootstrap_auc(rates_con, rates_ipsi, n_boot=n_boot, seed=u_idx)

                unit_records_by_geno[geno].append({
                    "mouseName": m_name,
                    "sessionName": s_name,
                    "unitIndex": u_idx,
                    "genotype": geno,
                    "AUC_boots": sorted_boot,
                })

    # Finalize statistics per genotype with Bonferroni correction
    for geno in genotypes:
        records = unit_records_by_geno[geno]
        n_units = len(records)
        alpha_bonf = alpha_val / n_units
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

        out_struct[geno] = rec_array
        out_struct[f"{geno}_alphaBonferroni"] = alpha_bonf
        out_struct[f"{geno}_nUnits"] = n_units
        print(f"  {geno}: {n_units} units processed (alpha_Bonferroni = {alpha_bonf:.4e})")

    return out_struct


def main(argv=None):
    parser = argparse.ArgumentParser(description="Direct NWB-based ROC/AUC calculation engine.")
    parser.add_argument("--nwb-dir", type=Path, default=DEFAULT_NWB_DIR,
                        help=f"Directory containing S1 .nwb files (default: {DEFAULT_NWB_DIR})")
    parser.add_argument("--resp-csv", type=Path, default=DEFAULT_RESP_CSV,
                        help=f"CSV listing responsive units (default: {DEFAULT_RESP_CSV})")
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR,
                        help=f"Directory to save ROC tables (default: {DEFAULT_OUT_DIR})")
    parser.add_argument("--n-boot", type=int, default=1000,
                        help="Number of bootstrap iterations (default: 1000)")
    args = parser.parse_args(argv)

    args.out_dir.mkdir(parents=True, exist_ok=True)

    if not args.resp_csv.exists():
        raise FileNotFoundError(f"Responsive units CSV not found: {args.resp_csv}")

    df_resp = pd.read_csv(args.resp_csv)
    print(f"Loaded responsive units list from {args.resp_csv}: {len(df_resp)} total units.")

    # 1. 50-ms bins (-50 to 150 ms)
    roc_50ms = compute_roc_for_bin_size(
        df_resp=df_resp,
        nwb_dir=args.nwb_dir,
        bin_size=0.05,
        time_window=(-0.05, 0.15),
        n_boot=args.n_boot
    )
    out_50ms_path = args.out_dir / "fig4_roc_tables_S1_50ms.mat"
    sio.savemat(out_50ms_path, {"rocTable50ms": roc_50ms}, do_compression=True)
    print(f"Wrote 50-ms ROC table -> {out_50ms_path}")

    # 2. 5-ms bins (-50 to 150 ms)
    roc_5ms = compute_roc_for_bin_size(
        df_resp=df_resp,
        nwb_dir=args.nwb_dir,
        bin_size=0.005,
        time_window=(-0.05, 0.15),
        n_boot=args.n_boot
    )
    out_5ms_path = args.out_dir / "fig4_roc_tables_S1_5ms.mat"
    sio.savemat(out_5ms_path, {"rocTable5ms": roc_5ms}, do_compression=True)
    print(f"Wrote 5-ms ROC table -> {out_5ms_path}")

    print("Direct NWB ROC calculation finished successfully!")


if __name__ == "__main__":
    main(sys.argv[1:])

