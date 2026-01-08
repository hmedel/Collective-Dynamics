# Master Experimental Design: Collective Dynamics on Elliptical Manifolds

**Date**: 2025-11-14
**Status**: Design Phase
**Goal**: Comprehensive study for high-impact publication

---

## Executive Summary

This document outlines a comprehensive experimental campaign to study:
1. **Clustering dynamics** and spontaneous pattern formation
2. **Phase transitions** in collision-driven systems on curved manifolds
3. **Coarsening kinetics** and comparison with theoretical predictions
4. **Scalability** and parallelization performance
5. **Phase diagrams** in parameter space

**Target**: Physical Review Letters / Physical Review E / Nature Physics

---

## I. Parameter Space Design

### A. Primary Control Parameters

#### 1. **Geometry (Eccentricity)**
```
Parameter: a/b ratio
Symbol: e = √(1 - b²/a²) (eccentricity)

Values:
- Circle:     a/b = 1.0  (e = 0.000)
- Low:        a/b = 1.5  (e = 0.745)
- Moderate:   a/b = 2.0  (e = 0.866)  ← Current baseline
- High:       a/b = 3.0  (e = 0.943)
- Very High:  a/b = 4.0  (e = 0.968)
- Extreme:    a/b = 5.0  (e = 0.980)

Total: 6 values
```

**Physical meaning**: Strength of metric variation
- Circle (e=0): Uniform metric, pure collision effects
- Extreme (e→1): Strong metric gradients, geometry-dominated

#### 2. **Number of Particles (System Size)**
```
Parameter: N
Physical: Determines collision frequency and collective behavior

Values:
- Small:      N = 20
- Medium:     N = 40   ← Current baseline
- Large:      N = 80
- Very Large: N = 160
- Extreme:    N = 320  (test parallelization limit)

Total: 5 values
```

**Scaling considerations**:
- Collision rate ∝ N²
- Computational cost ∝ N² (detection) + N (integration)
- Critical for testing parallelization overhead

#### 3. **Packing Fraction (Density)**
```
Parameter: φ = N·π·r² / (π·a·b)
Physical: Effective density on manifold

Controlled via particle radius r:
- Dilute:      r = 0.03  (φ ≈ 0.02)
- Low:         r = 0.04  (φ ≈ 0.04)
- Moderate:    r = 0.05  (φ ≈ 0.06)  ← Current baseline
- High:        r = 0.06  (φ ≈ 0.09)
- Dense:       r = 0.07  (φ ≈ 0.12)

Total: 5 values
```

**Physical meaning**:
- Low φ: Rare collisions, slow clustering
- High φ: Frequent collisions, fast clustering, potential jamming

#### 4. **Energy Scale (Temperature Analog)**
```
Parameter: E_total or ⟨v²⟩
Physical: Kinetic energy scale / effective temperature

Controlled via initial velocity range:
- Cold:        v_max = 0.5   (E/N ≈ 0.08)
- Cool:        v_max = 0.75  (E/N ≈ 0.18)
- Warm:        v_max = 1.0   (E/N ≈ 0.32)  ← Current baseline
- Hot:         v_max = 1.5   (E/N ≈ 0.72)
- Very Hot:    v_max = 2.0   (E/N ≈ 1.28)

Total: 5 values
```

**Physical meaning**:
- Low energy: Particles barely escape local regions
- High energy: Rapid circulation, fast mixing

### B. Secondary Control Parameters (Targeted Studies)

#### 5. **Initial Conditions**
```
Spatial distribution:
- Uniform:    φ ~ U(0, 2π)              ← Standard
- Localized:  φ ~ N(π/2, 0.3)           (Gaussian cluster)
- Bi-modal:   φ ~ 0.5·N(π/2, 0.2) + 0.5·N(3π/2, 0.2)
- Ring:       φ ~ U(π/2 - 0.5, π/2 + 0.5)  (confined sector)

Velocity distribution:
- Uniform:    φ̇ ~ U(-v_max, v_max)     ← Standard
- Maxwell:    φ̇ ~ N(0, σ_v)            (thermal-like)
- Unidirect:  φ̇ ~ U(0, v_max)          (all clockwise)

Total: 4 spatial × 3 velocity = 12 combinations
```

