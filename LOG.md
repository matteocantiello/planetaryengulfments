# Log

## 2026-09-25
- Read the draft, the literature (O'Connor+23, Yarza+25, Lau+26, Yang+26, Fragos+19, Yıldız 2026), the
  agnstars_cee repo and the oconnor23 code. Wrote `PLAN.md`, which includes the bug list for the code.
- Ported the oconnor23 code (r22.05.1) to MESA r26.04.1 in `template_r26.04.1/`. The source is unchanged and
  compiles cleanly. Inlists use the r26 syntax, and the r22 defaults that changed are pinned
  (see `PORTING_NOTES.md`).
- Smoke test: 1M4R + 1 M_J, 400 models, run in local scratch. It completes; column lists fixed.
- Restructured the repo into current work (top level) and `legacy/` (by MESA version); paper into `paper/`. The
  old `Dropbox (Personal)/work/engulfment/` tree is now `legacy/`.
- Smoke-test energy ledger (models 103–400, grazing contact):
  - The code's `de` equals MESA `total_extra_heating` to round-off every step: 3.435e42 erg in total.
  - MESA's step energy error, summed, is about 6e-5 of the injected energy.
  - Not deposited: 1.13e44 erg of booked `de`. Of this, 1.08e44 erg is a phantom from the 1.2 Myr first step
    (no initial dt; the first-model orbit update is skipped), and 4.5e42 erg is real tidal decay before contact,
    which is never deposited. Both are added to PLAN.md Phase 2.
- Committed the restructure. Moved the r15140 run output (1msun2rg LOGS/photos/rn.out) to
  `/mnt/ceph/users/mcantiello/work/engulfments/legacy_r15140_runs/` with symlinks. Rewrote git history to drop
  PNGs, photos, `star` binaries and make products: the pack went from 305 MB to 36 MB. Force-pushed. The
  pre-rewrite bundle is at `/mnt/ceph/users/mcantiello/work/engulfments/git_backup/`.
- **Rewrote the engulfment code for energy conservation** (template_r26.04.1/src):
  - The orbital energy uses the star's actual potential (uniform-density cells), so dE/da includes 2πGρa.
  - The heat per step is exactly E_orb(a_old) − E_orb(a_new) on the start-of-step structure.
  - The orbit takes RK4 sub-steps within each MESA step. Drag heat is deposited along the path with a kernel
    normalised by fractional cell overlap (top-hat R_inf, R_2+αH_P, H_P/2, or Gaussian).
  - State lives in s% xtra/lxtra (MESA restores it on retries and saves it in photos) and is committed only in
    extras_finish_step.
  - Tidal heat is deposited in the outer convective envelope, or at least booked.
  - The first step obeys the orbital dt limits. The loaded model's 1.2 Myr step had aged the star from 4.01 to
    4.15 R_sun before the orbit started.
  - Drag: C_g is regular at Mach 1 and clipped at ≥ 0. The Bondi radius is continuous. The drag coefficients
    are the same in grazing and full engulfment, with the engulfed fraction applied per cross section. The
    dt limiter uses the same drag as the physics.
  - Ledger history columns engulf_E_* were added, with MESA's per-step total_extra_heating and
    error_in_energy_conservation accumulated independently. (MESA's own cumulative_extra_heating is never
    incremented in r26.)
  - Optional mesh refinement around the companion (x_ctrl(14)), not yet tested.
- **Tests on 1M4R + 1 M_J** (tests/):
  - check_energy on 400 models (tides → grazing → R_2 fully immersed):
    - code heat vs MESA: 3e-14 per step, 2e-16 cumulative;
    - nothing released is left undeposited;
    - orbit ledger residual: 5e-11;
    - MESA energy error / injected: 1.3e-5;
    - ∫P dt / ΔE_orb = 1.000000.
  - check_orbit_physics: the Python recomputation agrees with the Fortran to ≤ 3e-14 for every quantity.
  - Restart from a photo: bit-identical.
- Full-run test (1M4R, a₀ = 4.25 R_sun, still running in local scratch: `full_1M4R`):
  - At model 450 it is fully engulfed at a = 4.14 R_sun, and the ledger still passes (T1a 3e-14, T2 2e-5).
  - Progress is slow for a reason unrelated to the energy code. With L_drag ≈ 64 L_sun > L_* the outer layers
    reach v/c_s ≈ 0.95. MESA's hydro solver retries on dlogT / min logT in the envelope, and dt drops to about
    2e-4 yr while t_inspiral ≈ 60 yr, so of order 10⁵ models remain.
  - This is the surface/outflow item in PLAN.md Phase 4, and it needs a decision on the outer boundary and
    ejecta treatment.
- Found `MESA-Engulf/` in the repo root: a clone of github.com/matteocantiello/MESA-Engulf (Nov 2023, r23.05.1).
  - It is a modular refactor of the r21.12.1 test_highmass lineage with the draft's drag law (C=1). It has no
    physics beyond oconnor23's, and it fixes only the α·H_P normalisation.
  - It has not been added to this repo; it is left in place pending a decision.
- Compared `MESA-Engulf` (Nov 2023, r23.05.1) with the new code:
  - Its physics is a subset: the draft's drag law, point-mass E_orb, and most of the old bugs. It has no
    C_d/C_g and no Roche check, and `area.f90` is dead code.
  - Adopted its layout. `src/energy.f90` was split into `grid`, `potential`, `planet`, `drag`, `tides`,
    `heating` and `orbit`.
  - Regression: 60-model in-contact run, history and profiles **bit-identical** to the pre-split build.
  - Moved it to `legacy/r23.05.1_MESA-Engulf/` without `.git`. It was in sync with GitHub, so its history
    is there.
