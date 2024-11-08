module PropagationBenchmarks

using StableRNGs: StableRNG

RNG = StableRNG(248221371)

using QuantumPropagators: prop_step!

import InteractiveUtils
import LinearAlgebra
import Pkg
import UUIDs

function _propagate(propagator, tlist)
    N = length(tlist) - 1  # number of intervals
    for _ ∈ 1:N
        prop_step!(propagator)
    end
end


"""Print information about the system running the benchmark."""
function info()
    InteractiveUtils.versioninfo()
    for name in keys(ENV)
        if contains(name, "THREAD") && (name != "JULIA_NUM_THREADS")
            println("  $name = $(ENV[name])")
        end
    end
    blas_config = LinearAlgebra.BLAS.get_config()
    println("BLAS Libraries:")
    for lib in blas_config.loaded_libs
        println("  $(basename(lib.libname)) [$(lib.interface)]")
    end
    println("Packages:")
    project_toml = Pkg.TOML.parsefile(joinpath(@__DIR__, "..", "Project.toml"))
    direct_deps = project_toml["deps"]
    deps = Pkg.dependencies()
    pkg_names = ["QuantumControl", "QuantumPropagators", "QuantumControlTestUtils"]
    col_width = maximum([length(name) for name in pkg_names])
    for name in pkg_names
        pkginfo = deps[UUIDs.UUID(direct_deps[name])]
        if pkginfo.is_tracking_path
            println("  $(rpad(name, col_width)): $(pkginfo.version) ($(pkginfo.source))")
        else
            println("  $(rpad(name, col_width)): $(pkginfo.version)")
        end
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
