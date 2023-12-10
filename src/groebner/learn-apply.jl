# Exposes learn and apply strategy to user

###
# Learn stage

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
    params = AlgorithmParameters(ring, representation, kws)
    ring, term_sorting_permutations =
        set_monomial_ordering!(ring, var_to_index, monoms, coeffs, params)
    term_homogenizing_permutation = Vector{Vector{Int}}()
    if params.homogenize
        term_homogenizing_permutation, ring, monoms, coeffs =
            homogenize_generators!(ring, monoms, coeffs, params)
    end
    trace, gb_monoms, gb_coeffs = _groebner_learn(ring, monoms, coeffs, params)
    if params.homogenize
        trace.term_homogenizing_permutations = term_homogenizing_permutation
        ring, gb_monoms, gb_coeffs =
            dehomogenize_generators!(ring, gb_monoms, gb_coeffs, params)
    end
    trace.representation = representation
    trace.term_sorting_permutations = term_sorting_permutations
    @log level = -7 """Sorting permutations:
    Terms: $(term_sorting_permutations)
    Polynomials: $(trace.input_permutation)"""
    # @print_performance_counters
    trace, convert_to_output(ring, polynomials, gb_monoms, gb_coeffs, params)
end

function _groebner_learn(
    ring,
    monoms,
    coeffs::Vector{Vector{C}},
    params
) where {C <: CoeffFF}
    @log level = -2 "Groebner learn phase over Z_p"
    # Initialize F4 structs
    trace, basis, pairset, hashtable =
        initialize_structs_with_trace(ring, monoms, coeffs, params)
    @log level = -5 "Before F4:" basis
    f4_learn!(trace, ring, trace.gb_basis, pairset, hashtable, params)
    @log level = -5 "After F4:" basis
    gb_monoms, gb_coeffs = export_basis_data(trace.gb_basis, trace.hashtable)
    trace, gb_monoms, gb_coeffs
end

###
# Apply stage

function _groebner_apply!(trace::TraceF4, polynomials, kws::KeywordsHandler)
    ring = extract_coeffs_raw!(trace, trace.representation, polynomials, kws)
    # TODO: this is a bit hacky
    params = AlgorithmParameters(
        ring,
        trace.representation,
        kws,
        orderings=(trace.params.original_ord, trace.params.target_ord)
    )
    ring = PolyRing(trace.ring.nvars, trace.ring.ord, ring.ch)
    flag, gb_monoms, gb_coeffs = _groebner_apply!(ring, trace, params)
    if trace.params.homogenize
        ring, gb_monoms, gb_coeffs =
            dehomogenize_generators!(ring, gb_monoms, gb_coeffs, params)
    end
    # @print_performance_counters
    !flag && return (flag, polynomials)
    flag, convert_to_output(ring, polynomials, gb_monoms, gb_coeffs, params)
end

function _groebner_apply!(ring, trace, params)
    @log level = -1 "Groebner Apply phase"
    @log level = -2 "Applying modulo $(ring.ch)"
    flag = f4_apply!(trace, ring, trace.buf_basis, params)
    gb_monoms, gb_coeffs = export_basis_data(trace.gb_basis, trace.hashtable)
    # Check once again that the sizes coincide
    length(gb_monoms) != length(gb_coeffs) && return false, gb_monoms, gb_coeffs
    @inbounds for i in 1:length(gb_monoms)
        if length(gb_monoms[i]) != length(gb_coeffs[i])
            return false, gb_monoms, gb_coeffs
        end
    end
    flag, gb_monoms, gb_coeffs
end
