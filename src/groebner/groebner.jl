# Backend for `groebner`

# Proxy function for handling exceptions.
function _groebner(polynomials, kws::KeywordsHandler)
    # We try to select an efficient internal polynomial representation, i.e., a
    # suitable representation of monomials and coefficients.
    polynomial_repr = select_polynomial_representation(polynomials, kws)
    try
        # The backend is wrapped in a try/catch to catch exceptions that one can
        # hope to recover from (and, perhaps, restart the computation with safer
        # parameters).
        return _groebner(polynomials, kws, polynomial_repr)
    catch err
        if isa(err, MonomialDegreeOverflow)
            @log level = 1 """
            Possible overflow of exponent vector detected. 
            Restarting with at least $(32) bits per exponent."""
            polynomial_repr =
                select_polynomial_representation(polynomials, kws, hint=:large_exponents)
            return _groebner(polynomials, kws, polynomial_repr)
        else
            # Something bad happened.
            rethrow(err)
        end
    end
end

function _groebner(
    polynomials,
    kws::KeywordsHandler,
    representation::PolynomialRepresentation
)
    # Extract ring information, exponents, and coefficients from the input
    # polynomials. Convert these to an internal polynomial representation. 
    # NOTE: This must copy the input, so that input `polynomials` is never
    # modified.
    ring, var_to_index, monoms, coeffs =
        convert_to_internal(representation, polynomials, kws)
    # Check and set parameters and monomial ordering
    params = AlgorithmParameters(ring, kws)
    # NOTE: at this point, we already know the computation method we are going to use,
    # and the parameters are set.
    ring = set_monomial_ordering!(ring, var_to_index, monoms, coeffs, params)
    # Fast path for the input of zeros
    if isempty(monoms)
        @log level = -2 "Input consisting of zero polynomials. Returning zero."
        return convert_to_output(ring, polynomials, monoms, coeffs, params)
    end
    # Compute a groebner basis!
    gbmonoms, gbcoeffs = _groebner(ring, monoms, coeffs, params)
    # Convert result back to the representation of input
    convert_to_output(ring, polynomials, gbmonoms, gbcoeffs, params)
end

# Groebner basis over Z_p.
# Just calls f4 directly.
function _groebner(
    ring::PolyRing,
    monoms::Vector{Vector{M}},
    coeffs::Vector{Vector{C}},
    params::AlgorithmParameters
) where {M <: Monom, C <: CoeffFF}
    # NOTE: we can mutate ring, monoms, and coeffs here.
    @log level = -1 "Backend: F4 over Z_$(ring.ch)"
    # NOTE: the sorting of input polynomials is not deterministic across
    # different Julia versions when sorting only w.r.t. the leading term
    basis, pairset, hashtable = initialize_structs(ring, monoms, coeffs, params)
    tracer = Tracer()
    f4!(ring, basis, pairset, hashtable, tracer, params)
    # Extract monomials and coefficients from basis and hashtable
    gbmonoms, gbcoeffs = export_basis_data(basis, hashtable)
    gbmonoms, gbcoeffs
end

# Groebner basis over Q.
# GB over the rationals uses modular computation.
function _groebner(
    ring::PolyRing,
    monoms::Vector{Vector{M}},
    coeffs::Vector{Vector{C}},
    params::AlgorithmParameters
) where {M <: Monom, C <: CoeffQQ}
    # NOTE: we can mutate ring, monoms, and coeffs here.
    # if params.strategy === :learn_and_apply
    #     _groebner_learn_and_apply(ring, monoms, coeffs, params)
    # else
    #     @assert params.strategy === :classic_modular
    #     _groebner_classic_modular(ring, monoms, coeffs, params)
    # end
    _groebner_classic_modular(ring, monoms, coeffs, params)
end

# Proxy function for handling exceptions.
# NOTE: probably at some point we'd want to merge this with error handling in
# _groebner. But for now, we keep it simple.
function _groebner_learn(polynomials, kws::KeywordsHandler)
    # We try to select an efficient internal polynomial representation, i.e., a
    # suitable representation of monomials and coefficients.
    polynomial_repr = select_polynomial_representation(polynomials, kws)
    try
        # The backend is wrapped in a try/catch to catch exceptions that one can
        # hope to recover from (and, perhaps, restart the computation with safer
        # parameters).
        return _groebner_learn(polynomials, kws, polynomial_repr)
    catch err
        if isa(err, MonomialDegreeOverflow)
            @log level = 1 """
            Possible overflow of exponent vector detected. 
            Restarting with at least $(32) bits per exponent."""
            polynomial_repr =
                select_polynomial_representation(polynomials, kws, hint=:large_exponents)
            return _groebner_learn(polynomials, kws, polynomial_repr)
        else
            # Something bad happened.
            rethrow(err)
        end
    end
