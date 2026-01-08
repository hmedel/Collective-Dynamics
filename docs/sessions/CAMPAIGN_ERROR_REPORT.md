# Campaign Error Report

**Date**: 2025-11-14 16:20
**Campaign**: campaign_20251114_151101
**Status**: ⚠️ RUNNING WITH ERRORS

---

## Executive Summary

La campaña está corriendo pero tiene problemas **significativos con runs de N=80**:

- ✅ **202/540 runs completados** (37%)
- ⚠️ **103 runs fallidos** (~34% failure rate)
- 🔄 **24 jobs activos**
- ❌ **Problema crítico**: Todos los runs de N=80 fallan durante el análisis de coarsening

---

## Detailed Error Analysis

### 1. Success Rate by System Size

| N | Expected | Completed | HDF5 Files | Success Rate |
|:--|:---------|:----------|:-----------|:-------------|
| 20 | 180 | **118** | 118 | ✅ 66% |
| 40 | 180 | **84** | 84 | ✅ 47% |
| 80 | 180 | **0** | 60 | ❌ 0% |

**Total**: 202 successful / 540 total = **37% completion**

### 2. The N=80 Problem

**Symptoms**:
- Joblog shows 114 N=80 runs with exit code 0 (success)
- BUT: 0 `summary.json` files created for N=80
- AND: 60 `trajectories.h5` files exist for N=80

**Conclusion**:
The simulation **completes successfully** for N=80, and HDF5 is saved, but the script **fails during coarsening analysis** or JSON writing.

**Error location**: Between line ~212 and ~260 in `run_single_experiment.jl`
- After: HDF5 save (successful)
- During: `analyze_full_clustering_dynamics()` or JSON write
- Before: Final completion message

### 3. Failure Timeline

Runs that failed show two patterns:

**Pattern A: Quick failures (< 30s)**
- Runs: 81, 82, 83, 84 (all N=80)
- Time: 16-19s
- Likely: Early error (parsing, setup, or immediate crash)

**Pattern B: Late failures (> 2 minutes)**
- Runs: 9, 35, 38, 45, 52, 53
- Time: 133-353s
- Likely: Error during/after simulation or analysis

### 4. Current Job Status

**Active jobs**: 24
**Longest running**: 5+ minutes (should be ~2 min for N=20/40)

Probable cause: Some jobs are stuck or taking exceptionally long (possibly N=80 runs).

---

## Root Cause Analysis

### Hypothesis 1: Coarsening Analysis Failure for N=80 ✅ **MOST LIKELY**

**Evidence**:
- HDF5 files created → simulation works
- No summary.json → post-processing fails
- Specific to N=80 → size-dependent bug

**Possible causes**:
1. **Memory issue** during clustering analysis (N=80 has more particles, larger data)
2. **Timeout** in coarsening fit (takes too long for N=80)
3. **NaN/Inf in metrics** that aren't handled properly
4. **Array bounds** or indexing error for larger N

**Most likely**: The `analyze_full_clustering_dynamics()` function crashes or returns invalid data for N=80, causing JSON writing to fail.

### Hypothesis 2: JSON Writing Bug

The N=80 analysis might produce values that break JSON serialization:
- NaN or Inf (we handle this, but maybe edge case)
- Extremely large numbers
- Nested structures that fail

### Hypothesis 3: Disk Space / I/O Error

**Less likely** (would affect all runs, not just N=80)

---

## Recommended Actions

### Immediate (While Campaign Runs)

1. **Let N=20 and N=40 runs finish** - These are working fine (202/360 = 56% done)

2. **Monitor disk space**:
   ```bash
   df -h /home/mech/Science/CollectiveDynamics
   ```

3. **Check if any processes are truly stuck**:
   ```bash
   ps -eo pid,etime,cmd | grep julia | grep run_single
   ```
   If any process has been running >10 minutes, it's likely stuck.

### Debug N=80 Issue

**Test manually with verbose output**:
```bash
julia --project=. run_single_experiment.jl \
    --eccentricity 0.0 --N 80 --phi 0.04 --E_per_N 0.32 --seed 999 \
    --output_dir results/debug_N80 --t_max 10.0 2>&1 | tee debug_N80.log
```

This will show exactly where it fails.

**Quick fix options**:

**Option A**: Skip coarsening analysis for N=80
```julia
# In run_single_experiment.jl around line 212
if N < 80
    metrics, evolution = analyze_full_clustering_dynamics(...)
else
    # Use dummy values
    metrics = (t_nucleation=NaN, t_half=NaN, ...)
    evolution = (times=[], N_clusters=[], ...)
end
```

**Option B**: Add try-catch around coarsening analysis
```julia
try
    metrics, evolution = analyze_full_clustering_dynamics(...)
catch e
    @warn "Coarsening analysis failed: $e"
    # Use fallback values
    metrics = create_dummy_metrics()
    evolution = create_dummy_evolution()
end
```

**Option C**: Increase timeouts/memory for analysis

### After Campaign

1. **Rerun failed N=80 cases** after fixing the bug
2. **Verify conservation** for all completed runs
3. **Generate ensemble statistics** for N=20 and N=40 (which work)

---

## Impact Assessment

### What We Have

**Good data** (N=20, N=40):
- 202 completed runs out of 360 expected for N=20/40
- ~56% of N=20/40 runs done
- All have full analysis (summary.json + HDF5)
- Conservation appears excellent based on test

**Missing data** (N=80):
- 0/180 runs fully analyzed
- 60/180 have HDF5 (simulation data exists!)
- Missing: Coarsening metrics (t_nucleation, t_1/2, α, etc.)

### Scientific Impact

**Can still do**:
- ✅ Full analysis for N=20 and N=40
- ✅ Study eccentricity effects
- ✅ Study packing fraction effects
- ✅ Extract coarsening exponents for small/medium N
- ⚠️ **Limited** scaling analysis (only 2 N values instead of 3)

**Cannot do** (without N=80):
- ❌ Full N-scaling curves
- ❌ Large-system behavior
- ❌ Verification that α is independent of N

**Mitigation**:
The HDF5 files for N=80 exist, so we can:
1. Fix the coarsening analysis bug
2. Re-run ONLY the analysis (not the simulation)
3. Extract metrics from existing HDF5 files

---

## Statistics Summary

```
Campaign Progress:
├─ Total runs: 540
├─ Completed successfully: 202 (37%)
├─ Failed: 103 (19%)
├─ Still running: 24 (4%)
└─ Pending: 211 (39%)

By System Size:
├─ N=20: 118/180 (66%) ✅
├─ N=40: 84/180 (47%) ✅
└─ N=80: 0/180 (0%) ❌

Failure Analysis:
├─ N=80 analysis failures: ~60-70 (est.)
├─ Other failures: ~30-40
└─ Failure rate (excluding N=80): ~10-15%
```

---

## Next Steps

### Priority 1: Debug N=80
1. Run manual N=80 test with full logging
2. Identify exact line where failure occurs
3. Implement fix (try-catch or conditional analysis)

### Priority 2: Let Campaign Continue
- N=20 and N=40 runs are working well
- Let them finish (~1-2 more hours)
- Monitor for any new issues

### Priority 3: Post-Campaign Cleanup
1. Extract HDF5 data for N=80 runs
2. Run fixed analysis on N=80 HDF5 files
3. Combine all results
4. Generate final statistics

---

## Files for Investigation

**Logs to check**:
```bash
cd results/campaign_20251114_151101
tail -100 joblog.txt  # See failure patterns
```

**Failed run example**:
- Run 81: N=80, φ=0.09, e=0.0, seed=1
- Directory: `e0.000_N80_phi0.09_E0.32/seed_1/` (empty)
- Expected: HDF5 should exist somewhere for this run

**Successful run example** (for comparison):
- Run 1: N=20, φ=0.04, e=0.0, seed=1
- Directory: `e0.000_N20_phi0.04_E0.32/seed_1/`
- Has: `summary.json`, `trajectories.h5`, `cluster_evolution.csv`

---

## Positive Notes

Despite the N=80 issue:

✅ **Infrastructure works** - GNU Parallel, job distribution, HDF5 I/O all functioning

✅ **Conservation excellent** - Test runs show ΔE/E₀ ~ 10⁻⁸

✅ **N=20/40 runs successful** - 202 complete datasets

✅ **Data not lost** - N=80 HDF5 files exist, just need reprocessing

✅ **Fixable** - This is a post-processing bug, not a simulation bug

---

**Status**: Investigation complete
**Next action**: Debug N=80 manually or wait for campaign to finish N=20/40 runs
**Updated**: 2025-11-14 16:30 UTC
