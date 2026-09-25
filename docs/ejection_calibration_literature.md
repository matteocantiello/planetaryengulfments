# Mass ejection in engulfment and common envelope: literature for calibrating the 1D prescription

Compiled 2026-09-25 from four literature searches: SPH CE, grid/moving-mesh CE, 1D models + α formalism, and
LRN/merger light curves. arXiv IDs are given. Journal refs and numbers marked † were not verified against the
source, and [derived] numbers are ratios we computed from tabulated quantities. Before these go into the paper,
verify every citation (DOI/arXiv) and re-read the numbers.

## Why a prescription is needed
Our option B (MESA 1D hydro; the drag energy is deposited as heat and outward-moving gas with Bernoulli > 0
is removed) does not reproduce 3D ejecta. For Yang+26's 1 M☉ / 100 R☉ giant + 5 M_J it ejects >10× less than
3D and unbinds nothing (LOG.md).

The published diagnosis (Ivanova & Nandez 2016, 1606.04923) is that 3D deposits energy **mechanically**, with
an entropy increase of only ~30%, whereas 1D heat deposition raises the entropy by a factor of several.
Radiative diffusion then removes heat deposited in 1D (Clayton+17; Wilson & Nordhaus 2019, 2022). Radiative 3D
runs likewise eject about half as much as adiabatic ones and almost nothing during plunge-in (Lau+2025 III,
2503.20506).

## Key numbers

### Energy efficiency: fraction of ΔE_orb that ends in unbound gas (no recombination)
| Source | System | ε |
|---|---|---|
| Ricker & Taam 2012 (1107.3889) | 1.05 M☉ RG + 0.6 M☉, FLASH | **0.25** to unbinding (0.15 M☉ for 2e46 of 8e46 erg); 0.75 puffs up the bound envelope |
| Sandquist+1998, 2000 | AGB/RGB + 0.1–0.6 M☉ | α_CE(ejected) = 0.09–0.56 (0.40, 0.24; Table 3 of 2000) |
| Passy+2012 (1107.5072) | 0.88 M☉ RGB, q = 0.11–1 | f_unb = 2–10% of envelope; [derived] ε ≈ 0.04 (q≈0.1) to 0.2–0.3 (q≈0.7–1) |
| Ivanova & Nandez 2016 (1606.04923) | 1.8 M☉ RGB, q = 0.028–0.2 | ejecta pre-plunge + plunge = 2/20/29/36/51% of M_env; [derived] E_ej/ΔE_orb = 0.075–0.20 |
| Reichardt+2020 (1911.02759) | P12 and N16, ideal vs MESA EOS | [derived] E_unb/ΔE_orb = 0.02 (tightly bound) to 0.21 (ideal); 0.28–0.89 with recombination |
| Lau+2022a (2111.00923), SPH | 12 M☉ RSG, q = 0.25 | f_th = 0.18 (ideal), 0.28 (+rad), 0.60 (full EOS) |
| Kramer+2020 (2007.00019), AREPO | 0.77 M☉ tip-RGB, q = 0.01–0.10 | ideal q=0.1: 7.3%; with OPAL, f_th = 78/52/22/17% for q = 0.10/0.06/0.04/0.01 |
| Sand+2020 (2007.11000), AREPO | 0.97 M☉ AGB, q = 0.25–0.75 | ideal f_th = 0.17/0.21/0.08; OPAL f_kin = 0.91/0.86/0.75 |
| Chamandy+2019a (1812.11196) | 2 M☉ RGB + 1 M☉ | 14% by end of plunge, almost none afterwards; "hidden" energy term: the gas sinks into M2's potential |
| Clayton+2017 (1705.08457), 1D MESA | constant heating | α_eject = 0.25 (low heating) to 0.05 (high heating): radiative losses rise with heating rate |
| Fragos+2019 (1907.12573), 1D MESA | 12 M☉ RSG + NS | dE_grav/dE_orb ≈ 1.4 (radiation-dominated envelope, heat trapped) |

### Where the ejecta come from: outer layers, locally energy-limited
- Ivanova & Nandez 2016: pre-plunge ejecta follow **δE_orb(r) + δE_bind(r) = 0**. The orbital energy released
  down to r unbinds the outer mass whose binding equals it, i.e. ε ≈ 1 for layers outside the orbit near the
  surface. The 3D predicted-vs-measured masses are 0.010–0.090 vs 0.01–0.10 M☉.
