# Experimental Pipeline Guide

**Date**: 2025-11-14
**Status**: Ready for Use
**Purpose**: Step-by-step guide for running comprehensive experimental campaigns

---

## Quick Start

```bash
# 1. Test the pipeline (5-10 minutes)
julia --project=. test_pipeline.jl

# 2. Generate parameter matrix (choose design)
julia --project=. generate_parameter_matrix.jl minimal  # 1,620 runs
julia --project=. generate_parameter_matrix.jl pilot    # 540 runs (recommended first)
julia --project=. generate_parameter_matrix.jl full     # 11,250 runs

# 3. Launch campaign
./launch_campaign.sh parameter_matrix_pilot.csv --mode parallel --jobs 24

# 4. Analyze results (after completion)
julia --project=. analyze_ensemble.jl results/campaign_YYYYMMDD_HHMMSS/e0.866_N040_phi0.06_E0.32

# 5. Generate phase diagrams
julia --project=. create_phase_diagrams.jl results/campaign_YYYYMMDD_HHMMSS
```

---

## Detailed Workflow

### Phase 1: Pipeline Validation (10 minutes)

**Purpose**: Verify everything works before launching thousands of jobs

```bash
# Run micro test (2 simulations, N=20, t=5s)
julia --project=. test_pipeline.jl
```

**What it tests**:
- ✓ Parameter matrix generation
- ✓ Single experiment execution
- ✓ HDF5 I/O (save/load)
- ✓ Ensemble analysis
- ✓ Coarsening metrics extraction

**Expected output**:
```
Pipeline Test: COMPLETED ✓
Test output: results/pipeline_test_YYYYMMDD_HHMMSS/
  ├── e0.866_N020_phi0.06_E0.32/
  │   ├── seed_1/
  │   │   ├── trajectories.h5
  │   │   ├── summary.json
  │   │   └── cluster_evolution.csv
  │   ├── seed_2/
  │   └── ensemble_analysis/
  │       ├── ensemble_summary.json
  │       ├── ensemble_N_clusters.png
  │       └── ensemble_s_max.png
```

**If test fails**: Check error messages, verify dependencies

---

### Phase 2: Parameter Matrix Generation

**Purpose**: Create systematic grid of parameters to explore

#### Option A: Pilot Study (Recommended First)
```bash
julia --project=. generate_parameter_matrix.jl pilot
```
- **Runs**: 540 (6 ecc × 3 N × 3 φ × 1 E × 10 seeds)
- **Time**: ~10 hours @ 24 cores
- **Purpose**: Quick exploration, verify trends

#### Option B: Minimal Factorial
```bash
julia --project=. generate_parameter_matrix.jl minimal
```
- **Runs**: 1,620 (6 ecc × 3 N × 3 φ × 3 E × 10 seeds)
- **Time**: ~1.5 days @ 24 cores
- **Purpose**: Publication-ready with key parameters

#### Option C: Full Factorial
```bash
julia --project=. generate_parameter_matrix.jl full
```
- **Runs**: 11,250 (6 ecc × 5 N × 5 φ × 5 E × 15 seeds)
- **Time**: ~2.5 days @ 24 cores
- **Purpose**: Comprehensive coverage

**Output**: `parameter_matrix_<design>.csv`

**Inspect the matrix**:
```bash
head -20 parameter_matrix_pilot.csv
```

**Columns**:
- `run_id`: Unique identifier
- `eccentricity`: e ∈ [0, 0.98]
- `a_b_ratio`: Geometry
- `N`: Number of particles
- `phi`: Packing fraction
- `radius`: Particle radius (auto-calculated)
- `E_per_N`: Energy per particle
- `v_max`: Initial velocity scale
- `seed`: Random seed

---

### Phase 3: Campaign Execution

**Purpose**: Run all simulations in parallel

#### Execution Mode 1: Local Workstation (GNU Parallel)

**Requirements**:
- GNU Parallel installed: `sudo apt install parallel`
- 24+ CPU cores recommended
- ~100 GB free disk space

**Launch**:
```bash
./launch_campaign.sh parameter_matrix_pilot.csv --mode parallel --jobs 24
```

**Monitoring**:
```bash
# Watch progress
tail -f results/campaign_YYYYMMDD_HHMMSS/joblog.txt

# Count completed runs
grep -c "^0" results/campaign_YYYYMMDD_HHMMSS/joblog.txt

# Check for failures
grep -v "^0" results/campaign_YYYYMMDD_HHMMSS/joblog.txt
```

#### Execution Mode 2: SLURM Cluster

**Launch**:
```bash
./launch_campaign.sh parameter_matrix_minimal.csv --mode slurm
```

