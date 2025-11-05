# Collective Dynamics on Manifolds

A comprehensive framework for studying collective dynamics of particles constrained to move on curved manifolds. This repository explores how geometry (curvature, torsion) affects the collective behavior of interacting particle systems.

## Overview

This project implements tools and examples for studying:
- **Differential geometry** of curves and surfaces in R³
- **Single and multi-particle dynamics** on curved manifolds
- **Collective phenomena**: synchronization, clustering, pattern formation
- **Geometry-dynamics interplay**: how intrinsic curvature affects collective behavior

The philosophy is to build up from simple to complex: starting with curves in R³, then moving to surfaces, and exploring how intrinsic geometry shapes emergent behavior.

## Features

### 🧮 Differential Geometry Tools
- Parametric curves in R³ with automatic computation of:
  - Frenet-Serret frame (tangent, normal, binormal vectors)
  - Curvature κ and torsion τ
  - Arc length and speed
- Predefined curves: helix, circle, Viviani's curve, lemniscate

### 🎯 Dynamics Models
- **Single particle dynamics**:
  - Free particle (constant parameter velocity)
  - Constant physical speed
  - Curvature-driven dynamics (geometry affects motion)

- **Multi-particle systems**:
  - Kuramoto-like synchronization
  - Attractive/repulsive interactions
  - Vicsek-like alignment
  - Custom interaction functions

### 📊 Visualization Tools
- 3D curve plotting with Frenet frames
- Curvature and torsion profiles
- Trajectory visualization
- Phase space plots
- Multi-particle animations
- Comprehensive summary figures

## Installation

### Requirements
- Python 3.8+
- NumPy
- SciPy
- Matplotlib

### Setup
```bash
# Clone the repository
git clone https://github.com/yourusername/Collective-Dynamics.git
cd Collective-Dynamics

# Install dependencies
pip install -r requirements.txt

# Optional: Install in development mode
pip install -e .
```

## Quick Start

### Example 1: Visualize a curve with its geometric properties

```python
from src.geometry.curves import helix
from src.visualization.plot_curves import plot_curve_3d
import matplotlib.pyplot as plt
import numpy as np

# Create a helix
curve = helix(radius=1.5, pitch=2.0)

# Plot with Frenet frames
fig = plt.figure()
ax = fig.add_subplot(111, projection='3d')
frenet_points = np.linspace(0, 4*np.pi, 8)
plot_curve_3d(curve, (0, 4*np.pi), ax=ax,
             show_frenet=True, frenet_points=frenet_points)
plt.show()

# Compute geometric quantities
t = np.pi
frame = curve.frenet_frame(t)
print(f"Curvature: {frame.curvature:.4f}")
print(f"Torsion: {frame.torsion:.4f}")
```

### Example 2: Single particle with curvature-driven dynamics

```python
from src.geometry.curves import helix
from src.dynamics.curve_dynamics import CurvatureDrivenDynamics

# Create curve and dynamics
curve = helix(radius=1.5, pitch=2.0)

# Particle attracted to high-curvature regions
force_function = lambda kappa: 2.0 * kappa - 0.1
dynamics = CurvatureDrivenDynamics(curve, force_function, damping=0.1)

# Integrate
times, positions, velocities = dynamics.integrate(
    initial_position=0.0,
    initial_velocity=0.5,
    t_span=(0, 30),
    n_points=1000
)
```

### Example 3: Multi-particle Kuramoto synchronization

```python
from src.geometry.curves import circle
from src.dynamics.curve_dynamics import MultiParticleSystem, kuramoto_interaction
import numpy as np

# Create circle and interaction
curve = circle(radius=2.0)
n_particles = 8
natural_frequencies = np.linspace(0.5, 1.5, n_particles)
interaction = kuramoto_interaction(coupling=2.0,
                                  natural_frequencies=natural_frequencies)

# Create system
system = MultiParticleSystem(curve, n_particles, interaction)

# Initial conditions
initial_positions = np.linspace(0, 2*np.pi, n_particles, endpoint=False)
initial_velocities = natural_frequencies * 0.1

# Integrate
times, positions, velocities = system.integrate(
    initial_positions,
    initial_velocities,
    t_span=(0, 20),
    n_points=1000,
    damping=0.1
)

# Measure synchronization
order_param = np.array([abs(np.mean(np.exp(1j * positions[i, :])))
                        for i in range(len(times))])
print(f"Final synchronization: {order_param[-1]:.3f}")
```

## Examples

