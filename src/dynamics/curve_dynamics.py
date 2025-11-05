"""
Dynamics of particles constrained to curves in R³.

This module implements various dynamical systems for particles moving on
parametric curves, including free motion, curvature-dependent dynamics,
and collective interactions.
"""

import numpy as np
from typing import Callable, Optional, List, Tuple
from scipy.integrate import solve_ivp
from dataclasses import dataclass

from ..geometry.curves import ParametricCurve


@dataclass
class ParticleState:
    """
    State of a particle on a curve.

    Attributes:
        position: Parameter value t on the curve
        velocity: Time derivative of parameter dt/dτ
    """
    position: float  # t parameter
    velocity: float  # dt/dτ


class CurveDynamics:
    """
    Base class for dynamics of particles on a curve.

    This class handles the integration of equations of motion for particles
    constrained to move along a parametric curve.
    """

    def __init__(self, curve: ParametricCurve):
        """
        Initialize dynamics on a curve.

        Args:
            curve: ParametricCurve object defining the manifold
        """
        self.curve = curve

    def equations_of_motion(self,
                           t: float,
                           position: float,
                           velocity: float,
                           **kwargs) -> Tuple[float, float]:
        """
        Compute the equations of motion dt/dτ and d²t/dτ².

        This is the base method that should be overridden by subclasses.

        Args:
            t: Current time
            position: Current parameter value on curve
            velocity: Current velocity
            **kwargs: Additional parameters

        Returns:
            Tuple (dt/dτ, d²t/dτ²)
        """
        raise NotImplementedError("Subclasses must implement equations_of_motion")

    def integrate(self,
                 initial_position: float,
                 initial_velocity: float,
                 t_span: Tuple[float, float],
                 n_points: int = 1000,
                 method: str = 'RK45',
                 **kwargs) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
        """
        Integrate the equations of motion.

        Args:
            initial_position: Initial parameter value t₀
            initial_velocity: Initial velocity dt/dτ|₀
            t_span: Time interval (t_start, t_end)
            n_points: Number of time points to return
            method: Integration method for solve_ivp
            **kwargs: Additional parameters for equations_of_motion

        Returns:
            Tuple (times, positions, velocities)
        """
        def system(time, state):
            pos, vel = state
            dpos_dt = vel
            dvel_dt = self.equations_of_motion(time, pos, vel, **kwargs)[1]
            return [dpos_dt, dvel_dt]

        # Initial conditions
        y0 = [initial_position, initial_velocity]

        # Solve ODE
        t_eval = np.linspace(t_span[0], t_span[1], n_points)
        solution = solve_ivp(
            system,
            t_span,
            y0,
            method=method,
            t_eval=t_eval,
            dense_output=True
        )

        times = solution.t
        positions = solution.y[0]
        velocities = solution.y[1]

        return times, positions, velocities

    def spatial_trajectory(self,
                          initial_position: float,
                          initial_velocity: float,
                          t_span: Tuple[float, float],
                          n_points: int = 1000,
                          **kwargs) -> Tuple[np.ndarray, np.ndarray]:
        """
        Compute the spatial trajectory in R³.

        Args:
            initial_position: Initial parameter value
            initial_velocity: Initial velocity
            t_span: Time interval
            n_points: Number of points
            **kwargs: Additional parameters

        Returns:
            Tuple (times, trajectory) where trajectory is shape (n_points, 3)
        """
        times, positions, velocities = self.integrate(
            initial_position,
            initial_velocity,
            t_span,
            n_points,
            **kwargs
        )

        trajectory = np.array([self.curve(t) for t in positions])
        return times, trajectory


class FreeParticleDynamics(CurveDynamics):
    """
    Free particle moving along a curve with constant speed in parameter space.

    The equation of motion is simply: d²t/dτ² = 0
    """

    def equations_of_motion(self,
                           t: float,
                           position: float,
                           velocity: float,
                           **kwargs) -> Tuple[float, float]:
        """Free particle: no acceleration."""
        return velocity, 0.0