**Monitoring**:
```bash
# Check queue
squeue -u $USER

# Check array status
squeue -j <JOB_ID>

# View output
tail -f results/campaign_YYYYMMDD_HHMMSS/logs/run_*.out
```

#### Execution Mode 3: Sequential (Debugging Only)

```bash
./launch_campaign.sh parameter_matrix_pilot.csv --mode sequential
```

**Note**: Very slow, use only for debugging specific runs

---

### Phase 4: Ensemble Analysis

**Purpose**: Aggregate results across seeds, compute statistics

#### Single Parameter Combination

```bash
# Analyze one (e, N, φ, E/N) combination
julia --project=. analyze_ensemble.jl results/campaign_YYYYMMDD_HHMMSS/e0.866_N040_phi0.06_E0.32
```

**Output**:
```
Ensemble Results (n=10 seeds):

Timescales:
  t_nucleation: 1.23 ± 0.15s
  t_1/2:        5.67 ± 0.42s
  t_cluster:    12.34 ± 1.05s

Growth Exponent:
  α:            0.52 ± 0.03
  R² (mean):    0.98

Final State:
  N_clusters:   1.0 ± 0.0
  σ_φ:          0.022 ± 0.003
  Fully clustered: 100%
```

**Saved files**:
- `ensemble_analysis/ensemble_summary.json`
- `ensemble_analysis/ensemble_N_clusters.png` (time series with error bands)
- `ensemble_analysis/ensemble_s_max.png` (growth curves)

#### All Combinations (Batch)

```bash
# Find all parameter combinations
find results/campaign_YYYYMMDD_HHMMSS -type d -name "e*_N*_phi*_E*" | while read dir; do
    julia --project=. analyze_ensemble.jl "$dir"
done
```

---

### Phase 5: Phase Diagrams (Coming Soon)

**Purpose**: Visualize trends across parameter space

```bash
julia --project=. create_phase_diagrams.jl results/campaign_YYYYMMDD_HHMMSS
```

**Planned outputs**:
1. **t_1/2 vs (e, φ)** - Clustering speed
2. **α vs (e, N)** - Growth exponent
3. **N_clusters_final vs (E/N, φ)** - Phase boundary
4. **Scaling collapse quality** - Test universality

---

## Data Structure

```
results/campaign_YYYYMMDD_HHMMSS/
├── parameter_matrix.csv           # Copy of input matrix
├── logs/                           # Execution logs
│   ├── run_1_*.out
│   └── ...
│
├── e0.000_N020_phi0.04_E0.18/      # Parameter combination
│   ├── seed_0001/                  # Individual run
│   │   ├── trajectories.h5         # Main data (HDF5, ~5 MB)
│   │   ├── summary.json            # Metrics summary
│   │   ├── cluster_evolution.csv   # Time series
│   │   └── (optional) collisions.csv
│   ├── seed_0002/
│   ├── ...
│   └── ensemble_analysis/          # Aggregated results
│       ├── ensemble_summary.json
│       ├── ensemble_N_clusters.png
│       └── ensemble_s_max.png
│
├── e0.866_N040_phi0.06_E0.32/
│   └── ...
│
└── phase_diagrams/                 # Global analysis
    ├── t_half_vs_e_phi.png
    ├── alpha_vs_e_N.png
    └── phase_boundary.png
```

---

## File Formats

### HDF5 Trajectories (`trajectories.h5`)

**Advantages**:
- 3-5x smaller than CSV
- 10-50x faster to read/write
- Supports compression
- Partial loading (time slices)

**Structure**:
```
/trajectories/
  - time         [n_snapshots]
  - phi          [n_snapshots, N]
  - phidot       [n_snapshots, N]
  - energy       [n_snapshots, N]
  - ...

/conservation/
  - time
  - total_energy
  - dE_E0

/metadata/
  - N, a, b, seed, etc. (as attributes)
```

**Loading in Julia**:
```julia
using HDF5
include("src/io_hdf5.jl")

# Load full trajectory
data = load_trajectories_hdf5("trajectories.h5")

# Load time slice (memory efficient)
data = load_trajectory_slice("trajectories.h5", (10.0, 20.0))
```

**Loading in Python** (for external analysis):
```python
import h5py

with h5py.File("trajectories.h5", "r") as f:
    times = f["trajectories/time"][:]
    phi = f["trajectories/phi"][:]
    N = f["metadata"].attrs["N"]
```

### JSON Summary (`summary.json`)

**Content**:
```json
{
  "parameters": {...},
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
  "final_state": {...},
  "conservation": {...}
}
```

**Loading**:
```julia
using JSON
summary = JSON.parsefile("summary.json")
println(summary["timescales"]["t_half"])
```

---

## Troubleshooting

### Simulation Fails Immediately

**Check**:
1. Project environment activated: `julia --project=.`
2. Dependencies installed: `] instantiate`
3. Threads available: `julia -t 24` or `--threads=24`