**Purpose**: Test universality vs sensitivity to initial conditions

#### 6. **Collision Properties**
```
- Restitution coefficient: α ∈ {0.95, 1.0}
  - α = 1.0: Perfectly elastic (current)
  - α < 1.0: Inelastic (energy dissipation)

- Collision method:
  - parallel_transport (current, best conservation)
  - geodesic_flow (alternative)
  - simple (baseline comparison)
```

**Purpose**: Test robustness and explore dissipative systems

### C. Full Factorial Design (Core Campaign)

**Minimal factorial** (proof of concept):
```
Factors: 6 eccentricities × 3 N × 3 φ × 3 E = 162 parameter combinations
Seeds: 10 independent runs per combination
Total: 1,620 simulations
```

**Full factorial** (comprehensive study):
```
Factors: 6 × 5 × 5 × 5 = 750 parameter combinations
Seeds: 15 independent runs per combination
Total: 11,250 simulations
```

**Estimated computational cost**:
- Per simulation: ~5-10 minutes (t_max = 50s, N=40 baseline)
- Total: 1,620 × 7.5 min = **8.5 days** (minimal) on single CPU
- With 24 cores: **8.5 hours** (minimal)
- Full factorial: **~2.5 months** single CPU, **2.5 days** with 24 cores

---

## II. Temporal Resolution

### A. Snapshot Strategy

**Problem**: Current save_interval = 0.1s is too coarse for dynamics

**Solution**: Multi-scale temporal sampling

#### 1. **High-Resolution Phase** (0 < t < 5s)
```
Purpose: Capture nucleation onset
save_interval = 0.01s  (100 Hz)
Expected snapshots: 500
```

#### 2. **Medium-Resolution Phase** (5s < t < 20s)
```
Purpose: Capture coarsening dynamics
save_interval = 0.05s  (20 Hz)
Expected snapshots: 300
```

#### 3. **Low-Resolution Phase** (20s < t < 50s)
```
Purpose: Capture late-time saturation
save_interval = 0.2s   (5 Hz)
Expected snapshots: 150
```

**Total per run**: ~950 snapshots (vs current ~300)

**Storage**:
- Per snapshot: ~5 KB (40 particles × 8 fields × 16 bytes)
- Per run: ~4.75 MB
- Full campaign: 11,250 × 4.75 MB = **53 GB** (manageable)

### B. Collision Event Tracking

**In addition to snapshots**, save detailed collision events:

```julia
struct CollisionEvent{T}
    time::T
    particle_i::Int32
    particle_j::Int32
    φ_i_before::T
    φ_i_after::T
    φ̇_i_before::T
    φ̇_i_after::T
    φ_j_before::T
    φ_j_after::T
    φ̇_j_before::T
    φ̇_j_after::T
    energy_before::T
    energy_after::T
    momentum_transfer::T
end
```

**Purpose**:
- Detailed collision statistics
- Velocity redistribution analysis
- Energy transfer network

**Storage**: ~200 bytes × ~10,000 collisions = ~2 MB per run

---

## III. Observables and Metrics

### A. Order Parameters (Characterize Clustering)

#### 1. **Spatial Order Parameters**
```julia
# Standard deviation (dispersion)
σ_φ(t) = std([φ₁(t), φ₂(t), ..., φ_N(t)])

# Circular variance (accounts for periodicity)
R(t) = |1/N ∑ⱼ exp(i·φⱼ(t))|  ∈ [0, 1]
# R=0: uniform, R=1: all at same φ

# Cluster participation ratio
IPR(t) = (∑ᵢ nᵢ⁴) / (∑ᵢ nᵢ²)²
# nᵢ = number in cluster i
# IPR=1/N_clusters (inverse of effective cluster count)
```

