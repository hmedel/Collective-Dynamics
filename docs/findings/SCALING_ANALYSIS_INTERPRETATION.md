# Finite-Size Scaling Analysis - Interpretation

**Date:** 2025-11-20
**Campaign:** `results/final_campaign_20251120_202723/`

## Attempted Analysis

We fitted the clustering radius data to the canonical finite-size scaling form:

```
R_∞(N) = R_bulk + A/N^α
```

Where:
- **R_bulk**: Thermodynamic limit (N → ∞)
- **A**: Amplitude of finite-size corrections
- **α**: Critical scaling exponent

## Results Summary

| e   | R_bulk | α      | χ²_red | Quality |
|-----|--------|--------|--------|---------|
| 0.0 | 0.272  | 8.817  | 0.203  | poor    |
| 0.3 | 0.253  | 9.200  | 3.202  | poor    |
| 0.5 | 0.041  | 9.373  | 7.365  | poor    |
| 0.7 | 25.56  | 0.005  | 0.141  | poor    |
| 0.8 | 44.05  | 0.001  | 0.412  | poor    |
| 0.9 | 169.21 | 0.001  | 3.837  | poor    |

## Key Observations

### 1. Anomalous Exponents

**Problem:** α values are either:
- **Very large** (α ~ 9) for e = 0.0-0.5
- **Very small** (α ~ 0.001) for e = 0.7-0.9

**Expected:** For typical critical phenomena, α ~ 0.5-2.0

**Interpretation:**
- α >> 1 suggests corrections decay faster than any power law → exponential or finite-size saturation
- α << 1 suggests corrections decay very slowly → logarithmic corrections or non-universal behavior

### 2. Huge Error Bars

Error bars on α are enormous (±100 to ±8000), indicating:
- **Poor constrainability** of the exponent with only 4 data points (N = 20, 40, 60, 80)
- The data may not follow a simple power law
- Need more N values or different functional form

### 3. Unphysical R_bulk Values

For e = 0.7-0.9, R_bulk >> 1, which is unphysical since:
- R is normalized and should be ~ 0-1
- This suggests the fit is extrapolating wildly

## Scientific Interpretation

### The Data Does NOT Follow Simple Power-Law Scaling

This is actually a **scientifically interesting result**:

#### Regime 1: Low-Moderate Eccentricity (e ≤ 0.5)
- Fast convergence (α >> 1)
- Suggests clustering is **not a critical phenomenon** in this regime
- System may equilibrate to a finite-size independent state quickly
- Possible interpretation: **Strong clustering saturation**

#### Regime 2: High Eccentricity (e ≥ 0.7)
- Non-monotonic N-dependence
- No clear convergence to bulk limit
- Suggests **geometric frustration** or **competing length scales**
- The intrinsic geometry may introduce non-universal behavior

## Alternative Approaches

Given these results, we should consider:

### 1. Logarithmic Corrections
```
R_∞(N) = R_bulk + A/log(N)
```

### 2. Exponential Saturation
```
R_∞(N) = R_bulk + A·exp(-N/N₀)
```

### 3. Non-Universal Behavior
Accept that different e regimes have fundamentally different scaling:
- **e < 0.5:** Fast saturation (clustering dominated)
- **e > 0.7:** Geometric frustration (curvature effects dominate)

### 4. More N Values Needed
- Current: N = [20, 40, 60, 80]
- Need: N = [10, 20, 30, ..., 100, 150, 200] for reliable fits
- With only 4 points, 3-parameter fits are poorly constrained

## Physical Hypothesis

### Why Doesn't Standard Scaling Work?

**Hypothesis:** The system is **NOT near a critical point**.

Standard finite-size scaling assumes:
```
ξ ∼ L^(1/ν)  (near criticality)
```

But our system may have:
1. **Strong first-order clustering** (e ~ 0.5): Abrupt transition, no power laws
2. **Geometric constraints** (high e): Curvature sets intrinsic length scale
3. **Multiple competing scales:**
   - Particle size: r ~ 0.02
   - System size: L ~ perimeter
   - Curvature radius: ρ(φ) ~ 1/κ(φ)

## Recommendations for Publication

### What to Report

1. **Honest Assessment:**
   > "We find that the clustering radius R_∞(N) does not follow simple power-law finite-size scaling. This suggests the system is not near a standard critical point."

2. **Show Raw Data:**
   - Plot R_∞ vs N for all e (already done ✅)
   - Don't try to force a power-law fit
   - Emphasize the **non-monotonic behavior** as the key finding

3. **Regime Classification:**
   - **Strong clustering regime** (e ~ 0.5): R_∞ ~ 0.03-0.15, weak N-dependence
   - **Weak clustering regime** (e ~ 0.9): R_∞ ~ 0.3-0.5, larger N-dependence
   - **Crossover region** (e ~ 0.7)

### What NOT to Report

- Don't report α values with huge error bars as "critical exponents"
- Don't claim "mean-field behavior" (α = 0.5) without better evidence
- Don't extrapolate R_bulk to N → ∞ with current data

## Next Steps

### For Current Dataset

1. ✅ **Accept non-power-law behavior** as a finding
2. **Characterize regimes** qualitatively:
   - Strong vs weak clustering
   - Geometric effects
3. **Plot heatmap** of R_∞(N, e) to visualize patterns

### For Future Work

1. **Extend N range:** N = 10-200 with finer sampling
2. **Vary particle density** φ independently
3. **Study dynamics:** Relaxation timescales τ(N)
4. **Theory:** Develop geometric theory for clustering on curved spaces

## Conclusion

**Key Message:** The absence of standard finite-size scaling is itself an interesting result, suggesting that clustering on curved manifolds is governed by geometric constraints rather than critical fluctuations.

This makes the paper **more interesting**, not less! The non-universal behavior reflects the rich interplay between:
- Discrete particle dynamics
- Continuous geometric curvature
- Finite-size effects

---

**Status:** Analysis complete, physical interpretation provided.

**Recommendation:** Focus paper on **geometric mechanisms of clustering** rather than critical scaling hypothesis.
