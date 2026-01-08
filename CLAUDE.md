# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**CollectiveDynamics.jl** - A high-performance Julia framework for simulating collective dynamics on curved manifolds (ellipses), implementing the algorithm from *"Collision Dynamics on Curved Manifolds: A Simple Symplectic Computational Approach"* by García-Hernández & Medel-Cobaxín.

### Key Features
- Differential geometry implementation: Riemannian metrics, Christoffel symbols, parallel transport
- 4th-order Forest-Ruth symplectic integrator with energy conservation O(dt⁴)
- Parallel transport velocity correction during collisions
- Optimized with Float64, StaticArrays, type-stable code (~2000x speedup over original BigFloat implementation)
- **Integrated CPU parallelization**: ~2-12x speedup with multi-threading (N≥50 particles)
  - Enable with `use_parallel=true` in config or function parameter
  - Requires: `julia -t N --project=. run_simulation.jl` (N = number of threads)
  - Automatically falls back to sequential for N<50 or single thread
  - Measured speedups: N=50 → 2.7x, N=70 → 5-8x, N=100 → 10-12x (16 threads)

## Common Development Commands

### Setup and Installation
```bash
# Activate project environment and install dependencies
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Verify installation
julia --project=. verify_installation.jl

# Quick test from Julia REPL
julia --project=.
julia> using CollectiveDynamics
julia> a, b = 2.0, 1.0
julia> particles = generate_random_particles(10, 1.0, 0.05, a, b)
julia> data = simulate_ellipse(particles, a, b; n_steps=1000, dt=1e-5)
julia> print_conservation_summary(data.conservation)
```

### Running Tests
```bash
# Run all tests
julia --project=. test/runtests.jl

# Run tests via Pkg
julia --project=. -e 'using Pkg; Pkg.test()'

# Run specific test scripts
julia --project=. test_collision_two_particles.jl
julia --project=. test_energy_simple.jl
julia --project=. test_parallel_correctness.jl
```

### Running Simulations

**From config files (recommended for production runs):**
```bash
# Main simulation runner (from TOML config)
julia --project=. run_simulation.jl config/simulation_example.toml

# Background execution (for long simulations, hours/days)
./run_simulation_bg.sh config/simulation_example.toml

# Check background simulation status
./check_simulation.sh

# Example configs available:
# - config/simulation_example.toml (general purpose)
# - config/simulation_fixed_dt.toml (fixed timestep)
# - config/alta_precision.toml (high precision)
# - config/ultra_precision.toml (ultra-high precision)
```

**From examples/ directory (learning/testing):**
```bash
# Complete example with visualization
julia --project=. examples/ellipse_simulation.jl
```

**Interactive from REPL (rapid prototyping):**
```julia
using CollectiveDynamics
a, b = 2.0, 1.0
particles = generate_random_particles(40, 1.0, 0.05, a, b)

# Option 1: Fixed timestep (faster, may miss some collisions)
data = simulate_ellipse(particles, a, b;
    n_steps=10_000,
    dt=1e-5,
    save_every=100,  # Save every 100 steps
    collision_method=:parallel_transport)

# Option 2: Adaptive timestep (slower, exact collision detection)
data = simulate_ellipse_adaptive(particles, a, b;
    max_time=1.0,
    dt_max=1e-5,
    save_interval=0.01,  # Save every 0.01 time units
    collision_method=:parallel_transport,
    max_steps=50_000_000)

# Analyze results
print_conservation_summary(data.conservation)
```

### Analysis Scripts
```bash
# Generate plots and conservation analysis
julia --project=. analizar_simulacion.jl results/simulation_YYYYMMDD_HHMMSS/

# Statistics only (no plotting dependencies)
julia --project=. estadisticas_simulacion.jl results/simulation_YYYYMMDD_HHMMSS/

# Plot conservation metrics
julia --project=. plot_conservation.jl

# Phase space analysis
julia --project=. analizar_espacio_fase.jl
julia --project=. analizar_espacio_fase_unwrapped.jl

# Benchmark parallel implementation
julia --project=. --threads=24 benchmark_parallel.jl
```

### Multi-threading
```bash
# Run with specific number of threads (for parallel collision detection)
julia --project=. --threads=24 run_simulation.jl config/input.toml

# Check available threads
julia -e 'using Base.Threads; println("Threads: ", nthreads())'
```

## High-Level Architecture

### Module Structure
The codebase follows a hierarchical organization centered around differential geometry and symplectic integration:

