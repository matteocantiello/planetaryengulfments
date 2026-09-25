#!/usr/bin/env python3
"""Status figures for the engulfment project (2026-09-25). Writes docs/figures/fig*.png.

Reads run output from runs/2026-09-25/ (symlink to Ceph) and the old r15140 10 Rsun run from git history.
Usage: python3 analysis/make_status_figures.py
"""
import io
import os
import subprocess
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUNS = os.path.join(ROOT, "runs", "2026-09-25")
OUT = os.path.join(ROOT, "docs", "figures")
os.makedirs(OUT, exist_ok=True)

G = 6.67430e-8
MSUN = 1.3271244e26 / G
RSUN = 6.957e10
YR = 3.15576e7

# reference palette (dataviz skill), first three categorical slots, validated all-pairs (light)
C1, C2, C3 = "#2a78d6", "#eb6834", "#1baf7a"
SURF, INK, INK2, GRID = "#fcfcfb", "#0b0b0b", "#52514e", "#e4e3df"
plt.rcParams.update({
    "figure.facecolor": SURF, "axes.facecolor": SURF, "savefig.facecolor": SURF,
    "axes.edgecolor": INK2, "axes.labelcolor": INK, "xtick.color": INK2, "ytick.color": INK2,
    "text.color": INK, "axes.grid": True, "grid.color": GRID, "grid.linewidth": 0.6,
    "axes.spines.top": False, "axes.spines.right": False, "font.size": 10,
    "axes.titlesize": 11, "axes.titleweight": "bold", "legend.frameon": False,
    "lines.linewidth": 1.6, "lines.markersize": 6,
})


def hist(run):
    return np.genfromtxt(os.path.join(RUNS, run, "LOGS", "history.data"), skip_header=5, names=True)


def old_r15140_history():
    txt = subprocess.run(["git", "-C", ROOT, "show",
                          "2dda85a:Dropbox (Personal)/work/engulfment/15140/template/LOGS/history.data"],
                         capture_output=True, text=True, check=True).stdout
    return np.genfromtxt(io.StringIO(txt), skip_header=5, names=True)


def save(fig, name):
    path = os.path.join(OUT, name)
    fig.savefig(path, dpi=160, bbox_inches="tight")
    plt.close(fig)
    print("wrote", path)


# ---------------------------------------------------------------- Fig 1: energy conservation
def fig_energy():
    runs = [("fix_1M4R", "4 R$_\\odot$ + 1 M$_J$, grazing"), ("rg10_draftlaw", "10 R$_\\odot$ + 1 M$_J$, draft drag"),
            ("rg10_B", "10 R$_\\odot$ + 1 M$_J$, option B"), ("agb200_10MJ_B", "AGB200 + 10 M$_J$, option B"),
            ("yang_B_dyn", "100 R$_\\odot$ + 5 M$_J$, option B"), ("yang_Amech", "100 R$_\\odot$ + 5 M$_J$, option A")]
    m1, m2, m3 = [], [], []
    for run, _ in runs:
        h = hist(run)
        dc, dm = np.diff(h["engulf_E_heat_code_cum"]), np.diff(h["engulf_E_heat_mesa_cum"])
        ok = dc > 0
        m1.append(max(np.max(np.abs(dc[ok] - dm[ok]) / dc[ok]), 1e-17))
        edep = h["engulf_E_drag_cum"][-1] + h["engulf_E_tide_dep_cum"][-1]
        m2.append(abs(h["engulf_E_err_mesa_cum"][-1]) / edep)
        act = h["engulf_active"] == 1
        rel = h["engulf_E_drag_cum"][-1] + h["engulf_E_tide_cum"][-1]
        m3.append(max(np.max(np.abs(h["engulf_orbit_ledger_resid"][act])) / rel, 1e-17))
    y = np.arange(len(runs))
    fig, ax = plt.subplots(figsize=(7.2, 3.6))
    ax.scatter(m1, y + 0.18, color=C1, marker="o", s=42, label="heat set by code vs heat integrated by MESA (max per step)", zorder=3)
    ax.scatter(m3, y, color=C3, marker="D", s=36, label="orbit ledger $E_{orb}(t)$ vs $E_{orb}(0)-E_{released}+W_{pot}$", zorder=3)
    ax.scatter(m2, y - 0.18, color=C2, marker="s", s=40, label="MESA cumulative energy error / energy injected", zorder=3)
    ax.axvline(1e-2, color=INK2, lw=0.8, ls="--")
    ax.text(1.3e-2, -0.45, "1% target\n(Fragos+19)", color=INK2, fontsize=8, va="top")
    ax.set_xscale("log")
    ax.set_xlim(1e-17, 1)
    ax.set_yticks(y)
    ax.set_yticklabels([lab for _, lab in runs])
    ax.invert_yaxis()
    ax.set_xlabel("relative error")
    ax.set_title("Energy conservation of the rewritten code (template_r26.04.1)", loc="left")
    ax.text(0, -0.52, "AGB200 and 100 R$_\\odot$ option-A runs still in progress at the time of plotting",
            transform=ax.transAxes, fontsize=7.5, color=INK2)
    ax.legend(loc="upper center", bbox_to_anchor=(0.45, -0.18), fontsize=8, ncol=1)
    save(fig, "fig1_energy_conservation.png")