#### 2. **Velocity Order Parameters**
```julia
# Velocity dispersion
σ_φ̇(t) = std([φ̇₁(t), φ̇₂(t), ..., φ̇_N(t)])

# Velocity alignment
v_align(t) = |∑ⱼ φ̇ⱼ(t)| / (N · ⟨|φ̇|⟩)  ∈ [0, 1]
# =1 if all move in same direction

# Kinetic temperature
T_kin(t) = ⟨(φ̇ - ⟨φ̇⟩)²⟩
```

#### 3. **Energy Distribution**
```julia
# Energy dispersion
σ_E(t) = std([E₁(t), E₂(t), ..., E_N(t)])

# Boltzmann entropy (approximation)
S(t) = -∑ᵢ pᵢ log(pᵢ)
# pᵢ = fraction in energy bin i

# Energy equipartition measure
χ_E(t) = ⟨E²⟩ / ⟨E⟩² - 1
# =0 for delta function, >0 for spread
```

### B. Clustering Metrics

#### 1. **Number of Clusters**
```julia
# Connectivity-based (current method)
N_clusters(t, r_threshold) = count_connected_components(
    adjacency_matrix(particles, r_threshold)
)

# Threshold scan
N_clusters(t) vs r_threshold  → critical threshold r_c
```

#### 2. **Cluster Size Distribution**
```julia
# Histogram of cluster sizes
n(s, t) = number of clusters with size s at time t

# Scaling form (coarsening theory)
n(s, t) ~ s^(-τ) · f(s / s_avg(t))
# τ = scaling exponent, f = scaling function
```

#### 3. **Cluster Growth Kinetics**
```julia
# Average cluster size
s_avg(t) = ⟨s⟩ = (∑ᵢ nᵢ · sᵢ) / N_total

# Maximum cluster size (dominant cluster)
s_max(t) = max(s₁, s₂, ..., s_N_clusters)

# Growth exponent
s_max(t) ~ t^α  →  fit to extract α
# Compare with theory: α = 1/2 (diffusive), α = 1/3 (LSW)
```

### C. Phase Space Structure

#### 1. **Trajectory Analysis**
```julia
# Lyapunov exponents (chaos)
λ = lim_{t→∞} 1/t · log(δ(t) / δ₀)

# Recurrence analysis
recurrence_rate(ε) = fraction of times ||x(t) - x(t')|| < ε

# Ergodicity breaking measure
EB(t) = ⟨x²⟩_time / ⟨x⟩²_time - ⟨x²⟩_ensemble / ⟨x⟩²_ensemble
```

#### 2. **Correlation Functions**
```julia
# Spatial correlation
C_space(Δφ, t) = ⟨ρ(φ, t) · ρ(φ + Δφ, t)⟩_φ

# Velocity correlation
C_vel(Δφ, t) = ⟨φ̇(φ, t) · φ̇(φ + Δφ, t)⟩_φ

# Time autocorrelation
C_time(τ) = ⟨x(t) · x(t + τ)⟩_t / ⟨x²⟩
```

### D. Thermodynamic Quantities

#### 1. **Entropy Production**
```julia
# Configurational entropy
S_conf(t) = -∑ᵢ pᵢ(t) log pᵢ(t)
# pᵢ = probability in spatial bin i

# Rate of entropy change
dS/dt = finite difference of S(t)

# Irreversibility measure
Σ(t) = ∫₀ᵗ (dS/dt')² dt'  (cumulative production)
```

#### 2. **Pressure-like Quantities**
```julia
# Collision pressure (force on boundaries)
P_coll(t) = (collision rate) × (momentum transfer per collision)

# Virial pressure
P_virial(t) = N·T_kin + ⟨r · F⟩ / (area)
```

---

## IV. Analysis Protocols

### A. Time-Series Analysis

