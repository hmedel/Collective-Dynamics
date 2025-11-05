"""
Example 1: Single Particle Dynamics on Curves in R³

This example demonstrates the dynamics of a single particle moving on
various parametric curves embedded in 3D space. We explore:
1. Different types of curves (helix, circle, Viviani's curve)
2. Different dynamics (free particle, constant speed, curvature-driven)
3. How curvature affects the motion

Author: Collective Dynamics Project
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..'))

import numpy as np
import matplotlib.pyplot as plt

from src.geometry.curves import helix, circle, viviani_curve, ParametricCurve
from src.dynamics.curve_dynamics import (
    FreeParticleDynamics,
    ConstantSpeedDynamics,
    CurvatureDrivenDynamics
)
from src.visualization.plot_curves import (
    plot_curve_3d,
    plot_curvature_profile,
    plot_trajectory_on_curve,
    plot_summary_figure
)


def example_1_helix():
    """
    Example 1: Free particle on a helix.

    A particle moves freely (constant velocity in parameter space) on a helix.
    """
    print("=" * 60)
    print("Example 1: Free Particle on a Helix")
    print("=" * 60)

    # Create a helix
    curve = helix(radius=1.0, pitch=2.0)

    # Initial conditions
    t0 = 0.0
    v0 = 1.0  # Constant velocity in parameter space

    # Create dynamics
    dynamics = FreeParticleDynamics(curve)

    # Integrate
    times, positions, velocities = dynamics.integrate(
        initial_position=t0,
        initial_velocity=v0,
        t_span=(0, 10),
        n_points=500
    )

    # Create summary figure
    fig = plot_summary_figure(curve, times, positions, velocities,
                             t_range=(0, 4*np.pi))

    plt.savefig('example_1_helix_free_particle.png', dpi=150, bbox_inches='tight')
    print("Saved figure: example_1_helix_free_particle.png")
    print()


def example_2_constant_speed():
    """
    Example 2: Particle with constant physical speed on a helix.

    Unlike the free particle, this particle maintains constant speed
    in physical space (not parameter space).
    """
    print("=" * 60)
    print("Example 2: Constant Speed on a Helix")
    print("=" * 60)

    # Create a helix with varying pitch
    curve = helix(radius=1.0, pitch=3.0)

    # Initial conditions
    t0 = 0.0
    v0 = 0.5

    # Create dynamics with constant physical speed
    dynamics = ConstantSpeedDynamics(curve, speed=1.0)

    # Integrate
    times, positions, velocities = dynamics.integrate(
        initial_position=t0,
        initial_velocity=v0,
        t_span=(0, 15),
        n_points=500
    )

    # Create summary figure
    fig = plot_summary_figure(curve, times, positions, velocities,
                             t_range=(0, 4*np.pi))

    plt.savefig('example_2_helix_constant_speed.png', dpi=150, bbox_inches='tight')
    print("Saved figure: example_2_helix_constant_speed.png")
    print()


def example_3_curvature_driven():
    """
    Example 3: Curvature-driven dynamics on a helix.

    The particle experiences a force proportional to the local curvature.
    This demonstrates how geometry affects dynamics.
    """
    print("=" * 60)
    print("Example 3: Curvature-Driven Dynamics on a Helix")
    print("=" * 60)

    # Create a helix
    curve = helix(radius=1.5, pitch=2.0)

    # Force function: particle is attracted to high-curvature regions
    def force_function(kappa):
        return 2.0 * kappa - 0.1  # Attractive force proportional to curvature

    # Initial conditions
    t0 = 0.0
    v0 = 0.5

    # Create curvature-driven dynamics
    dynamics = CurvatureDrivenDynamics(curve, force_function, damping=0.1)

    # Integrate
    times, positions, velocities = dynamics.integrate(
        initial_position=t0,
        initial_velocity=v0,
        t_span=(0, 30),
        n_points=1000
    )

    # Create summary figure
    fig = plot_summary_figure(curve, times, positions, velocities,
                             t_range=(0, 6*np.pi))

    plt.savefig('example_3_helix_curvature_driven.png', dpi=150, bbox_inches='tight')
    print("Saved figure: example_3_helix_curvature_driven.png")
    print()


def example_4_viviani_curve():
    """
    Example 4: Dynamics on Viviani's curve.

    Viviani's curve has non-constant curvature, which creates interesting
    dynamics when the force depends on curvature.
    """
    print("=" * 60)
    print("Example 4: Curvature-Driven Dynamics on Viviani's Curve")
    print("=" * 60)

    # Create Viviani's curve
    curve = viviani_curve(radius=1.0)

    # Plot the curve with Frenet frames
    fig = plt.figure(figsize=(12, 5))

    # Plot 1: Curve with Frenet frames
    ax1 = fig.add_subplot(121, projection='3d')
    frenet_points = np.linspace(0, 2*np.pi, 8)
    plot_curve_3d(curve, (0, 2*np.pi), ax=ax1,
                 show_frenet=True, frenet_points=frenet_points,
                 scale=0.3)
    ax1.set_title("Viviani's Curve with Frenet Frames")

    # Plot 2: Curvature profile
    ax2 = fig.add_subplot(122)
    plot_curvature_profile(curve, (0, 2*np.pi), ax=ax2)

    plt.tight_layout()
    plt.savefig('example_4_viviani_geometry.png', dpi=150, bbox_inches='tight')
    print("Saved figure: example_4_viviani_geometry.png")

    # Now simulate dynamics
    def force_function(kappa):
        # Particle repelled by high curvature
        return -1.0 * kappa + 0.5

    dynamics = CurvatureDrivenDynamics(curve, force_function, damping=0.15)

    # Integrate
    times, positions, velocities = dynamics.integrate(
        initial_position=0.5,
        initial_velocity=0.3,
        t_span=(0, 40),
        n_points=1000
    )

    # Create summary figure
    fig = plot_summary_figure(curve, times, positions, velocities,
                             t_range=(0, 2*np.pi))

    plt.savefig('example_4_viviani_dynamics.png', dpi=150, bbox_inches='tight')
    print("Saved figure: example_4_viviani_dynamics.png")
    print()


def example_5_comparison():
    """
    Example 5: Comparison of different dynamics on the same curve.

    We compare free particle, constant speed, and curvature-driven dynamics
    side by side on a helix.
    """
    print("=" * 60)
    print("Example 5: Comparison of Different Dynamics")
    print("=" * 60)

    # Create a helix
    curve = helix(radius=1.0, pitch=2.0)

    # Common parameters
    t0 = 0.0
    v0 = 0.5
    t_span = (0, 15)
    n_points = 500

    # Dynamics 1: Free particle
    dyn1 = FreeParticleDynamics(curve)
    times1, pos1, vel1 = dyn1.integrate(t0, v0, t_span, n_points)

    # Dynamics 2: Constant speed
    dyn2 = ConstantSpeedDynamics(curve, speed=1.0)
    times2, pos2, vel2 = dyn2.integrate(t0, v0, t_span, n_points)

    # Dynamics 3: Curvature-driven
    force_func = lambda kappa: 1.0 * kappa - 0.05
    dyn3 = CurvatureDrivenDynamics(curve, force_func, damping=0.1)
    times3, pos3, vel3 = dyn3.integrate(t0, v0, t_span, n_points)

    # Create comparison figure
    fig = plt.figure(figsize=(18, 10))

    # Row 1: 3D trajectories
    ax1 = fig.add_subplot(2, 3, 1, projection='3d')
    plot_trajectory_on_curve(curve, times1, pos1, ax=ax1)
    ax1.set_title('Free Particle')

    ax2 = fig.add_subplot(2, 3, 2, projection='3d')
    plot_trajectory_on_curve(curve, times2, pos2, ax=ax2)
    ax2.set_title('Constant Speed')

    ax3 = fig.add_subplot(2, 3, 3, projection='3d')
    plot_trajectory_on_curve(curve, times3, pos3, ax=ax3)
    ax3.set_title('Curvature-Driven')

    # Row 2: Phase space
    ax4 = fig.add_subplot(2, 3, 4)
    ax4.plot(pos1, vel1, 'b-', linewidth=2, label='Free')
    ax4.set_xlabel('Position')
    ax4.set_ylabel('Velocity')
    ax4.set_title('Free Particle Phase Space')
    ax4.grid(True, alpha=0.3)

    ax5 = fig.add_subplot(2, 3, 5)
    ax5.plot(pos2, vel2, 'g-', linewidth=2, label='Constant Speed')
    ax5.set_xlabel('Position')
    ax5.set_ylabel('Velocity')
    ax5.set_title('Constant Speed Phase Space')
    ax5.grid(True, alpha=0.3)

    ax6 = fig.add_subplot(2, 3, 6)
    ax6.plot(pos3, vel3, 'r-', linewidth=2, label='Curvature-Driven')
    ax6.set_xlabel('Position')
    ax6.set_ylabel('Velocity')
    ax6.set_title('Curvature-Driven Phase Space')
    ax6.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig('example_5_comparison.png', dpi=150, bbox_inches='tight')
    print("Saved figure: example_5_comparison.png")
    print()


def main():
    """Run all examples."""
    print("\n" + "=" * 60)
    print("SINGLE PARTICLE DYNAMICS ON CURVES IN R³")
    print("=" * 60 + "\n")

    # Run examples
    example_1_helix()
    example_2_constant_speed()
    example_3_curvature_driven()
    example_4_viviani_curve()
    example_5_comparison()

    print("=" * 60)
    print("All examples completed successfully!")
    print("=" * 60)


if __name__ == "__main__":
    main()
