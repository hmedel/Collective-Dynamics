# Next Steps for Collective Dynamics Project

**Date**: 2026-01-08
**Status**: Ready for publication / presentation

---

## Immediate Next Steps

### 1. More Particles (N scaling)
- Run simulations with N = 80, 100 particles
- Verify if clustering effect scales with system size
- Check if formation time τ depends on N

### 2. Longer Simulations (Cluster Lifetime)
- Run t_max = 1000s or more
- Measure cluster lifetime distribution
- Determine if clusters are truly metastable or transient

### 3. Theoretical Development
- Derive ρ ∝ 1/√g from kinetic theory (Boltzmann equation on manifold)
- Calculate effective collision cross-section at curved regions
- Explain why collisions trap particles at high-curvature regions

### 4. Paper Preparation
- Main result: Non-equilibrium clustering on curved manifolds
- Key finding: ρ(φ) ∝ 1/√g (opposite to equilibrium)
- Target journals: Physical Review Letters, Physical Review E

---

## Completed Milestones

- [x] Discovered two-cluster states (Jan 2026)
- [x] E/N scan campaign (75 runs)
- [x] Verified ρ ∝ 1/√g (anti-equilibrium result)
- [x] Confirmed NOT a phase transition
- [x] Established curvature-driven mechanism

---

## Open Scientific Questions

1. **Why 1/√g instead of √g?**
   - Hypothesis: Collision-mediated trapping at high-κ regions
   - Need: Kinetic theory derivation

2. **Cluster lifetime distribution**
   - Is it exponential? Power-law?
   - What sets the characteristic time?

3. **N-dependence**
   - Does effect strengthen with N?
   - Is there a critical N for clustering?

4. **3D extension**
   - On ellipsoids, where do particles cluster?
   - Expect rings at high-curvature latitudes?

---

## Technical Improvements

1. **GPU parallelization** - For large N simulations
2. **Adaptive output** - Save more data near cluster events
3. **Real-time visualization** - For presentations/demos

---

**Last updated**: 2026-01-08
