"""
Visualization tools for curves and dynamics in R³.

This module provides functions to visualize parametric curves, their
Frenet-Serret frames, curvature profiles, and particle trajectories.
"""

import numpy as np
import matplotlib.pyplot as plt
from matplotlib import animation
from mpl_toolkits.mplot3d import Axes3D
from typing import Optional, Tuple, List

from ..geometry.curves import ParametricCurve, FrenetFrame


def plot_curve_3d(curve: ParametricCurve,
                  t_range: Tuple[float, float],
                  n_points: int = 1000,
                  ax: Optional[plt.Axes] = None,
                  show_frenet: bool = False,
                  frenet_points: Optional[List[float]] = None,
                  scale: float = 0.5,
                  color: str = 'blue',
                  linewidth: float = 2.0,
                  **kwargs) -> plt.Axes:
    """
    Plot a parametric curve in 3D.

    Args:
        curve: ParametricCurve object to plot
        t_range: Parameter range (t_min, t_max)
        n_points: Number of points to sample
        ax: Optional existing axes (creates new if None)
        show_frenet: Whether to show Frenet-Serret frames
        frenet_points: Parameter values where to show frames
        scale: Scale factor for frame vectors
        color: Color of the curve
        linewidth: Width of the curve line
        **kwargs: Additional arguments passed to plot

    Returns:
        Matplotlib 3D axes object
    """
    if ax is None:
        fig = plt.figure(figsize=(10, 8))
        ax = fig.add_subplot(111, projection='3d')

    # Sample the curve
    t_values = np.linspace(t_range[0], t_range[1], n_points)
    points = curve.evaluate_array(t_values)

    # Plot the curve
    ax.plot(points[:, 0], points[:, 1], points[:, 2],
           color=color, linewidth=linewidth, label='Curve', **kwargs)

    # Plot Frenet frames if requested
    if show_frenet and frenet_points is not None:
        for t in frenet_points:
            point = curve(t)
            frame = curve.frenet_frame(t)

            # Plot tangent (red), normal (green), binormal (blue)
            ax.quiver(point[0], point[1], point[2],
                     frame.tangent[0], frame.tangent[1], frame.tangent[2],
                     color='red', length=scale, arrow_length_ratio=0.3,
                     linewidth=1.5)
            ax.quiver(point[0], point[1], point[2],
                     frame.normal[0], frame.normal[1], frame.normal[2],
                     color='green', length=scale, arrow_length_ratio=0.3,
                     linewidth=1.5)
            ax.quiver(point[0], point[1], point[2],
                     frame.binormal[0], frame.binormal[1], frame.binormal[2],
                     color='blue', length=scale, arrow_length_ratio=0.3,
                     linewidth=1.5)

    ax.set_xlabel('X')
    ax.set_ylabel('Y')
    ax.set_zlabel('Z')
    ax.set_title('Parametric Curve in R³')

    # Equal aspect ratio
    set_axes_equal(ax)

    return ax


def plot_curvature_profile(curve: ParametricCurve,
                           t_range: Tuple[float, float],
                           n_points: int = 500,
                           ax: Optional[plt.Axes] = None,
                           show_torsion: bool = True) -> plt.Axes:
    """
    Plot the curvature and torsion as functions of the parameter.

    Args:
        curve: ParametricCurve object
        t_range: Parameter range (t_min, t_max)
        n_points: Number of points to sample
        ax: Optional existing axes
        show_torsion: Whether to also plot torsion

    Returns:
        Matplotlib axes object
    """
    if ax is None:
        fig, ax = plt.subplots(figsize=(10, 6))

    t_values = np.linspace(t_range[0], t_range[1], n_points)
    curvatures = np.array([curve.curvature(t) for t in t_values])

    ax.plot(t_values, curvatures, 'b-', linewidth=2, label='Curvature κ(t)')

    if show_torsion:
        torsions = np.array([curve.torsion(t) for t in t_values])
        ax.plot(t_values, torsions, 'r--', linewidth=2, label='Torsion τ(t)')

    ax.set_xlabel('Parameter t')
    ax.set_ylabel('Value')
    ax.set_title('Curvature and Torsion Profile')
    ax.legend()
    ax.grid(True, alpha=0.3)

    return ax