### Running the Examples

The `examples/` directory contains comprehensive demonstrations:

```bash
# Single particle dynamics
cd examples/01_curves_in_R3
python example_single_particle.py

# Multi-particle collective dynamics
python example_multi_particle.py
```

These generate publication-quality figures showing:
- Free particle motion
- Constant speed dynamics
- Curvature-driven behavior
- Kuramoto synchronization
- Clustering and spreading
- Vicsek-like alignment

### Interactive Notebooks

Launch Jupyter notebooks for interactive exploration:

```bash
jupyter notebook notebooks/01_intro_curves_dynamics.ipynb
```

The notebooks provide:
- Step-by-step tutorials
- Interactive visualizations
- Exercises to explore different scenarios
- Explanations of the mathematics and physics

## Project Structure

```
Collective-Dynamics/
├── src/
│   ├── geometry/           # Differential geometry tools
│   │   ├── curves.py       # Curves in R³
│   │   └── surfaces.py     # Surfaces in R³ (coming soon)
│   ├── dynamics/           # Dynamical systems
│   │   ├── curve_dynamics.py
│   │   └── surface_dynamics.py (coming soon)
│   └── visualization/      # Plotting tools
│       └── plot_curves.py
├── examples/               # Example scripts
│   ├── 01_curves_in_R3/
│   │   ├── example_single_particle.py
│   │   └── example_multi_particle.py
│   └── 02_surfaces_in_R3/ (coming soon)
├── notebooks/              # Jupyter notebooks
│   └── 01_intro_curves_dynamics.ipynb
├── tests/                  # Unit tests
└── docs/                   # Documentation

```

## Mathematical Background

### Differential Geometry of Curves

A parametric curve in R³ is given by γ(t) = (x(t), y(t), z(t)). Key quantities:

- **Tangent vector**: T = γ' / |γ'|
- **Curvature**: κ = |γ' × γ''| / |γ'|³
- **Normal vector**: N = T' / |T'|
- **Binormal vector**: B = T × N
- **Torsion**: τ = (γ' × γ'') · γ''' / |γ' × γ''|²

These form the **Frenet-Serret frame**, which completely characterizes the local geometry of the curve.

### Dynamics on Manifolds

For a particle constrained to a curve γ(t), we parameterize its position by t and study the evolution:
- Position: t(τ) where τ is time
- Velocity: dt/dτ
- Acceleration: d²t/dτ²

The acceleration can depend on:
1. **Geometry**: local curvature κ(t), torsion τ(t)
2. **Interactions**: forces from other particles
3. **External fields**: potentials, damping, etc.

### Collective Phenomena

When multiple particles interact on a manifold, we observe:
- **Synchronization**: particles align their phases (Kuramoto model)
- **Clustering**: particles aggregate due to attractive forces
- **Pattern formation**: spatial structures emerge from local rules
- **Curvature effects**: geometry modulates interaction strength and range

## Roadmap

### Current (v0.1): Curves in R³ ✅
- [x] Differential geometry of curves
- [x] Single particle dynamics
- [x] Multi-particle interactions
- [x] Visualization tools
- [x] Examples and notebooks

### Next (v0.2): Surfaces in R³ 🚧
- [ ] Parametric surfaces with Gaussian and mean curvature
- [ ] Geodesic motion
- [ ] Dynamics on spheres, tori, and general surfaces
- [ ] Surface-based collective dynamics

### Future (v0.3+): Advanced Topics 📋
- [ ] Riemannian manifolds with arbitrary metrics
- [ ] Topological effects on dynamics
- [ ] Active matter on curved surfaces
- [ ] Connection to continuum models

## Contributing

Contributions are welcome! Areas of interest:
- New interaction models
- Additional geometric objects
- Performance optimizations
- Documentation improvements
- More examples and applications

Please open an issue or pull request.

## Citation

If you use this code in your research, please cite:

```bibtex
@software{collective_dynamics_manifolds,
  author = {Your Name},
  title = {Collective Dynamics on Manifolds},
  year = {2025},
  url = {https://github.com/yourusername/Collective-Dynamics}
}
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

Inspired by research on:
- Collective dynamics and self-organization
- Active matter on curved surfaces
- Synchronization phenomena
- Differential geometry and physics

## Contact

For questions, suggestions, or collaborations, please open an issue or contact [your email].

---

**Keywords**: collective dynamics, differential geometry, synchronization, active matter, curved manifolds, Kuramoto model, curvature, emergent behavior