# ---------------------------------------------------------------- Fig 2: bugs found in the r22 code
def fig_bugs():
    fig, axes = plt.subplots(1, 2, figsize=(8.6, 3.3))
    # (a) first step: star aged 1.2 Myr before the orbit starts (old code), new code limits dt
    ax = axes[0]
    for run, lab, col, mk in (("smoke_1M4R", "ported r22 code", C2, "s"), ("fix_1M4R", "rewritten code", C1, "o")):
        h = hist(run)
        n = min(60, len(h))
        ax.plot(np.r_[0, h["model_number"][:n]], np.r_[4.0101, h["radius"][:n]], color=col, marker=mk, ms=3,
                lw=1.2, label=lab)
    ax.axhline(4.0101, color=INK2, lw=0.8, ls=":")
    ax.text(62, 4.013, "loaded model, 4.010 R$_\\odot$", color=INK2, fontsize=8, ha="right", va="bottom")
    ax.set_xlabel("model number")
    ax.set_ylabel("stellar radius [R$_\\odot$]")
    ax.set_title("(a) First step: star aged 1.2 Myr\n     before the orbit starts", loc="left", fontsize=9.5)
    ax.legend(fontsize=8, loc="center right")
    # (b) missing 2 pi G rho a term: old decay rate too fast by 1 + 3 rho/rho_bar(<a)
    ax = axes[1]
    p = np.genfromtxt(os.path.join(RUNS, "rg10_B", "LOGS", "profile1.data"), skip_header=5, names=True)
    r, m, rho = p["radius"] * RSUN, p["mass"] * MSUN, 10 ** p["logRho"]
    rhobar = m / (4 / 3 * np.pi * r ** 3)
    ax.plot(p["radius"], 1 + 3 * rho / rhobar, color=C1)
    ax.set_xscale("log")
    ax.set_ylim(0.9, 2.1)
    ax.set_xlabel("separation $a$ [R$_\\odot$]  (1 M$_\\odot$, 10 R$_\\odot$ giant)")
    ax.set_ylabel("$(dE/da)_{true}\\,/\\,(dE/da)_{point\\ mass}$")
    ax.set_title("(b) Old decay rate too fast by $1+3\\rho/\\bar\\rho(<a)$\n     (missing $2\\pi G\\rho a$ in $dE_{orb}/da$)", loc="left", fontsize=9.5)
    ax.set_xlim(0.05, 11)
    fig.tight_layout()
    save(fig, "fig2_bugs_in_r22_code.png")