- Yang+26 (2510.25547), planet case: [derived] M_unb·GM*/R* ≈ ΔE_orb to 0.3 R*, i.e. ε ≈ 1 **when measured
  against the Bernoulli deficit of the outer layers**. B includes P/ρ, and outer convective layers have B ≈ 0.
  So ε must be defined against the local Bernoulli binding, not against GM/r (otherwise it looks > 1).
- Lau+2025 (2210.15848), SPH hot Jupiter in a 1 M☉ / 4 R☉ giant: M_unb = (0.8–2.0)×10⁻⁵ M☉ (decreasing with
  resolution), all from the surface. [derived] Its binding (~1.5e43 erg) is ~ΔE_orb of the grazing leg only.
- MacLeod & Loeb 2020a (2003.01123): mass lost between the Roche limit and R1 is Δm/M2 = 0.13 (q=0.01, 100%
  bound), 0.31 (q=0.03, 11% unbound), 0.21–0.25 (q=0.1). Fit (Eq. 10): f_bound ≈ 0.68 (q/0.1)^−0.05 ...

### Planet regime (q ~ 1e-3 – 1e-2)
| Source | System | Ejecta |
|---|---|---|
| Yang+2026 (2510.25547), Athena++, adiabatic | 1 M☉ / 100 R☉ + 5 M_J, e = 0.65, stopped at 0.3 R* | ΔM_tot = (2–3)e-3 M☉ at disruption, (4–6)e-3 by ~300 t_dyn; ΔM_unb(B>0) = 1.5–2e-3, rising |
| Lau+2025 (2210.15848), SPH | 1 M☉ / 4 R☉ + 1 M_J | M_unb ≈ 1e-5 M☉ from the surface; planet ~90% ablated |
| Staff+2016 (1602.03130), Enzo | 3.5 M☉ RGB/AGB + 10 M_J | 1e-3 / 3e-3 M☉, resolution-dependent; energy error exceeds the planet's ΔE_orb |
| Kramer+2020, q = 0.01 | tip-RGB + 10 M_J | f_th ≈ 17% (OPAL, with recombination) |
| Yarza+2023 (2203.11227) | wind tunnel | ~10 M_J can eject a 1 M☉ envelope only near the RGB tip (α=1) |

### Observational α_CE (post-CE binaries)
- WD + brown dwarf: **α = 0.24–0.41**, no recombination needed (Zorotovic & Schreiber 2022, 2204.13715).
- WD + M dwarf: α ≈ 0.2–0.3 (Zorotovic+2010, 1006.1621; Thai+2026, 2607.06333); 1/3 (Scherbak & Fuller 2023,
  2211.02036); 0.32 (Ge+2024, 2311.17304).
- Selection bias: only surviving systems are observed.

### Recombination
- It turns 7–30% into 50–100% unbound for stellar companions (Nandez+15; Reichardt+20; Sand+20; Kramer+20;
  Moreno+22; González-Bolívar+22, 24), but on slow post-plunge timescales.
- Its effect is weak for q ≲ 0.04 (Kramer+20). Radiative losses reduce the usable fraction (Lau+2025 III; only
  10–40% usable per Thai+26).
- For planets it is secondary for the dynamical ejecta. It matters for the light curve (plateau).

### Existing 1D precedent
Bronner+2024 (2311.06332), Bronner+2025 (2412.04543):
- MESA with drag coefficient C_d and heating width C_h·R_a, calibrated on Sand+20 / Vetter+24.
- It reproduces 3D ejection **only with recombination** and fails at q = 0.75.
- Their fit parameters are (C_d, C_h) = (0.23, 4.0) at q = 0.25 and (0.30, 1.30) at q = 0.5.
- Clayton+2017 remove layers with v > v_esc on a 0.01 yr e-folding time.

### Energy formalism mapping (ε in a time-dependent model vs α_CE)
- α_CE (−ΔE_orb) = E_bind.
- Nandez & Ivanova 2016: α_bind + α_rec + α_unb^∞ ≈ 1. The ejecta keep 20–50% of ΔE_orb at infinity
  (α_kin^∞ = 0.16–0.47).
