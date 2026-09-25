#!/usr/bin/env python3
"""Independent re-computation of the companion's orbit diagnostics from a MESA profile.

usage: check_orbit_physics.py RUN_DIR [RUN_DIR ...]

For every profile in RUN_DIR/LOGS, recompute from the profile alone (default controls of
template_r26.04.1/inlist_project: drag law 1, Mach-dependent C_d, Ostriker C_g) the enclosed mass, Keplerian
velocity, orbital energy in the star's potential (by numerical quadrature, not the Fortran cell formula),
the mean density around the companion, Mach number, drag coefficients and drag luminosity.
Compare them with the engulf_* history columns of the same model.
Needs profile columns: mass, radius, dm, logRho, csound, pressure_scale_height.
"""
import sys
import numpy as np
from scipy.integrate import quad

G = 6.67430e-8
MSUN = 1.3271244e26 / G
RSUN = 6.957e10
LSUN = 3.828e33


def read(path, skip=5):
    return np.genfromtxt(path, skip_header=skip, names=True)


def controls(run):
    """x_ctrl(1), x_ctrl(2) from the run's inlist_project."""
    vals = {}
    for line in open(f"{run}/inlist_project"):
        line = line.split("!")[0].strip()
        for key in ("x_ctrl(1)", "x_ctrl(2)"):
            if line.replace(" ", "").startswith(key + "="):
                vals[key] = float(line.split("=")[1].replace("d", "e"))
    return vals["x_ctrl(1)"] * MSUN, vals["x_ctrl(2)"] * RSUN


class Star:
    def __init__(self, p):
        self.r_out = p["radius"] * RSUN                  # outer face of each cell, surface first
        self.dm = p["dm"]
        self.m_out = np.cumsum(self.dm[::-1])[::-1]       # mass inside outer face (M_center = 0)
        self.r_in = np.r_[self.r_out[1:], 0.0]
        self.m_in = self.m_out - self.dm
        self.rho = 10 ** p["logRho"]
        self.cs = p["csound"]
        self.Hp = p["pressure_scale_height"] * RSUN
        self.R = self.r_out[0]
        self.M = self.m_out[0]

    def cell(self, x):
        return int(np.searchsorted(-self.r_in, -x, side="right"))   # first k with r_in[k] <= x

    def m(self, x):
        if x >= self.R:
            return self.M
        k = self.cell(x)
        C = self.dm[k] / (self.r_out[k] ** 3 - self.r_in[k] ** 3)
        return self.m_in[k] + C * (x ** 3 - self.r_in[k] ** 3)

    def e_orb(self, x):
        """Specific orbital energy with Phi from quadrature of g = G m(r)/r^2."""
        if x >= self.R:
            return -0.5 * G * self.M / x
        edges = self.r_out[: self.cell(x) + 1][::-1]
        pts = np.r_[x, edges[edges > x]]
        integral = sum(quad(lambda r: G * self.m(r) / r ** 2, lo, hi, epsrel=1e-12)[0]
                       for lo, hi in zip(pts[:-1], pts[1:]))
        phi = -G * self.M / self.R - integral
        return 0.5 * G * self.m(x) / x + phi

    def mean_rho(self, x, w):
        lo, hi = x - w, x + w
        a, b = np.maximum(self.r_in, lo), np.minimum(self.r_out, hi)
        frac = np.where(b > a, (b ** 3 - a ** 3) / (self.r_out ** 3 - self.r_in ** 3), 0.0)
        wts = frac * self.dm
        return (wts * self.rho).sum() / wts.sum() if wts.sum() > 0 else 0.0


def f_intercept(x, Rx, R):
    depth = Rx + R - x
    if Rx <= 0 or depth <= 0:
        return 0.0
    if depth >= 2 * Rx:
        return 1.0
    y = abs(Rx - depth)
    al = np.arccos(min(1.0, y / Rx))
    f = (al - (y / Rx) * np.sin(al)) / np.pi
    return 1 - f if depth > Rx else f


def C_grav(mach, lnL):
    sub = lambda m: 0.5 * np.log((1 + m) / (1 - m)) - m
    sup = lambda m: lnL + 0.5 * np.log(1 - 1 / m ** 2)
    if mach <= 0.9:
        c = sub(mach)
    elif mach >= 1.1:
        c = sup(mach)
    else:
        w = (mach - 0.9) / 0.2
        c = (1 - w) * sub(0.9) + w * sup(1.1)
    return max(0.0, c)


def check(run):
    M2, R2 = controls(run)
    h = read(f"{run}/LOGS/history.data")
    idx = np.atleast_2d(np.loadtxt(f"{run}/LOGS/profiles.index", skiprows=1))
    worst = {}
    print(f"== {run}")
    for model, _, num in idx.astype(int):
        p = read(f"{run}/LOGS/profile{num}.data")
        row = h[h["model_number"] == model][-1]
        st = Star(p)
        a = row["engulf_a"] * RSUN
        m = st.m(a)
        v = np.sqrt(G * m / a)
        k = min(st.cell(a), len(st.dm) - 1) if a < st.R else 0
        cs, Hp = st.cs[k], st.Hp[k]
        mach = v / cs
        Racc = 2 * G * M2 / (v ** 2 + cs ** 2)
        Rinf = max(R2, Racc)
        fp, fa = f_intercept(a, R2, st.R), f_intercept(a, Racc, st.R)
        rho = st.mean_rho(a, Rinf) if (fp > 0 or fa > 0) else 0.0
        Cd = 0.375 + 0.125 * np.tanh(1.75 * (mach - 1))
        Cg = C_grav(mach, np.log(max(Hp, Rinf) / Rinf))
        F = rho * v ** 2 * max(Cd * np.pi * R2 ** 2 * fp, Cg * np.pi * Racc ** 2 * fa)
        mine = dict(m_enc=m / MSUN, v_orb=v / 1e5, mach=mach, R_acc=Racc / RSUN, f_eng_p=fp,
                    rho=rho, C_d=Cd, C_g=Cg, L_drag=F * v / LSUN, E_orb=M2 * st.e_orb(a))
        line = [f"model {model:6d} a={a / RSUN:.5f}"]
        for key, val in mine.items():
            ref = row["engulf_" + key]
            rel = abs(val - ref) / max(abs(ref), 1e-300) if (val or ref) else 0.0
            worst[key] = max(worst.get(key, 0.0), rel)
            if rel > 1e-8:
                line.append(f"{key}: py {val:.10e} f90 {ref:.10e} rel {rel:.1e}")
        print("  " + ("; ".join(line) if len(line) > 1 else line[0] + "  all agree to 1e-8"))
    print("  worst relative differences: " + ", ".join(f"{k} {v:.1e}" for k, v in worst.items()))
    return max(worst.values())


if __name__ == "__main__":
    worst = max(check(run) for run in sys.argv[1:])
    print("PASS" if worst < 1e-8 else "CHECK")
