# ---
# jupyter:
#   jupytext:
#     formats: ipynb,jl:light
#     text_representation:
#       extension: .jl
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.16.4
#   kernelspec:
#     display_name: Julia 1.11.1
#     language: julia
#     name: julia-1.11
# ---

# # Benchmarks for `Cheby` on dense matrices (in-place)

using QuantumPropagators: Cheby

import QuantumPropagators
import CSV
import DataFrames
using Plots
using QuantumControl: run_or_load

import PropagationBenchmarks
using PropagationBenchmarks: run_benchmarks, params, Vary
using PropagationBenchmarks: generate_exact_solution
using PropagationBenchmarks: calibrate_cheby
using PropagationBenchmarks: generate_trial_data, generate_timing_data
using PropagationBenchmarks: BenchmarkSeries
using PropagationBenchmarks:
    Units, plot_prec_runtimes, plot_size_runtime, plot_scaling, plot_overhead

using AppleAccelerate #  no-op on non-Apple
PropagationBenchmarks.info()

# +
projectdir(path...) = joinpath(@__DIR__, path...)
datadir(path...) = projectdir("data", "A01_01_Cheby_InPlace_Dense", path...)
mkpath(datadir())

SYSTEMS_CACHE = Dict();
EXACT_SOLUTIONS_CACHE = Dict();
CALIBRATION_CACHE = Dict();

QuantumPropagators.disable_timings();
# -

FORCE = (get(ENV, "FORCE", "0") in ["true", "1"])

# ## Runtime over System Size

SYSTEM_PARAMETERS = params(
    # see arguments of `random_dynamic_generator`
    N = Vary(100, 200, 300, 400, 500, 600, 700, 800, 900, 1000),
    spectral_envelope = 1.0,
    exact_spectral_envelope = true,
    number_of_controls = 1,
    density = 1,
    hermitian = true,
    dt = 1.0,
    nt = 1001,
);

BENCHMARK_PARAMETERS = params(method = Cheby, cheby_coeffs_limit = Vary(1e-15, 1e-8));

size_trial_data = run_or_load(datadir("benchmark_size_trials.jld2"); force = FORCE) do
    run_benchmarks(;
        system_parameters = SYSTEM_PARAMETERS,
        benchmark_parameters = BENCHMARK_PARAMETERS,
        generate_benchmark = generate_trial_data,
        systems_cache = SYSTEMS_CACHE,
    )
end;

# +
QuantumPropagators.enable_timings();

size_timing_data = run_or_load(datadir("benchmark_size_timing.jld2"); force = FORCE) do
    run_benchmarks(;
        system_parameters = SYSTEM_PARAMETERS,
        benchmark_parameters = BENCHMARK_PARAMETERS,
        generate_benchmark = generate_timing_data,
        systems_cache = SYSTEMS_CACHE,
    )
end;

QuantumPropagators.disable_timings();
# -

size_runtime_data = merge(size_trial_data, size_timing_data)

plot_size_runtime(size_runtime_data) do row
    if row[:cheby_coeffs_limit] == 1e-15
        return :high
    elseif row[:cheby_coeffs_limit] == 1e-8
        return :low
    else
        error("Unexpected `cheby_coeffs_limit`")
    end
end

# ## Runtime over Precision

PRECISION = Vary(1e-4, 1e-5, 1e-6, 1e-7, 1e-8, 1e-9, 1e-10, 1e-11, 1e-12, 1e-15);

SYSTEM_PARAMETERS = params(
    # see arguments of `random_dynamic_generator`
    N = Vary(1_000, 100, 10),
    spectral_envelope = 1.0,
    exact_spectral_envelope = true,
    number_of_controls = 1,
    density = 1,
    hermitian = true,
    dt = 1.0,
    nt = 1001,
);

EXACT_SOLUTION_PARAMETERS = params(method = Cheby, cheby_coeffs_limit = 1e-15,);

BENCHMARK_PARAMETERS = params(method = Cheby, precision = PRECISION,);

prec_trial_data = run_or_load(datadir("benchmark_prec_trials.jld2"); force = FORCE) do
    run_benchmarks(;
        system_parameters = SYSTEM_PARAMETERS,
        exact_solution_parameters = EXACT_SOLUTION_PARAMETERS,
        generate_exact_solution = generate_exact_solution,
        benchmark_parameters = BENCHMARK_PARAMETERS,
        generate_benchmark = generate_trial_data,
        calibrate = calibrate_cheby,  # translate `precision` into `cheby_coeffs_limit`
        calibrated_keys_to_store = [:cheby_coeffs_limit],
        systems_cache = SYSTEMS_CACHE,
        calibration_cache = CALIBRATION_CACHE,
        exact_solutions_cache = EXACT_SOLUTIONS_CACHE,
    )