def plot_trajectory_on_curve(curve: ParametricCurve,
                             times: np.ndarray,
                             positions: np.ndarray,
                             t_range: Optional[Tuple[float, float]] = None,
                             n_curve_points: int = 1000,
                             ax: Optional[plt.Axes] = None,
                             show_start: bool = True,
                             show_end: bool = True,
                             particle_color: str = 'red',
                             **kwargs) -> plt.Axes:
    """
    Plot a particle trajectory on a curve.

    Args:
        curve: ParametricCurve object
        times: Time array
        positions: Parameter positions array
        t_range: Parameter range for plotting curve (uses positions range if None)
        n_curve_points: Number of points for the background curve
        ax: Optional existing axes
        show_start: Whether to mark the starting point
        show_end: Whether to mark the ending point
        particle_color: Color for particle trajectory
        **kwargs: Additional arguments

    Returns:
        Matplotlib 3D axes object
    """
    if ax is None:
        fig = plt.figure(figsize=(10, 8))
        ax = fig.add_subplot(111, projection='3d')

    # Determine plot range
    if t_range is None:
        t_range = (positions.min(), positions.max())

    # Plot the background curve
    plot_curve_3d(curve, t_range, n_curve_points, ax=ax,
                 color='lightgray', alpha=0.5, linewidth=1)

    # Convert parameter positions to spatial positions
    trajectory = np.array([curve(t) for t in positions])

    # Plot the trajectory
    ax.plot(trajectory[:, 0], trajectory[:, 1], trajectory[:, 2],
           color=particle_color, linewidth=2, label='Particle trajectory')

    # Mark start and end
    if show_start:
        ax.scatter(*trajectory[0], color='green', s=100,
                  marker='o', label='Start', zorder=5)

    if show_end:
        ax.scatter(*trajectory[-1], color='red', s=100,
                  marker='s', label='End', zorder=5)

    ax.set_xlabel('X')
    ax.set_ylabel('Y')
    ax.set_zlabel('Z')
    ax.set_title('Particle Trajectory on Curve')
    ax.legend()

    set_axes_equal(ax)

    return ax


def plot_multi_particle_trajectories(curve: ParametricCurve,
                                     times: np.ndarray,
                                     trajectories: np.ndarray,
                                     t_range: Optional[Tuple[float, float]] = None,
                                     n_curve_points: int = 1000,
                                     ax: Optional[plt.Axes] = None,
                                     colors: Optional[List[str]] = None,
                                     show_markers: bool = True,
                                     **kwargs) -> plt.Axes:
    """
    Plot multiple particle trajectories on a curve.

    Args:
        curve: ParametricCurve object
        times: Time array
        trajectories: Spatial trajectories array of shape (n_times, n_particles, 3)
        t_range: Parameter range for the curve
        n_curve_points: Number of points for background curve
        ax: Optional existing axes
        colors: List of colors for each particle
        show_markers: Whether to show start/end markers
        **kwargs: Additional arguments

    Returns:
        Matplotlib 3D axes object
    """
    if ax is None:
        fig = plt.figure(figsize=(12, 9))
        ax = fig.add_subplot(111, projection='3d')

    n_particles = trajectories.shape[1]

    # Default colors
    if colors is None:
        cmap = plt.cm.viridis
        colors = [cmap(i / n_particles) for i in range(n_particles)]

    # Plot background curve
    if t_range is None:
        # Estimate range from trajectories
        all_positions = trajectories.reshape(-1, 3)
        t_range = (0, 2 * np.pi)  # Default fallback

    plot_curve_3d(curve, t_range, n_curve_points, ax=ax,
                 color='lightgray', alpha=0.3, linewidth=1)

    # Plot each particle trajectory
    for i in range(n_particles):
        traj = trajectories[:, i, :]
        ax.plot(traj[:, 0], traj[:, 1], traj[:, 2],
               color=colors[i], linewidth=1.5, alpha=0.8,
               label=f'Particle {i+1}')

        if show_markers:
            ax.scatter(*traj[0], color=colors[i], s=50, marker='o', zorder=5)
            ax.scatter(*traj[-1], color=colors[i], s=50, marker='s', zorder=5)

    ax.set_xlabel('X')
    ax.set_ylabel('Y')
    ax.set_zlabel('Z')
    ax.set_title(f'Multi-Particle Dynamics on Curve ({n_particles} particles)')

    # Legend only if not too many particles
    if n_particles <= 10:
        ax.legend()

    set_axes_equal(ax)

    return ax


def plot_phase_space(times: np.ndarray,
                    positions: np.ndarray,
                    velocities: np.ndarray,
                    ax: Optional[plt.Axes] = None,
                    **kwargs) -> plt.Axes:
    """
    Plot phase space (position vs velocity).

    Args:
        times: Time array
        positions: Position array
        velocities: Velocity array
        ax: Optional existing axes
        **kwargs: Additional arguments

    Returns:
        Matplotlib axes object
    """
    if ax is None:
        fig, ax = plt.subplots(figsize=(8, 6))

    ax.plot(positions, velocities, linewidth=1.5, **kwargs)
    ax.scatter(positions[0], velocities[0], color='green',
              s=100, marker='o', label='Start', zorder=5)
    ax.scatter(positions[-1], velocities[-1], color='red',
              s=100, marker='s', label='End', zorder=5)

    ax.set_xlabel('Position (parameter t)')
    ax.set_ylabel('Velocity (dt/dτ)')
    ax.set_title('Phase Space')
    ax.legend()
    ax.grid(True, alpha=0.3)

    return ax