class ConstantSpeedDynamics(CurveDynamics):
    """
    Particle moving with constant speed in physical space (not parameter space).

    The constraint is |dγ/dτ| = v₀, which gives:
    d²t/dτ² = -(γ' · γ'') / |γ'|² * (dt/dτ)²
    """

    def __init__(self, curve: ParametricCurve, speed: float = 1.0):
        """
        Initialize constant-speed dynamics.

        Args:
            curve: ParametricCurve object
            speed: Desired constant speed in physical space
        """
        super().__init__(curve)
        self.speed = speed

    def equations_of_motion(self,
                           t: float,
                           position: float,
                           velocity: float,
                           **kwargs) -> Tuple[float, float]:
        """Maintain constant speed in physical space."""
        gamma_prime = self.curve.derivative(position, 1)
        gamma_double_prime = self.curve.derivative(position, 2)

        norm_gamma_prime = np.linalg.norm(gamma_prime)

        # Adjust velocity to maintain constant physical speed
        if norm_gamma_prime < 1e-10:
            acceleration = 0.0
        else:
            # Compute d²t/dτ² to maintain constant |dγ/dτ|
            dot_product = np.dot(gamma_prime, gamma_double_prime)
            acceleration = -(dot_product / (norm_gamma_prime ** 2)) * velocity ** 2

        return velocity, acceleration


class CurvatureDrivenDynamics(CurveDynamics):
    """
    Dynamics where the force depends on the local curvature.

    This implements: d²t/dτ² = f(κ(t)) where κ is the curvature.
    """

    def __init__(self,
                 curve: ParametricCurve,
                 force_function: Callable[[float], float],
                 damping: float = 0.0):
        """
        Initialize curvature-driven dynamics.

        Args:
            curve: ParametricCurve object
            force_function: Function f(κ) that returns the force given curvature
            damping: Damping coefficient
        """
        super().__init__(curve)
        self.force_function = force_function
        self.damping = damping

    def equations_of_motion(self,
                           t: float,
                           position: float,
                           velocity: float,
                           **kwargs) -> Tuple[float, float]:
        """Apply curvature-dependent force."""
        kappa = self.curve.curvature(position)
        force = self.force_function(kappa)
        acceleration = force - self.damping * velocity
        return velocity, acceleration


class MultiParticleSystem:
    """
    System of multiple particles on a curve with interactions.

    This class handles the collective dynamics of N particles on a curve,
    where particles can interact through various interaction functions.
    """

    def __init__(self,
                 curve: ParametricCurve,
                 n_particles: int,
                 interaction_function: Optional[Callable[[np.ndarray, np.ndarray], np.ndarray]] = None):
        """
        Initialize a multi-particle system.

        Args:
            curve: ParametricCurve object
            n_particles: Number of particles
            interaction_function: Function f(positions, velocities) returning forces
        """
        self.curve = curve
        self.n_particles = n_particles
        self.interaction_function = interaction_function

    def equations_of_motion(self,
                           time: float,
                           state: np.ndarray,
                           damping: float = 0.0,
                           external_force: Optional[Callable[[float, float, float], float]] = None) -> np.ndarray:
        """
        Compute equations of motion for all particles.

        Args:
            time: Current time
            state: State vector [t₁, t₂, ..., tₙ, v₁, v₂, ..., vₙ]
            damping: Damping coefficient
            external_force: Optional external force function f(t, position, velocity)

        Returns:
            Time derivative of state vector
        """
        n = self.n_particles
        positions = state[:n]
        velocities = state[n:]

        d_state = np.zeros(2 * n)

        # Positions evolve according to velocities
        d_state[:n] = velocities

        # Compute accelerations
        forces = np.zeros(n)

        # Add interaction forces if present
        if self.interaction_function is not None:
            interaction_forces = self.interaction_function(positions, velocities)
            forces += interaction_forces

        # Add external forces if present
        if external_force is not None:
            for i in range(n):
                forces[i] += external_force(time, positions[i], velocities[i])

        # Add damping
        forces -= damping * velocities

        d_state[n:] = forces

        return d_state

    def integrate(self,
                 initial_positions: np.ndarray,
                 initial_velocities: np.ndarray,
                 t_span: Tuple[float, float],
                 n_points: int = 1000,
                 method: str = 'RK45',
                 **kwargs) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
        """
        Integrate the multi-particle system.

        Args:
            initial_positions: Initial positions array of shape (n_particles,)
            initial_velocities: Initial velocities array of shape (n_particles,)
            t_span: Time interval (t_start, t_end)
            n_points: Number of time points
            method: Integration method
            **kwargs: Additional parameters for equations_of_motion

        Returns:
            Tuple (times, positions, velocities) where positions and velocities
            have shape (n_points, n_particles)
        """
        # Initial state
        y0 = np.concatenate([initial_positions, initial_velocities])

        # Time points
        t_eval = np.linspace(t_span[0], t_span[1], n_points)

        # Solve ODE
        solution = solve_ivp(
            lambda t, y: self.equations_of_motion(t, y, **kwargs),
            t_span,
            y0,
            method=method,
            t_eval=t_eval,
            dense_output=True
        )

        times = solution.t
        n = self.n_particles
        positions = solution.y[:n].T  # Shape: (n_points, n_particles)
        velocities = solution.y[n:].T

        return times, positions, velocities

    def spatial_trajectories(self,
                            initial_positions: np.ndarray,
                            initial_velocities: np.ndarray,
                            t_span: Tuple[float, float],
                            n_points: int = 1000,
                            **kwargs) -> Tuple[np.ndarray, np.ndarray]:
        """
        Compute spatial trajectories of all particles.

        Args:
            initial_positions: Initial positions
            initial_velocities: Initial velocities
            t_span: Time interval
            n_points: Number of time points
            **kwargs: Additional parameters

        Returns:
            Tuple (times, trajectories) where trajectories has shape
            (n_points, n_particles, 3)
        """
        times, positions, velocities = self.integrate(
            initial_positions,
            initial_velocities,
            t_span,
            n_points,
            **kwargs
        )

        # Convert parameter positions to spatial positions
        trajectories = np.zeros((n_points, self.n_particles, 3))
        for i in range(n_points):
            for j in range(self.n_particles):
                trajectories[i, j] = self.curve(positions[i, j])

        return times, trajectories