# ---------------------------------------------------------------- Fig 3: 10 Rsun, old vs new
def fig_rg10():
    old = old_r15140_history()
    new = hist("rg10_draftlaw")
    b = hist("rg10_B")
    fig, axes = plt.subplots(1, 3, figsize=(10, 3.2))

    def t_rel(h, acol):
        t = (h["star_age"] - h["star_age"][0])
        a = h[acol]
        i0 = np.argmax(a < 9.0)
        return (t - t[i0]) * 365.25, a

    sets = ((old, "Orbital_separation", "r15140 code (2022)", C2, "--"),
            (new, "engulf_a", "rewritten, draft drag law", C1, "-"),
            (b, "engulf_a", "rewritten, O'Connor drag + option B", C3, "-"))
    for h, acol, lab, col, ls in sets:
        t, a = t_rel(h, acol)
        R = h["radius"] if "radius" in h.dtype.names else 10 ** h["log_R"]
        L = 10 ** h["log_L"]
        sel = (t > -20) & (t < 60)
        axes[0].plot(t[sel], a[sel], color=col, ls=ls, label=lab)
        axes[1].plot(t[sel], L[sel], color=col, ls=ls)
        axes[2].plot(t[sel], R[sel], color=col, ls=ls)
    # disruption points
    axes[0].plot([], [])
    ia = np.where(new["engulf_active"] == 1)[0][-1]
    axes[0].annotate("Roche-lobe overflow\n(new code) at 1.34 R$_\\odot$", xy=(t_rel(new, "engulf_a")[0][ia], 1.34),
                     xytext=(12, 4.5), fontsize=8, color=INK2, arrowprops=dict(arrowstyle="-", color=INK2, lw=0.7))
    axes[0].annotate("ram pressure only\n(old code) at 0.65 R$_\\odot$", xy=(t_rel(old, "Orbital_separation")[0][771 - 1], 0.65),
                     xytext=(25, 1.9), fontsize=8, color=INK2, arrowprops=dict(arrowstyle="-", color=INK2, lw=0.7))
    axes[0].set_ylabel("separation $a$ [R$_\\odot$]")
    axes[1].set_ylabel("$L$ [L$_\\odot$]")
    axes[1].set_yscale("log")
    axes[2].set_ylabel("$R$ [R$_\\odot$]")
    for ax in axes:
        ax.set_xlabel("days since $a$ = 9 R$_\\odot$")
    axes[0].set_title("1 M$_\\odot$, 10 R$_\\odot$ giant + 1 M$_J$: plunge", loc="left")
    fig.legend(*axes[0].get_legend_handles_labels(), loc="upper center", bbox_to_anchor=(0.5, -0.02), ncol=3, fontsize=8)
    fig.tight_layout()
    save(fig, "fig3_10Rsun_old_vs_new.png")


# ---------------------------------------------------------------- Fig 4: 1D outflow vs Yang+26 3D
def fig_yang():
    td = np.sqrt((100 * RSUN) ** 3 / (G * MSUN)) / YR
    fig, axes = plt.subplots(1, 2, figsize=(9, 3.4))
    for run, lab, col, mk in (("yang_B_dyn", "option B (1D hydro, remove B>0 gas)", C1, "o"),
                              ("yang_Amech", "option A, $\\epsilon$ = 0.2 (provisional; in progress)", C2, "s")):
        h = hist(run)
        t = (h["star_age"] - h["star_age"][0]) / td
        axes[0].plot(t, h["engulf_a"] / 100, color=col, label=lab)
        mo = h["engulf_Mout_1R0"]
        if run == "yang_Amech":
            mo = h["engulf_M_wind_cum"]
            lab = "option A: mass removed"
        else:
            lab = "option B: outward flux through R$_\\star$"
        sel = mo > 0
        axes[1].plot(t[sel], mo[sel], color=col, label=lab)
    # Yang+26 3D results (Fig. 7; e = 0.65): ejected 2-3e-3 at disruption (~170 t_dyn), 4-6e-3 by ~300 t_dyn;
    # unbound (B>0) 1.5-2e-3
    axes[1].fill_between([150, 190], 2e-3, 3e-3, color=C3, alpha=0.35, lw=0)
    axes[1].fill_between([280, 320], 4e-3, 6e-3, color=C3, alpha=0.35, lw=0)
    axes[1].errorbar([170], [1.75e-3], yerr=[[0.25e-3], [0.25e-3]], fmt="D", color=C3, ms=5, capsize=2,
                     label="Yang+26 3D: unbound (B>0)")
    axes[1].plot([], [], color=C3, alpha=0.5, lw=6, label="Yang+26 3D: ejected")
    axes[0].axhline(0.3, color=INK2, lw=0.8, ls=":")
    axes[0].text(5, 0.32, "0.3 R$_\\star$: disruption (as in Yang+26)", color=INK2, fontsize=8)
    axes[0].set_xlabel("time [$t_{dyn}$ = 18.4 d]")
    axes[0].set_ylabel("$a / R_\\star$")
    axes[0].set_title("Orbit: circular 1D vs Yang+26 ($e$ = 0.65)", loc="left", fontsize=10)
    axes[0].legend(fontsize=8, loc="upper right")
    axes[1].set_yscale("log")
    axes[1].set_ylim(1e-7, 1e-2)
    axes[1].set_xlabel("time [$t_{dyn}$]")
    axes[1].set_ylabel("mass [M$_\\odot$]")
    axes[1].set_title("Ejecta: 1D is >10$\\times$ below 3D", loc="left", fontsize=10)
    axes[1].legend(fontsize=7.5, loc="lower right")
    fig.suptitle("1 M$_\\odot$, 100 R$_\\odot$ giant + 5 M$_J$ (Yang+26 setup)", x=0.01, ha="left", fontsize=11,
                 fontweight="bold")
    fig.tight_layout()
    save(fig, "fig4_outflow_vs_Yang26.png")


