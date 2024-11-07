using DataStructures: OrderedDict
import Tables
using PrettyTables: pretty_table

function _update_headers!(headers, new_keys)
    insert_index = 0
    for (i, key) in enumerate(new_keys)
        j = findfirst(isequal(key), headers)
        if isnothing(j)
            insert_index += 1
            insert!(headers, insert_index, key)
        else
            insert_index = j
        end
    end
    return headers
end


struct CollectedBenchmarks
    headers::Vector{Symbol}
    benchmarks::Vector{OrderedDict{Symbol,Any}}
    function CollectedBenchmarks(benchmarks::Vector)
        headers = Symbol[]
        for benchmark::OrderedDict ∈ benchmarks
            _update_headers!(headers, keys(benchmark))
        end
        return new(headers, benchmarks)
    end
end
# TODO: documentation


Tables.istable(::Type{CollectedBenchmarks}) = true
Tables.rowaccess(::Type{CollectedBenchmarks}) = true
Tables.rows(table::CollectedBenchmarks) = table

Base.eltype(b::CollectedBenchmarks) = Any
Base.length(b::CollectedBenchmarks) = length(b.benchmarks)

function Base.getindex(b::CollectedBenchmarks, i::Int64)
    return OrderedDict(key => get(b.benchmarks[i], key, missing) for key ∈ b.headers)
end

function Base.iterate(b::CollectedBenchmarks, st = 1)
    if st > length(b)
        return nothing
    else
        row_data = b[st]
        return (row_data, st + 1)
    end
end

function Base.filter(f, b::CollectedBenchmarks)
    mask = [f(b[i]) for i ∈ 1:length(b)]
    return CollectedBenchmarks(b.benchmarks[mask])
end


function Base.show(io::IO, ::MIME"text/plain", b::CollectedBenchmarks)
    pretty_table(io, b; show_row_number = true)
end

function Base.show(io::IO, ::MIME"text/html", b::CollectedBenchmarks)
    pretty_table(io, b; backend = Val(:html), show_row_number = true)
end

function _assert_equal(a, b)
    if a == b
        return a
    else
        error("All values must match when merging CollectedBenchmarks")
    end
end

function Base.merge(b::CollectedBenchmarks, others::CollectedBenchmarks...)
    N = length(b)
    for other in others
        if length(other) ≠ N
            error("All CollectedBenchmarks must have the same number of rows.")
        end
    end
    return CollectedBenchmarks([
        merge(
            # Can't use mergewith, see
            # https://github.com/JuliaCollections/OrderedCollections.jl/issues/77
            _assert_equal,
            b.benchmarks[i],
            [other.benchmarks[i] for other in others]...
        ) for i = 1:N
    ])
end
