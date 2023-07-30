# Select parameters for Groebner basis computation

# It seems there is no Xoshiro rng in Julia v < 1.8.
# Use Random.Xoshiro, if available, as it is a bit faster.
const _default_rng_type = @static if VERSION >= v"1.8.0"
    Random.Xoshiro
else
    Random.MersenneTwister
end

"""
    AlgorithmParameters

Stores all parameters for a single GB computation.
"""
struct AlgorithmParameters{Ord1, Ord2, Ord3}
    # Output polynomials monomial ordering
    target_ord::Ord1
    # Monomial ordering for computation
    computation_ord::Ord2
    # Original ordering
    original_ord::Ord3

    # Basis correctness checks levels
    heuristic_check::Bool
    randomized_check::Bool
    certify_check::Bool

    check::Bool

    # Linear algebra backend to be used. Currently available are
    # - :deterministic for exact deterministic algebra,
    # - :randomized for probabilistic linear algebra
    linalg::Symbol

    # Reduced Groebner basis is needed
    reduced::Bool

    maxpairs::Int

    # Ground field of computation. Currently options are
    # - :qq for rationals,
    # - :zp for integers modulo a prime.
    ground::Symbol

    # TODO: introduce two strategies: :classic_modular and :learn_and_apply
    strategy::Symbol
    majority_threshold::Int

    threading::Bool

    # Random number generator seed
    seed::UInt64
    rng::_default_rng_type

    sweep::Bool
end

function AlgorithmParameters(ring, kwargs::KeywordsHandler; orderings=nothing)
    if orderings !== nothing
        target_ord = orderings[2]
        computation_ord = orderings[2]
        original_ord = orderings[1]
    else
        if kwargs.ordering === InputOrdering() || kwargs.ordering === nothing
            ordering = ring.ord
        else
            ordering = kwargs.ordering
        end
        target_ord = ordering
        computation_ord = ordering
        original_ord = ring.ord
    end

    heuristic_check = true
    randomized_check = true
    certify_check = kwargs.certify

    linalg = kwargs.linalg

    ground = :zp
    if iszero(ring.ch)
        ground = :qq
    end

    reduced = kwargs.reduced
    maxpairs = kwargs.maxpairs

    threading = false

    strategy = kwargs.strategy
    majority_threshold = 1

    seed = kwargs.seed

    rng = _default_rng_type(seed)

    useed = UInt64(seed)

    sweep = kwargs.sweep

    @log level = -1 """
    Selected parameters:
    target_ord = $target_ord
    computation_ord = $computation_ord
    original_ord = $original_ord
    heuristic_check = $heuristic_check
    randomized_check = $randomized_check
    certify_check = $certify_check
    check = $(kwargs.check)
    linalg = $linalg
    reduced = $reduced
    maxpairs = $maxpairs
    ground = $ground
    strategy = $strategy
    majority_threshold = $majority_threshold
    threading = $threading
    seed = $seed
    rng = $rng
    sweep = $sweep"""

    AlgorithmParameters(
        target_ord,
        computation_ord,
        original_ord,
        heuristic_check,
        randomized_check,
        certify_check,
        kwargs.check,
        linalg,
        reduced,
        maxpairs,
        ground,
        strategy,
        majority_threshold,
        threading,
        useed,
        rng,
        sweep
    )
end
