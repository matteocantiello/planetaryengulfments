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
- **Speed question.** The old r15140 runs show the same regime dependence:
  - `15140/template` (1 M_sun, 10 R_sun) did the whole engulfment in 920 models.
  - `1msun2rg` (2 R_sun) stalled at dt ~ 1e-7 yr for over 100k models and hit the Slurm time limit.
  - The new code on the same 10 R_sun model (draft drag law, `rg10_draftlaw`) plunges on the same schedule
    (a = 7.06 R_sun at model 700; the old run had 7.49 at model 552).
  - So the 4 R_sun stall is a compact-star problem, not a regression.
- **Outflow options implemented** (x_integer_ctrl(4); src/outflow.f90; inlist `use_other_adjust_mdot = .true.`):
  - A (default, f_w PROVISIONAL): Γ = P_drag t_th / E_bind of the heated region and everything above it.
    A fraction f_w·max(0, 1−1/Γ) of the drag power removes surface gas at Ṁ = P_wind / e_lift instead of
    heating.
  - B: all drag energy goes into heat; outermost contiguous gas that is unbound (Bernoulli > 0) and moving
    outward is removed.
  - The ledger has new terms: E_wind (withheld heat), M_wind, E_unfunded (should be 0), and E_unb_removed (B).
  - Regression with x_integer_ctrl(4) = 0: every pre-existing column is bit-identical.
  - B is not yet exercised.
- **Stall diagnosis revised.** The heated layer in the 4 R_sun case has Γ ≈ 1e-3 while grazing and an estimated
  ~0.06 in the stalled state. Its thermal time (~0.01 yr) is far shorter than the time to unbind it, so it
  radiates the heat in thermal balance rather than being ejected. Option A therefore correctly gives no outflow
  there.
  - The retries are Newton divergences (log T < 1, > 12, |Δlog T| > 99) in a thin, T-inverted, compressed shell
    at the old photosphere (H ionisation zone). This points to numerical stiffness.
  - Earlier statement corrected: the flow is not near-sonic (max v/c_s = 0.007); I misread a terminal column.
- Stopped the 4 R_sun runs (full_1M4R, A_1M4R) at the user's request. Work now focuses on larger radii.
- **10 R_sun regression** (`rg10_draftlaw`: r15140 model 1msun_rg_10, draft drag law, old settings):
  - Complete run (tides → grazing → plunge → disruption → 10 t_KH relaxation) in 949 models and 22 min.
    The old r15140 run took 920 models.
  - Disrupted by **Roche-lobe overflow** at a = 1.34 R_sun. The old code had only the ram-pressure criterion
    and went on to 0.65 R_sun. f_ram along the trajectory agrees between old and new (0.25 at 1.34–1.36 R_sun).
  - Ledger: code vs MESA heat 6e-14 per step; MESA energy error 1.4e-6 of 9.4e44 erg injected; orbit ledger
    2e-7 while active.
  - check_energy.py now evaluates the orbit ledger only while the companion is active.
- Note: the 1 M_sun models (1M4R, 1M10R, 1M80R) have Z = 0.02, but the template kap setting (Zbase = 0.0142,
  a09) came from oconnor23, where it matches the rgb/agb models. The 1M10R runs use Zbase = 0.02 with gs98.
  The template default still needs a decision.
- Running: rg10_A (1M10R + 1 M_J, option A) and rg10_B (option B), for the A/B calibration.
- **Option A, first version, rejected.** Γ with the thermal time t_th in `rg10_A` switched on at a = 9.35 R_sun
  (t_th = 3.3 yr) and sent all drag power (1e4 L_sun) into the outflow. L collapsed to 1.2 L_sun and dt fell to
  5e-10 yr. Run stopped.
- **Option B at 10 R_sun (`rg10_B`)**, complete, 870 models:
  - quasi-static (surface v/c_s <= 0.016);
  - **no unbound gas**;
  - L peak 59.7 L_sun (from 36.2), R max 10.46 R_sun;
  - Roche disruption at 1.33 R_sun.
  - Ledger: code vs MESA heat 6.5e-14; MESA energy error 7e-7 of 9.4e44 erg; orbit ledger 5e-9.
  - This agrees with O'Connor+23 (RGB + M_J engulfments are quasi-static).
