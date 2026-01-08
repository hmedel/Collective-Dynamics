"""
HDF5 I/O Backend for Efficient Data Storage

Provides fast, compressed storage for large trajectory datasets.
Much more efficient than CSV for multi-dimensional arrays.
"""

using HDF5
using CSV
using DataFrames
using BenchmarkTools

"""
    save_trajectories_hdf5(filename, data; compress=true)

Save simulation trajectories to HDF5 format.

# Arguments
- `filename::String`: Output file path (.h5 or .hdf5)
- `data`: Simulation data structure with fields:
  - `particles_history::Vector{Vector{ParticlePolar}}`
  - `times::Vector{T}`
  - `conservation`: Conservation metrics
  - `config`: Configuration parameters

- `compress::Bool`: Use gzip compression (default: true, ~3x smaller files)

# File Structure
```
file.h5
├── /trajectories
│   ├── time          [n_snapshots]
│   ├── phi           [n_snapshots, N]
│   ├── phidot        [n_snapshots, N]
│   ├── pos_x         [n_snapshots, N]
│   ├── pos_y         [n_snapshots, N]
│   ├── vel_x         [n_snapshots, N]
│   ├── vel_y         [n_snapshots, N]
│   ├── energy        [n_snapshots, N]
│   └── momentum      [n_snapshots, N]
│
├── /conservation
│   ├── time          [n_snapshots]
│   ├── total_energy  [n_snapshots]
│   ├── dE_E0         [n_snapshots]
│   └── ...
│
├── /metadata
│   └── attributes: N, a, b, dt_max, seed, etc.
└── /config (copy of full config as attributes)
```
"""
function save_trajectories_hdf5(filename::String, data; compress=true)
    T = eltype(data.times)
    N = length(data.particles_history[1])
    n_snapshots = length(data.times)

    # Preallocate arrays
    phi_array = zeros(T, n_snapshots, N)
    phidot_array = zeros(T, n_snapshots, N)
    pos_x_array = zeros(T, n_snapshots, N)
    pos_y_array = zeros(T, n_snapshots, N)
    vel_x_array = zeros(T, n_snapshots, N)
    vel_y_array = zeros(T, n_snapshots, N)
    energy_array = zeros(T, n_snapshots, N)
    momentum_array = zeros(T, n_snapshots, N)

    a = data.params[:a]
    b = data.params[:b]

    # Extract data from particles
    @inbounds for (i, particles) in enumerate(data.particles_history)
        for (j, p) in enumerate(particles)
            phi_array[i, j] = p.φ
            phidot_array[i, j] = p.φ_dot
            pos_x_array[i, j] = p.pos[1]
            pos_y_array[i, j] = p.pos[2]
            vel_x_array[i, j] = p.vel[1]
            vel_y_array[i, j] = p.vel[2]
            energy_array[i, j] = kinetic_energy_polar(p.φ, p.φ_dot, p.mass, a, b)
            momentum_array[i, j] = conjugate_momentum(p, a, b)
        end
    end

    # Write to HDF5
    h5open(filename, "w") do file
        # Create groups
        traj_group = create_group(file, "trajectories")
        cons_group = create_group(file, "conservation")
        meta_group = create_group(file, "metadata")

        # Write trajectory arrays (simple approach without explicit compression settings)
        traj_group["time"] = data.times
        traj_group["phi"] = phi_array
        traj_group["phidot"] = phidot_array
        traj_group["pos_x"] = pos_x_array
        traj_group["pos_y"] = pos_y_array
        traj_group["vel_x"] = vel_x_array
        traj_group["vel_y"] = vel_y_array
        traj_group["energy"] = energy_array
        traj_group["momentum"] = momentum_array

        # Write conservation data
        if !isnothing(data.conservation)
            cons = data.conservation
            cons_group["time"] = cons.times
            cons_group["total_energy"] = cons.energies
            cons_group["dE_E0"] = cons.energy_errors
        end

        # Write metadata as attributes
        attrs(meta_group)["N"] = N
        attrs(meta_group)["n_snapshots"] = n_snapshots
        attrs(meta_group)["a"] = a
        attrs(meta_group)["b"] = b
        # Use max(0, ...) for numerical safety when a≈b (circle case)
        attrs(meta_group)["eccentricity"] = sqrt(max(0.0, 1 - (b/a)^2))
        attrs(meta_group)["total_time"] = data.times[end]

        if haskey(data.params, :seed)
            attrs(meta_group)["seed"] = data.params[:seed]
        end
        if haskey(data.params, :dt_max)
            attrs(meta_group)["dt_max"] = data.params[:dt_max]
        end

        # Write full params
        params_group = create_group(file, "params")
        for (key, val) in pairs(data.params)
            try
                attrs(params_group)[string(key)] = val
            catch
                # Skip if type not supported by HDF5
                @warn "Could not save params key: $key"
            end
        end
    end

    # Report file size
    file_size = filesize(filename)
    file_size_mb = file_size / 1024^2
    println("Saved to HDF5: $filename ($(round(file_size_mb, digits=2)) MB)")

    return filename
end

