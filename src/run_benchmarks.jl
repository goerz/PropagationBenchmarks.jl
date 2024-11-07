using DataStructures: OrderedDict
using ProgressMeter: Progress, next!
using Random: shuffle


# Task Executor.
# The loop over i here could be parallelized if Julia had multi-threaded
# garbage collection. As it is, GC will stall when running multi-threaded,
# throwing off any benchmarks.
function _map(f; title = "", as_args = nothing, as_kwargs = nothing, static_kwargs...)
    ntasks = 0
    if as_args ≢ nothing && as_kwargs ≢ nothing
        @assert length(as_args) == length(as_kwargs)
        ntasks = length(as_args)
    elseif as_args ≢ nothing
        ntasks = length(as_args)
    elseif as_kwargs ≢ nothing
        ntasks = length(as_kwargs)
    end
    results = Vector{Any}(undef, ntasks)
    progressmeter = Progress(ntasks, title)
    for i ∈ shuffle(1:ntasks)
        # We've shuffled `i` to even out progress if different tasks have
        # significantly different runtime
        args = isnothing(as_args) ? [] : as_args[i]
        kwargs = isnothing(as_kwargs) ? Dict() : as_kwargs[i]
        results[i] = f(args...; kwargs..., static_kwargs...)
        next!(progressmeter)
    end
    return results
end


"""Default argument for `calibrate` in `run_benchmarks`."""
function no_calibrate(system, exact_solution; kwargs...)
    return params(; kwargs...)
end


