# Handoff: upgrading a project to a new MESA release

*Written 2026-09-25 from the rednoise project, which moved from MESA r15140 to r26.04.1 (SDK 26.6.1) in
September 2026. It is meant for a Claude instance working on a **different project whose MESA version is not
known in advance**. §1–§5 are the general procedure: find the old version, find every difference, port,
validate. §6 is the rednoise migration as a worked example of what the procedure turns up. Everything was
checked on the Flatiron workstation (user mcantiello); the two helper scripts are included verbatim in §7.*

---

## 0. The procedure in one paragraph
Identify the old MESA version from the project's files (§1). Install the new release next to the old one,
never over it (§2). Collect the differences in three ways: the official changelog for **every** release
in between, a mechanical diff of the two installs' defaults files, and the compiler plus MESA itself, which
report every broken name (§3). Port the project into a fresh copy of the new `star/work` directory (§4).
Validate one model against the old version before running anything at scale (§5).

## 1. Find the old version
Any of these works; check at least two:
- **Output files:** line 3 of any `LOGS/history.data` (or profile) header holds `version_number`, compiler,
  `MESA_SDK_version` and build date, e.g. `"r26.4.1" "gfortran" "15.2.0" "x86_64-linux-26.6.1"`.
- **Run logs:** `rn.out` / terminal output prints ` version_number r26.4.1` near the top.
- **The install itself:** `$MESA_DIR/data/version_number` in whatever `MESA_DIR` the project's `rn`/`mk`/submit
  scripts or shell profile set. Old numbering is plain integers (e.g. `15140`); since 2022 it is `rYY.MM.P`.
- **Code style hints** (only if nothing else is available): `use crlibm_lib`, `s% lnP`, `extra_controls_inlist1_name`
  and per-type overshoot controls (`overshoot_f_above_burn_h_core`) mean pre-r22; array overshoot controls
  (`overshoot_f(1)`) mean ≥ r23.05.1.

Installed on this machine (`/mnt/home/mcantiello/`): MESA r7624, r11701, r15140 (`mesa15140`), r22.05.1,
r22.11.1, r24.08.1, **r26.04.1** (`mesa-26.04.1`, the current one); SDK 26.6.1 (`mesasdk-26.6.1`) and older SDK
tarballs. If the old version is installed, it can be diffed directly (§3.2). Otherwise download its zip from
Zenodo just for the diff, without building it.

## 2. Install the new release (skip if it is already there)
1. **Latest release:** the MESA Zenodo concept DOI https://doi.org/10.5281/zenodo.2602941 always resolves to the
   newest version (from `docs/source/installation.rst`). Each release needs a minimum **MESA SDK** version,
   given on the installation page and in the release notes. SDKs are on Rich Townsend's site; the URL pattern
   used here was `http://user.astro.wisc.edu/~townsend/resource/download/mesasdk/mesasdk-x86_64-linux-<VERSION>.tar.gz`.
2. Unpack both next to the old installs (the r26 zip is 2.2 GB; `unzip`, or `module load p7zip`).
3. Build:
   ```bash
   export MESASDK_ROOT=/path/to/mesasdk-<ver>; source "$MESASDK_ROOT/bin/mesasdk_init.sh"
   export MESA_DIR=/path/to/mesa-<ver>
   cd $MESA_DIR && ./install
   ```
   Success: the end of `$MESA_DIR/build.log` says "MESA installation was successful". Warnings about executable
   stacks and array bounds are normal.
4. Keep the SDK apart from Lmod compiler/MPI modules and conda in the same shell (ABI clashes). Every run and
   submit script should export `MESASDK_ROOT`, source the SDK init, and set `MESA_DIR` and `OMP_NUM_THREADS`;
   don't rely on login shells on compute nodes.

## 3. Find all the differences (the core of the job)
Use all three sources. Each catches things the others miss.

### 3.1 Read the changelog for every release in between
`$MESA_DIR/docs/source/changelog.rst` (new install; also on docs.mesastar.org) has one section per release with
**"Backwards-incompatible changes"**, "New Features" and "Bug Fixes". Read the backwards-incompatible part of
*every* release after the old version up to the new one. In r26.04.1 the file covers r22.05.1 onward (r26.4.1,
r25.12.1, r24.08.1, r24.03.1, r23.05.1, r22.11.1, r22.05.1). For older starting points, the per-release
announcements with their upgrade notes are in `docs/source/news/` (one file per release, e.g.
`2020-12-07-r15140.rst`, `2020-03-05-r12778.rst`); read those after the old version too. Also read `known_bugs.rst`.
Note every renamed or removed control, every changed default, and every change to `run_star_extras` interfaces.

