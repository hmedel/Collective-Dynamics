# Effective Temperature Framework for Clustering Dynamics

**Date**: 2025-11-15
**Context**: Collective dynamics on elliptical manifolds
**Purpose**: Establish E/N as an effective temperature parameter

---

## Motivation

Although our system is **not thermalized** in the strict statistical mechanics sense (it's a deterministic, microcanonical hard-sphere gas), the **energy per particle** E/N plays a role analogous to temperature.

This framework allows us to:
1. Make connections to statistical mechanics and phase transitions
2. Predict clustering behavior as a function of "thermal" energy
3. Test for critical temperature T_c where clustering transitions occur

---

## The Analogy

### Statistical Mechanics (Canonical Ensemble)

In a thermal equilibrium system at temperature T:

```
k_B T ~ <E_kinetic> per particle
```

where:
- k_B = Boltzmann constant
- T = absolute temperature
- <E_kinetic> = average kinetic energy

**Physical meaning**: Temperature measures the average kinetic energy of particles.

### Our System (Microcanonical Ensemble)

In our hard-sphere gas on an ellipse:

```
E/N = E_total / N = average kinetic energy per particle
```

where:
- E_total = conserved total energy
- N = number of particles
- All energy is kinetic (no potential energy)

**Physical meaning**: E/N measures the "activity level" of the system.

---

## Defining Effective Temperature

We define an **effective temperature** as:

```
T_eff ≡ (2/k_B) * (E/N)
```

or, setting k_B = 1 for convenience:

```
T_eff = 2 * (E/N)
```

The factor of 2 comes from the equipartition theorem (E_kinetic = (1/2) k_B T per degree of freedom in 1D).

### Dimensionless Effective Temperature

For our system with b = 1 (semi-minor axis), we can define:

```
T̃ ≡ T_eff / E_ref = (E/N) / (v_ref² / 2)
```

where v_ref is a reference velocity scale, e.g., v_ref = √(b·g) for "thermal" speed.

**Current experiments use**: E/N = 0.32 (fixed)

**This corresponds to**: T_eff ≈ 0.64 in dimensionless units

---

## Physical Predictions

### High Temperature Regime (T_eff >> 1)

**Expected behavior**:
- Particles move too fast to "stick" together
- Collisions frequently break up forming clusters
- **Gas phase**: N_clusters ~ N (mostly isolated particles)
- Clustering time: τ_cluster → ∞

**Analogy**: Ideal gas at high T

### Intermediate Temperature (T_eff ~ 1)

**Expected behavior**:
- Balance between kinetic energy and collision "binding"
- Transient clusters form and dissolve
- **Liquid phase**: N_clusters ~ N/10 to N/2 (droplets)
- Clustering time: τ_cluster ~ 10-100 s

**Analogy**: Liquid state near boiling point

### Low Temperature (T_eff << 1)

**Expected behavior**:
- Particles move slowly, easily "stick" after collisions
- Rapid cluster formation
- **Crystal phase**: N_clusters = 1 (single cluster)
- Clustering time: τ_cluster ~ 1-10 s

**Analogy**: Crystallization from supercooled liquid

---

## Critical Temperature Hypothesis

We hypothesize a **critical effective temperature** T_c where clustering behavior changes qualitatively:

```
T_eff > T_c  →  Gas phase (no global clustering)
T_eff < T_c  →  Liquid/Crystal phase (clustering occurs)
```

**Determination of T_c**:

Run simulations over a range of E/N values and measure:
- N_clusters_final vs E/N
- τ_cluster vs E/N
- Order parameter: φ_cluster = s_max/N

**Predicted signature**:
- **Above T_c**: φ_cluster ~ 0.1 (no clustering)
- **Below T_c**: φ_cluster ~ 1.0 (full clustering)
- **At T_c**: Critical fluctuations, power-law behavior

---

## Connection to Phase Diagrams

### 2D Phase Diagram: (T_eff, eccentricity e)

Variables:
- **x-axis**: Effective temperature T_eff = E/N
- **y-axis**: Eccentricity e = √(1 - b²/a²)

Phases:
- **Gas**: High T, any e → No clustering
- **Liquid**: Intermediate T, any e → Partial clustering
- **Crystal**: Low T, any e → Full clustering

**Eccentricity effect**:
- Higher e → lower T_c (geometric effects accelerate clustering)
- Prediction: T_c(e) decreases with e

### 3D Phase Diagram: (T_eff, e, packing fraction φ)

Adding packing fraction φ = (N · π r²) / A_ellipse:

- **Gas**: High T or low φ
- **Liquid**: Intermediate T and φ
- **Crystal**: Low T or high φ

**Packing effect**:
- Higher φ → more collisions → faster clustering
- Prediction: τ_cluster ∝ 1/φ at fixed T_eff

---

## Experimental Design: Temperature Scan

### Proposed Experiment: Vary E/N at Fixed N, e

**Parameters**:
- N = 40 (fixed)
- a/b = 2.0, e = 0.866 (fixed)
- **E/N** = [0.05, 0.1, 0.2, 0.4, 0.8, 1.6, 3.2] (7 values)
- Seeds: 10 per case
- Time: t_max = 100 s

**Metrics to measure**:
1. τ_cluster (clustering time) vs E/N
2. N_clusters_final vs E/N
3. σ_φ_final (spatial spread) vs E/N
4. Growth exponent α vs E/N

**Expected results**:
- τ_cluster increases with E/N (harder to cluster at high "temperature")
- N_clusters_final increases with E/N (more gas-like)
- Critical point: E/N ~ 0.5-1.0 (estimate)

### Proposed Experiment: Full Phase Diagram

**Parameters**:
- **E/N** = [0.1, 0.2, 0.4, 0.8, 1.6] (5 values)
- **e** = [0.0, 0.5, 0.75, 0.866, 0.943] (5 values)
- N = 40 (fixed)
- Seeds: 10 per combination
- **Total runs**: 5 × 5 × 10 = 250

**Output**: 2D phase diagram in (T_eff, e) space

---

## Caveats and Limitations

### This is NOT True Thermalization

Our system is:
- **Deterministic** (no stochastic thermostat)
- **Microcanonical** (E fixed, not sampled from Boltzmann distribution)
- **Small-N** (N=40-80, not thermodynamic limit)
- **Low-dimensional** (1D manifold embedded in 2D)

Therefore:
- Boltzmann distribution may not apply
- Ergodic hypothesis may be violated
- Finite-size effects are important

### What E/N DOES Control

Even without true thermalization, E/N controls:
1. **Mean particle speed**: v_rms ~ √(E/N)
2. **Collision frequency**: f_coll ∝ v_rms
3. **Relative velocity in collisions**: Δv ∝ √(E/N)
4. **Cluster stability**: Low E/N → easier to form stable clusters

---

## Effective Temperature in Current Results

### Experiment 4: Eccentricity Scan (E/N = 0.32 fixed)

From COMPLETE_FINDINGS_SUMMARY.md:

| Case | e | t_1/2 | Final σ_φ |
|:-----|:--|:------|:----------|
| Circle | 0.00 | 7.5s | 0.015 |
| Moderate | 0.87 | 5.0s | 0.022 |
| High | 0.94 | 3.5s | 0.030 |
| Extreme | 0.98 | 2.5s | 0.011 |

**Interpretation with T_eff**:
- All at same "temperature" T_eff = 0.64
- Clustering time decreases with e **despite constant T**
- → Geometry (curvature variation) provides additional clustering mechanism beyond thermal effects

### Experiment 5: Statistical Study (E/N = 0.32 fixed)

From statistical_summary.txt:

```
T_eff = 0.64 (fixed)
Compactification: 0.66-0.74 ± 0.36-0.50
τ_1/2: 3.3-6.0 ± 3.1-3.8 s
```

**Interpretation**:
- At T_eff = 0.64, system is in **liquid phase** (intermediate clustering)
- Large error bars suggest proximity to critical point?
- Need T-scan to confirm phase

---

## Recommendations

### Short Term

1. **Reprocess existing data** with T_eff framework:
   - Add T_eff = E/N to all summary.json files
   - Plot results vs T_eff instead of just e or φ
   - Check for scaling collapse

2. **Analyze current campaign** with T-lens:
   - Campaign used E/N = 0.32 (fixed)
   - But varied φ (packing fraction)
   - Can extract T-dependence indirectly?

### Medium Term

3. **Run T-scan experiment** (7 temps × 10 seeds = 70 runs):
   - E/N = [0.05, 0.1, 0.2, 0.4, 0.8, 1.6, 3.2]
   - Fixed: N=40, e=0.866
   - Measure: τ_cluster, φ_cluster vs T_eff

4. **Locate critical temperature**:
   - Fit τ_cluster(T) ~ (T - T_c)^{-ν}
   - Identify T_c where behavior changes
   - Test universality class (2D Ising? Different?)

### Long Term

5. **Full phase diagram** (250 runs):
   - Map (T_eff, e) parameter space
   - Classify regions: gas/liquid/crystal
   - Publish as main result

6. **Theoretical modeling**:
   - Kinetic theory with effective temperature
   - Fokker-Planck equation
   - Mean-field theory of clustering

---

## Conclusion

The **effective temperature T_eff = E/N** provides a powerful framework for understanding clustering dynamics, even though our system is not truly thermalized. It allows us to:

✅ Make quantitative predictions about clustering behavior
✅ Connect to statistical mechanics language
✅ Design experiments to test phase transitions
✅ Build intuition about the role of kinetic energy

**Next step**: Run temperature scan experiment to validate framework and locate critical temperature T_c.

---

**Document Status**: Draft for discussion
**Author**: Analysis framework
**Next action**: Implement T_eff calculations in analysis scripts