- **Option A revised:** Γ = P_drag t_cross / E_bind, where t_cross is the sound-crossing time of the overlying
  column (the hydrostatic readjustment time; cf. O'Connor+23 Eqs. 30, 36). On the same case (`rg10_A2`), Γ stays
  below 7e-4 through the plunge, so there is no outflow, consistent with B.
- **Option B on O'Connor's AGB200 + 10 M_J** (`agb200_10MJ_B`), in progress:
  - after 24 yr, R 203 → 404 R_sun, L 4.1e3 → 1.6e4 L_sun;
  - surface v/c_s = 1.5 (supersonic), but no gas is unbound yet (O'Connor: expansion reaches about 0.4 v_esc).
  - This is the dynamical regime needed to calibrate A.
- `rg10_A2` (revised A) is identical to `rg10_B`:
  - 870 models, a_dis 1.3347 R_sun, L_max 59.66 L_sun, R_max 10.464 R_sun, no mass removed;
  - Γ_max = 5e-3;
  - all ledger checks pass.
- `agb200_10MJ_B`: disruption (Roche) at 0.77 R_sun after 27 yr.
  - R 203 → 809 R_sun; L 4.1e3 → 2.2e4 L_sun, then fading to 3e2 L_sun; surface v/c_s up to 1.9.
  - **No gas becomes unbound**, even in O'Connor's disruptive regime (they report the same).
  - So in MESA 1D hydro, option B removes nothing in either regime. 3D (Yang+26: ~1e-3 M_sun ejected for
    5 M_J in a 100 R_sun giant) does eject mass. Calibrating A needs a decision on the target: B (1D hydro) or
    3D results.
- **Template now matches O'Connor+23.** Their published r22.05.1 package (Zenodo 10.5281/zenodo.7692746,
  downloaded) uses:
  - MLT_option = 'TDC' with α_MLT = 2;
  - heat deposited over R_p ± 1·H_P (our kernel 2, α = 1);
  - a09 opacities with Zbase = 0.0142, also for their Z = 0.02 1M*R models.

  The published physics equals our oconnor23 copy, rearranged. Their starting models are identical to ours.
- **Yang+26 comparison setup:**
  - New history columns: cumulative outward mass flux through 1, 2, 4 R0, all gas and gas with Bernoulli > 0,
    matching Yang Eqs. 11–12.
  - New x_ctrl(17): while in contact, dt ≤ x_ctrl(17)·t_dyn.
  - Host `starting_models/1M100R.mod`: 1M80R evolved to R = 100.02 R_sun, L = 1219 L_sun, Teff = 3410 K
    (Yang: 100, 1220, 3406); Z = 0.02, gs98.
- **Yang comparison, unresolved** (`yang_B`, `yang_A`): 5 M_J from 0.95 R*, stopped at 0.3 R*.
  - Inspiral in 12 yr (Yang, eccentric: ~8.7 yr). C_g = 1.6–3.1 along the path (Yang's 3D calibration:
    1.5–3).
  - Only 16 steps of 0.2–2.8 yr ≫ t_dyn = 0.05 yr, so the hydro response is not resolved. Ejected through R0:
    1.5e-4 M_sun (Yang 2–3e-3); unbound 0; L 1219 → 1239 L_sun.
  - Γ_max (A) = 2e-3.
- Running: `yang_B_dyn` with dt ≤ 0.1 t_dyn.
- **Resolved B vs Yang+26** (`yang_B_dyn`: dt ≤ 0.1 t_dyn, 3161 models; ledger passes, MESA energy error
  3.4e-5 of injected):
  - Inspiral 95 → 30 R_sun takes 15.8 yr = 314 t_dyn (circular). Yang takes ~170 t_dyn (eccentric, e = 0.65,
    deeper pericentre passages). The orbit agrees with the unresolved run.
  - Ejected through R0: 1.6e-4 M_sun (Yang 2–3e-3); through 2 and 4 R0: 0; unbound: 0 (Yang ~1e-3).
    R +1%, L +2% (Yang: peaks up to a few × 10³ L*).
  - **B does not reproduce the 3D ejecta; it is short by more than 10× in ejected mass and gives zero unbound
    mass.**
  - Reason: ejecting 2.5e-3 M_sun from R* takes ≳ G M M_ej / R* ≈ 1e44 erg, about half of the 2.4e44 erg
    released down to 0.3 R*. In 3D that energy goes into bulk motion through the planet's wake and shocks,
    concentrated near the planet. In 1D it becomes heat spread over a whole spherical shell, and the convective
    envelope carries it away (L_drag ≲ L*).
  - Yang's gas is also adiabatic (no cooling), which favours ejection.
  - Consequence: A has to be a **mechanical-ejection prescription calibrated directly to 3D**, not to B.
    Γ(t_cross) = 2e-3 here, so the current A gives no outflow either.
- **Option A recast.** Constant mechanical fraction ε of the drag power (x_integer_ctrl(5) = 1, default), or
  Γ-limited (= 2). Provisional ε = 0.2.
  - `yang_Amech` (ε = 0.2, dt ≤ 0.1 t_dyn), in progress at 8.7 yr: removed 2.6e-5 M_sun (Yang unbound 1.5–2e-3).
  - Ledger closes (E_wind withheld exactly; MESA error 5e-4 of injected).
  - The orbit ledger residual (4.6e-4) now includes the E_orb change from mass removed between steps. It should
    be folded into W_pot.
  - e_lift = (1 + β²) GM/R − u overcharges the ejecta compared with the Bernoulli deficit used in 3D.
- **Literature searches** (SPH CE, grid CE, 1D + α formalism, LRN light curves) are summarised in
  `docs/ejection_calibration_literature.md`. The main points:
  - Dynamical ejecta come from the outer layers and are locally energy-limited: δE_orb + δE_bind = 0
    (Ivanova & Nandez 2016). Yang's planet case gives ε ≈ 1 against the Bernoulli deficit.
  - Deeper deposition has ε ≈ 0.02–0.3 (Ricker & Taam 2012: 0.25).
  - Brown-dwarf post-CE α = 0.24–0.41.
  - Light curves: multi-shell Matsumoto & Metzger 2022.
  - This leads to prescription v2: an outer, Bernoulli-limited channel plus a deep ε channel.