### 3.2 Diff the two installs mechanically
The defaults files are the authoritative list of every control and its default:
`star/defaults/{controls,star_job,pgstar}.defaults`, `eos/defaults/eos.defaults`, `kap/defaults/kap.defaults`
(the eos/kap namelists were split out of controls at some point, so a control can move between files), plus
`star/defaults/{history,profile}_columns.list`.
- `mesa_defaults_diff.sh OLD_MESA_DIR NEW_MESA_DIR` (§7) lists controls removed, the count added, **defaults
  whose value changed**, and removed history/profile column names. r15140 → r26.04.1: hundreds of removed
  controls, 46 changed defaults, including `MLT_option 'Cox' → 'TDC'`.
- `mesa_check_inlists.sh NEW_MESA_DIR <project inlists>` (§7) lists every control the project sets that the
  new version does not know. On the old rednoise inlists it found exactly what we had fixed by hand
  (per-type overshoot, removed mesh controls, old inlist-chaining syntax); on the ported inlists it prints
  nothing.
- **Changed defaults matter as much as removed names.** A control the project never set can change the physics
  silently. Go through the "default changed" list and decide, for each relevant one, whether to pin the old
  value in the inlist or accept the new one (and say so in the paper).
- **run_star_extras interfaces:** diff `star/work/src/run_star_extras.f90`, `star/other/*.f90` (hook
  interfaces), `star_data/public/*.inc` (the `star_info` fields `s% ...`), and for EOS/kap calls
  `eos/public/eos_lib.f90`, `kap/public/kap_lib.f90`. Example:
  `diff <(grep -ho "real(dp), pointer :: [A-Za-z_0-9]*" OLD/star_data/public/*.inc | sort -u) <(... NEW ...)`
  shows renamed or removed arrays.
- Compare with the new `star/test_suite/` cases closest to the project; they show current idiomatic inlists.

### 3.3 Let the compiler and MESA report the rest
- `./mk` in the ported work directory: every removed module, field or changed subroutine signature is a
  compile error. The default work makefile compiles with bounds checking; keep it for testing.
- A short run: MESA stops at startup on any unknown inlist control and on any unknown history/profile column
  name. Fix one, rerun, repeat.
- Then grep the **source** of the new version for anything your run_star_extras reads, to check its meaning
  has not changed (§6.3 has two cases where the name stayed but the content changed).

## 4. Port the project
1. Copy the new `$MESA_DIR/star/work` to a new directory (e.g. `template_<version>`). Carry over the project's
   `src/run_star_extras.f90` edits, `inlist*` files and column lists. Do **not** compile the old work directory
   against the new MESA, and do not modify the old template (running jobs and photo restarts depend on it).
2. Fix everything found in §3 and compile until clean.
3. Make implicit choices explicit in the inlists: composition/mixture and opacity tables, convection option
   (`MLT_option`), atmosphere, network, and the profile and photo controls (§6.3).
4. **Photos are not portable across MESA versions:** runs restart from scratch after an upgrade.

## 5. Validate before running at scale
1. **Smoke test** (tens of models) of one model per configuration (each Z, each rotation setup, each opacity
   choice) on local disk. Check that all extra history columns are written and that the kap tables load. The
   first run of each new table setup writes EOS/kap caches in `$MESA_DIR/data/*/cache`; do these one at a time
   so simultaneous grid jobs don't race to create them. `MESA_CACHES_DIR` can relocate them
   (`docs/source/reference/env_vars.rst`).
2. **Reproduce the old version** on one reference model at a matched evolutionary state (e.g. the same central
   X), for the quantities the science uses. Change one thing at a time (code, then mixture, then other physics)
   so each difference can be attributed. In rednoise the new code with the old physics choices reproduced the
   old results to ≤ 3%; everything larger came from deliberate physics changes.
3. Run at least one model through the **pre-MS** and the **end of the MS**; that's where new-version crashes
   appeared.
4. Keep a dated log of every change, test and decision in the project (rednoise: `models/GRID_LOG.md`), because
   setup scripts go stale.

