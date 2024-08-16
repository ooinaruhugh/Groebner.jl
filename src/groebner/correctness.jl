# This file is a part of Groebner.jl. License is GNU GPL v2.

### 
# Checking correctness in modular computation

@noinline __not_a_basis_error(basis, msg) = throw(DomainError(basis, msg))

# Checks if the basis is reconstructed correctly.
# There are 3 levels of checks:
#   - heuristic check (dedicated to discard obviously bad cases),
#   - randomized check (checks correctness modulo a prime),
#   - certification (checks correctness directly over the rationals).
#
# Usually, by default, only the first two are active, which gives the correct
# basis with a high probability
@timeit function correctness_check!(
        state,
    lucky,
    ring,
    basis_qq,
    basis_zz,
    basis_ff,
    hashtable,
    params
)
    # First we check the size of the coefficients with a heuristic
    if params.heuristic_check
        if !heuristic_correctness_check(state.gb_coeffs_qq, lucky.modulo)
            @log :misc "Heuristic check failed."
            return false
        end
        @log :misc "Heuristic check passed!"
    end

    # Then check that a basis is also a basis modulo a prime
    if params.randomized_check
        if !randomized_correctness_check!(

            state,
            ring,
            basis_zz,
            basis_ff,
            lucky,
            hashtable,
            params
        )
            @log :misc "Randomized check failed."
            return false
        end
        @log :misc "Randomized check passed!"
    end
    if params.certify_check
        return certify_correctness_check!(

            state,
            ring,
            basis_qq,
            basis_ff,
            hashtable,
            params
        )
    end
    true
end

# Heuristic bound on the size of coefficients of the basis.
threshold_in_heuristic_check(sznum, szden, szmod) = 1.10 * (sznum + szden) >= szmod

# Checks that 
#   ln(num) + ln(den) < C ln(modulo)
# for all coefficients of form num/den
function heuristic_correctness_check(
    gb_coeffs_qq::Vector{Vector{T}},
    modulo::BigInt
) where {T <: CoeffQQ}
    modulo_size = Base.GMP.MPZ.sizeinbase(modulo, 2)

    @inbounds for i in 1:length(gb_coeffs_qq)
        res = heuristic_correctness_check(gb_coeffs_qq[i], modulo, modulo_size)
        !res && return false
    end

    true
end

function heuristic_correctness_check(
    gb_coeffs_qq::Vector{T},
    modulo::BigInt,
    modulo_size=Base.GMP.MPZ.sizeinbase(modulo, 2)
) where {T <: CoeffQQ}
    @inbounds for i in 1:length(gb_coeffs_qq)
        n = numerator(gb_coeffs_qq[i])
        d = denominator(gb_coeffs_qq[i])

        if threshold_in_heuristic_check(
            Base.GMP.MPZ.sizeinbase(n, 2),
            Base.GMP.MPZ.sizeinbase(d, 2),
            modulo_size
        )
            @log :debug "Heuristic check failed for coefficient $n/$d and modulo $modulo"
            return false
        end
    end

    true
end

function randomized_correctness_check!(
        state,
    ring,
    input_zz,
    gb_ff,
    lucky,
    hashtable,
    params
)
    # NOTE: this function may modify the given hashtable!
    prime = next_check_prime!(lucky)
    @log :misc "Checking the correctness of reconstrcted basis modulo $prime"
    ring_ff, input_ff =
        reduce_modulo_p!(state.buffer, ring, input_zz, prime, deepcopy=true)
    # TODO: do we really need to re-scale things to be fraction-free?
    gb_coeffs_zz = _clear_denominators!(state.buffer, state.gb_coeffs_qq)
    gb_zz = basis_deep_copy_with_new_coeffs(gb_ff, gb_coeffs_zz)
    ring_ff, gb_ff = reduce_modulo_p!(state.buffer, ring, gb_zz, prime, deepcopy=false)
    # Check that initial ideal contains in the computed groebner basis modulo a
    # random prime
    arithmetic = select_arithmetic(CoeffModular, prime, :auto, false)
    basis_make_monic!(gb_ff, arithmetic, params.changematrix)
    f4_normalform!(ring_ff, gb_ff, input_ff, hashtable, arithmetic)
    for i in 1:(input_ff.nprocessed)
        # meaning that something is not reduced
        if !io_iszero_coeffs(input_ff.coeffs[i])
            @log :misc "Some input generators are not in the ideal generated by the reconstructed basis modulo $prime"
            return false
        end
    end
    # Check that the basis is a groebner basis modulo a prime
    pairset = pairset_initialize(UInt64)
    if !f4_isgroebner!(ring_ff, gb_ff, pairset, hashtable, arithmetic)
        @log :misc "Not all of S-polynomials reduce to zero modulo $prime"
        return false
    end
    true
end

function certify_correctness_check!(state, ring, input_qq, gb_ff, hashtable, params)
    @log :misc "Checking the correctness of reconstructed basis over the rationals"
    gb_qq = basis_deep_copy_with_new_coeffs(gb_ff, state.gb_coeffs_qq)
    ring_qq = PolyRing(ring.nvars, ring.ord, 0)
    input_qq = basis_deepcopy(input_qq)
    f4_normalform!(ring_qq, gb_qq, input_qq, hashtable, params.arithmetic)
    for i in 1:(input_qq.nprocessed)
        # Meaning that some polynomial is not reduced to zero
        if !io_iszero_coeffs(input_qq.coeffs[i])
            @log :misc "Some input generators are not in the ideal generated by the reconstructed basis"
            return false
        end
    end
    # Check that the basis is a groebner basis modulo a prime
    pairset = pairset_initialize(UInt64)
    if !f4_isgroebner!(ring_qq, gb_qq, pairset, hashtable, params.arithmetic)
        @log :misc "Not all of S-polynomials reduce to zero"
        return false
    end
    true
end

# TODO :)
function majority_vote!(state, basis_ff, params)
    true
end
