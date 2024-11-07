using QuantumControl: propagate
using LinearAlgebra: norm


function calibrate_cheby(system, exact_solution; precision, kwargs...)
    cheby_coeffs_limit_candidates = Float64[
        1e-2,
        1e-3,
        1e-4,
        1e-5,
        1e-6,
        1e-7,
        1e-8,
        1e-9,
        1e-10,
        1e-11,
        1e-12,
        1e-13,
        1e-14,
        1e-15,
    ]
    verbose = false
    Ψ₀ = system.initial_state
    H = system.generator
    tlist = system.tlist
    Ψ_exact = exact_solution
    if precision < 1e-14
        if verbose
            println("Tuned cheby: precision $precision → default 'machine precision'",)
        end
        return kwargs
    end
    i::Int = 0
    N = length(cheby_coeffs_limit_candidates)
    cheby_coeffs_limit::Float64 = precision
    i_start = max(1, Int(round(log(10, precision))) - 2)
    for i = i_start:N
        cheby_coeffs_limit = cheby_coeffs_limit_candidates[i]
        tuned_args =
            merge(kwargs, Dict(:cheby_coeffs_limit => cheby_coeffs_limit, :check => false))
        Ψ = propagate(Ψ₀, H, tlist; tuned_args...)
        task_error = norm(Ψ - Ψ_exact)
        if task_error ≤ precision
            if verbose
                println(
                    "Tuned cheby: precision $precision with cheby_coeffs_limit=$cheby_coeffs_limit",
                )
            end
            tuned_args = merge(kwargs, Dict(:cheby_coeffs_limit => cheby_coeffs_limit))
            return tuned_args
        end
    end
    error("Could not tune cheby")
end
