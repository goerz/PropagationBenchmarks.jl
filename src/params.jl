using DataStructures: OrderedDict

"""A parameter value that is to be varied in a benchmark.

See [`params`](@ref).
"""
struct Vary{T}
    values::Vector{T}
    function Vary(values::Vararg{T}) where {T}
        if length(values) < 2
            error("Must specify more than one value")
        end
        new{T}(T[values...])
    end
    function Vary(values::Vector{T}) where {T}
        if length(values) < 2
            error("Must specify more than one value")
        end
        new{T}(values)
    end
end


"""Construct parameters for `run_benchmarks`.

E.g.

```julia
system_parameters = params(
    N=Vary(10, 100, 1000),
    exact_spectral_envelope=true,
    hermitian=true
),
```

returns an `OrderedDict` of the given keyword arguments, suitable for passing
to `run_benchmarks`. All values must be numbers, strings, symbols, or instances
of [`Vary`](@ref).
"""
function params(; kwargs...)
    return OrderedDict(k => v for (k, v) ∈ kwargs)
end


function expand_variations(p::OrderedDict{Symbol,T}) where {T}
    value_of_sane_type = Union{Number,String,Symbol,Module}
    keys_to_vary = Symbol[]
    for (k, v) ∈ p
        if v isa Vary
            push!(keys_to_vary, k)
        else
            @assert v isa value_of_sane_type "typeof(v) = $(typeof(v))"
        end
    end
    result = OrderedDict{Symbol,Any}[]
    for vals in Iterators.product([p[k].values for k ∈ keys_to_vary]...)
        p_expanded = OrderedDict{Symbol,Any}(k => v for (k, v) ∈ p)
        for (k, v) ∈ zip(keys_to_vary, vals)
            @assert v isa value_of_sane_type
            p_expanded[k] = v
        end
        push!(result, p_expanded)
    end
    return result
end