end

function _groebner_learn(polynomials, kws, representation)
    ring, var_to_index, monoms, coeffs =
        convert_to_internal(representation, polynomials, kws)
    if isempty(monoms)
        @log level = -2 "Input consisting of zero polynomials. Error will follow"
        throw(DomainError("Input consisting of zero polynomials."))
    end
    params = AlgorithmParameters(ring, kws)
    ring = set_monomial_ordering!(ring, var_to_index, monoms, coeffs, params)
    graph, gb_monoms, gb_coeffs = _groebner_learn(ring, monoms, coeffs, params)
    graph.representation = representation
    graph, convert_to_output(ring, polynomials, gb_monoms, gb_coeffs, params)
end

function _groebner_apply!(graph::ComputationGraphF4, polynomials, kws::KeywordsHandler)
    # representation = select_polynomial_representation(polynomials, kws)
    ring = extract_coeffs_raw!(graph, graph.representation, polynomials, kws)
    @assert _is_input_compatible(graph, ring, kws) "Input does not seem to be compatible with the learned graph."
    params = AlgorithmParameters(ring, kws)
    flag, gb_monoms, gb_coeffs = _groebner_apply!(ring, graph, params)
    !flag && return (flag, polynomials)
    flag, convert_to_output(ring, polynomials, gb_monoms, gb_coeffs, params)
end

function _is_input_compatible(graph, ring, kws)
    # TODO: Check that leading monomials coincide!
    if graph.ring.ord != ring.ord
        @log level = -1 "Input ordering is different from the one used to learn the graph."
        # TODO
        # return false
        return true
    end
    if graph.sweep_output != kws.sweep
        @log level = 1 "Input sweep option is different ($(kws.sweep)) from the one used to learn the graph ($(graph.sweep_output))."
        return false
    end
    @log level = -1 "In groebner_apply! the argument monom=$(kws.monoms) was ignored"
    true
end

function _groebner_learn(
    ring,
    monoms,
    coeffs::Vector{Vector{C}},
    params
) where {C <: CoeffFF}
    @log level = -2 "Groebner learn phase over Z_p"
    # Initialize F4 structs
    graph, basis, pairset, hashtable =
        initialize_structs_learn(ring, monoms, coeffs, params)
    @log level = -5 "Before F4:" basis
    f4_learn!(graph, ring, graph.gb_basis, pairset, hashtable, params)
    @log level = -5 "After F4:" basis
    gb_monoms, gb_coeffs = export_basis_data(graph.gb_basis, graph.hashtable)
    graph, gb_monoms, gb_coeffs
end

function _groebner_apply!(ring, graph, params)
    @log level = -1 "Groebner Apply phase"
    @log level = -2 "Applying modulo $(ring.ch)"
    flag = f4_apply!(graph, ring, graph.buf_basis, params)
    gb_monoms, gb_coeffs = export_basis_data(graph.gb_basis, graph.hashtable)
    # Check once again that the sizes coincide
    length(gb_monoms) != length(gb_coeffs) && return false, gb_monoms, gb_coeffs
    @inbounds for i in 1:length(gb_monoms)
        if length(gb_monoms[i]) != length(gb_coeffs[i])
            return false, gb_monoms, gb_coeffs
        end
    end
    flag, gb_monoms, gb_coeffs
end

