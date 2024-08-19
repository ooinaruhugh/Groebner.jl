# This file is a part of Groebner.jl. License is GNU GPL v2.

### 
# Select parameters in Groebner basis computation

# Specifies linear algebra backend algorithm
struct LinearAlgebra
    algorithm::Symbol
    sparsity::Symbol

    LinearAlgebra(algorithm, sparsity) = new(algorithm, sparsity)
end

struct PolynomialRepresentation
    monomtype::Type
    coefftype::Type
    # If this field is false, then any implementation of the arithmetic in Z/Zp
    # must cast the coefficients into a wider integer type before performing any
    # arithmetic operations to avoid the risk of overflow.
    using_wide_type_for_coeffs::Bool
end

function gb_select_polynomial_representation(
    char,
    nvars,
    ordering,
    homogenize,
    monoms,
    arithmetic;
    hint::Symbol=:none
)
    if !(hint in (:none, :large_exponents))
        @log :warn "The given hint=$hint was discarded"
    end
    monomtype = gb_select_monomtype(char, nvars, ordering, homogenize, hint, monoms)
    coefftype, using_wide_type_for_coeffs =
        gb_select_coefftype(char, nvars, ordering, homogenize, hint, monoms, arithmetic)
    PolynomialRepresentation(monomtype, coefftype, using_wide_type_for_coeffs)
end

function gb_select_monomtype(char, nvars, ordering, homogenize, hint, monoms)
    if hint === :large_exponents
        # use 64 bits if large exponents detected
        desired_monom_type = ExponentVector{UInt64}
        @assert monom_is_supported_ordering(desired_monom_type, ordering)
        return desired_monom_type
    end

    # If homogenization is requested, or if a part of the ordering is
    # lexicographical, the generators will potentially be homogenized later.
    if homogenize
        desired_monom_type = ExponentVector{UInt32}
        @assert monom_is_supported_ordering(desired_monom_type, ordering)
        return desired_monom_type
    end

    ExponentSize = UInt8
    variables_per_word = div(sizeof(UInt), sizeof(ExponentSize))
    # if dense representation is requested
    if monoms === :dense
        @assert monom_is_supported_ordering(ExponentVector{ExponentSize}, ordering)
        return ExponentVector{ExponentSize}
    end

    # if sparse representation is requested
    if monoms === :sparse
        if monom_is_supported_ordering(
            SparseExponentVector{ExponentSize, Int32, nvars},
            ordering
        )
            return SparseExponentVector{ExponentSize, Int32, nvars}
        end
        @log :info """
        The given monomial ordering $(ordering) is not implemented for
        $(monoms) monomial representation. Falling back to other monomial
        representations."""
    end

    # if packed representation is requested
    if monoms === :packed
        if monom_is_supported_ordering(PackedTuple1{UInt64, ExponentSize}, ordering)
            if nvars < variables_per_word
                return PackedTuple1{UInt64, ExponentSize}
            elseif nvars < 2 * variables_per_word
                return PackedTuple2{UInt64, ExponentSize}
            elseif nvars < 3 * variables_per_word
                return PackedTuple3{UInt64, ExponentSize}
            elseif nvars < 4 * variables_per_word
                return PackedTuple4{UInt64, ExponentSize}
            end
            @log :info """
            Unable to use $(monoms) monomial representation, too many
            variables ($nvars). Falling back to dense monomial
            representation."""
        else
            @log :info """
            The given monomial ordering $(ordering) is not implemented for
            $(monoms) monomial representation. Falling back to dense
            representation."""
        end
    end

    # in the automatic choice, we always prefer packed representations
    if monoms === :auto
        if monom_is_supported_ordering(PackedTuple1{UInt64, ExponentSize}, ordering)
            if nvars < variables_per_word
                return PackedTuple1{UInt64, ExponentSize}
            elseif nvars < 2 * variables_per_word
                return PackedTuple2{UInt64, ExponentSize}
            elseif nvars < 3 * variables_per_word
                return PackedTuple3{UInt64, ExponentSize}
            elseif nvars < 4 * variables_per_word
                return PackedTuple4{UInt64, ExponentSize}
            end
        end
    end

    ExponentVector{ExponentSize}
end

function gb_get_tight_signed_int_type(x::T) where {T <: Integer}
    types = (Int8, Int16, Int32, Int64, Int128)
    idx = findfirst(T -> x <= typemax(T), types)
    @assert !isnothing(idx)
    types[idx]
end

function gb_get_tight_unsigned_int_type(x::T) where {T <: Integer}
    types = (UInt8, UInt16, UInt32, UInt64, UInt128)
    idx = findfirst(T -> x <= typemax(T), types)
    @assert !isnothing(idx)
    types[idx]
end

