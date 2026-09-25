# Tests

Run directories live outside the repo (local scratch or Ceph); these scripts read their `LOGS/`.

| Script | What it checks |
|---|---|
| `check_energy.py RUN...` | Energy ledger: heat the code sets = heat MESA integrates (T1a); everything released by the orbit is deposited or booked (T1b); orbit ledger (T1c); MESA's cumulative energy error relative to the injected energy (T2). |
| `check_orbit_physics.py RUN...` | Independent Python recomputation, from each profile, of m(a), v, E_orb (quadrature of the potential), mean density, Mach, C_d, C_g and L_drag, compared with the `engulf_*` history columns. Needs profile columns `dm`, `pressure_scale_height`. |

The restart test (T6) is manual: copy a run, `./re x000NN`, and compare the history rows after NN. It was
bit-identical on 2026-09-25 (LOG.md).
