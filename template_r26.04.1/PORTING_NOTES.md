# Port of the engulfment code to MESA r26.04.1

Started 2026-09-25. Procedure: `docs/MESA_UPGRADE_HANDOFF.md`.

## Source version
- The most recent code was `legacy/r22.05.1_oconnor23/` (git HEAD d178f59, 2023-04-14). It was the
  setup for O'Connor et al. 2023 and was built against **MESA r22.05.1**; the `star` binary records
  `/Users/mcantiello/astro/mesa-r22.05.1`, and `README_NEXT.txt` says r22.05.1.
- Older copies were not ported: `legacy/r15140/refactor/` and `legacy/r15140/runs/` (r15140, the version stated in the paper draft) and
  `legacy/r21.12.1/test_highmass/`.

## Status
The source below was ported unchanged, then rewritten the same day for energy conservation (see
`../LOG.md` and `../PLAN.md` Phase 2). The unchanged port is commit f2aa9f8. For the r22 comparison, build that
commit's `src/`.

## How the template was built
1. Copied a fresh `$MESA_DIR/star/work` (r26.04.1).
2. `src/run_star_extras.f90` and `src/energy.f90` were copied from oconnor23 **unchanged**. They compile against r26
   with no edits. The only compiler output is a pre-existing `-Wampersand` warning in the format string at
   run_star_extras.f90:767.
3. `make/makefile`: MESA's standard work makefile with `RUN_STAR_EXTRA_OBJS = energy.o`, plus a dependency of
   `run_star_extras.o` on `energy.o`.
4. `inlist`: the r26 array syntax (`read_extra_*_inlist(1)`, `extra_*_inlist_name(1)`). Since r23.05.1 the
   old `...inlist1` names are rejected.
5. `inlist_project` was ported from oconnor23. The changes:
   - `load_model_filename` now points into `starting_models/`, which holds the oconnor23 `.mod` files.
   - `pgstar_flag = .false.` by default.
   - `MLT_option = 'Cox'` is kept. The r26 default is `'TDC'`. Note that O'Connor+23 describe TDC with α=2 in
     their paper, and the old clone at `~/work/planetaryengulfments` has an uncommitted switch to TDC.
   - kap: the `a09` main tables are kept. The CO and lowT prefixes are now written out explicitly (`gs98_co`,
     `lowT_fa05_gs98`) because they were implicit defaults. They are the same in r22 and r26.
   - Two r22.05.1 defaults that changed in r26.04.1 are pinned to their r22 values for the reproduction test:
     `use_gold2_tolerances = .true.` and `use_time_centered_eps_grav = .false.`.
   - `photo_digits = 5`, so photo names do not wrap every 1000 models.
6. Column lists: the fresh r26 defaults, with the extra columns the oconnor23 lists enabled, plus energy accounting:
   - history: `total_energy`, `total_extra_heating`, `total_energy_sources_and_sinks`,
     `error_in_energy_conservation`, `rel_error_in_energy_conservation`, `cumulative_energy_error`,
     `rel_cumulative_energy_error`, `log_rel_run_E_err`, energy components and `kh_timescale`;
   - profile: `extra_heat`, `velocity`, `mlt_vc`.

   `tri_alfa` was renamed to `tri_alpha` in r22.11.1, but the project never enabled it.
7. `inlist_pgstar` is `legacy/r22.05.1_oconnor23/inlist_pgstar_engulf` copied unchanged. The inlist checker finds no unknown
   controls in it.
8. `mesa_env.sh` sets `MESASDK_ROOT` (SDK 26.6.1), `MESA_DIR` (r26.04.1) and `OMP_NUM_THREADS`.
9. `stash.py` was not copied. It moved to `$MESA_DIR/scripts` in r24.03.1.

## Differences found (r22.05.1 → r26.04.1)
- **Changelog backwards-incompatible entries relevant here:**
  - inlist chaining became arrays (r23.05.1);
  - pgstar `file_extension` was removed and `pause` renamed to `pause_flag` (r25.12.1); neither is used here;
  - extra history values are now always saved as floats (r24.03.1);
  - `tri_alfa` was renamed to `tri_alpha` (r22.11.1).
- **Defaults whose value changed** (`mesa_defaults_diff.sh`):
  - `use_gold2_tolerances` .true. → .false.;
  - `use_time_centered_eps_grav` .false. → .true.;
  - `max_abs_rel_run_E_err` 0.01 → −1 (MESA no longer stops on large energy error);
  - `warn_when_large_rel_run_E_err` 0.01 → 0.1;
  - `max_corr_jump_limit` and `max_resid_jump_limit` 1d6 → 1d12;
  - `overshoot_D_min` 1d2 → 1d-2 (no overshoot is used here);
  - Skye/FreeEOS EOS blend limits (irrelevant at envelope conditions);
  - asteroseismic solar references.
- **run_star_extras interface:** unchanged for what this code uses: `other_energy`, `s% extra_heat` (auto_diff
  since r15140+), `s% xtra`, `star_alloc_extras`/`extra_work`, `R_function2_param*`, `s% scale_height`,
  `s% csound`, `s% kh_timescale`.
- **Where `other_energy` is called in r26:** once per step attempt, from `check_for_extra_heat` in
  `star/private/evolve.f90:1650`, before the solver. It is **not** called per Newton iteration. It is
  re-called on retries.
- **`s% xtra(:)`, `s% ixtra(:)` and `s% lxtra(:)` are written to photos in r26** (`photo_out.f90:137-139`). They can
  replace the `move_extra_info`/`extra_work` machinery.

## Validation status
- [x] Compiles (SDK 26.6.1, gfortran 15.2.0).
- [x] Smoke test: 1M4R + 1 M_J, 400 models: runs; ledger checked (LOG.md).
- [ ] Reproduce r22.05.1 on one reference case. This needs SDK 22.6.1, whose tarball is in `~`, to rebuild the
      oconnor23 code against `~/mesa-r22.05.1`. That r22 install was built with GCC 12.1. No r22 Linux run of
      this code exists: the 2023 Slurm job failed because the binary had been built on a Mac.
- [ ] Unpin the r22 defaults one at a time and record the effect.