function gb_select_coefftype(
    char,
    nvars,
    ordering,
    homogenize,
    hint,
    monoms,
    arithmetic;
    using_wide_type_for_coeffs=false
)
    if iszero(char)
        return Rational{BigInt}, true
    end
    @assert char > 0
    @assert char < typemax(UInt64)

    tight_signed_type = gb_get_tight_signed_int_type(char)

    if arithmetic === :floating
        return Float64, true
    end

    if arithmetic === :signed
        if typemax(Int32) < char < typemax(UInt32) ||
           typemax(Int64) < char < typemax(UInt64)
            @log :warn "Cannot use $(arithmetic) arithmetic with characteristic $char"
            @assert false
        elseif !using_wide_type_for_coeffs
            return tight_signed_type, using_wide_type_for_coeffs
        else
            return widen(tight_signed_type), using_wide_type_for_coeffs
        end
    end

    tight_unsigned_type = gb_get_tight_unsigned_int_type(char)
    tight_unsigned_type = if !using_wide_type_for_coeffs
        tight_unsigned_type
    else
        widen(tight_unsigned_type)
    end

    tight_unsigned_type, using_wide_type_for_coeffs
end

# Stores parameters for a single GB computation.
mutable struct AlgorithmParameters{MonomOrd1, MonomOrd2, Arithmetic <: AbstractArithmetic}
    # NOTE: in principle, MonomOrd1, ..., MonomOrd3 can be subtypes of any type

    # Desired monomial ordering of output polynomials
    target_ord::MonomOrd1
    # Original monomial ordering of input polynomials
    original_ord::MonomOrd2

    # Specifies correctness checks levels
    heuristic_check::Bool
    randomized_check::Bool
    certify_check::Bool

    # If do homogenize input generators
    homogenize::Bool

    # This option only makes sense for functions `normalform` and `kbase`. It
    # specifies if the program should check if the input is indeed a Groebner
    # basis.
    check::Bool

    # Linear algebra backend to be used
    linalg::LinearAlgebra

    # This can hold buffers or precomputed multiplicative inverses to speed up
    # the arithmetic in the ground field
    arithmetic::Arithmetic
    representation::PolynomialRepresentation

    # If reduced Groebner basis is needed
    reduced::Bool

    # Limit the number of critical pairs in the F4 matrix by this number
    maxpairs::Int

    # Selection strategy. One of the following:
    # - :normal
    # well, it is tricky to implement sugar selection with F4..
    selection_strategy::Symbol

    # Ground field of computation. This can be one of the following:
    # - :qq for the rationals
    # - :zp for integers modulo a prime
    ground::Symbol

    # Strategy for modular computation in groebner. This can be one of the
    # following:
    # - :classic_modular
    # - :learn_and_apply
    modular_strategy::Symbol
    batched::Bool

    # In modular computation of the basis, compute (at least!) this many bases
    # modulo different primes until a consensus in majority vote is reached
    majority_threshold::Int

    # Use multi-threading.
    threaded_f4::Symbol
    threaded_multimodular::Symbol

    # Random number generator
    seed::UInt64
    rng::Random.Xoshiro

    # Internal option for `groebner`.
    # At the end of F4, polynomials are interreduced. 
    # We can mark and sweep polynomials that are redundant prior to
    # interreduction to speed things up a bit. This option specifies if such
    # sweep should be done.
    sweep::Bool

    statistics::Symbol

    use_flint::Bool

    changematrix::Bool
end

