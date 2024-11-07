using DataStructures: OrderedDict
using QuantumPropagators: QuantumPropagators, init_prop, propagate
using TimerOutputs: TimerOutputs
using BenchmarkTools: @benchmark


"""
A `generate_benchmark` function to collect `BenchmarkTools.Trial` data

```julia
run_benchmarks(;
    …,
    generate_benchmark=generate_trial_data,
)
```

will include two columns in the resulting [`CollectedBenchmarks`](@ref):

* `init_prop`, mapping to an instance of `BenchmarkTools.Trial` with the data
  for a call to `init_prop`
* `propagate`, mapping to an instance of `BenchmarkTools.Trial` with the data
  for a propagation (`prop_step!`, executed in a loop).
"""
function generate_trial_data(system, exact_solution; kwargs...)
    @assert !QuantumPropagators.timings_enabled()
    H = system.generator
    Ψ₀ = system.initial_state
    Ψ_exact = exact_solution
    tlist = system.tlist
    bm_init_prop = @benchmark begin
        init_prop($Ψ₀, $H, $tlist; $kwargs...)
    end
    bm_propagate = @benchmark begin
        _propagate(propagator, $tlist)
    end setup = (propagator = init_prop($Ψ₀, $H, $tlist; $kwargs...)) evals = 1
    # TODO: limit seconds (in calibrate)
    return OrderedDict(:init_prop => bm_init_prop, :propagate => bm_propagate)
end


function generate_timing_data(system, exact_solution; kwargs...)
    @assert QuantumPropagators.timings_enabled()
    H = system.generator
    Ψ₀ = system.initial_state
    Ψ_exact = exact_solution
    tlist = system.tlist
    # warmup
    propagator = init_prop(Ψ₀, H, tlist; kwargs...)
    _propagate(propagator, tlist)
    # measurement
    propagator = init_prop(Ψ₀, H, tlist; kwargs...)
    _propagate(propagator, tlist)
    # data extraction
    timing_data = TimerOutputs.flatten(propagator.wrk.timing_data)
    n_mul = 0
    percent = 0.0
    try
        n_mul = TimerOutputs.ncalls(timing_data["matrix-vector product"])
        percent =
            100 * (
                TimerOutputs.time(timing_data["matrix-vector product"]) /
                TimerOutputs.time(timing_data["prop_step!"])
            )
    catch exc
        @error "timing data not available: $exc"
    end

    return OrderedDict(
        :timesteps => length(tlist) - 1,
        :matrix_vector_products => n_mul,
        :percent => percent
    )
end
# TODO: rename, documentation
