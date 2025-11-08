#!/bin/bash
# Script para ejecutar el test de conservación de momento conjugado

set -e

cd "$(dirname "$0")"

echo "======================================================================"
echo "Test de Conservación de Momento Conjugado"
echo "======================================================================"
echo ""
echo "Este test verificará que la nueva implementación conserva correctamente"
echo "el momento conjugado p_θ = m g(θ) θ̇ = m [a²sin²θ + b²cos²θ] θ̇"
echo ""
echo "Presiona ENTER para continuar..."
read

# Ejecutar test
julia --project=. test_conjugate_momentum.jl

echo ""
echo "======================================================================"
echo "Test completado"
echo "======================================================================"
echo ""
echo "Si deseas ejecutar una simulación completa, usa:"
echo "  julia --project=. run_simulation.jl config/simulation_example.toml"
echo ""
echo "Y luego analiza con:"
echo "  julia --project=. estadisticas_simulacion.jl results/simulation_XXXXXX/"
echo ""