#### 1. **Characterization Timescales**
```
For each run, extract:

1. Nucleation time (t_nucleation):
   - When N_clusters first drops below N/2
   - Or when R(t) first exceeds 0.5

2. Half-clustering time (t_1/2):
   - When s_max reaches 0.5·N

3. Full-clustering time (t_cluster):
   - When s_max reaches 0.95·N

4. Saturation time (t_sat):
   - When ds_max/dt < threshold
```

#### 2. **Growth Exponent Fitting**
```julia
# For each run:
# 1. Extract s_max(t) in range [t_nucleation, t_cluster]
# 2. Log-log fit: log(s_max) ~ α·log(t) + const
# 3. Extract α with confidence interval

# Aggregate across seeds:
α_mean ± α_std for each parameter combination
```

#### 3. **Coarsening Scaling Analysis**
```julia
# Cluster size distribution at different times
n(s, t₁), n(s, t₂), ..., n(s, t_final)

# Test scaling collapse:
s^τ · n(s, t) vs s/⟨s(t)⟩
# Should collapse to single curve if scaling holds

# Extract τ from power-law regime
```

### B. Phase Diagram Construction

#### 1. **2D Phase Diagrams**

**Diagram 1: Clustering Speed**
```
Axes: (e, φ)  (eccentricity vs packing fraction)
Color: t_1/2  (time to half-clustering)

Expected features:
- Fast clustering: High e, High φ (collisions + geometry)
- Slow clustering: Low e, Low φ (weak effects)
```

**Diagram 2: Growth Exponent**
```
Axes: (e, N)  (eccentricity vs system size)
Color: α  (growth exponent)

Test if α depends on parameters or is universal
```

**Diagram 3: Final State**
```
Axes: (E/N, φ)  (energy vs density)
Color: N_clusters_final

Identify phases:
- Single cluster (ordered)
- Multiple clusters (fragmented)
- No clustering (disordered)
```

#### 2. **Phase Boundaries**

Extract transition lines:
```
# Clustering transition
t_cluster < threshold  →  "clusters"
t_cluster > threshold  →  "no clustering"

# Draw boundary in (e, φ, E/N) space
```

### C. Statistical Analysis

#### 1. **Ensemble Averages**
```
For each (e, N, φ, E) combination:

- Mean: ⟨O⟩ = (1/n_seeds) ∑ᵢ Oᵢ
- Std:  σ_O = sqrt(⟨O²⟩ - ⟨O⟩²)
- SEM:  σ_mean = σ_O / sqrt(n_seeds)

Report: ⟨O⟩ ± σ_mean
```

#### 2. **Hypothesis Testing**
```
Compare two parameter sets A and B:

H₀: ⟨O_A⟩ = ⟨O_B⟩  (null hypothesis)

Test: Welch's t-test (unequal variances)
t = (⟨O_A⟩ - ⟨O_B⟩) / sqrt(σ²_A/n_A + σ²_B/n_B)

If p < 0.05: reject H₀ (significant difference)
```

#### 3. **Scaling Collapse Quality**
```
Measure goodness of scaling collapse:

χ² = ∑ᵢ (f_scaled,i - f_theory,i)² / σᵢ²

Compare with null model (no scaling)
```

---

## V. Comparison with Theory

### A. Coarsening Theory (Lifshitz-Slyozov-Wagner)

**Standard LSW theory** (1D, 3D):
```
Growth law: R(t) ~ t^α
- α = 1/3  (3D, diffusion-limited)
- α = 1/2  (1D, interface-limited)

Size distribution:
n(s) ~ s^(-3/2) exp(-s/⟨s⟩)  (3D)
```

**Our system** (1D manifold):
- Expect α ≈ 1/2 (1D-like?)
- Or different due to geometry?

**Test**:
1. Measure α from fits
2. Compare n(s) with LSW prediction
3. Check scaling collapse quality

### B. Active Matter Models

**Vicsek-like models**:
```
Alignment interaction + noise → collective motion
Order parameter: v_align(t)

Our system:
- NO explicit alignment rule
- But collisions can create effective alignment
- Test if v_align increases with clustering
```