function _groebner_classic_modular(
    ring::PolyRing,
    monoms::Vector{Vector{M}},
    coeffs::Vector{Vector{C}},
    params::AlgorithmParameters
) where {M <: Monom, C <: CoeffQQ}
    # NOTE: we can mutate ring, monoms, and coeffs here.
    @log level = -1 "Backend: classic multi-modular F4"
    # Initialize supporting structs
    state = GroebnerState{BigInt, C}(params)
    # Initialize F4 structs
    basis, pairset, hashtable =
        initialize_structs(ring, monoms, coeffs, params, normalize=false)
    tracer = Tracer(params)
    # Scale the input coefficients to integers to speed up the subsequent search
    # for lucky primes
    @log level = -5 "Input polynomials" basis
    @log level = -2 "Clearing the denominators of the input polynomials"
    basis_zz = clear_denominators!(state.buffer, basis, deepcopy=false)
    @log level = -5 "Integer coefficients are" basis_zz.coeffs
    # Handler for lucky primes
    luckyprimes = LuckyPrimes(basis_zz.coeffs)
    prime = next_lucky_prime!(luckyprimes)
    @log level = -2 "The first lucky prime is $prime"
    @log level = -2 "Reducing input generators modulo $prime"
    # Perform reduction modulo prime and store result in basis_ff
    ring_ff, basis_ff = reduce_modulo_p!(state.buffer, ring, basis_zz, prime, deepcopy=true)
    @log level = -5 "Reduced coefficients are" basis_ff.coeffs
    #####
    @log level = -5 "Before F4" basis_ff
    f4!(ring_ff, basis_ff, pairset, hashtable, tracer, params)
    @log level = -5 "After F4:" basis_ff
    # Reconstruct coefficients and write results to the accumulator.
    # CRT reconstrction is trivial here.
    @log level = -2 "Reconstructing coefficients from Z_$prime to QQ"
    crt_reconstruct!(state, ring_ff, luckyprimes, basis_ff)
    success_reconstruct = rational_reconstruct!(state, luckyprimes)
    @log level = -5 "Reconstructed coefficients" state.gb_coeffs_qq
    @log level = -2 "Successfull reconstruction: $success_reconstruct"
    correct_basis = false
    if success_reconstruct
        @log level = -2 "Verifying the correctness of reconstruction"
        correct_basis = correctness_check!(
            state,
            luckyprimes,
            ring_ff,
            basis,
            basis_zz,
            basis_ff,
            hashtable,
            params
        )
        @log level = -2 "Passed correctness check: $correct_basis"
        # At this point, if the constructed basis is correct, we return it.
        if correct_basis
            # take monomials from the basis modulo a prime
            gb_monoms, _ = export_basis_data(basis_ff, hashtable)
            # take coefficients from the reconstrcted basis
            gb_coeffs_qq = state.gb_coeffs_qq
            return gb_monoms, gb_coeffs_qq
        end
    end
    # At this point, either the reconstruction or the correctness check failed.
    # Continue to compute Groebner bases modulo different primes in batches. 
    batchsize = 1
    batchsize_multiplier = 2
    @log level = -2 """
      Preparing to compute bases in batches.. 
      The initial size of the batch is $batchsize. 
      The size increases in a geometric progression. 
      The batch size multiplier is $batchsize_multiplier.
      """
    if !tracer.ready_to_use
        @log level = -2 """
          The tracer is disabled until the shape of the basis is not determined via majority vote.
          The threshold for the majority vote is $(params.majority_threshold)
          """
    end
    # After each computed basis we reconstruct from (Z_n, Z_m) to Z_mn via the
    # linear CRT reconstrction. Rational reconstruction is applied only at the
    # end of the batch.
    iters = 0
    while !correct_basis
        @log level = -2 """
          Used $(length(luckyprimes.primes)) primes in total over $(iters) iterations.
          The current batch size is $batchsize.
          """
        for j in 1:batchsize
            prime = next_lucky_prime!(luckyprimes)
            @log level = -2 "The lucky prime is $prime"
            @log level = -2 "Reducing input generators modulo $prime"
            # Perform reduction modulo prime and store result in basis_ff
            ring_ff, basis_ff =
                reduce_modulo_p!(state.buffer, ring, basis_zz, prime, deepcopy=true)
            f4!(ring_ff, basis_ff, pairset, hashtable, tracer, params)
            if !majority_vote!(state, basis_ff, tracer, params)
                @log level = -2 "Majority vote is not conclusive, aborting reconstruction!"
                continue
            end
            @log level = -2 "Reconstructing coefficients from Z_$(luckyprimes.modulo) * Z_$(prime) to Z_$(luckyprimes.modulo * prime)"
            crt_reconstruct!(state, ring_ff, luckyprimes, basis_ff)
        end
        @log level = -2 "Reconstructing coefficients from Z_$(luckyprimes.modulo * prime) to QQ"
        success_reconstruct = rational_reconstruct!(state, luckyprimes)
        @log level = -2 "Reconstruction successfull: $success_reconstruct"
        !success_reconstruct && continue
        correct_basis = correctness_check!(
            state,
            luckyprimes,
            ring_ff,
            basis,
            basis_zz,
            basis_ff,
            hashtable,
            params
        )
        iters += 1
        batchsize = batchsize * batchsize_multiplier
    end
    @log level = -2 "Correctness check passed!"
    @log level = -2 "Used $(length(luckyprimes.primes)) primes in total over $(iters) iterations"
    # take monomials from the basis modulo a prime
    gb_monoms, _ = export_basis_data(basis_ff, hashtable)
    # take coefficients from the reconstrcted basis
    gb_coeffs_qq = state.gb_coeffs_qq
    return gb_monoms, gb_coeffs_qq
end
