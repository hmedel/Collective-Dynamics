"""
Differential geometry tools for curves in R³.

This module provides tools to work with parametric curves embedded in 3D space,
including computation of the Frenet-Serret frame, curvature, and torsion.
"""

import numpy as np
from typing import Callable, Tuple, Optional
from dataclasses import dataclass


@dataclass
class FrenetFrame:
    """
    Frenet-Serret frame at a point on a curve.

    Attributes:
        tangent: Unit tangent vector T
        normal: Unit normal vector N
        binormal: Unit binormal vector B
        curvature: Curvature κ
        torsion: Torsion τ
    """
    tangent: np.ndarray
    normal: np.ndarray
    binormal: np.ndarray
    curvature: float
    torsion: float


class ParametricCurve:
    """
    A parametric curve in R³: γ(t) = (x(t), y(t), z(t)).

    The curve is defined by a function that takes a parameter t and returns
    a 3D point. This class provides methods to compute differential geometry
    quantities like curvature, torsion, and the Frenet-Serret frame.
    """

    def __init__(self,
                 curve_func: Callable[[float], np.ndarray],
                 derivative_func: Optional[Callable[[float], np.ndarray]] = None,
                 second_derivative_func: Optional[Callable[[float], np.ndarray]] = None,
                 third_derivative_func: Optional[Callable[[float], np.ndarray]] = None,
                 dt: float = 1e-5):
        """
        Initialize a parametric curve.

        Args:
            curve_func: Function γ(t) that returns a 3D point
            derivative_func: Optional function γ'(t) (computed numerically if not provided)
            second_derivative_func: Optional function γ''(t)
            third_derivative_func: Optional function γ'''(t)
            dt: Step size for numerical differentiation
        """
        self.gamma = curve_func
        self._gamma_prime = derivative_func
        self._gamma_double_prime = second_derivative_func
        self._gamma_triple_prime = third_derivative_func
        self.dt = dt

    def __call__(self, t: float) -> np.ndarray:
        """Evaluate the curve at parameter t."""
        return self.gamma(t)

    def derivative(self, t: float, order: int = 1) -> np.ndarray:
        """
        Compute the derivative of the curve at parameter t.

        Args:
            t: Parameter value
            order: Order of derivative (1, 2, or 3)

        Returns:
            Derivative vector at t
        """
        if order == 1:
            if self._gamma_prime is not None:
                return self._gamma_prime(t)
            # Numerical differentiation using central differences
            return (self.gamma(t + self.dt) - self.gamma(t - self.dt)) / (2 * self.dt)

        elif order == 2:
            if self._gamma_double_prime is not None:
                return self._gamma_double_prime(t)
            # Numerical second derivative
            return (self.derivative(t + self.dt, 1) - self.derivative(t - self.dt, 1)) / (2 * self.dt)

        elif order == 3:
            if self._gamma_triple_prime is not None:
                return self._gamma_triple_prime(t)
            # Numerical third derivative
            return (self.derivative(t + self.dt, 2) - self.derivative(t - self.dt, 2)) / (2 * self.dt)

        else:
            raise ValueError(f"Derivative order {order} not supported")

    def speed(self, t: float) -> float:
        """
        Compute the speed |γ'(t)| at parameter t.

        Args:
            t: Parameter value

        Returns:
            Speed (magnitude of velocity)
        """
        gamma_prime = self.derivative(t, 1)
        return np.linalg.norm(gamma_prime)

    def tangent(self, t: float) -> np.ndarray:
        """
        Compute the unit tangent vector T(t) at parameter t.

        Args:
            t: Parameter value

        Returns:
            Unit tangent vector
        """
        gamma_prime = self.derivative(t, 1)
        speed = np.linalg.norm(gamma_prime)
        if speed < 1e-10:
            raise ValueError(f"Speed too small at t={t}, cannot compute tangent")
        return gamma_prime / speed

    def curvature(self, t: float) -> float:
        """
        Compute the curvature κ(t) at parameter t.

        The curvature is given by: κ = |γ' × γ''| / |γ'|³

        Args:
            t: Parameter value

        Returns:
            Curvature value
        """
        gamma_prime = self.derivative(t, 1)
        gamma_double_prime = self.derivative(t, 2)

        cross_product = np.cross(gamma_prime, gamma_double_prime)
        numerator = np.linalg.norm(cross_product)
        denominator = np.linalg.norm(gamma_prime) ** 3

        if denominator < 1e-10:
            return 0.0

        return numerator / denominator

    def normal(self, t: float) -> np.ndarray:
        """
        Compute the unit normal vector N(t) at parameter t.

        The normal is defined as N = T' / |T'|, where T is the tangent vector.

        Args:
            t: Parameter value

        Returns:
            Unit normal vector
        """
        # Compute T'(t) numerically
        T_plus = self.tangent(t + self.dt)
        T_minus = self.tangent(t - self.dt)
        T_prime = (T_plus - T_minus) / (2 * self.dt)

        norm = np.linalg.norm(T_prime)
        if norm < 1e-10:
            # If T' is nearly zero, the curve is approximately straight
            # Return an arbitrary perpendicular vector
            T = self.tangent(t)
            # Find a vector not parallel to T
            if abs(T[0]) < 0.9:
                v = np.array([1.0, 0.0, 0.0])
            else:
                v = np.array([0.0, 1.0, 0.0])
            # Gram-Schmidt orthogonalization
            N = v - np.dot(v, T) * T
            return N / np.linalg.norm(N)

        return T_prime / norm

    def binormal(self, t: float) -> np.ndarray:
        """
        Compute the unit binormal vector B(t) at parameter t.

        The binormal is defined as B = T × N.

        Args:
            t: Parameter value

        Returns:
            Unit binormal vector
        """
        T = self.tangent(t)
        N = self.normal(t)
        return np.cross(T, N)

    def torsion(self, t: float) -> float:
        """
        Compute the torsion τ(t) at parameter t.

        The torsion is given by: τ = (γ' × γ'') · γ''' / |γ' × γ''|²

        Args:
            t: Parameter value

        Returns:
            Torsion value
        """
        gamma_prime = self.derivative(t, 1)
        gamma_double_prime = self.derivative(t, 2)
        gamma_triple_prime = self.derivative(t, 3)

        cross_product = np.cross(gamma_prime, gamma_double_prime)
        numerator = np.dot(cross_product, gamma_triple_prime)
        denominator = np.linalg.norm(cross_product) ** 2

        if denominator < 1e-10:
            return 0.0

        return numerator / denominator

    def frenet_frame(self, t: float) -> FrenetFrame:
        """
        Compute the complete Frenet-Serret frame at parameter t.

        Args:
            t: Parameter value

        Returns:
            FrenetFrame object containing T, N, B, κ, and τ
        """
        T = self.tangent(t)
        N = self.normal(t)
        B = self.binormal(t)
        kappa = self.curvature(t)
        tau = self.torsion(t)

        return FrenetFrame(
            tangent=T,
            normal=N,
            binormal=B,
            curvature=kappa,
            torsion=tau
        )

    def arc_length(self, t0: float, t1: float, n_points: int = 1000) -> float:
        """
        Compute the arc length of the curve from t0 to t1.

        Uses trapezoidal integration to approximate the integral of speed.

        Args:
            t0: Starting parameter
            t1: Ending parameter
            n_points: Number of points for integration

        Returns:
            Arc length
        """
        t_values = np.linspace(t0, t1, n_points)
        speeds = np.array([self.speed(t) for t in t_values])
        return np.trapz(speeds, t_values)

    def evaluate_array(self, t_array: np.ndarray) -> np.ndarray:
        """
        Evaluate the curve at multiple parameter values.

        Args:
            t_array: Array of parameter values

        Returns:
            Array of shape (len(t_array), 3) with curve points
        """
        return np.array([self.gamma(t) for t in t_array])


