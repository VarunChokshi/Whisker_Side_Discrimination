"""
mseio — shared IO helpers for the MSessionExplorer-format Python figure pipeline.

The MATLAB paper-figure code reads MSessionExplorer (`se`) objects and MATLAB
`table` objects. Neither is readable by scipy. So each figure has a MATLAB
"export" step that flattens the panel-ready results into a plain -v7 struct
(numeric arrays + cellstr text only — never `table`, `string`, or class objects).
These helpers load those flattened structs.
"""
from __future__ import annotations
from pathlib import Path
import numpy as np
import scipy.io as sio


def load_struct(path) -> dict:
    """Load a flattened -v7 .mat as a plain dict (squeeze_me, no mat_struct records)."""
    m = sio.loadmat(str(path), squeeze_me=True, struct_as_record=False)
    return {k: v for k, v in m.items() if not k.startswith("__")}


def cellstr(x) -> np.ndarray:
    """MATLAB cellstr/char -> 1-D numpy array of python str (trimmed)."""
    return np.array([str(s).strip() for s in np.atleast_1d(x).ravel()], dtype=object)


def col(x) -> np.ndarray:
    """Force a numeric field to a 1-D float array (handles scalars)."""
    return np.atleast_1d(np.asarray(x, dtype=float)).ravel()


def ensure_dir(p) -> Path:
    p = Path(p)
    p.mkdir(parents=True, exist_ok=True)
    return p


def mround(x) -> int:
    """MATLAB round(): half away from zero (Python's round() is banker's rounding)."""
    return int(np.floor(np.abs(x) + 0.5) * np.sign(x))