# ---------------------------------------------------------------- Fig 5: literature ejection vs q
def fig_literature():
    fig, ax = plt.subplots(figsize=(6.8, 4.2))
    ideal = [  # (q, unbound fraction of envelope, label) -- ideal gas, no recombination
        (0.11, 0.02, "P12"), (0.17, 0.06, "P12"), (0.34, 0.08, "P12"), (0.68, 0.10, "P12"), (1.0, 0.10, "P12"),
        (0.25, 0.17, "S20"), (0.5, 0.21, "S20"), (0.75, 0.08, "S20"), (0.1, 0.073, "K20"),
        (0.57, 0.26, "RT12"), (0.5, 0.08, "O16"), (0.5, 0.14, "C19"), (0.13, 0.31, "S98"), (0.12, 0.23, "S98")]
    recomb = [(0.10, 0.778, "K20"), (0.06, 0.521, "K20"), (0.04, 0.218, "K20"), (0.01, 0.166, "K20"),
              (0.25, 0.91, "S20"), (0.5, 0.86, "S20"), (0.75, 0.75, "S20"),
              (0.028, 0.02, "IN16"), (0.056, 0.20, "IN16"), (0.083, 0.29, "IN16"), (0.11, 0.36, "IN16"),
              (0.2, 0.51, "IN16")]
    # planets: unbound mass / envelope mass. Lau+25: 1.6e-5 Msun of ~0.75 Msun; Yang+26: 1.5-2e-3 of ~0.6 Msun
    planets = [(1.0e-3, 1.6e-5 / 0.75, "L25"), (4.8e-3, 1.75e-3 / 0.6, "Y26")]
    for data, col, mk, lab in ((ideal, C1, "o", "3D, ideal gas (no recombination)"),
                               (recomb, C2, "s", "3D, with recombination energy"),
                               (planets, C3, "D", "3D, planetary companions (ideal gas)")):
        q, f, names = zip(*data)
        ax.scatter(q, f, color=col, marker=mk, s=38, label=lab, zorder=3, edgecolors=SURF, linewidths=0.8)
        if data is planets:
            for qi, fi, n in data:
                ax.annotate({"L25": "Lau+25 (SPH, 4 R$_\\odot$ host)", "Y26": "Yang+26 (Athena++, 100 R$_\\odot$ host)"}[n],
                            (qi, fi), xytext=(6, -2), textcoords="offset points", fontsize=7.5, color=INK2)
    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlim(5e-4, 2)
    ax.set_ylim(1e-5, 1.5)
    ax.set_xlabel("mass ratio $q = M_2/M_1$")
    ax.set_ylabel("unbound fraction of the envelope")
    ax.set_title("Mass unbound in multi-D common-envelope / engulfment simulations", loc="left", fontsize=10)
    ax.legend(fontsize=8, loc="lower right")
    ax.text(0, -0.2, "Ideal gas: Passy+12, Sand+20, Kramer+20, Ricker & Taam 12, Ohlmann+16, Chamandy+19, Sandquist+98.\n"
            "With recombination: Kramer+20, Sand+20, Ivanova & Nandez 16 (ejecta by end of plunge).\n"
            "Planets: unbound mass / envelope mass (envelope 0.75 and 0.6 M$_\\odot$). See docs/ejection_calibration_literature.md",
            transform=ax.transAxes, fontsize=7, color=INK2, va="top")
    save(fig, "fig5_literature_unbound_vs_q.png")


# ---------------------------------------------------------------- Fig 6: AGB200 + 10 MJ (dynamical regime)
def fig_agb():
    h = hist("agb200_10MJ_B")
    t = h["star_age"] - h["star_age"][0]
    fig, axes = plt.subplots(1, 3, figsize=(10, 3.0))
    ia = np.where(h["engulf_active"] == 1)[0][-1]
    axes[0].plot(t, h["engulf_a"], color=C1)
    axes[0].set_ylabel("separation [R$_\\odot$]")
    axes[1].plot(t, h["radius"], color=C1)
    axes[1].set_ylabel("$R$ [R$_\\odot$]")
    axes[2].plot(t, 10 ** h["log_L"], color=C1)
    axes[2].set_ylabel("$L$ [L$_\\odot$]")
    axes[2].set_yscale("log")
    for ax in axes:
        ax.axvline(t[ia], color=INK2, lw=0.8, ls=":")
        ax.set_xlabel("years")
        ax.set_xlim(0, min(t[-1], 60))
    axes[0].text(t[ia] + 1, 150, "Roche\ndisruption", color=INK2, fontsize=8)
    axes[0].set_title("AGB200 + 10 M$_J$, option B: supersonic surface, no unbound gas", loc="left", fontsize=10)
    fig.tight_layout()
    save(fig, "fig6_AGB200_10MJ.png")