# Predefined common curves

def helix(radius: float = 1.0, pitch: float = 1.0) -> ParametricCurve:
    """
    Create a circular helix.

    The helix is parameterized as:
    γ(t) = (r cos(t), r sin(t), p·t/(2π))

    Args:
        radius: Radius of the helix
        pitch: Vertical distance per complete turn

    Returns:
        ParametricCurve object representing the helix
    """
    def gamma(t):
        return np.array([
            radius * np.cos(t),
            radius * np.sin(t),
            pitch * t / (2 * np.pi)
        ])

    def gamma_prime(t):
        return np.array([
            -radius * np.sin(t),
            radius * np.cos(t),
            pitch / (2 * np.pi)
        ])

    def gamma_double_prime(t):
        return np.array([
            -radius * np.cos(t),
            -radius * np.sin(t),
            0.0
        ])

    def gamma_triple_prime(t):
        return np.array([
            radius * np.sin(t),
            -radius * np.cos(t),
            0.0
        ])

    return ParametricCurve(
        gamma,
        gamma_prime,
        gamma_double_prime,
        gamma_triple_prime
    )


def circle(radius: float = 1.0,
          center: np.ndarray = np.array([0., 0., 0.]),
          normal: np.ndarray = np.array([0., 0., 1.])) -> ParametricCurve:
    """
    Create a circle in 3D space.

    Args:
        radius: Radius of the circle
        center: Center point of the circle
        normal: Normal vector to the plane containing the circle

    Returns:
        ParametricCurve object representing the circle
    """
    # Normalize the normal vector
    normal = normal / np.linalg.norm(normal)

    # Create two orthogonal vectors in the plane
    if abs(normal[0]) < 0.9:
        u = np.array([1., 0., 0.])
    else:
        u = np.array([0., 1., 0.])

    u = u - np.dot(u, normal) * normal
    u = u / np.linalg.norm(u)
    v = np.cross(normal, u)

    def gamma(t):
        return center + radius * (np.cos(t) * u + np.sin(t) * v)

    def gamma_prime(t):
        return radius * (-np.sin(t) * u + np.cos(t) * v)

    def gamma_double_prime(t):
        return radius * (-np.cos(t) * u - np.sin(t) * v)

    def gamma_triple_prime(t):
        return radius * (np.sin(t) * u - np.cos(t) * v)

    return ParametricCurve(
        gamma,
        gamma_prime,
        gamma_double_prime,
        gamma_triple_prime
    )


def viviani_curve(radius: float = 1.0) -> ParametricCurve:
    """
    Create Viviani's curve (intersection of a sphere and a cylinder).

    This is a beautiful curve that lies on both a sphere of radius 2r
    and a cylinder of radius r.

    Args:
        radius: Radius parameter

    Returns:
        ParametricCurve object representing Viviani's curve
    """
    def gamma(t):
        return np.array([
            radius * (1 + np.cos(t)),
            radius * np.sin(t),
            2 * radius * np.sin(t / 2)
        ])

    return ParametricCurve(gamma)


def lemniscate_3d(a: float = 1.0) -> ParametricCurve:
    """
    Create a 3D lemniscate (figure-eight curve).

    Args:
        a: Scale parameter

    Returns:
        ParametricCurve object representing the 3D lemniscate
    """
    def gamma(t):
        return np.array([
            a * np.cos(t) / (1 + np.sin(t)**2),
            a * np.sin(t) * np.cos(t) / (1 + np.sin(t)**2),
            a * np.sin(t) / (1 + np.sin(t)**2)
        ])

    return ParametricCurve(gamma)