- Hence ε (all energy given to ejecta) ≈ α_CE (1 + f_∞), with f_∞ = E_∞/E_bind ~ 0.5–1.
- Yarza+2022 (2210.00010): drag work ≠ −ΔE_orb(point mass) when the enclosed mass changes. Our E_orb uses the
  actual potential, which includes this term.

## Proposed prescription v2 (to implement and calibrate)
1. **Surface/outer channel (energy-limited, ε_out ≈ 1).** Orbital energy released while the companion is in
   the outer layers unbinds overlying gas, with each layer costing its Bernoulli deficit
   −B = −(½v² + h − Gm/r) (Ivanova & Nandez 2016; Yang+26).
   - Removal: from the surface, at the rate set by energy, with e_lift = −B_surf + ½ v_∞².
   - Calibration: Yang+26 (loose host), Lau+2025 (compact host), MacLeod & Loeb 2020a.
2. **Deep channel (ε_deep ≈ 0.02–0.3).** Rising with q and falling with envelope binding (Ricker & Taam 2012;
   Passy+12; Ivanova & Nandez 2016). Most of the energy puffs up the bound envelope, i.e. heat in MESA.
3. **Recombination and slow ejection.** Leave to MESA's EOS and heat, plus a light-curve model. Test against
   Bronner+24 / Sand+20 for stellar q.
4. The transition between 1 and 2 is set by the binding energy of the mass above the companion compared with
   the orbital energy released: the layers outside the orbit get unbound first.

## Light curves (ejecta component)
Recommended: a time-dependent multi-shell version of Matsumoto & Metzger 2022 (2202.10478).
- One shell per MESA interval with dM = Ṁ_ej Δt.
- Initial energy E0 = ½ dM v², R0 = R*.
- Saha H/He, effective γ3, analytic κ (their Eqs. 1–7).
- Colliding shells merge, conserving momentum; the dissipated energy goes into heat.
- Steady-wind limit: L_rec ≈ X ε_H Ṁ/m_p = 9.7×10¹² erg/g × Ṁ (Metzger+2012, 1204.0796).
- Useful scalings (MM22):
  - plateau t_pl ≈ 140 d ρ_i,−11^(−1/3) (M_ej/M☉)^(1/3) (v/300)^(−1);
  - L_pl ≈ 4.8e38 f_ad,0.3 ρ^(1/3) (M_ej/M☉)^(2/3) (v/300) erg/s;
  - cooling peak t_pk ≈ 6.7 d (M/1e-2)^(1/2)(v/500)^(−1/2), L_pk ≈ 1e39 (R0/10R☉)(v/500)² erg/s.
- Popov-type formulae (Ivanova+13) are for comparison only.
- Inputs from MESA: Ṁ_ej(t), v_∞(t), R0(t), X/Y/Z, L*(t).

Benchmarks:
| Event | E_rad | L_peak | Duration | M_ej |
|---|---|---|---|---|
| ZTF SLRN-2020 (De+23; Lau+25 2504.07275; Yarza+25 2507.05365) | 6–6.5e41 erg | 1.3e35 erg/s | ~25 d plateau, 10× fade in 150 d | ~1e-4 M☉ |
| V1309 Sco (Tylenda+11) | ~2–3e44 erg | ~1.2e38 erg/s | — | 0.03–0.08 M☉ |
| M31LRN 2015 (MacLeod+17, 1605.01493) | 6.4e45 erg total | ~1e39 erg/s† | peak rise ~8 d, plateau 10–50 d | ~1e-2 (fast) + ~0.3 M☉ (MacLeod+17); 1.1 M☉ (MM22) |

## Most useful for calibration (from the searches)
1. **Yang+2026:** direct target. Compare fluxes through 1–4 R* (our engulf_Mout/Munb columns).
2. **Lau+2025 (2210.15848):** compact-host planet endpoint, with Lau+2025 III for the radiative correction.
3. **Ivanova & Nandez 2016 (1606.04923):** q-scan and the local ejection rule.
4. **Ricker & Taam 2012:** clean energy split.
5. **Kramer+2020 and Sand+2020 with Bronner+2024:** q-dependence, recombination, and the existing MESA
   calibration.
6. **MacLeod & Loeb 2020a:** pre-plunge ejecta vs q.
