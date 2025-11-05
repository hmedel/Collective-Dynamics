"""
Example 2: Multi-Particle Collective Dynamics on Curves in R³

This example demonstrates collective dynamics of multiple particles on curves,
including:
1. Kuramoto-like synchronization
2. Attractive interactions
3. Repulsive interactions
4. Vicsek-like alignment

These examples show how collective behavior emerges from local interactions
on curved manifolds.

Author: Collective Dynamics Project
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..'))

import numpy as np
import matplotlib.pyplot as plt

from src.geometry.curves import helix, circle
from src.dynamics.curve_dynamics import (
    MultiParticleSystem,
    kuramoto_interaction,
    attractive_interaction,
    repulsive_interaction,
    vicsek_like_interaction
)
from src.visualization.plot_curves import (
    plot_curve_3d,
    plot_multi_particle_trajectories
)


def example_1_kuramoto_sync():
    """
    Example 1: Kuramoto synchronization on a circle.

    Multiple particles with different natural frequencies synchronize
    through Kuramoto-like coupling on a circular curve.
    """
    print("=" * 60)
    print("Example 1: Kuramoto Synchronization on a Circle")
    print("=" * 60)

    # Create a circle
    curve = circle(radius=2.0)

    # Number of particles
    n_particles = 8

    # Natural frequencies (distributed around 1.0)
    natural_frequencies = np.linspace(0.5, 1.5, n_particles)

    # Create interaction
    coupling = 2.0
    interaction = kuramoto_interaction(coupling, natural_frequencies)

    # Create multi-particle system
    system = MultiParticleSystem(curve, n_particles, interaction)

    # Initial conditions (evenly spaced on circle)
    initial_positions = np.linspace(0, 2*np.pi, n_particles, endpoint=False)
    initial_velocities = natural_frequencies * 0.1  # Start near natural frequencies

    # Integrate
    times, positions, velocities = system.integrate(
        initial_positions,
        initial_velocities,
        t_span=(0, 20),
        n_points=1000,
        damping=0.1
    )

    # Get spatial trajectories
    times_spatial, trajectories = system.spatial_trajectories(
        initial_positions,
        initial_velocities,
        t_span=(0, 20),
        n_points=1000,
        damping=0.1
    )

    # Create visualization
    fig = plt.figure(figsize=(16, 6))

    # Plot 1: 3D trajectories
    ax1 = fig.add_subplot(131, projection='3d')
    plot_multi_particle_trajectories(curve, times_spatial, trajectories,
                                    t_range=(0, 2*np.pi), ax=ax1)
    ax1.set_title('Particle Trajectories')

    # Plot 2: Positions over time
    ax2 = fig.add_subplot(132)
    for i in range(n_particles):
        ax2.plot(times, positions[:, i], linewidth=1.5, alpha=0.8)
    ax2.set_xlabel('Time')
    ax2.set_ylabel('Position (mod 2π)')
    ax2.set_title('Positions vs Time')
    ax2.grid(True, alpha=0.3)

    # Plot 3: Order parameter (measure of synchronization)
    ax3 = fig.add_subplot(133)
    order_param = np.zeros(len(times))
    for t_idx in range(len(times)):
        # Compute Kuramoto order parameter
        phases = positions[t_idx, :]
        order_param[t_idx] = abs(np.mean(np.exp(1j * phases)))

    ax3.plot(times, order_param, 'r-', linewidth=2)
    ax3.set_xlabel('Time')
    ax3.set_ylabel('Order Parameter R')
    ax3.set_title('Synchronization Measure')
    ax3.set_ylim([0, 1.1])
    ax3.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig('example_multi_1_kuramoto.png', dpi=150, bbox_inches='tight')
    print("Saved figure: example_multi_1_kuramoto.png")
    print(f"Final order parameter: {order_param[-1]:.3f}")
    print()


def example_2_attractive():
    """
    Example 2: Particles with attractive interactions on a helix.

    Particles attract each other and form clusters.
    """
    print("=" * 60)
    print("Example 2: Attractive Interactions on a Helix")
    print("=" * 60)

    # Create a helix
    curve = helix(radius=1.5, pitch=2.0)

    # Number of particles
    n_particles = 10

    # Create attractive interaction
    coupling = 0.5
    interaction = attractive_interaction(coupling, range_param=np.inf)

    # Create multi-particle system
    system = MultiParticleSystem(curve, n_particles, interaction)

    # Initial conditions (random positions)
    np.random.seed(42)
    initial_positions = np.random.uniform(0, 2*np.pi, n_particles)
    initial_velocities = np.random.uniform(-0.2, 0.2, n_particles)

    # Integrate
    times_spatial, trajectories = system.spatial_trajectories(
        initial_positions,
        initial_velocities,
        t_span=(0, 30),
        n_points=1000,
        damping=0.2
    )

    # Create visualization
    fig = plt.figure(figsize=(12, 5))

    ax1 = fig.add_subplot(121, projection='3d')
    plot_multi_particle_trajectories(curve, times_spatial, trajectories,
                                    t_range=(0, 4*np.pi), ax=ax1)
    ax1.set_title('Attractive Interactions: Clustering')

    # Plot pairwise distances over time
    times, positions, velocities = system.integrate(
        initial_positions,
        initial_velocities,
        t_span=(0, 30),
        n_points=1000,
        damping=0.2
    )

    ax2 = fig.add_subplot(122)
    # Compute mean pairwise distance
    mean_distances = np.zeros(len(times))
    for t_idx in range(len(times)):
        dists = []
        for i in range(n_particles):
            for j in range(i+1, n_particles):
                # Distance in parameter space (mod 2π)
                dist = abs(positions[t_idx, i] - positions[t_idx, j])
                dist = min(dist, 2*np.pi - dist)
                dists.append(dist)
        mean_distances[t_idx] = np.mean(dists)

    ax2.plot(times, mean_distances, 'b-', linewidth=2)
    ax2.set_xlabel('Time')
    ax2.set_ylabel('Mean Pairwise Distance')
    ax2.set_title('Clustering Measure')
    ax2.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig('example_multi_2_attractive.png', dpi=150, bbox_inches='tight')
    print("Saved figure: example_multi_2_attractive.png")
    print(f"Initial mean distance: {mean_distances[0]:.3f}")
    print(f"Final mean distance: {mean_distances[-1]:.3f}")
    print()


def example_3_repulsive():
    """
    Example 3: Particles with repulsive interactions on a circle.

    Particles repel each other and spread out evenly.
    """
    print("=" * 60)
    print("Example 3: Repulsive Interactions on a Circle")
    print("=" * 60)

    # Create a circle
    curve = circle(radius=2.0)

    # Number of particles
    n_particles = 6

    # Create repulsive interaction
    coupling = 1.0
    interaction = repulsive_interaction(coupling, cutoff=0.1)

    # Create multi-particle system
    system = MultiParticleSystem(curve, n_particles, interaction)

    # Initial conditions (clustered)
    initial_positions = np.random.uniform(0, 1, n_particles)  # Start clustered
    initial_velocities = np.zeros(n_particles)

    # Integrate
    times_spatial, trajectories = system.spatial_trajectories(
        initial_positions,
        initial_velocities,
        t_span=(0, 20),
        n_points=1000,
        damping=0.3
    )

    times, positions, velocities = system.integrate(
        initial_positions,
        initial_velocities,
        t_span=(0, 20),
        n_points=1000,
        damping=0.3
    )

    # Create visualization
    fig = plt.figure(figsize=(16, 6))

    # Plot 1: 3D trajectories
    ax1 = fig.add_subplot(131, projection='3d')
    plot_multi_particle_trajectories(curve, times_spatial, trajectories,
                                    t_range=(0, 2*np.pi), ax=ax1)
    ax1.set_title('Repulsive Interactions: Spreading')

    # Plot 2: Positions over time
    ax2 = fig.add_subplot(132)
    for i in range(n_particles):
        ax2.plot(times, positions[:, i] % (2*np.pi), linewidth=2, alpha=0.8,
                marker='o', markevery=100, markersize=4)
    ax2.set_xlabel('Time')
    ax2.set_ylabel('Position (mod 2π)')
    ax2.set_title('Positions vs Time (spreading out)')
    ax2.grid(True, alpha=0.3)

    # Plot 3: Snapshot at different times
    ax3 = fig.add_subplot(133, projection='polar')
    time_snapshots = [0, len(times)//3, 2*len(times)//3, -1]
    colors = ['red', 'orange', 'blue', 'green']
    labels = ['t=0', 't=T/3', 't=2T/3', 't=T']

    for idx, (t_idx, color, label) in enumerate(zip(time_snapshots, colors, labels)):
        theta = positions[t_idx, :] % (2*np.pi)
        r = np.ones(n_particles) * (1 + idx * 0.2)
        ax3.scatter(theta, r, s=100, color=color, label=label, zorder=10)

    ax3.set_ylim([0, 2])
    ax3.set_title('Particle Positions (polar view)')
    ax3.legend(loc='upper right', bbox_to_anchor=(1.3, 1.0))

    plt.tight_layout()
    plt.savefig('example_multi_3_repulsive.png', dpi=150, bbox_inches='tight')
    print("Saved figure: example_multi_3_repulsive.png")
    print()


def example_4_vicsek_alignment():
    """
    Example 4: Vicsek-like alignment on a helix.

    Particles align their velocities, similar to flocking behavior.
    """
    print("=" * 60)
    print("Example 4: Vicsek-like Alignment on a Helix")
    print("=" * 60)

    # Create a helix
    curve = helix(radius=1.5, pitch=3.0)

    # Number of particles
    n_particles = 12

    # Create Vicsek-like interaction
    coupling = 2.0
    noise = 0.1
    interaction = vicsek_like_interaction(coupling, noise)

    # Create multi-particle system
    system = MultiParticleSystem(curve, n_particles, interaction)

    # Initial conditions (random)
    np.random.seed(123)
    initial_positions = np.random.uniform(0, 4*np.pi, n_particles)
    initial_velocities = np.random.uniform(-0.5, 0.5, n_particles)

    # Integrate
    times, positions, velocities = system.integrate(
        initial_positions,
        initial_velocities,
        t_span=(0, 25),
        n_points=1000,
        damping=0.05
    )

    times_spatial, trajectories = system.spatial_trajectories(
        initial_positions,
        initial_velocities,
        t_span=(0, 25),
        n_points=1000,
        damping=0.05
    )

    # Create visualization
    fig = plt.figure(figsize=(16, 6))

    # Plot 1: 3D trajectories
    ax1 = fig.add_subplot(131, projection='3d')
    plot_multi_particle_trajectories(curve, times_spatial, trajectories,
                                    t_range=(0, 6*np.pi), ax=ax1)
    ax1.set_title('Vicsek Alignment on Helix')

    # Plot 2: Velocities over time
    ax2 = fig.add_subplot(132)
    for i in range(n_particles):
        ax2.plot(times, velocities[:, i], linewidth=1, alpha=0.6)
    ax2.plot(times, np.mean(velocities, axis=1), 'r-', linewidth=3,
            label='Mean velocity')
    ax2.set_xlabel('Time')
    ax2.set_ylabel('Velocity')
    ax2.set_title('Velocity Alignment')
    ax2.legend()
    ax2.grid(True, alpha=0.3)

    # Plot 3: Velocity variance (alignment measure)
    ax3 = fig.add_subplot(133)
    velocity_std = np.std(velocities, axis=1)
    ax3.plot(times, velocity_std, 'b-', linewidth=2)
    ax3.set_xlabel('Time')
    ax3.set_ylabel('Velocity Std Dev')
    ax3.set_title('Alignment Measure (lower = more aligned)')
    ax3.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig('example_multi_4_vicsek.png', dpi=150, bbox_inches='tight')
    print("Saved figure: example_multi_4_vicsek.png")
    print(f"Initial velocity std: {velocity_std[0]:.3f}")
    print(f"Final velocity std: {velocity_std[-1]:.3f}")
    print()


def main():
    """Run all multi-particle examples."""
    print("\n" + "=" * 60)
    print("MULTI-PARTICLE COLLECTIVE DYNAMICS ON CURVES IN R³")
    print("=" * 60 + "\n")

    # Run examples
    example_1_kuramoto_sync()
    example_2_attractive()
    example_3_repulsive()
    example_4_vicsek_alignment()

    print("=" * 60)
    print("All multi-particle examples completed successfully!")
    print("=" * 60)


if __name__ == "__main__":
    main()