## 6. Worked example: what the procedure found for r15140 → r26.04.1
### 6.1 Inlists
- Inlist chaining: `read_extra_controls_inlist1 = .true.` / `extra_controls_inlist1_name` became arrays,
  `read_extra_controls_inlist(1)` / `extra_controls_inlist_name(1)` (same for star_job, eos, kap, pgstar).
- Separate `&eos` and `&kap` namelists; `Zbase`, `use_Type2_opacities` and `kap_*_prefix` go in `&kap`.
- Overshooting is array-based (since r23.05.1): `overshoot_scheme(1) = 'exponential'`,
  `overshoot_zone_type(1) = 'any'`, `overshoot_zone_loc(1) = 'core'`, `overshoot_bdy_loc(1) = 'top'`,
  `overshoot_f(1)`, `overshoot_f0(1)`; the per-type controls are gone.
- Removed mesh controls `xtra_coef_czb_*`, `xtra_coef_*_nb_czb`, `xtra_dist_*`. Targeted resolution now uses
  `use_other_mesh_functions` with the `other_mesh_fcn_data` hook (`star/other/other_mesh_functions.f90`).
- Fortran namelists do not accept `;` as a separator: one statement per line.
- History columns removed: `c_core_mass`, `o_core_mass`, `si_core_mass`, `num_backups`, `tau100_lgT`
  (`tri_alfa` also left the default list); profile: `super_ad`.

### 6.2 run_star_extras
- `use crlibm_lib` → `use math_lib`; `s% lnP`/`s% P` → `s% lnPeos`/`s% Peos`.
- `eosDT_get` lost the `Z, X, abar, zbar` arguments and the `d_dabar/d_dzbar` outputs, and gained
  `d_dxa(num_eos_basic_results, species)` (allocate it). Current call:
  `eosDT_get(eos_handle, species, chem_id, net_iso, xa(:,k), Rho, arg_not_provided, T, arg_not_provided,
  res, d_dlnRho, d_dlnT, d_dxa, ierr)`.
- Useful r26 facilities: `s% need_to_save_profiles_now` plus `s% save_profiles_model_priority` (triggered
  profiles that survive the cap), `s% xtra(:)`/`s% ixtra(:)` (saved in photos, so restart-safe), and
  `s% x_ctrl(:)`, `x_integer_ctrl`, `x_logical_ctrl` for inlist knobs.
- Guard the centre cell when reading `r(k+1)` etc.: a zone finder crashed on fully convective pre-MS models
  (`Index nz+1 of s%r above upper bound`).

### 6.3 Same name, different content (found only by reading the new source, §3.3)
- `MLT_option` default is now `'TDC'` (time-dependent convection), and **`s% conv_vel` = 3·D_mix/(α H_P)**, where
  D_mix includes rotational mixing (`star/private/mix_info.f90`). In rotating models every conv_vel-based
  velocity, Mach number or turnover time was inflated (×2.6 in v at 20 Msun, Ω/Ω_crit = 0.2). Use **`s% mlt_vc`**
  (and the `mlt_vc` profile column).
- **`s% mixing_type` becomes `rotation_mixing` wherever D_rot > D_conv**, so zone finders based on it shred weak
  convective zones in rotating models. Use **`s% mlt_mixing_type`**, and don't write into MESA's own
  `s% mixing_region_*` arrays.
- Composition and opacity default to GS98 (`initial_zfracs = 3`, `kap_file_prefix = 'gs98'`) unless set. With a
  small network the metal mixture that sets the opacity enters only through the kap tables. rednoise now sets
  Asplund09 explicitly: `initial_zfracs = 6`; `kap_file_prefix = 'a09'`, `kap_CO_prefix = 'a09_co'`,
  `kap_lowT_prefix = 'lowT_fa05_a09p'`. OP and OPLIB tables also ship. Switching the mixture at fixed Z changed
  the Fe-bump convective flux ×2.5; treat it as a first-order choice.
- `max_num_profile_models = 100` discards old profiles; `photo_digits = 3` makes photo names wrap every 1000
  models, so resume from the newest photo **by modification time** (`ls -1t photos | head -1`).