"""Run a series of benchmarks and collect the results in a table.

```julia
collected_benchmarks = run_benchmarks(;
    system_parameters,
    exact_solution_parameters,
    benchmark_parameters,
    generate_system=generate_system,
    generate_exact_solution=generate_exact_solution,
    generate_benchmark,
    calibrate=no_calibrate,
    systems_cache=Dict(),
    exact_solutions_cache=Dict(),
    calibration_cache=Dict(),
    calibrated_keys_to_store=[]
)
```

runs a series of benchmarks in 4 stages:

1.  Run

        system = generate_system(;kwargs...)

    where the `kwargs` for each call are obtained from expanding
    `system_parameters`. Note that `generate_system` must be fully
    deterministic, that is, it should not use an unseeded random number
    generator.

    The default [`generate_system`](@ref) delegates to
    `QuantumControlTestUtils.RandomObjects.random_dynamic_generator` and
    `QuantumControlTestUtils.RandomObjects.random_state_vector` to return a
    [`BenchmarkSystem`](@ref)

2.  For every system, run

        generate_exact_solution(system; exact_solution_parameters...)

    to obtain  an exact solution.

    The default [`generate_exact_solution`] assumes `system` to be a
    [`BenchmarkSystem`](@ref) instance and runs `propagate` with the
    `exact_solution_parameters` as keyword arguments.


3.  For every system and every `kwargs` expanded from `benchmark_parameters`

        benchmark_kwargs = calibrate(system, exact_solution; kwargs...)

    to transform the `benchmark_parameters` into tuned keyword argument that
    will be passed to `generate_benchmark` in the final step.

    The default `no_calibrate` leaves the `kwargs` unchanged.

4.  For every system and `benchmark_kwargs` obtained from the calibration, run

        benchmark_dict = generate_benchmark(
            system, exact_solution; benchmark_kwargs...
        )

    which must return an `OrderedDict` mapping Symbols to arbitrary result
    objects.

    The is no default `generate_benchmark`; it must always be given explicitly.


The `run_benchmarks` function returns a [`CollectedBenchmarks`](@ref) instance
that contains rows of OrderedDicts. The keys and values in each row are the
varied parameters from `system_parameters` and `benchmark_parameters`, any
key-value pairs from the calibrated `benchmark_kwargs` for which the keys are
listed in `calibrated_keys_to_store`, and the key-value pairs returned by
`generate_benchmark`.

The `system_parameters`, `exact_solution_parameters`, and
`benchmark_parameters` should be instantiated via the [`params`](@ref)
function. For `system_parameters` and `benchmark_parameters`, values that
should be varied must be wrapped in a [`Vary`](@ref) list. Ultimately, the
[`CollectedBenchmarks`](@ref) will include one row for each element of the
Cartesian product of all varied parameters, and the varied parameters will be
included as columns. Note that `exact_solution_parameters` does not allow for
[`Vary`](@ref) parameters.

The results of `generate_system`, `generate_exact_solution`, and `calibrate`
can be memoized by passing a Dict-object as `systems_cache`,
`exact_solutions_cache`, and `calibration_cache`, respectively. These may be
persisted to disk using the [`save_cache`](@ref) and [`load_cache`](@ref)
functions. The respective caches must be unique to the given `generate_system`,
`generate_exact_solution`, and `calibrate` function, but otherwise, can be
shared between multiple calls to `run_benchmarks` with different parameters.
"""
function run_benchmarks(;
    system_parameters::OrderedDict,
    systems_cache = Dict(),
    generate_system::Function = generate_system,
    exact_solution_parameters::OrderedDict,
    generate_exact_solution::Function = generate_exact_solution,
    exact_solutions_cache = Dict(),
    benchmark_parameters::OrderedDict,
    generate_benchmark::Function,
    calibration_cache = Dict(),
    calibrate::Function = no_calibrate,
    calibrated_keys_to_store = []
)
    title = "generate systems: "
    system_parameters_expansion = expand_variations(system_parameters)
    missing_system_cache_keys = []
    for params ∈ system_parameters_expansion
        # the params dict serves as the cache key
        if !haskey(systems_cache, params)
            push!(missing_system_cache_keys, params)
        end
    end
    new_systems = _map(generate_system; title, as_kwargs = missing_system_cache_keys)
    for (cache_key, system) ∈ zip(missing_system_cache_keys, new_systems)
        systems_cache[cache_key] = system
    end
    systems = [systems_cache[params] for params ∈ system_parameters_expansion]

    title = "exact solutions:  "
    @assert length(expand_variations(exact_solution_parameters)) == 1
    solution_cache_keys = []  # keys for all systems
    missing_solution_cache_keys = []  # keys for systems not in cache
    systems_with_missing_solution = Any[]
    for (i, system) ∈ enumerate(systems)
        p = system_parameters_expansion[i]
        solution_cache_key = OrderedDict(p..., exact_solution_parameters...)
        push!(solution_cache_keys, solution_cache_key)
        if !haskey(exact_solutions_cache, solution_cache_key)
            push!(missing_solution_cache_keys, solution_cache_key)
            push!(systems_with_missing_solution, system)
        end
    end
    new_solutions = _map(
        generate_exact_solution;
        title,
        as_args = [[s,] for s ∈ systems_with_missing_solution],
        exact_solution_parameters...
    )
    for (solution_cache_key, solution) ∈ zip(missing_solution_cache_keys, new_solutions)
        exact_solutions_cache[solution_cache_key] = solution
    end
    exact_solutions = [
        exact_solutions_cache[solution_cache_key] for
        solution_cache_key ∈ solution_cache_keys
    ]

    title = "calibrate:        "
    benchmark_parameters_expansion = expand_variations(benchmark_parameters)
    benchmark_tasks_args = []
    benchmark_tasks_kwargs = []
    calibration_cache_keys = []
    missing_calibration_cache_keys = []
    missing_calibration_indices = Int64[]
    n = 0
    for i = 1:length(systems)
        for j = 1:length(benchmark_parameters_expansion)
            n += 1
            push!(benchmark_tasks_args, (systems[i], exact_solutions[i]))
            push!(benchmark_tasks_kwargs, benchmark_parameters_expansion[j])
            calibration_cache_key = OrderedDict(
                system_parameters_expansion[i]...,
                exact_solution_parameters...,
                benchmark_parameters_expansion[j]...
            )
            push!(calibration_cache_keys, calibration_cache_key)
            if !haskey(calibration_cache, calibration_cache_key)
                push!(missing_calibration_cache_keys, calibration_cache_key)
                push!(missing_calibration_indices, n)
            end
        end
    end
    new_calibrations = _map(
        calibrate;
        title,
        as_args = benchmark_tasks_args[missing_calibration_indices],
        as_kwargs = benchmark_tasks_kwargs[missing_calibration_indices]
    )
    for (calibration_cache_key, calibrated_parameters) ∈
        zip(missing_calibration_cache_keys, new_calibrations)
        calibration_cache[calibration_cache_key] = calibrated_parameters
    end
    calibrated_benchmark_tasks_kwargs = [
        calibration_cache[calibration_cache_key] for
        calibration_cache_key ∈ calibration_cache_keys
    ]

    title = "benchmark:        "
    benchmark_results = _map(
        generate_benchmark;
        title,
        as_args = benchmark_tasks_args,
        as_kwargs = calibrated_benchmark_tasks_kwargs
    )
    # each benchmark in benchmarks should be an OrderedDict key => data,
    # whatever the `generate_benchmark` function wants

    # combine varied parameters with benchmark results into a table-like
    # CollectedBenchmarks
    benchmarks = OrderedDict[]  # Vector of OrderedDicts
    varied_system_keys = [k for (k, v) ∈ system_parameters if v isa Vary]
    varied_benchmark_keys = [k for (k, v) ∈ benchmark_parameters if v isa Vary]
    varied_keys = Set([varied_system_keys..., varied_benchmark_keys...])
    for (calibration_cache_key, calibrated_params, benchmark_result) ∈
        zip(calibration_cache_keys, calibrated_benchmark_tasks_kwargs, benchmark_results)
        # The `calibration_cache_key` is an OrderedDict containing all the
        # fully expanded original parameters for `generate_system` and
        # `generate_benchmark` (and technically also the
        # exact_solution_parameters, but those are going to be identical for
        # all benchmarks
        varied_params =
            OrderedDict(k => v for (k, v) ∈ calibration_cache_key if k ∈ varied_keys)
        calibrated_wanted_params = OrderedDict(
            k => v for (k, v) ∈ calibrated_params if k ∈ calibrated_keys_to_store
        )
        push!(
            benchmarks,
            OrderedDict(varied_params..., calibrated_wanted_params..., benchmark_result...)
        )
    end

    return CollectedBenchmarks(benchmarks)

end