**Comparison**:
- Phase transition: v_align(ρ) shows critical density?
- Critical exponents: β, ν, γ
- Finite-size scaling

### C. Granular Flows

**Granular gas theory**:
```
Inelastic hard spheres:
- Energy decay: E(t) ~ t^(-2) (homogeneous cooling)
- Clustering instability (inelastic collapse)

Our system (elastic):
- E = const (no cooling)
- But clustering still occurs!
- Mechanism: geometry, not dissipation
```

**Comparison**:
- Velocity distributions: Maxwell vs non-Maxwell?
- Cluster formation: similar morphology?
- Collision network structure

### D. Statistical Mechanics on Manifolds

**Equilibrium prediction**:
```
Canonical ensemble on curved manifold:
ρ_eq(φ) ∝ exp(-βH(φ)) · √g(φ)

For our system:
H = (1/2) m g_φφ φ̇²  (kinetic only)
→ ρ_eq(φ) ∝ √g_φφ(φ)

Prediction:
ρ(π/2) / ρ(0) ~ sqrt(g(π/2) / g(0)) ≈ sqrt(a/b) = √2
```

**Test**:
- Measure ρ(φ) at late times
- Compare with √g(φ) prediction
- If stronger clustering → non-equilibrium effect

---

## VI. Parallelization Study

### A. Scalability Test

**Goal**: Determine optimal N for parallelization

**Protocol**:
```
Fix: e = 0.87, φ = 0.06, E/N = 0.32, t_max = 10s
Vary: N = 20, 40, 60, 80, 100, 120, 160, 200, 320
Threads: 1, 2, 4, 8, 12, 16, 24

Measure:
- Wall time vs N for each thread count
- Speedup: S(N, n_threads) = T(N, 1) / T(N, n_threads)
- Efficiency: E = S / n_threads

Expected:
- Small N (<50): overhead dominates, S < 1
- Large N (>100): good scaling, S ≈ 10-15
```

### B. Overhead Analysis

**Breakdown**:
```
Total time = T_collision + T_integrate + T_overhead

Measure each component:
- T_collision: time in find_next_collision_parallel
- T_integrate: time in forest_ruth_step_polar
- T_overhead: everything else (I/O, projection, etc.)

Plot: Fraction vs N for parallel vs sequential
```

### C. Memory Profiling

```
Track:
- Peak memory usage vs N
- Memory per particle
- Allocations per timestep

Identify bottlenecks:
- Large allocations?
- GC pressure?
```

---

## VII. Visualization Suite

### A. Real-Time Monitoring Plots

**During simulation** (every 100 steps):
```
1. Phase space (φ, φ̇) with color by energy
2. Spatial density histogram ρ(φ)
3. Conservation metrics (ΔE/E₀, ΔP/P₀)
4. Current cluster sizes (bar chart)
```

### B. Post-Processing Plots

**Single-run analysis**:
```
1. Time series:
   - σ_φ(t), σ_φ̇(t), σ_E(t)
   - N_clusters(t) for multiple thresholds
   - s_max(t) with power-law fit

2. Phase space:
   - Trajectory spaghetti plot
   - Initial vs final distribution overlay
   - Poincaré section (if relevant)

3. Spatial:
   - ρ(φ) snapshots at t = 0, t_1/2, t_final
   - Curvature overlay: κ(φ) vs ρ(φ)

4. Collision network:
   - Graph of collision partners
   - Degree distribution
```

**Multi-run analysis**:
```
1. Ensemble averages:
   - ⟨σ_φ(t)⟩ ± σ with shaded error bands
   - ⟨s_max(t)⟩ with individual runs (transparency)

2. Distributions:
   - Histogram of t_1/2 across seeds
   - α distribution (growth exponent)

3. Scaling collapse:
   - n(s, t) · s^τ vs s/⟨s(t)⟩
   - All times on one plot
```

