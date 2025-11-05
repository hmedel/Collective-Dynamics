# Examples: Dynamics on Curves in R³

This directory contains examples demonstrating collective dynamics on parametric curves embedded in 3D space.

## Files

### `example_single_particle.py`
Explores single particle dynamics under different force laws:
- **Example 1**: Free particle on a helix (constant parameter velocity)
- **Example 2**: Constant physical speed on a helix
- **Example 3**: Curvature-driven dynamics (particle attracted to high-curvature regions)
- **Example 4**: Dynamics on Viviani's curve (variable curvature)
- **Example 5**: Side-by-side comparison of different dynamics

Run with:
```bash
python example_single_particle.py
```

Generates figures:
- `example_1_helix_free_particle.png`
- `example_2_helix_constant_speed.png`
- `example_3_helix_curvature_driven.png`
- `example_4_viviani_geometry.png`
- `example_4_viviani_dynamics.png`
- `example_5_comparison.png`

### `example_multi_particle.py`
Demonstrates collective dynamics with multiple interacting particles:
- **Example 1**: Kuramoto synchronization on a circle
- **Example 2**: Attractive interactions leading to clustering
- **Example 3**: Repulsive interactions causing particles to spread
- **Example 4**: Vicsek-like velocity alignment

Run with:
```bash
python example_multi_particle.py
```

Generates figures:
- `example_multi_1_kuramoto.png`
- `example_multi_2_attractive.png`
- `example_multi_3_repulsive.png`
- `example_multi_4_vicsek.png`

## Key Concepts

### Curvature-Driven Dynamics
The force on a particle depends on the local curvature κ(t):
```
d²t/dτ² = f(κ(t))
```

Example force functions:
- Attractive to high curvature: `f(κ) = α·κ - β`
- Repulsive from high curvature: `f(κ) = -α·κ + β`

### Kuramoto Synchronization
Multiple particles with different natural frequencies synchronize through coupling:
```
dθᵢ/dt = ωᵢ + (K/N) Σⱼ sin(θⱼ - θᵢ)
```

The order parameter R measures synchronization (R = 1 means perfect sync).

### Interaction Types
- **Attractive**: Particles cluster together
- **Repulsive**: Particles spread out evenly
- **Vicsek-like**: Particles align their velocities (flocking)

## Customization

You can easily modify the examples to:
- Use different curves (helix, circle, Viviani, or custom)
- Change interaction strengths and ranges
- Vary the number of particles
- Implement new force functions
- Adjust visualization parameters

See the source code for detailed comments and parameter descriptions.

## Next Steps

After exploring these examples, try:
1. Combining curvature-driven forces with interactions
2. Creating custom curves with specific curvature profiles
3. Implementing new interaction functions
4. Moving to 2D surfaces (coming in `02_surfaces_in_R3/`)
