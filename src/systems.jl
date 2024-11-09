using DataStructures: OrderedDict
using QuantumPropagators: propagate
using QuantumControlTestUtils.RandomObjects: random_dynamic_generator, random_state_vector
using StableRNGs: StableRNG


"""A system for benchmarking time propagation.

```julia
system = BenchmarkSystem(initial_state, generator, tlist)
```

wraps around the given state, generator, and time grid.
"""
struct BenchmarkSystem{ST,GT}
    initial_state::ST
    generator::GT
    tlist::Vector{Float64}
    function BenchmarkSystem(
        initial_state::ST,
        generator::GT,
        tlist::Vector{Float64}
    ) where {ST,GT}
        return new{ST,GT}(initial_state, generator, tlist)
    end
end


"""Construct a system for benchmarking time propagation.

```julia
system = generate_system(; N, dt=1.0, nt=1001, kwargs...)
```

returns a [`BenchmarkSystem`](@ref) based on
`QuantumControlTestUtils.RandomObjects.random_dynamic_generator` and
`QuantumControlTestUtils.RandomObjects.random_state_vector`.

To ensure that `generate_system` is deterministic, a stable random number
generator is used, with a seed derived from hashing the parameters.

This function is the default `generate_system` for [`run_benchmarks`](@ref).
"""
function generate_system(; N, dt = 1.0, nt = 1001, kwargs...)
    seed = hash(OrderedDict(:N => N, :dt => dt, :nt => nt, kwargs...))
    rng = StableRNG(seed)
    tlist = collect(range(0, step = dt, length = nt))
    H = random_dynamic_generator(N, tlist; rng, kwargs...)
    Ψ₀ = random_state_vector(N; rng)
    return BenchmarkSystem(Ψ₀, H, tlist)
end


"""Determine an "exact" solution for the given `system`.

```julia
Ψ = generate_exact_solution(system; kwargs...)
```

propagates the given [`BenchmarkSystem`](@ref) using
`QuantumPropagators.propagate` with the given keyword arguments.
"""
function generate_exact_solution(system::BenchmarkSystem; kwargs...)
    return propagate(system.initial_state, system.generator, system.tlist; kwargs...)
end

"""Do not generate an exact solutions"""
do_not_use_exact_solution(args...; kwargs...) = nothing
