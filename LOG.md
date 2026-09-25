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