**Publication figures**:
```
1. Fig 1: System schematic + phase space evolution
2. Fig 2: Clustering timescales vs (e, φ, N, E)
3. Fig 3: Growth exponent analysis + coarsening collapse
4. Fig 4: Phase diagrams (2D slices)
5. Fig 5: Comparison with theory (LSW, active matter)
6. Fig 6: Parallelization performance (speedup curves)
```

### C. Animations

```
1. Particle positions on ellipse (2D view)
   - Color by velocity or energy
   - Trails showing recent history

2. Phase space evolution (φ, φ̇)
   - Points moving in time
   - Cluster formation visible

3. Cluster growth process
   - Voronoi tessellation or radius circles
   - Merging events highlighted
```

---

## VIII. Data Management

### A. Directory Structure

```
results/
├── campaign_YYYYMMDD_HHMMSS/
│   ├── metadata.toml              # Campaign parameters
│   ├── parameter_sweep.csv        # All combinations tested
│   │
│   ├── e0.00_N020_phi0.02_E0.08/  # Parameter combination
│   │   ├── seed_0001/
│   │   │   ├── config.toml
│   │   │   ├── trajectories.h5    # HDF5 for efficiency
│   │   │   ├── collisions.csv
│   │   │   ├── summary.json
│   │   │   └── snapshots/
│   │   │       ├── t_000.00s.png
│   │   │       └── ...
│   │   ├── seed_0002/
│   │   └── ...
│   │   ├── ensemble_analysis/     # Aggregated over seeds
│   │   │   ├── mean_timeseries.csv
│   │   │   ├── t_half_distribution.csv
│   │   │   └── figures/
│   │   └── ensemble_summary.json
│   │
│   ├── e0.87_N040_phi0.06_E0.32/
│   └── ...
│   │
│   ├── phase_diagrams/            # Global analysis
│   │   ├── t_half_vs_e_phi.png
│   │   ├── alpha_vs_e_N.png
│   │   └── phase_boundary.png
│   │
│   └── campaign_report.pdf        # Auto-generated summary
```

### B. File Formats

**Trajectories** (HDF5):
```julia
# Much faster I/O than CSV for large datasets
using HDF5

h5open("trajectories.h5", "w") do file
    file["time"] = times              # (n_snapshots,)
    file["phi"] = phi_history         # (n_snapshots, N)
    file["phidot"] = phidot_history   # (n_snapshots, N)
    file["energy"] = energy_history   # (n_snapshots, N)
    # Attributes
    attrs(file)["N"] = N
    attrs(file)["a"] = a
    attrs(file)["b"] = b
    attrs(file)["seed"] = seed
end
```

**Summary** (JSON):
```json
{
  "parameters": {"N": 40, "a": 2.0, "b": 1.0, ...},
  "timescales": {
    "t_nucleation": 1.23,
    "t_half": 5.67,
    "t_cluster": 12.34
  },
  "growth_exponent": {
    "alpha": 0.52,
    "alpha_std": 0.03,
    "R_squared": 0.98
  },
  "final_state": {
    "N_clusters": 1,
    "sigma_phi": 0.022,
    "sigma_phidot": 0.569
  },
  "conservation": {
    "dE_E0_final": 2.17e-9,
    "dE_E0_max": 3.45e-8
  }
}
```

### C. Metadata Tracking

**Campaign metadata**:
```toml
[campaign]
id = "campaign_20251114_comprehensive"
date_start = "2025-11-14T10:00:00"
date_end = "2025-11-16T22:30:00"
total_runs = 11250
completed_runs = 8734
status = "in_progress"

[code]
git_commit = "a1b2c3d4"
version = "v2.0.0-polar"

[compute]
hostname = "cluster-node-04"
threads = 24
julia_version = "1.10.0"

[parameters]
eccentricities = [0.0, 0.745, 0.866, 0.943, 0.968, 0.980]
N_values = [20, 40, 80, 160, 320]
phi_values = [0.02, 0.04, 0.06, 0.09, 0.12]
E_per_N_values = [0.08, 0.18, 0.32, 0.72, 1.28]
n_seeds = 15
```

---

## IX. Automated Pipeline