function AlgorithmParameters(ring, kwargs::KeywordArguments; hint=:none, orderings=nothing)
    if orderings !== nothing
        target_ord = orderings[2]
        original_ord = orderings[1]
    else
        if kwargs.ordering === InputOrdering() || kwargs.ordering === nothing
            ordering = ring.ord
        else
            ordering = kwargs.ordering
        end
        target_ord = ordering
        original_ord = ring.ord
    end

    heuristic_check = true
    randomized_check = true
    certify_check = kwargs.certify

    homogenize = if kwargs.homogenize === :yes
        true
    else
        if kwargs.homogenize === :auto
            if ring.nvars <= 1
                false
            elseif target_ord isa Lex || target_ord isa ProductOrdering
                true
            else
                false
            end
        else
            false
        end
    end

    linalg = kwargs.linalg
    if !iszero(ring.ch) && (linalg === :randomized || linalg === :auto)
        # Do not use randomized linear algebra if the field characteristic is
        # too small. 
        # TODO: In the future, it would be good to adapt randomized linear
        # algebra to this case by taking more random samples
        if ring.ch < 500
            if linalg === :randomized
                @log :misc """
                The field characteristic is too small ($(ring.ch)).
                Switching from randomized linear algebra to a deterministic one."""
            end
            linalg = :deterministic
        end
    end
    if linalg === :auto
        linalg = :randomized
    end
    linalg_sparsity = :sparse
    linalg_algorithm = LinearAlgebra(linalg, linalg_sparsity)

    representation = gb_select_polynomial_representation(
        ring.ch,
        ring.nvars,
        target_ord,
        homogenize,
        kwargs.monoms,
        kwargs.arithmetic,
        hint=hint
    )

    arithmetic = select_arithmetic(
        representation.coefftype,
        ring.ch,
        kwargs.arithmetic,
        representation.using_wide_type_for_coeffs
    )

    ground = :zp
    if iszero(ring.ch)
        ground = :qq
    end

    reduced = kwargs.reduced
    maxpairs = kwargs.maxpairs

    selection_strategy = kwargs.selection
    if selection_strategy === :auto
        if target_ord isa Union{Lex, ProductOrdering}
            selection_strategy = :normal # TODO :sugar
        else
            selection_strategy = :normal
        end
    end

    threaded = kwargs.threaded
    if !(_threaded[])
        if threaded === :yes
            @log :warn """
            You have explicitly provided keyword argument `threaded = :yes`,
            however, multi-threading is disabled globally in Groebner.jl due to
            the environment variable GROEBNER_NO_THREADED=0.

            Consider enabling threading by setting GROEBNER_NO_THREADED to 1"""
        end
        threaded = :no
    end

    if ground === :zp
        threaded_f4 = threaded
        threaded_multimodular = :no
    else
        @assert ground === :qq
        threaded_f4 = :no
        threaded_multimodular = threaded
    end

    # By default, modular computation uses learn & apply
    modular_strategy = kwargs.modular
    if modular_strategy === :auto
        modular_strategy = :learn_and_apply
    end
    if !reduced
        @log :misc """
        The option reduced=$reduced was passed in the input, 
        falling back to classic multi-modular algorithm."""
        modular_strategy = :classic_modular
    end
    batched = kwargs.batched

    majority_threshold = 1

    seed = kwargs.seed
    rng = Random.Xoshiro(seed)
    useed = UInt64(seed)

    sweep = kwargs.sweep

    statistics = kwargs.statistics

    use_flint = kwargs.use_flint

    changematrix = kwargs.changematrix
    if changematrix
        if !(target_ord isa DegRevLex)
            __throw_input_not_supported(
                "Only DegRevLex is supported with changematrix = true.",
                target_ord
            )
        end
    end

    @log :misc """
    Selected parameters:
    target_ord = $target_ord
    original_ord = $original_ord
    heuristic_check = $heuristic_check
    randomized_check = $randomized_check
    certify_check = $certify_check
    check = $(kwargs.check)
    linalg = $linalg_algorithm
    threaded_f4 = $threaded_f4
    threaded_multimodular = $threaded_multimodular
    arithmetic = $arithmetic
    using_wide_type_for_coeffs = $(representation.using_wide_type_for_coeffs)
    reduced = $reduced
    homogenize = $homogenize
    maxpairs = $maxpairs
    selection_strategy = $selection_strategy
    ground = $ground
    modular_strategy = $modular_strategy
    batched = $batched
    majority_threshold = $majority_threshold
    seed = $seed
    rng = $rng
    sweep = $sweep
    statistics = $statistics
    use_flint = $use_flint
    changematrix = $changematrix"""

    AlgorithmParameters(
        target_ord,
        original_ord,
        heuristic_check,
        randomized_check,
        certify_check,
        homogenize,
        kwargs.check,
        linalg_algorithm,
        arithmetic,
        representation,
        reduced,
        maxpairs,
        selection_strategy,
        ground,
        modular_strategy,
        batched,
        majority_threshold,
        threaded_f4,
        threaded_multimodular,
        useed,
        rng,
        sweep,
        statistics,
        use_flint,
        changematrix
    )
end

function params_mod_p(
    params::AlgorithmParameters,
    prime::C;
    using_wide_type_for_coeffs=nothing
) where {C <: Coeff}
    is_wide_type_coeffs = if !isnothing(using_wide_type_for_coeffs)
        using_wide_type_for_coeffs
    else
        params.representation.using_wide_type_for_coeffs
    end
    representation = PolynomialRepresentation(
        params.representation.monomtype,
        params.representation.coefftype,
        is_wide_type_coeffs
    )
    AlgorithmParameters(
        params.target_ord,
        params.original_ord,
        params.heuristic_check,
        params.randomized_check,
        params.certify_check,
        params.homogenize,
        params.check,
        params.linalg,
        select_arithmetic(C, prime, :auto, is_wide_type_coeffs),
        representation,
        params.reduced,
        params.maxpairs,
        params.selection_strategy,
        params.ground,
        params.modular_strategy,
        params.batched,
        params.majority_threshold,
        params.threaded_f4,
        params.threaded_multimodular,
        params.seed,
        params.rng,
        params.sweep,
        params.statistics,
        params.use_flint,
        params.changematrix
    )
end
