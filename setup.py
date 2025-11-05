"""
Setup script for Collective Dynamics on Manifolds
"""

from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="collective-dynamics",
    version="0.1.0",
    author="Collective Dynamics Project",
    author_email="your.email@example.com",
    description="A framework for studying collective dynamics on curved manifolds",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/yourusername/Collective-Dynamics",
    packages=find_packages(),
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Science/Research",
        "Topic :: Scientific/Engineering :: Physics",
        "Topic :: Scientific/Engineering :: Mathematics",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
    ],
    python_requires=">=3.8",
    install_requires=[
        "numpy>=1.20.0",
        "scipy>=1.7.0",
        "matplotlib>=3.3.0",
    ],
    extras_require={
        "dev": [
            "pytest>=6.0.0",
            "black>=21.0",
            "flake8>=3.9.0",
        ],
        "notebooks": [
            "jupyter>=1.0.0",
            "ipywidgets>=7.6.0",
            "ipympl>=0.8.0",
        ],
    },
    keywords="collective dynamics, differential geometry, synchronization, "
             "active matter, curved manifolds, kuramoto model",
    project_urls={
        "Bug Reports": "https://github.com/yourusername/Collective-Dynamics/issues",
        "Source": "https://github.com/yourusername/Collective-Dynamics",
    },
)
