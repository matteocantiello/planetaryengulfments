# Legacy material (pre-2026). Do not modify.

This is kept for reference and for validating the r26 port. The current code is in `../template_r26.04.1/`.

| Path | MESA | Date | Contents |
|---|---|---|---|
| `r22.05.1_oconnor23/` | r22.05.1 | Apr 2023 | **Latest pre-port code**: the O'Connor et al. 2023 setup; starting models rgb*/agb*/1M*R. It was ported unchanged to r26. The `star` binary here is a macOS build and will not run on Linux. |
| `r21.12.1/` | r21.12.1 | 2022 | `test_highmass` run directory; `energy_test.ipynb`, `engulfment.ipynb` |
| `r15140/refactor/` | r15140 | Oct 2022 | Refactored code (older than oconnor23) |
| `r15140/runs/` | r15140 | Oct 2022 | Runs `1msun{2,4,10}rg` (1msun2rg has full LOGS, 5.1 GB) and old submit scripts (`grid`, `run1`, `run4`: note the broken `export OMP_NUM_THREADS = N` syntax) |
| `notebooks/` | r11701 era | | `engulfment_11701*.ipynb`, `mesa.ipynb` |

These paths were under `Dropbox (Personal)/work/engulfment/` until 2026-09-25. Several of them are in git
history but no longer on disk: `15140/{ms1,template,msun_mj_2rsun_rj,tests/refactor}`, `15140/engulfment.ipynb`,
and the `r21.12.1` pngs. They are the r15140 runs behind the draft's figures. To recover them:
```bash
git show d178f59 --stat                                   # list
git checkout d178f59 -- "Dropbox (Personal)/work/engulfment/15140"   # restore into the worktree
```
An older clone of this repo, `~/work/planetaryengulfments`, has the same history. Its only extra content is an
uncommitted `MLT_option = 'TDC'` edit in oconnor23/inlist_project and a failed 2023 Slurm log.