- Grid-specific settings rednoise needed: `min_timestep_limit` 0.1 s → 1d-8; hard lgTeff/lgL limits left at the
  default −1. For rotation near critical: `max_mdot_redo_cnt = 200`, `mdot_revise_factor = 1.2`,
  `implicit_mdot_boost = 0.05`, `surf_omega_div_omega_crit_limit = 0.98` (0.90 keeps inside
  `w_div_wcrit_max = 0.89`), `surf_omega_div_omega_crit_tol = 0.02`.
- The bundled GYRE is 8.1 *libraries only* (`$MESA_DIR/gyre`); a standalone GYRE (9.1.1 here, in
  `~/software/gyre-9.1.1`) must be built separately.

### 6.4 Operational (Flatiron)
- One template directory per MESA/code version; never rebuild a binary that running jobs or photo restarts use.
- Submit from a shared filesystem or set `#SBATCH --chdir=<model dir>`: jobs submitted from local workstation disk
  (`/home/...`) failed within 2 s on compute nodes.
- LOGS/photos on Ceph, code and inlists on `/mnt/home`; disBatch for many models, with a `timeout` per task.
- For Claude: only `squeue`, `sinfo`, `sacct`, `seff`, `scontrol show` and `sacctmgr show/list` may be run; the
  user runs `sbatch`/`scancel` (give them the exact line). Never poll Slurm in a loop. Local MESA test runs on
  the workstation are fine.

## 7. Helper scripts (verbatim; also in rednoise `handoff/mesa_upgrade_tools/`)
```bash
#!/bin/bash
# mesa_defaults_diff.sh OLD_MESA_DIR NEW_MESA_DIR
# Lists controls removed / added / with changed default values between two MESA installs.
old=$1; new=$2
files="star/defaults/controls.defaults star/defaults/star_job.defaults star/defaults/pgstar.defaults eos/defaults/eos.defaults kap/defaults/kap.defaults"
extract() { # name|value, comments stripped, one per control (array index kept)
  [ -f "$1" ] && sed 's/!.*//' "$1" | grep -E '^ *[A-Za-z_][A-Za-z0-9_]*(\([^)]*\))? *=' | sed -E 's/^ *//; s/ *= */|/; s/ *$//' | sort -u -t'|' -k1,1
}
for f in $files; do
  o=$(mktemp); n=$(mktemp)
  extract "$old/$f" > $o; extract "$new/$f" > $n
  # namelists moved between files (e.g. kap/eos split out of controls) show up as removed here and added there
  echo "=== $f"
  echo "--- removed (in old, not in new):"; join -t'|' -v1 $o $n | cut -d'|' -f1 | tr '\n' ' '; echo
  echo "--- added:";   join -t'|' -v2 $o $n | cut -d'|' -f1 | wc -l | xargs echo "  count:"
  echo "--- default changed (name | old | new):"; join -t'|' $o $n | awk -F'|' '$2!=$3'
  rm -f $o $n
done
for f in star/defaults/history_columns.list star/defaults/profile_columns.list; do
  echo "=== $f: column names removed"
  diff <(sed 's/!.*//' $old/$f | awk '{print $1}' | grep -v '^$' | sort -u) <(sed 's/!.*//' $new/$f | awk '{print $1}' | grep -v '^$' | sort -u) | grep '^<' | tr '\n' ' '; echo
done
```

```bash
#!/bin/bash
# mesa_check_inlists.sh NEW_MESA_DIR inlist [inlist ...]
# Controls set in the given inlists that do not exist in the new version's defaults files.
new=$1; shift
known=$(cat $new/star/defaults/{controls,star_job,pgstar}.defaults $new/eos/defaults/eos.defaults \
            $new/kap/defaults/kap.defaults $new/star/defaults/*_dev.defaults 2>/dev/null \
        | sed 's/!.*//' | grep -oE '^ *[A-Za-z_][A-Za-z0-9_]*' | tr -d ' ' | sort -u)
for f in "$@"; do
  sed 's/!.*//' "$f" | grep -oE '^ *[A-Za-z_][A-Za-z0-9_]*(\([^)]*\))? *=' | sed -E 's/\(.*//; s/[ =]//g' | sort -u \
  | comm -23 - <(echo "$known") | sed "s#^#$f: unknown in new MESA: #"
done
```
Limitations: the column-list diff compares the *default* lists, so a project list can still use a name the
new version rejects (MESA reports it at startup). Controls documented only in comments, or set through
run_star_extras, are not covered. The changelog (§3.1) is still required.
