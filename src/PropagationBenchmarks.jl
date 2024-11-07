module PropagationBenchmarks

using StableRNGs: StableRNG

RNG = StableRNG(248221371)

using QuantumPropagators: prop_step!

function _propagate(propagator, tlist)
    N = length(tlist) - 1  # number of intervals
    for _ ∈ 1:N
        prop_step!(propagator)
    end
end


include("params.jl")
export params, Vary

include("systems.jl")
export generate_system

include("collected_benchmarks.jl")

include("generate_benchmarks.jl")
export generate_trial_data, generate_timing_data

include("run_benchmarks.jl")
export run_benchmarks

include("caches.jl")
export load_cache, save_cache

include("cheby.jl")
export calibrate_cheby

include("units.jl")  # submodule Units

include("plotting.jl")
export BenchmarkSeries


end