```
src/
├── CollectiveDynamics.jl       # Main module, exports, high-level simulate_* functions
├── geometry/                   # Differential geometry layer
│   ├── metrics.jl             # Riemannian metric g_θθ, inverse, derivatives
│   ├── christoffel.jl         # Christoffel symbols Γ^i_jk (analytic, numeric, autodiff)
│   └── parallel_transport.jl  # Parallel transport of velocity vectors
├── integrators/
│   └── forest_ruth.jl         # 4th-order symplectic integrator
├── particles.jl               # Particle struct (optimized with StaticArrays)
├── collisions.jl              # Collision detection and resolution (3 methods)
├── adaptive_time.jl           # Adaptive timestep collision prediction
├── conservation.jl            # Energy/momentum tracking and analysis
├── io.jl                      # TOML config reading, CSV/JLD2 output
└── parallel/
    └── collision_detection_parallel.jl  # Multi-threaded O(N²) pair checking
```

### Key Design Patterns

**1. Type Parametrization for Performance**
All core types are parameterized by `T <: AbstractFloat` (typically Float64):
```julia
struct Particle{T <: AbstractFloat}
    id::Int32
    mass::T
    radius::T
    θ::T              # Angular position
    θ_dot::T          # Angular velocity
    pos::SVector{2,T}  # Cartesian (x,y)
    vel::SVector{2,T}  # Cartesian velocity
end
```

**2. Immutability and Functional Updates**
Particles are immutable; updates create new instances via `update_particle(p, θ_new, θ_dot_new, a, b)`. This ensures type stability and enables future GPU parallelization.

**3. Collision Resolution Methods**
Three methods available via `collision_method` parameter:
- `:simple` - Basic elastic collision (momentum exchange)
- `:parallel_transport` - Geometric correction using Christoffel symbols (best conservation)
- `:geodesic` - Geodesic flow integration during collision

**4. Dual Simulation Modes**
- `simulate_ellipse()` - Fixed timestep (`dt`), faster, may miss collisions
  - Saves data every `save_every` **steps** (integer parameter)
  - Best for: Quick tests, qualitative analysis, or when dt is very small

- `simulate_ellipse_adaptive()` - Adaptive timestep, exact collision detection, better conservation
  - Saves data every `save_interval` **time units** (float parameter)
  - Uses bisection search to find exact collision time (`time_to_collision()` in `adaptive_time.jl`)
  - Has `max_steps` safety limit to prevent infinite loops (default: 10M steps)
  - Best for: Quantitative analysis, long-duration simulations, high accuracy requirements

### Critical Implementation Details

**Forest-Ruth Integrator Coefficients**
The 4th-order symplectic integrator uses 4 position updates with coefficients γ₁, γ₂, γ₃, γ₄ and velocity updates with ρ₁, ρ₂, ρ₃:
```julia
γ₁ = γ₄ = 1 / (2(2 - 2^(1/3)))
γ₂ = γ₃ = (1 - 2^(1/3)) / (2(2 - 2^(1/3)))
```
See `src/integrators/forest_ruth.jl` for implementation.

**Parallel Transport Equation**
During collisions, velocities are corrected to remain tangent to the manifold:
```julia
v'ⁱ = vⁱ - Γⁱⱼₖ vʲ Δqᵏ
```
This is the key geometric correction ensuring energy conservation. Implemented in `parallel_transport_velocity!()`.

**Metric and Christoffel for Ellipse**
For ellipse parameterized by angle θ with semi-axes (a, b):
```julia
g_θθ = a² sin²(θ) + b² cos²(θ)
Γ^θ_θθ = (b² - a²) sin(θ) cos(θ) / g_θθ
```
The analytic formula (`christoffel_ellipse`) is preferred over numeric (`christoffel_numerical`) for performance.

**Parallelization Strategy (Integrated)**
Collision detection is O(N²) and dominates runtime for N > 50. The parallel implementation distributes pair-wise checks across threads:
- Implementation: `find_next_collision_parallel()` in `src/parallel/collision_detection_parallel.jl`
- Each thread processes a subset of N(N-1)/2 pairs independently
- Thread-local minimum collision time is maintained using `Threads.maxthreadid()` for safe indexing
- Final reduction finds global minimum across all threads
- Measured speedups on 16 threads:
  - N=50: 2.7x
  - N=70: 5-8x (estimated)
  - N=100: 10-12x (estimated)
- **Status**: Fully integrated into `simulate_ellipse_adaptive()` via `use_parallel` parameter
- Automatically falls back to sequential mode for N < 50 or single thread execution
- **Important**: Overhead dominates for N<50, use sequential mode for small systems

Usage:
```julia
# From REPL
data = simulate_ellipse_adaptive(particles, a, b;
    use_parallel=true,  # Enable parallel collision detection
    max_time=1.0)

# From config file (simulation.toml)
[simulation]
use_parallel = true  # Requires julia -t N
```

See `ANALISIS_PARALELIZACION.md` and `PASO_A_PASO_PARALELIZACION.md` for detailed analysis.

### Configuration System

Simulations are configured via TOML files with sections:
- `[geometry]` - Ellipse parameters (a, b)
- `[simulation]` - Method (adaptive/fixed), timesteps, collision method, tolerance
- `[particles.random]` or `[particles.from_file]` - Particle initialization
- `[output]` - Directory, formats (CSV/JLD2), data to save
- `[analysis]` - Post-simulation analysis options