def animate_particle_on_curve(curve: ParametricCurve,
                              times: np.ndarray,
                              positions: np.ndarray,
                              t_range: Tuple[float, float],
                              n_curve_points: int = 1000,
                              interval: int = 20,
                              trail_length: int = 50,
                              save_path: Optional[str] = None) -> animation.FuncAnimation:
    """
    Create an animation of a particle moving on a curve.

    Args:
        curve: ParametricCurve object
        times: Time array
        positions: Parameter positions array
        t_range: Parameter range for the curve
        n_curve_points: Number of points for background curve
        interval: Interval between frames in milliseconds
        trail_length: Length of the particle trail
        save_path: Optional path to save the animation

    Returns:
        FuncAnimation object
    """
    fig = plt.figure(figsize=(10, 8))
    ax = fig.add_subplot(111, projection='3d')

    # Plot the curve
    t_values = np.linspace(t_range[0], t_range[1], n_curve_points)
    curve_points = curve.evaluate_array(t_values)
    ax.plot(curve_points[:, 0], curve_points[:, 1], curve_points[:, 2],
           color='lightgray', linewidth=2, alpha=0.5)

    # Convert positions to spatial coordinates
    trajectory = np.array([curve(t) for t in positions])

    # Initialize particle and trail
    particle, = ax.plot([], [], [], 'ro', markersize=10, label='Particle')
    trail, = ax.plot([], [], [], 'r-', linewidth=2, alpha=0.6, label='Trail')

    ax.set_xlabel('X')
    ax.set_ylabel('Y')
    ax.set_zlabel('Z')
    ax.set_title('Particle Dynamics on Curve')
    ax.legend()

    set_axes_equal(ax)

    def init():
        particle.set_data([], [])
        particle.set_3d_properties([])
        trail.set_data([], [])
        trail.set_3d_properties([])
        return particle, trail

    def animate(frame):
        # Current position
        current_pos = trajectory[frame]
        particle.set_data([current_pos[0]], [current_pos[1]])
        particle.set_3d_properties([current_pos[2]])

        # Trail
        start_idx = max(0, frame - trail_length)
        trail_points = trajectory[start_idx:frame+1]
        trail.set_data(trail_points[:, 0], trail_points[:, 1])
        trail.set_3d_properties(trail_points[:, 2])

        return particle, trail

    anim = animation.FuncAnimation(
        fig, animate, init_func=init,
        frames=len(times), interval=interval, blit=True
    )

    if save_path:
        anim.save(save_path, writer='pillow', fps=30)

    return anim


def set_axes_equal(ax: plt.Axes):
    """
    Set equal aspect ratio for 3D plots.

    Makes sure that the scaling is equal in all directions.

    Args:
        ax: Matplotlib 3D axes object
    """
    limits = np.array([
        ax.get_xlim3d(),
        ax.get_ylim3d(),
        ax.get_zlim3d(),
    ])

    center = np.mean(limits, axis=1)
    radius = 0.5 * np.max(np.abs(limits[:, 1] - limits[:, 0]))

    ax.set_xlim3d([center[0] - radius, center[0] + radius])
    ax.set_ylim3d([center[1] - radius, center[1] + radius])
    ax.set_zlim3d([center[2] - radius, center[2] + radius])


def plot_summary_figure(curve: ParametricCurve,
                       times: np.ndarray,
                       positions: np.ndarray,
                       velocities: np.ndarray,
                       t_range: Tuple[float, float],
                       figsize: Tuple[float, float] = (16, 10)) -> plt.Figure:
    """
    Create a comprehensive summary figure with multiple panels.

    Args:
        curve: ParametricCurve object
        times: Time array
        positions: Parameter positions
        velocities: Velocities
        t_range: Parameter range for the curve
        figsize: Figure size

    Returns:
        Matplotlib figure object
    """
    fig = plt.figure(figsize=figsize)

    # 3D trajectory
    ax1 = fig.add_subplot(2, 3, 1, projection='3d')
    plot_trajectory_on_curve(curve, times, positions, t_range=t_range, ax=ax1)

    # Curvature profile
    ax2 = fig.add_subplot(2, 3, 2)
    plot_curvature_profile(curve, t_range, ax=ax2)

    # Phase space
    ax3 = fig.add_subplot(2, 3, 3)
    plot_phase_space(times, positions, velocities, ax=ax3)

    # Position vs time
    ax4 = fig.add_subplot(2, 3, 4)
    ax4.plot(times, positions, 'b-', linewidth=2)
    ax4.set_xlabel('Time τ')
    ax4.set_ylabel('Position (parameter t)')
    ax4.set_title('Position vs Time')
    ax4.grid(True, alpha=0.3)

    # Velocity vs time
    ax5 = fig.add_subplot(2, 3, 5)
    ax5.plot(times, velocities, 'r-', linewidth=2)
    ax5.set_xlabel('Time τ')
    ax5.set_ylabel('Velocity (dt/dτ)')
    ax5.set_title('Velocity vs Time')
    ax5.grid(True, alpha=0.3)

    # Speed in physical space vs time
    ax6 = fig.add_subplot(2, 3, 6)
    physical_speeds = np.array([
        curve.speed(positions[i]) * abs(velocities[i])
        for i in range(len(times))
    ])
    ax6.plot(times, physical_speeds, 'g-', linewidth=2)
    ax6.set_xlabel('Time τ')
    ax6.set_ylabel('Physical Speed |dγ/dτ|')
    ax6.set_title('Physical Speed vs Time')
    ax6.grid(True, alpha=0.3)

    plt.tight_layout()

    return fig