### A. Job Submission Script

```bash
#!/bin/bash
# submit_campaign.sh

# Load parameter matrix
PARAM_FILE="parameter_matrix.csv"

# Launch all jobs
while IFS=',' read -r e N phi E seed; do
    # Skip header
    [[ "$e" == "eccentricity" ]] && continue

    # Create job script
    cat > job_${e}_${N}_${phi}_${E}_${seed}.sh <<EOF
#!/bin/bash
#SBATCH --job-name=sim_${e}_${N}_${seed}
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=24
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --output=logs/sim_${e}_${N}_${seed}_%j.out

julia --project=. --threads=24 run_single_experiment.jl \
    --eccentricity $e \
    --N $N \
    --phi $phi \
    --E_per_N $E \
    --seed $seed \
    --output_dir results/campaign_main
EOF

    # Submit
    sbatch job_${e}_${N}_${phi}_${E}_${seed}.sh

done < "$PARAM_FILE"
```

### B. Analysis Pipeline

```julia
# analyze_campaign.jl

using ProgressMeter

function analyze_full_campaign(campaign_dir)
    # 1. Find all completed runs
    runs = find_completed_runs(campaign_dir)

    @showprogress "Analyzing runs..." for run in runs
        # Extract observables
        data = load_trajectories(run)

        # Compute metrics
        metrics = compute_all_metrics(data)

        # Save summary
        save_summary(run, metrics)
    end

    # 2. Aggregate by parameter combination
    @showprogress "Aggregating ensembles..." for combo in unique_combinations(runs)
        ensemble_data = load_ensemble(campaign_dir, combo)

        # Statistical analysis
        stats = compute_ensemble_statistics(ensemble_data)

        # Plots
        plot_ensemble(ensemble_data, stats)

        # Save
        save_ensemble_analysis(campaign_dir, combo, stats)
    end

    # 3. Global analysis
    @info "Generating phase diagrams..."
    phase_diagrams = compute_phase_diagrams(campaign_dir)
    plot_phase_diagrams(phase_diagrams)

    @info "Comparing with theory..."
    theory_comparison = compare_with_theories(campaign_dir)

    # 4. Generate report
    @info "Creating campaign report..."
    generate_report(campaign_dir, phase_diagrams, theory_comparison)

    return campaign_dir
end
```

### C. Real-Time Dashboard

```julia
# dashboard.jl (using Dash.jl or similar)

# Web interface showing:
# - Campaign progress (%)
# - Currently running jobs
# - Completed parameter combinations (grid view)
# - Live plots of selected metrics
# - Estimated time to completion
```

---

## X. Timeline and Priorities

### Phase 1: Infrastructure (Week 1)
**Goal**: Build automation tools

- [ ] Implement multi-scale snapshot system
- [ ] Create HDF5 I/O backend
- [ ] Develop ensemble analysis functions
- [ ] Build parameter matrix generator
- [ ] Test pipeline with minimal factorial (162 runs)

**Deliverable**: Working automated pipeline

### Phase 2: Pilot Study (Week 2)
**Goal**: Test design with subset

**Minimal factorial**:
- 6 eccentricities × 3 N [20, 40, 80] × 3 φ [0.04, 0.06, 0.09] × 10 seeds
- Total: 540 runs (~10 hours with 24 cores)

**Analyze**:
- Verify trends
- Identify interesting regimes
- Refine analysis tools

**Deliverable**: Proof of concept results

### Phase 3: Full Campaign (Weeks 3-4)
**Goal**: Execute comprehensive study

- Launch full factorial (11,250 runs)
- Monitor and debug
- Handle failures and restarts

**Deliverable**: Complete dataset

### Phase 4: Analysis and Writing (Weeks 5-8)
**Goal**: Publication-ready results

- Deep analysis of all data
- Theory comparisons
- Figure generation
- Manuscript writing

**Deliverable**: Submitted manuscript

---

## XI. Extensions and Future Work

### A. 3D Extension