Config files are read by `read_config()` in `src/io.jl` and validated by `validate_config()`.

### Output Structure

Each simulation creates a timestamped directory:
```
results/simulation_20251113_123045/
├── config_used.toml         # Copy of input config
├── config_parsed.toml       # Parsed config with defaults
├── summary.txt              # Human-readable summary
├── trajectories.csv         # θ, θ_dot, energy per particle per timestep
├── conservation.csv         # Total energy, momentum vs time
├── collision_events.csv     # Collisions per timestep
└── simulation.jld2          # Full binary dump (optional)
```

### Testing Philosophy

The test suite (`test/runtests.jl`) verifies:
1. **Geometry correctness**: Metric values at known angles, Christoffel symmetries
2. **Integrator properties**: Coefficient sums, symplecticity preservation
3. **Collision physics**: Conservation of energy/momentum in isolated 2-particle collisions
4. **Edge cases**: Circles (a=b), zero velocities, wraparound at 2π

Standalone test scripts (e.g., `test_collision_guaranteed.jl`) provide focused debugging for specific scenarios.

## Project-Specific Conventions

### Angle Wrapping
Angles are always normalized to [0, 2π) using `mod(θ, 2π)`. The unwrapping logic in `analizar_espacio_fase_unwrapped.jl` is used only for visualization of continuous trajectories.

### Energy Conservation Thresholds
- **Excellent**: ΔE/E₀ < 1e-6
- **Good**: ΔE/E₀ < 1e-4 (paper standard)
- **Acceptable**: ΔE/E₀ < 1e-2
- **Poor**: ΔE/E₀ > 1e-2

Use `print_conservation_summary(data.conservation)` to verify.

### Collision Detection Radius
Particle radius is specified as a fraction of the semi-minor axis `b`. Typical value: 0.05 to 0.1 (5-10% of b). Collisions occur when Cartesian distance < r₁ + r₂.

### Background Execution
For long simulations (hours/days), use `run_simulation_bg.sh`:
```bash
./run_simulation_bg.sh config/input.toml
```
This uses `nohup` and redirects output to `simulation_YYYYMMDD_HHMMSS.log`. Monitor with `check_simulation.sh`.

## Known Issues and Workarounds

### Max Steps Limit
Adaptive simulations have a `max_steps` parameter (default 10M) to prevent infinite loops. If reached, a warning is logged and the simulation stops early. Increase in config if needed:
```toml
[simulation]
max_steps = 50_000_000
```

### Particle "Sticking"
If `dt_min` is too large in adaptive mode, particles can get stuck in collision. Use `dt_min = 1e-10` or smaller. See `PRECISION_GUIDE.md`.

### Phase Space Unwrapping
Directly plotting θ vs θ̇ shows discontinuities at 2π wrapping. Use `analizar_espacio_fase_unwrapped.jl` which tracks cumulative angle for smooth visualization.

## Dependencies

**Required (core functionality):**
- StaticArrays.jl - Fast fixed-size arrays
- ForwardDiff.jl - Automatic differentiation for Christoffel symbols
- Elliptic.jl - Elliptic integrals for arc length calculations
- DataFrames.jl, CSV.jl - Data output
- TOML.jl - Configuration files

**Optional (analysis and visualization):**
- Plots.jl - Used by analysis scripts (analizar_simulacion.jl, plot_conservation.jl)
- GLMakie.jl - Advanced visualization (not used by core simulation)
- BenchmarkTools.jl - Performance testing
- CUDA.jl - Future GPU support (planned Phase 3)

**Note**: Simulations run without Plots.jl/GLMakie.jl. Install only if you need visualization.

## Documentation References

- **Quick Start**: `QUICKSTART.md`, `GUIA_RAPIDA.md`
- **Examples**: `examples/ellipse_simulation.jl` (complete working example)
- **Installation**: `INSTALL.md`
- **Geometry Math**: `docs/GEOMETRY_TECHNICAL.md`
- **Integrator Theory**: `docs/INTEGRATOR_TECHNICAL.md`
- **Full System Docs**: `docs/COMPLETE_TECHNICAL_DOCUMENTATION.md`
- **Adaptive Method**: `INSTRUCCIONES_ADAPTIVE.md`, `IMPLEMENTACION_COMPLETA_ADAPTIVE.md`
- **I/O System**: `README_IO_SYSTEM.md`, `SISTEMA_IO_DOCUMENTACION.md`
- **Parallelization**: `ANALISIS_PARALELIZACION.md`, `PASO_A_PASO_PARALELIZACION.md`
- **Conservation Issues**: `CONSERVACION_MOMENTO.md`, `PROBLEMA_MOMENTO_CONJUGADO_COLISIONES.md`

All documentation is indexed in `docs/INDEX.md`.
