# Engulfments with MESA

1D MESA simulations of a planet or star (radially much smaller than its host) spiralling into a companion's
envelope. The orbital energy lost to drag is deposited as heat in the primary.

## Layout
| Path | What | Status |
|---|---|---|
| `STATUS.md` | **Restart point**: state of code, runs, findings, next steps | **read first** |
| `PLAN.md` | Plan: cleanup, port, code fixes, energy-conservation tests, paper | **current** |
| `LOG.md` | Dated log of changes, tests, decisions | **current** |
| `template_r26.04.1/` | Engulfment code for MESA r26.04.1 (src, inlists, column lists, starting models); see its `PORTING_NOTES.md` | **current** |
| `paper/` | Draft paper (`engulfments.tex`, figures, bib) | current (text and figures still from r15140) |
| `literature/` | Reference PDFs (not in git) | current |
| `docs/` | `MESA_UPGRADE_HANDOFF.md`; `ejection_calibration_literature.md` (CE/engulfment ejecta literature); `figures/` (status figures) | reference |
| `tests/` | Energy-ledger and physics cross-check scripts (`README.md` inside) | current |
| `analysis/` | `make_status_figures.py` (regenerates `docs/figures`) | current |
| `runs/` | Symlink to run output on Ceph (not in git); `runs/2026-09-25/` = day-1 runs | data |
| `legacy/` | All pre-2026 code, runs and notebooks, by MESA version; see `legacy/README.md` | **old, read-only** |

## Using the current code
```bash
cd template_r26.04.1
source mesa_env.sh      # SDK 26.6.1, MESA_DIR=~/mesa-26.04.1
./mk
./rn                    # copy the template to a run directory first for real runs
```
Run output (LOGS, photos) belongs on Ceph (`/mnt/ceph/users/mcantiello/...`), not in this repo.