# ---------------------------------------------------------------- Fig 7: option A v2 (ejection rule) validation
def static_rule(prof, mp_msun):
    """Ivanova & Nandez 2016 Eq. 32 on an unperturbed profile: mass outside the crossing radius."""
    p = np.genfromtxt(prof, skip_header=5, names=True)
    r, m, dm = p["radius"] * RSUN, p["mass"] * MSUN, p["dm"]
    eb = np.cumsum(-p["total_energy"] * dm)           # binding (gravity + internal) of the mass above
    mab = np.cumsum(dm)
    de = np.maximum(G * mp_msun * MSUN * (m / (2 * r) - m[0] / (2 * r[0])), 0)
    ok = de >= eb
    k = 0
    while k + 1 < len(ok) and ok[k + 1]:
        k += 1
    return mab[k] / MSUN


def fig_v2():
    mj = 9.546e-4
    fig, axes = plt.subplots(1, 2, figsize=(9.6, 3.6))
    ax = axes[0]
    mps = np.array([1, 2, 5, 10, 20, 30])
    for prof, col, lab in ((os.path.join(RUNS, "phys_1M4R", "LOGS", "profile1.data"), C1, "4 R$_\\odot$ host"),
                           (os.path.join(RUNS, "rg10_B", "LOGS", "profile1.data"), C2, "10 R$_\\odot$ host")):
        ax.plot(mps, [static_rule(prof, x * mj) for x in mps], color=col, marker="o", ms=4, label=f"rule, {lab}")
    ax.errorbar([1.05], [1.4e-5], yerr=[[0.6e-5], [0.6e-5]], fmt="D", color=C1, ms=7, capsize=2,
                markeredgecolor=SURF, label="Lau+25 SPH, 4 R$_\\odot$ + 1 M$_J$")
    h = hist("v2c_rg10_10MJ")
    ax.plot([10], [h["engulf_M_wind_cum"][-1]], "s", color=C2, ms=8, markeredgecolor=INK,
            label="MESA v2 (time dependent), 10 R$_\\odot$")
    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlabel("planet mass [M$_J$]")
    ax.set_ylabel("unbound / ejected mass [M$_\\odot$]")
    ax.set_title("(a) Outer channel: Ivanova & Nandez rule", loc="left", fontsize=10)
    ax.legend(fontsize=7.5, loc="upper left")
    ax.text(0.98, 0.04, "100 R$_\\odot$ and AGB hosts: rule gives 0", transform=ax.transAxes, ha="right",
            fontsize=8, color=INK2)
    ax = axes[1]
    td = np.sqrt((100 * RSUN) ** 3 / (G * MSUN)) / YR
    for run, lab, col in (("v2_yang_wake", "v2 + wake term ($\\epsilon_{wake}$ = 0.25; in progress)", C1),
                          ("yang_Amech", "constant $\\epsilon$ = 0.2 (form 1)", C2)):
        h = hist(run)
        t = (h["star_age"] - h["star_age"][0]) / td
        sel = h["engulf_M_wind_cum"] > 0
        ax.plot(t[sel], h["engulf_M_wind_cum"][sel], color=col, label=lab)
    ax.fill_between([150, 190], 1.5e-3, 2e-3, color=C3, alpha=0.45, lw=0)
    ax.plot([], [], color=C3, alpha=0.6, lw=6, label="Yang+26 3D unbound ($e$ = 0.65)")
    ax.text(10, 4e-3, "v2 without wake term: 0 (rule)", fontsize=8, color=INK2)
    ax.set_yscale("log")
    ax.set_ylim(1e-7, 1e-2)
    ax.set_xlabel("time [$t_{dyn}$]")
    ax.set_ylabel("mass removed [M$_\\odot$]")
    ax.set_title("(b) 100 R$_\\odot$ + 5 M$_J$: wake term", loc="left", fontsize=10)
    ax.legend(fontsize=7.5, loc="lower right")
    fig.tight_layout()
    save(fig, "fig7_v2_ejection_rule.png")


if __name__ == "__main__":
    fig_energy()
    fig_bugs()
    fig_rg10()
    fig_yang()
    fig_literature()
    fig_agb()
    fig_v2()