Once 2D is complete:
- Ellipsoid: (x/a)² + (y/b)² + (z/c)² = 1
- Spherical-like coordinates (θ, φ)
- Richer phase space (more degrees of freedom)
- Expected: Even more complex patterns (ribbons, vortices?)

### B. External Fields

Add external potential:
```
H = T + V_external(φ)

Examples:
- Gravity-like: V ∝ y = r(φ)·sin(φ)
- Harmonic trap: V ∝ (φ - φ₀)²
```

### C. Dissipative Systems

Inelastic collisions (α < 1):
- Energy decay
- Clustering via cooling
- Connection to granular gases

### D. Driven Systems

External driving:
- Periodic forcing
- Thermal bath coupling
- Non-equilibrium steady states

---

## XII. Resource Requirements

### A. Computational

**CPU**:
- Minimal factorial: ~8.5 CPU-days = 8.5 hours @ 24 cores
- Full factorial: ~70 CPU-days = 2.5 days @ 24 cores (parallelized)
- Analysis: ~5 CPU-days

**Storage**:
- Trajectories: 11,250 runs × 5 MB = **56 GB**
- Collisions: 11,250 runs × 2 MB = **22 GB**
- Plots: ~10 GB
- Total: ~100 GB (very manageable)

**Memory**:
- Per simulation: <1 GB (N=320)
- Analysis: ~4 GB (loading ensembles)

### B. Human Time

**Implementation**: 1-2 weeks
**Pilot study**: 1 week (running + analysis)
**Full campaign**: 2 weeks (monitoring + debugging)
**Analysis**: 2-4 weeks
**Writing**: 4-8 weeks

**Total**: 3-4 months to publication

---

## XIII. Success Metrics

### Computational Success
- [ ] All 11,250 simulations complete
- [ ] Conservation: ΔE/E₀ < 10⁻⁸ for 99% of runs
- [ ] Speedup > 10x for N=320 with 24 threads

### Scientific Success
- [ ] Clear phase diagram with identifiable regimes
- [ ] Measured growth exponent α with error bars
- [ ] Successful scaling collapse (χ² test)
- [ ] Comparison with ≥2 theoretical frameworks
- [ ] ≥1 novel, unexpected finding

### Publication Success
- [ ] 6+ publication-quality figures
- [ ] Comprehensive SI with all data
- [ ] Code repository public (Zenodo DOI)
- [ ] Submitted to Phys. Rev. E or equivalent
- [ ] Preprint on arXiv

---

## XIV. References and Theory Background

### Key Papers to Compare

**Coarsening**:
1. Lifshitz & Slyozov (1961) - LSW theory
2. Bray (1994) - Review of coarsening kinetics
3. Amar & Family (1995) - Surface growth universality

**Active Matter**:
1. Vicsek et al. (1995) - Flocking model
2. Toner & Tu (1995) - Hydrodynamic theory
3. Chaté et al. (2008) - Phase transitions in active matter

**Granular Flows**:
1. Goldhirsch & Zanetti (1993) - Clustering instability
2. Brilliantov & Pöschel (2004) - Kinetic theory book
3. Mehta (2007) - Granular matter review

**Geometry & Mechanics**:
1. Arnold (1989) - Mathematical methods of classical mechanics
2. do Carmo (1992) - Riemannian geometry
3. Marsden & Ratiu (1999) - Mechanics on manifolds

---

## XV. Next Steps

### Immediate (This Session)
1. Review and refine this design document
2. Create parameter matrix CSV
3. Implement multi-scale snapshot system
4. Test HDF5 I/O
5. Build coarsening exponent analyzer

### This Week
1. Complete pipeline infrastructure
2. Run pilot study (162 or 540 runs)
3. Validate analysis tools
4. Generate first phase diagram

### Next Session
1. Review pilot results
2. Refine based on findings
3. Launch full campaign
4. Begin paper outline

---

**Status**: Design document complete, ready for implementation
**Author**: Claude Code
**Date**: 2025-11-14
**Next Review**: After pilot study completion
