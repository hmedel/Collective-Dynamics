# Poster: Non-Equilibrium Clustering on Curved Manifolds

## Title
**Curvature-Induced Particle Clustering: A Non-Equilibrium Steady State on Elliptical Manifolds**

or shorter:

**Collision-Driven Clustering on Curved Manifolds: Breaking Equilibrium Predictions**

---

## Authors
H. García-Hernández, [Co-authors]
Institution

---

## Abstract (50 words)
We discover that hard-sphere particles on elliptical manifolds spontaneously form two clusters at high-curvature regions. Remarkably, the steady-state density ρ(φ) ∝ 1/√g—the **opposite** of equilibrium predictions. This curvature-induced clustering represents a novel non-equilibrium steady state driven by collision dynamics, not thermal equilibration.

---

## PANEL 1: Introduction & Motivation

### The Question
How does geometry affect collective behavior of interacting particles?

### The System
- N = 40 hard-sphere particles constrained to an ellipse
- Elastic collisions with parallel transport correction
- Symplectic integration (energy conservation ΔE/E₀ ~ 10⁻⁹)

### Why Ellipse?
- Simplest curved 1D manifold with non-constant curvature
- κ varies from a/b² (poles) to b/a² (equator)
- Natural testbed for curvature effects

**[FIGURE 1: System schematic - ellipse with particles and curvature coloring]**

---

## PANEL 2: Key Discovery - Two-Cluster States

### Observation
Particles spontaneously form **TWO clusters** at the ellipse poles (φ ≈ 0, π)

### Order Parameters
| Parameter | Formula | Meaning |
|-----------|---------|---------|
| ψ (polar) | \|⟨e^{iφ}⟩\| | Single cluster detection |
| S (nematic) | \|⟨e^{2iφ}⟩\| | Two-cluster detection |

### Results (75 runs, 3 eccentricities, 5 temperatures)
- **100% of runs** show clustering at e = 0.9
- Nematic order S dominates over polar order ψ
- Formation time τ decreases with eccentricity

**[FIGURE 2: Time evolution of ψ and S order parameters]**

---

## PANEL 3: The Surprising Result

### Equilibrium Prediction (WRONG!)
Statistical mechanics predicts:
```
ρ_eq(φ) ∝ √g_φφ(φ)
```
More particles where metric is LARGER (low curvature regions)

### What We Measure (OPPOSITE!)
```
ρ_measured(φ) ∝ 1/√g_φφ(φ) ∝ κ(φ)^{2/3}
```
More particles where metric is SMALLER (HIGH curvature regions)

### Correlation Analysis

| e | Corr(ρ, √g) | Corr(ρ, 1/√g) | Corr(ρ, κ) |
|---|-------------|---------------|------------|
| 0.5 | **-0.48** | +0.49 | +0.50 |
| 0.8 | **-0.81** | +0.83 | +0.83 |
| 0.9 | **-0.91** | +0.92 | +0.89 |

**[FIGURE 3: Measured ρ(φ) vs predicted √g - showing anti-correlation]**

---

## PANEL 4: Physical Mechanism

### Why Particles Accumulate at High Curvature

1. **Velocity reduction**: At high-κ, particles slow down to navigate the turn
2. **Collision trapping**: Slowed particles collide more → further trapping
3. **Positive feedback**: Higher local density → more collisions → more trapping

### Analogy
Like cars on a highway:
- Cars pile up at **sharp curves** (high curvature)
- Not at straight sections (low curvature)
- Even though equilibrium would predict uniform distribution

### NOT a Phase Transition
- No sharp transition at critical parameter
- Metastable dynamics (6-14% time clustered)
- Wrong temperature dependence (higher T → more clustering)

**[FIGURE 4: Schematic of trapping mechanism]**

---

## PANEL 5: Implications

### Theoretical
1. Equilibrium statistical mechanics fails on curved manifolds with collisions
2. Non-equilibrium steady state (NESS) dominates
3. Kinetic theory approach needed

### Analogies in Other Systems
| System | "Slow region" | Result |
|--------|---------------|--------|
| **This work** | High curvature | Two-cluster state |
| Traffic flow | Speed limit zones | Traffic jams |
| Active matter | High friction | Motility-induced clustering |
| Bacteria | Obstacles/walls | Boundary accumulation |

### Future Directions
- Extension to 3D ellipsoids
- Theoretical derivation of ρ ∝ 1/√g
- Large N scaling behavior

---

## PANEL 6: Summary

### Take-Home Messages

1. **Curvature drives clustering**: Particles accumulate at high-κ regions

2. **Anti-equilibrium behavior**: ρ ∝ 1/√g, not √g

3. **Collision dynamics**: The key mechanism is collision-mediated trapping

4. **Non-equilibrium steady state**: System is NOT in thermal equilibrium

### Key Numbers
- Clustering: 100% at e = 0.9
- Formation time: τ ~ 15s
- Anti-correlation: r = -0.91
- Energy conservation: ΔE/E₀ ~ 10⁻⁹

**[FIGURE 5: Summary graphic with key results]**

---

## References
1. García-Hernández & Medel-Cobaxín, "Collision Dynamics on Curved Manifolds" (in preparation)
2. [Relevant references on active matter, traffic flow, curved space dynamics]

---

## Contact
email@institution.edu
GitHub: github.com/hmedel/Collective-Dynamics

---

# Figure List

1. **Figure 1**: System schematic
   - Ellipse with particles shown as circles
   - Color-coded by local curvature
   - Inset: metric g_φφ(φ) profile

2. **Figure 2**: Order parameters time evolution
   - ψ(t) and S(t) for representative run
   - Show cluster formation dynamics

3. **Figure 3**: Density comparison (MAIN RESULT)
   - ρ_measured(φ) vs φ (histogram)
   - √g_φφ(φ) prediction overlaid (dashed)
   - Clear visual of anti-correlation

4. **Figure 4**: Correlation summary
   - Bar chart: correlation coefficients by eccentricity
   - Show transition from weak to strong anti-correlation

5. **Figure 5**: Physical mechanism schematic
   - Cartoon of collision trapping at high-κ
   - Traffic jam analogy
