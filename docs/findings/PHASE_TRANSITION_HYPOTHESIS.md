# Phase Transition Hypothesis

## Summary

Analysis of existing data suggests a **temperature-dependent phase transition** in the collective dynamics on ellipses.

## Evidence

### 1. Earlier Experiments (Clustering Observed)

From `results_experiment_1/`:
- **Energy**: E = 12.65 for N = 40
- **E/N ≈ 0.32**
- **Result**: Strong clustering observed
  - All 40 particles converged to single sector
  - σ_φ reduced by 98.6%
  - Formed "traveling cluster"

### 2. Intrinsic v3 Campaign (No Clustering)

From `results/intrinsic_v3_campaign_20251126_110434/`:
- **Energy**: E ≈ 18.36 for N = 40
- **E/N ≈ 0.46**
- **Result**: No clustering
  - 97% classified as "gas" phase
  - σ_φ > 1.3 throughout
  - Compactification ratio > 1 (expanding, not clustering)

### 3. Comparison

| Parameter | Experiment 1 | Intrinsic v3 | Difference |
|-----------|--------------|--------------|------------|
| E/N | 0.32 | 0.46 | +44% |
| σ_φ evolution | Decreasing | Increasing | Opposite |
| Final state | Clustered | Dispersed | Opposite |
| Phase | Crystal | Gas | Different |

## Hypothesis

**Critical Temperature Hypothesis**:
```
T_c (E/N)_c ≈ 0.35 - 0.40
```

Below this temperature: clustering/crystal phase
Above this temperature: dispersed/gas phase

## E/N Scan Campaign

To test this hypothesis, we launched an E/N scan campaign with:

| E/N Values | Expected Phase |
|------------|----------------|
| 0.05 | Crystal (strong) |
| 0.10 | Crystal |
| 0.20 | Crystal/Transition |
| 0.40 | Transition/Gas |
| 0.80 | Gas |
| 1.60 | Gas (strong) |
| 3.20 | Gas (very hot) |

Three eccentricities: e = 0.0 (circle), 0.866 (moderate), 0.968 (high)

## Predictions

1. **E/N = 0.05**: Should show rapid clustering (σ_φ < 0.5 by t=20)
2. **E/N = 0.20**: Critical region, may show transient clustering
3. **E/N = 0.40**: Should remain gas-like (like intrinsic_v3)
4. **E/N dependence**: Critical E/N may increase with eccentricity

## Physical Interpretation

The phase transition likely reflects:
- **Low E/N**: Collisions dominate, energy dissipation leads to clustering
- **High E/N**: Kinetic energy overcomes clustering tendency
- **Curvature coupling**: Higher eccentricity may enhance clustering threshold

## Next Steps

1. Complete E/N scan campaign (~210 simulations)
2. Run phase classification on results
3. Plot phase diagram in (E/N, e) space
4. Identify critical temperature T_c(e)
5. Finite-size scaling analysis