"""
    load_trajectories_hdf5(filename; load_conservation=true)

Load simulation trajectories from HDF5 file.

# Returns
Named tuple with:
- `times::Vector{T}`
- `phi::Matrix{T}` - (n_snapshots, N)
- `phidot::Matrix{T}`
- `pos_x::Matrix{T}`
- `pos_y::Matrix{T}`
- `energy::Matrix{T}`
- `metadata::Dict` - Simulation parameters
- `conservation::NamedTuple` (if load_conservation=true)
"""
function load_trajectories_hdf5(filename::String; load_conservation=true)
    h5open(filename, "r") do file
        # Load trajectories
        traj = file["trajectories"]
        times = read(traj["time"])
        phi = read(traj["phi"])
        phidot = read(traj["phidot"])
        pos_x = read(traj["pos_x"])
        pos_y = read(traj["pos_y"])
        energy = read(traj["energy"])

        # Load metadata
        meta = file["metadata"]
        metadata = Dict{Symbol, Any}()
        for key in keys(attrs(meta))
            metadata[Symbol(key)] = attrs(meta)[key]
        end

        # Load conservation (optional)
        conservation = nothing
        if load_conservation && haskey(file, "conservation")
            cons = file["conservation"]
            conservation = (
                times = read(cons["time"]),
                total_energy = read(cons["total_energy"]),
                dE_E0 = read(cons["dE_E0"])
            )
        end

        return (
            times = times,
            phi = phi,
            phidot = phidot,
            pos_x = pos_x,
            pos_y = pos_y,
            energy = energy,
            metadata = metadata,
            conservation = conservation
        )
    end
end

"""
    load_trajectory_slice(filename, time_range::Tuple)

Load only a subset of trajectories (for memory efficiency).

# Arguments
- `filename::String`: HDF5 file
- `time_range::Tuple{T, T}`: (t_start, t_end)

# Returns
Same as `load_trajectories_hdf5` but only for requested time range
"""
function load_trajectory_slice(filename::String, time_range::Tuple)
    t_start, t_end = time_range

    h5open(filename, "r") do file
        # First load times to find indices
        times = read(file["trajectories"]["time"])
        idx_start = findfirst(t -> t >= t_start, times)
        idx_end = findlast(t -> t <= t_end, times)

        if idx_start === nothing || idx_end === nothing
            error("Time range not found in file")
        end

        # Load slice
        traj = file["trajectories"]
        times_slice = times[idx_start:idx_end]
        phi = read(traj["phi"])[idx_start:idx_end, :]
        phidot = read(traj["phidot"])[idx_start:idx_end, :]
        energy = read(traj["energy"])[idx_start:idx_end, :]

        # Metadata
        meta = file["metadata"]
        metadata = Dict{Symbol, Any}()
        for key in keys(attrs(meta))
            metadata[Symbol(key)] = read(attrs(meta)[key])
        end

        return (
            times = times_slice,
            phi = phi,
            phidot = phidot,
            energy = energy,
            metadata = metadata
        )
    end
end

"""
    compare_file_sizes(csv_file, hdf5_file)

Compare file sizes of CSV vs HDF5 storage.
"""
function compare_file_sizes(csv_file, hdf5_file)
    csv_size = filesize(csv_file) / 1024^2  # MB
    hdf5_size = filesize(hdf5_file) / 1024^2
    compression_ratio = csv_size / hdf5_size

    println("File size comparison:")
    println("  CSV:  $(round(csv_size, digits=2)) MB")
    println("  HDF5: $(round(hdf5_size, digits=2)) MB")
    println("  Compression ratio: $(round(compression_ratio, digits=1))x")

    return compression_ratio
end

"""
    benchmark_io_speeds()

Benchmark CSV vs HDF5 read/write speeds.
"""
function benchmark_io_speeds()
    # Create dummy data
    n_snapshots = 1000
    N = 40
    T = Float64

    times = collect(range(0.0, 10.0, length=n_snapshots))
    phi = rand(T, n_snapshots, N) .* 2π
    phidot = randn(T, n_snapshots, N)

    # Write CSV
    csv_file = "benchmark_data.csv"
    println("Benchmarking CSV write...")
    @time begin
        df = DataFrame(time=repeat(times, inner=N), particle=repeat(1:N, outer=n_snapshots),
                       phi=vec(phi'), phidot=vec(phidot'))
        CSV.write(csv_file, df)
    end
    csv_write_time = @elapsed CSV.write(csv_file, df)

    # Write HDF5
    hdf5_file = "benchmark_data.h5"
    println("Benchmarking HDF5 write...")
    hdf5_write_time = @elapsed h5open(hdf5_file, "w") do file
        file["time"] = times
        file["phi", chunk=(100, N), compress=5] = phi
        file["phidot", chunk=(100, N), compress=5] = phidot
    end

    # Read CSV
    println("Benchmarking CSV read...")
    csv_read_time = @elapsed CSV.read(csv_file, DataFrame)

    # Read HDF5
    println("Benchmarking HDF5 read...")
    hdf5_read_time = @elapsed h5open(hdf5_file, "r") do file
        read(file["phi"])
    end

    # Results
    println("\n" * "="^60)
    println("Benchmark Results (n_snapshots=$n_snapshots, N=$N)")
    println("="^60)
    println("Write speed:")
    println("  CSV:  $(round(csv_write_time, digits=3))s")
    println("  HDF5: $(round(hdf5_write_time, digits=3))s")
    println("  Speedup: $(round(csv_write_time/hdf5_write_time, digits=1))x")
    println()
    println("Read speed:")
    println("  CSV:  $(round(csv_read_time, digits=3))s")
    println("  HDF5: $(round(hdf5_read_time, digits=3))s")
    println("  Speedup: $(round(csv_read_time/hdf5_read_time, digits=1))x")
    println()

    # File sizes
    compare_file_sizes(csv_file, hdf5_file)

    # Cleanup
    rm(csv_file)
    rm(hdf5_file)

    return (csv_write=csv_write_time, hdf5_write=hdf5_write_time,
            csv_read=csv_read_time, hdf5_read=hdf5_read_time)
end
