# Engulfments with MESA: plan (2026-09-25)

Goal: finish the 1D MESA engulfment paper (`paper/engulfments.tex`). A secondary much
smaller than the primary spirals in, and drag heating is deposited in the primary's envelope. First the code has
to be clean, current (MESA r26.04.1) and **demonstrably energy-conserving**.

Code lineage: r15140 (`legacy/r15140/`, the version stated in the draft) → r21.12.1 (`legacy/r21.12.1/`) →
r22.05.1 (`legacy/r22.05.1_oconnor23/`, April 2023, the most recent) → r26.04.1 (`template_r26.04.1/`, this port).

---

## Phase 0 — Clean up the repo
**Done 2026-09-25 (on disk; not yet committed).** Everything was moved and nothing deleted. Layout: see
`README.md`. Current work is at the top level; all pre-2026 material is in `legacy/` by MESA version (see
`legacy/README.md`).

Remaining:
1. **Commit the restructure.** Git sees the old `Dropbox (Personal)/...` paths as deleted and `legacy/` as new.
   `git add -A` records these as renames. It also stages the removal of the r15140 files that were already
   missing from disk; they stay in history.
2. Move the old run data (`legacy/r15140/runs/1msun2rg`, 5.1 GB) to Ceph and leave a symlink.
3. Optional: rewrite history (`git filter-repo`) to drop the 3761 PNGs and binaries (the pack is about 305 MB).
   This needs a force-push to `github.com/matteocantiello/planetaryengulfments`.
4. Retire the old clone `~/work/planetaryengulfments`. Its only unique content is a one-line TDC edit and a
   failed Slurm log.
5. Create `tests/` and `analysis/` when Phase 3 starts, with run output on Ceph (`runs -> /mnt/ceph/...`).

## Phase 1 — Port to MESA r26.04.1 (started; see `template_r26.04.1/PORTING_NOTES.md`)
- [x] Fresh r26 work directory. oconnor23 `src/` compiles unchanged. Inlists moved to r26 syntax; r22 defaults
      that changed are pinned; column lists regenerated with the energy-accounting columns added.
- [x] Smoke test: 1M4R + 1 M_J, 400 models, completes.
- [ ] **Reproduce r22.05.1.** Rebuild the oconnor23 code against `~/mesa-r22.05.1` with SDK 22.6.1 (its
      tarball is in `~`). Run the same 1M4R-1MJ case, and one O'Connor+23 case (RGB50-1MJ), on both versions.
      Compare a(t), L(t), R(t) and the injected energy; aim for ≲ a few %. Then unpin the r22 defaults one at a
      time.
- [ ] Reconcile the setup with O'Connor+23 as published. They report TDC with α_MLT = 2; our oconnor23 inlist
      has Cox. Their Zenodo inlists are at doi:10.5281/zenodo.7692746.

## Phase 2 — Fix the code
**Done 2026-09-25**: `template_r26.04.1/src` was rewritten; see LOG.md. All items below are fixed except 11
(mesh refinement), which is implemented but not yet tested. The list is kept as a record of what was wrong in the
r22 code.

Problems found in `legacy/r22.05.1_oconnor23/src` (RSE = run_star_extras.f90, EN = energy.f90):

**Energy bookkeeping**
1. `total_energy_injected` is never incremented (RSE 40, 366, 392). The history column is always 0.
2. **The orbit–heat coupling is not energy-consistent.**
   - `E_orb = -G m(a) M_p / 2a` is evaluated with a frozen `m(krr_center)` at both radii (RSE 269–271), and
     the decay law leaves out the 2πGρa term. The true relation is
     `dE_orb/da = M_p [G m(a)/(2a²) + 2πGρ(a) a]`, so decay is too fast by a factor of about `1 + 3ρ/ρ̄(<a)`.
   - The `E_orb` history column is therefore not a conserved partner of the heat.
   - Fix: take `E_orb = M_p [v_K²/2 + Φ(a)]` with Φ from the MESA structure. Deposit exactly `F·v·dt`, and solve
     for the new separation from `E_orb(a_new) = E_orb(a) − F v dt`.