**Test single run manually**:
```bash
julia --project=. --threads=24 run_single_experiment.jl \
    --eccentricity 0.866 --N 40 --phi 0.06 --E_per_N 0.32 --seed 1 \
    --output_dir results/debug_test --t_max 5.0
```

### HDF5 Errors

**Error**: `HDF5-DIAG: Error detected in HDF5`

**Solution**:
```julia
using Pkg
Pkg.build("HDF5")
```

### Memory Issues (N > 100)

**Symptoms**: Jobs killed by OOM

**Solutions**:
1. Reduce snapshot frequency
2. Use time slicing: Load trajectories in chunks
3. Increase SLURM memory: `#SBATCH --mem=16G`

### Conservation Warnings

**Warning**: `ΔE/E₀ > 1e-6`

**Check**:
- Projection enabled? (default: yes, every 100 steps)
- dt_min too large? (default: 1e-10, should be fine)
- Very high energy cases? (E/N > 1.0 may need dt_min smaller)

---

## Performance Optimization

### Parallelization

**Automatic behavior**:
- N < 50: Sequential (overhead dominates)
- N ≥ 50: Parallel (8-12x speedup)

**Force mode**:
```bash
# Force sequential (debugging)
julia run_single_experiment.jl ... --no-use_parallel

# Force parallel (N < 50, testing)
julia run_single_experiment.jl ... --use_parallel
```

### Computational Cost Estimates

**Per simulation** (t_max = 50s):

| N   | Sequential | Parallel (24 threads) | Speedup |
|:----|:-----------|:----------------------|:--------|
| 20  | 3 min      | 3 min                 | 1.0x    |
| 40  | 8 min      | 8 min                 | 1.0x    |
| 80  | 30 min     | 5 min                 | 6x      |
| 160 | 2 hours    | 12 min                | 10x     |
| 320 | 8 hours    | 40 min                | 12x     |

**Campaign totals**:

| Design  | Runs   | Time (24 cores) | Storage |
|:--------|:-------|:----------------|:--------|
| Pilot   | 540    | ~10 hours       | ~5 GB   |
| Minimal | 1,620  | ~1.5 days       | ~15 GB  |
| Full    | 11,250 | ~2.5 days       | ~60 GB  |

---

## Advanced Usage

### Custom Parameter Sweep

**Edit** `generate_parameter_matrix.jl`:

```julia
# Add custom eccentricity values
eccentricities_custom = [
    (e=0.5, a_b=1.15, label="Custom1"),
    (e=0.9, a_b=2.29, label="Custom2"),
]
```

### Custom Analysis

**Write your own analyzer**:

```julia
using HDF5
include("src/io_hdf5.jl")

# Load all runs for a combination
seed_dirs = readdir("results/campaign/e0.866_N040_phi0.06_E0.32", join=true)

for seed_dir in filter(isdir, seed_dirs)
    hdf5_file = joinpath(seed_dir, "trajectories.h5")
    data = load_trajectories_hdf5(hdf5_file)

    # Your custom analysis
    custom_metric = my_analysis_function(data)

    println("Seed $seed_dir: $custom_metric")
end
```

### Export to Other Tools

**MATLAB**:
```matlab
h5disp('trajectories.h5')
phi = h5read('trajectories.h5', '/trajectories/phi');
```

**Python (NumPy)**:
```python
import h5py
import numpy as np

with h5py.File('trajectories.h5', 'r') as f:
    phi = f['trajectories/phi'][:]
    times = f['trajectories/time'][:]
```

---

## Next Steps

1. ✅ **Validate pipeline**: `julia test_pipeline.jl`
2. ✅ **Generate matrix**: `julia generate_parameter_matrix.jl pilot`
3. ⏳ **Launch pilot**: `./launch_campaign.sh parameter_matrix_pilot.csv --mode parallel`
4. ⏳ **Analyze results**: `julia analyze_ensemble.jl ...`
5. ⏳ **Generate phase diagrams**: `julia create_phase_diagrams.jl ...`
6. ⏳ **Compare with theory**: Run coarsening collapse analysis
7. ⏳ **Write paper**: Results → manuscript

---

## Support

**Documentation**:
- Design: `EXPERIMENTAL_DESIGN_MASTER.md`
- Pipeline: `PIPELINE_GUIDE.md` (this file)
- Science: `SCIENTIFIC_FINDINGS.md`
- Code: `CLAUDE.md`

**Questions**:
- Check existing docs
- Review example runs in `results/pipeline_test_*/`
- Inspect source: `src/coarsening_analysis.jl`, `src/io_hdf5.jl`

---

**Status**: Pipeline ready for production use ✓
**Last updated**: 2025-11-14
**Version**: v1.0