# Common interaction functions

def kuramoto_interaction(coupling: float, natural_frequencies: Optional[np.ndarray] = None):
    """
    Create a Kuramoto-like interaction function.

    The force on particle i is:
    F_i = ω_i + (K/N) Σⱼ sin(θⱼ - θᵢ)

    Args:
        coupling: Coupling strength K
        natural_frequencies: Natural frequencies ω for each particle

    Returns:
        Interaction function
    """
    def interaction(positions: np.ndarray, velocities: np.ndarray) -> np.ndarray:
        n = len(positions)
        forces = np.zeros(n)

        if natural_frequencies is not None:
            forces += natural_frequencies

        for i in range(n):
            for j in range(n):
                if i != j:
                    forces[i] += (coupling / n) * np.sin(positions[j] - positions[i])

        return forces

    return interaction


def attractive_interaction(coupling: float, range_param: float = np.inf):
    """
    Create an attractive interaction with optional finite range.

    Args:
        coupling: Coupling strength
        range_param: Interaction range (infinite by default)

    Returns:
        Interaction function
    """
    def interaction(positions: np.ndarray, velocities: np.ndarray) -> np.ndarray:
        n = len(positions)
        forces = np.zeros(n)

        for i in range(n):
            for j in range(n):
                if i != j:
                    diff = positions[j] - positions[i]
                    distance = abs(diff)

                    if distance < range_param:
                        # Attractive force proportional to distance
                        forces[i] += coupling * np.sign(diff) * distance

        return forces

    return interaction


def repulsive_interaction(coupling: float, cutoff: float = 1.0):
    """
    Create a repulsive interaction (inverse distance law).

    Args:
        coupling: Coupling strength
        cutoff: Cutoff distance to avoid singularities

    Returns:
        Interaction function
    """
    def interaction(positions: np.ndarray, velocities: np.ndarray) -> np.ndarray:
        n = len(positions)
        forces = np.zeros(n)

        for i in range(n):
            for j in range(n):
                if i != j:
                    diff = positions[j] - positions[i]
                    distance = max(abs(diff), cutoff)

                    # Repulsive force proportional to 1/distance²
                    forces[i] -= coupling * np.sign(diff) / (distance ** 2)

        return forces

    return interaction


def vicsek_like_interaction(coupling: float, noise: float = 0.0):
    """
    Create a Vicsek-like alignment interaction.

    Particles try to align their velocities with nearby particles.

    Args:
        coupling: Coupling strength
        noise: Noise amplitude

    Returns:
        Interaction function
    """
    def interaction(positions: np.ndarray, velocities: np.ndarray) -> np.ndarray:
        n = len(positions)
        forces = np.zeros(n)

        # Average velocity of all particles
        avg_velocity = np.mean(velocities)

        for i in range(n):
            # Force to align with average velocity
            forces[i] = coupling * (avg_velocity - velocities[i])

            # Add noise
            if noise > 0:
                forces[i] += noise * np.random.randn()

        return forces

    return interaction