3. **The α·H_P deposition mode injects more than `de`** (RSE 297–300): the loop spans the union of regions but
   normalises by the smaller `dmsum_companion_hp`.
4. **The heated cells are off by one.**
   - `locate_on_grid` puts the bottom at the first cell lying entirely below a−R, and `krr_center` is the cell
     below a.
   - A top-hat over whole cells also jumps as the companion crosses cell faces.
   - Fix: a kernel normalised exactly by fractional cell overlap, with top-hat, Gaussian (Fragos+19) and H_P
     shell (O'Connor+23) options.
5. **Restarts and the first step.**
   - `store_extra_info` runs before `a` is updated (RSE 657 vs 661).
   - `use_other_energy` and `stop_age` side effects are not restored.
   - The first step deposits heat without moving the orbit.
   - Fix: keep state in `s% xtra/lxtra`, which r26 writes to photos, and commit it in `extras_finish_step` only.
5b. **The first step is 1.2 Myr** (found in the r26 smoke test, 1M4R). No `set_initial_dt` is used, so the
    loaded model's dt is taken. The code books a tidal `de` of 1.1×10⁴⁴ erg for that step, but the orbit is not
    moved and nothing is deposited. The star also evolves 1.2 Myr before the orbit starts. Fix:
    `set_initial_dt`, and bound the first step with the same da/a tolerance.
6. **Tidal decay.** Outside the star its energy is not deposited anywhere. In the smoke test that was 4.5×10⁴² erg before contact, compared with 3.4×10⁴² erg deposited in the first 300 contact steps. Inside the star it is deposited in the
   planet's shell (RSE 279). Decide what to do and put it in the ledger. Also, the tidal `dt_next` override must be
   `min(...)` (RSE 671–672).

**Drag**
7. **`C_grav` can be negative or diverge** (EN 46–51): negative when H_P < R_influence, and infinite at Mach 1.
   A negative `drag_area` makes the planet move outward. Fix: a form that is regular through Mach 1 and clipped
   (Kim & Kim 2007/Kim 2010), or Yang+26's L_int.
8. **Drag jumps at the end of grazing.** It uses `area` with no coefficient while grazing and `C·area` once
   engulfed (RSE 219 vs 225), a factor 2–4 drop.
9. **The Bondi radius is discontinuous at Mach 1** by a factor of 2 (EN 77–87).
10. **The timestep limiter uses a different drag from the physics** (RSE 714–753): `area` instead of
    `drag_area`, a single-cell ρ, `m(k)`, and `s% m(1)` for v_K. The loop at RSE 680 has no `k ≤ nz` guard.

**Resolution and integration**
11. **Mesh refinement around the companion never runs.**
    - `R_function2_param*` are in the wrong units (off by Rsun), and `R_function2_weight` is left at 0.
    - Fix: the r26 `other_mesh_fcn_data` hook, with width about R_influence.
12. **The orbit takes one explicit Euler step per MESA step**, with dr up to 0.5 R_influence. Fix: sub-step the
    orbit (RK4 on the frozen start-of-step structure) and deposit ∑F·v·Δt, so the heat does not depend on dt.

**Cosmetic:** `dt_next/Rsun` in the printout (RSE 770); the `-Wampersand` warning (RSE 767); unconditional
per-step `write`s.

## Phase 3 — Energy-conservation and convergence tests (`tests/`)
Status 2026-09-25: T1, T2 and T6 pass on grazing runs, and the physics cross-check passes. Still to do: a full run through the plunge and disruption; T3, T4, T5, T7.
- **T1, code ledger.** Every step, ∑ extra_heat·dm·dt must equal the intended ΔE_orb to round-off. The cumulative
  injected energy must equal E_orb(a₀) − E_orb(a) with the same potential.
- **T2, MESA ledger.** ΔE_star − (∫extra_heat − ∫L_surf − ∫L_ν + ∫L_nuc) must be ≈ 0, using
  `total_extra_heating`, `error_in_energy_conservation` and `cumulative_energy_error`.
  - Normalise by the **injected** energy, not by MESA's `rel_*`, which divides by the star's total energy
    (~10⁴⁸⁻⁴⁹ erg compared with ~10⁴⁴⁻⁴⁶ erg injected).
  - Target: ≲1% of the injected energy (the Fragos+19 standard).
- **T3, global ledger and virial check.** Plot E_star + E_orb + ∫L dt against time. Compare ΔE_grav/ΔE_orb with
  (3−3γ)/(4−3γ) (Fragos+19).
- **T4, passive-envelope benchmark.** Use a very small M_p so the heating is negligible. MESA's a(t) should match
  an independent Python ODE integration on the initial profile (O'Connor Eq. 24).
- **T5, convergence.**
  - Vary the timestep tolerances (`x_ctrl(4,5)`), `mesh_delta_coeff`, `varcontrol_target` and the kernel width.
  - Observables: a(t), L_peak, t_peak, the disruption radius and total E_injected.
- **T6, restart.** Run N steps, restart from a photo, and compare with the uninterrupted run.
- **T7, drag benchmark (Lau+26).** At r = 2.8 R☉ in the 1 M☉, 4 R☉ giant (ρ = 0.0118 g cm⁻³, v = 231 km/s,
  Mach 2), η_pres = 0.464 gives F·v ≈ 1.0×10⁴⁰ erg/s. The same model is in our grid.

## Phase 4 — Physics choices and scope for the paper
Status 2026-09-25:
- The template matches O'Connor+23.
- Outflow options A and B are implemented. B cannot reproduce the 3D ejecta, so A is being recast (v2) and
  calibrated on the literature (`docs/ejection_calibration_literature.md`).
- The compact-host numerical stall is parked. See `STATUS.md`.

- **Drag.**
  - Our current C_d = 1 with no ½ is about 2× Lau+26's calibrated η_pres ≈ 0.46.
  - O'Connor+23 use a Mach-dependent C_d of 0.25–0.5 and the max of ram and gravitational drag.
  - agnstars_cee uses the sum.
  - Decide on one fiducial and bracket the rest.
- **Grazing.** Yarza+25's stratified cross-section (App. A) could replace the plane-parallel intercepted area.
  Also reconcile our long grazing phase with their hours-to-days τ_drag near the surface.
- **Disruption and ablation.** Our current criterion is ram pressure (Jia & Spruit). The alternatives are Roche
  (O'Connor Eq. 18) and continuous ablation (Lau+26, which ablates fully at 1.1 R☉ in the 4 R☉ giant, inside
  the convection zone). The draft's line "ablation is ineffective" needs revising. Handle the remaining orbital
  energy at disruption explicitly.
- **Deposition kernel.** Top-hat over 2R_infl, Gaussian (Fragos), or H_P shell (O'Connor). None has a 3D
  calibration, so run a sensitivity study.
- **Convection.** TDC (r26 default; O'Connor used α = 2) or Cox. Use `s% mlt_vc`, not `conv_vel`.
- **Surface and outflow.** Track mass with positive Bernoulli parameter. Consider the Fragos+19 outer BC.
  Compare with Yang+26's ejecta masses.
- **Orbit.** Radial infall velocity once drag ~ gravity (the draft's TODO); buoyancy term (Lau+26 Eq. 20).
- **Scope options.**
  - (a) Hot Jupiters on subgiants and the lower RGB (the draft's core; complements O'Connor+23, which covers
    evolved giants).
  - (b) Main-sequence engulfment, benchmarked against ZTF SLRN-2020 (De+23, Yarza+25).
  - (c) Brown dwarfs and low-mass stars as companions. The back-reaction of the companion's gravity becomes
    non-negligible here.
  - (d) A cross-check on an O'Connor+23 model.

## Phase 5 — Paper
- Update the MESA version and citations. Fix the drag convention text, the "size 2A" wording, the duplicate
  `eq:rabondi` label and the `eqQ:` typo.
- Add missing references: O'Connor+23, Lau+25a, Lau+26, Yarza+23, Yarza+25, Yang+26, De+23, Yıldız 2026,
  Kim & Kim 2007.
- Frame the paper as the compact-star companion of O'Connor+23, and as the first with the stellar back-reaction
  compared with Lau+26's fixed-structure 1D integration. Report the energy-conservation tests (no prior 1D
  engulfment paper does).