end;

# +
QuantumPropagators.enable_timings();

prec_timing_data = run_or_load(datadir("benchmark_prec_timings.jld2"); force = FORCE) do
    run_benchmarks(;
        system_parameters = SYSTEM_PARAMETERS,
        exact_solution_parameters = EXACT_SOLUTION_PARAMETERS,
        generate_exact_solution = generate_exact_solution,
        benchmark_parameters = BENCHMARK_PARAMETERS,
        generate_benchmark = generate_timing_data,
        calibrate = calibrate_cheby,
        calibrated_keys_to_store = [:cheby_coeffs_limit],
        systems_cache = SYSTEMS_CACHE,
        calibration_cache = CALIBRATION_CACHE,
        exact_solutions_cache = EXACT_SOLUTIONS_CACHE,
    )
end;

QuantumPropagators.disable_timings();
# -

prec_runtime_data = merge(prec_trial_data, prec_timing_data)

plot_prec_runtimes(
    prec_runtime_data,
    [1000, 100, 10];
    units = Dict(1000 => :s, 100 => :ms, 10 => :ms),
    size = (600, 600),
    plot_title = "Runtime for in-place Cheby on dense matrices",
    csv = datadir("cheby_inplace_dense_runtime_N={N}.csv"),
)


# ## Scaling with Spectral Envelope

# For larger system sizes, the runtime of the propagation should be dominated by matrix-vector products. The number of matrix_vector products should depend only on the desired precision and the spectral envelope of the system (for `dt=1.0`; or alternatively, on `dt` if the spectral envelope is kept constant). We analyze here how the number of matrix-vector products scales with the spectral envelope for the default "high" precision (machine precision), and for lower precision (roughly half machine precision).
#
# This scaling should be mostly independent of the size or the encoding of the system.

# +
QuantumPropagators.enable_timings();

scaling_data = run_or_load(datadir("benchmark_scaling.jld2"); force = FORCE) do
    run_benchmarks(;
        system_parameters = params(
            N = 100,
            spectral_envelope = Vary(0.5, 1.0, 5.0, 10.0, 15.0, 20.0, 25.0),
            exact_spectral_envelope = true,
            number_of_controls = 1,
            density = 1,
            hermitian = true,
            dt = 1.0,
            nt = 1001,
        ),
        benchmark_parameters = params(
            method = Cheby,
            cheby_coeffs_limit = Vary(1e-15, 1e-8)
        ),
        generate_benchmark = generate_timing_data,
        systems_cache = SYSTEMS_CACHE,
    )
end;

QuantumPropagators.disable_timings();
# -

scaling_data


plot_scaling(
    scaling_data;
    plot_title = "Scaling for Cheby",
    csv = datadir("cheby_scaling_{highlow}.csv")
) do row
    if row[:cheby_coeffs_limit] == 1e-15
        return :high
    elseif row[:cheby_coeffs_limit] == 1e-8
        return :low
    else
        error("Unexpected `cheby_coeffs_limit`")
    end
end


# ## Overhead with System Size


# For sufficiently large systems, the propagation should be dominated by matrix-vector products. Here, we analyze the "overhead", i.e., the percentage of the runtime _not_ spent in matrix-vector products, for smaller systems.

# +
QuantumPropagators.enable_timings();

overhead_data = run_or_load(datadir("benchmark_overhead.jld2"); force = FORCE) do
    run_benchmarks(;
        system_parameters = params(
            N = Vary(5, 10, 50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000),
            spectral_envelope = 1.0,
            exact_spectral_envelope = true,
            number_of_controls = 1,
            density = 1,
            hermitian = true,
            dt = 1.0,
            nt = 1001,
        ),
        benchmark_parameters = params(method = Cheby),
        generate_benchmark = generate_timing_data,
        systems_cache = SYSTEMS_CACHE,
    )
end

QuantumPropagators.disable_timings();
# -

overhead_data

plot_overhead(
    overhead_data;
    csv = datadir("cheby_inplace_dense_overhead.csv"),
    plot_title = "Overhead for in-place Cheby on dense matrices",
)
