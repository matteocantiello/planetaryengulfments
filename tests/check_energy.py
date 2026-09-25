#!/usr/bin/env python3
"""Energy ledger of an engulfment run (template_r26.04.1 history columns).

usage: check_energy.py RUN_DIR [RUN_DIR ...]

Checks, for each run:
  T1a  heat set by the code == heat integrated by MESA (sum extra_heat*dm*dt), step by step and cumulatively
  T1b  energy released by the orbit == energy deposited + energy booked but not deposited (tides)
  T1c  orbit ledger: E_orb(t) == E_orb(0) - E_drag - E_tide + W_pot (W_pot: potential changes under the orbit)
  T2   MESA energy conservation, cumulative signed error relative to the energy injected
"""
import sys
import numpy as np


def read_history(run):
    return np.genfromtxt(f"{run}/LOGS/history.data", skip_header=5, names=True)


def check(run):
    h = read_history(run)
    n = len(h)
    E_drag, E_tide, E_tdep = h["engulf_E_drag_cum"], h["engulf_E_tide_cum"], h["engulf_E_tide_dep_cum"]
    E_code, E_mesa = h["engulf_E_heat_code_cum"], h["engulf_E_heat_mesa_cum"]
    E_dep = E_drag + E_tdep
    last = -1
    print(f"== {run}: {n} models, a {h['engulf_a'][0]:.5f} -> {h['engulf_a'][last]:.5f} Rsun, "
          f"active at end: {bool(h['engulf_active'][last])}")
    print(f"   E_drag {E_drag[last]:.4e}  E_tide {E_tide[last]:.4e} (deposited {E_tdep[last]:.4e})  erg")

    # T1a: per step and cumulative
    d_code, d_mesa = np.diff(E_code), np.diff(E_mesa)
    m = d_code > 0
    step_rel = np.abs(d_code[m] - d_mesa[m]) / d_code[m] if m.any() else np.array([0.0])
    cum_rel = abs(E_code[last] - E_mesa[last]) / E_code[last] if E_code[last] > 0 else 0.0
    ok1a = step_rel.max() < 1e-10 and cum_rel < 1e-10
    print(f"T1a code heat vs MESA heat: max per-step rel diff {step_rel.max():.2e}, cumulative {cum_rel:.2e}"
          f"  [{'PASS' if ok1a else 'FAIL'}]")

    # T1b: deposited = drag + deposited tides (code heat), everything released is booked
    rel1b = abs(E_code[last] - E_dep[last]) / max(E_dep[last], 1e-300)
    ok1b = rel1b < 1e-10
    print(f"T1b heat set == E_drag + E_tide_dep: rel diff {rel1b:.2e}  [{'PASS' if ok1b else 'FAIL'}]; "
          f"not deposited: {E_tide[last] - E_tdep[last]:.3e} erg")

    # T1c: orbit ledger; residual only from potential changes between steps (e.g. remeshing)
    resid = h["engulf_orbit_ledger_resid"]
    released = E_drag[last] + E_tide[last]
    rel1c = np.abs(resid).max() / max(released, 1e-300)
    print(f"T1c orbit ledger: max |resid| / released {rel1c:.2e}; W_pot / released "
          f"{h['engulf_W_pot_cum'][last] / max(released, 1e-300):.3e}  [{'PASS' if rel1c < 1e-6 else 'CHECK'}]")

    # T2: MESA's cumulative signed energy error vs injected energy
    err = h["engulf_E_err_mesa_cum"]
    rel2 = abs(err[last]) / max(E_dep[last], 1e-300)
    abs2 = np.abs(np.diff(err)).sum() / max(E_dep[last], 1e-300)
    print(f"T2  MESA energy error: signed cum / E_dep {rel2:.2e}, sum|step err| / E_dep {abs2:.2e}  "
          f"[{'PASS' if rel2 < 1e-2 else 'FAIL'} at 1%]")

    # integration accuracy of the orbit sub-steps
    pr = h["engulf_power_ratio"][h["engulf_E_drag_cum"] + h["engulf_E_tide_cum"] > 0]
    if len(pr):
        print(f"    int P dt / Delta E_orb per step: min {pr.min():.6f} max {pr.max():.6f}")
    print(f"    first steps dt (yr): {', '.join(f'{x:.3e}' for x in np.diff(h['star_age'][:4]))}")


if __name__ == "__main__":
    for run in sys.argv[1:]:
        check(run)
