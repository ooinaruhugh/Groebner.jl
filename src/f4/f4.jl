# Main file that defines the f4! function.

# Functions here mostly work with a subset of these objects:
# ring      - current polynomial ring,
# basis     - a struct that stores polynomials,
# matrix    - a struct that is used for F4-style reduction,
# hashtable - a hashtable that stores monomials.

@noinline __throw_maximum_iterations_exceeded(iters) =
    throw("""Something probably went wrong in Groebner.jl/F4. 
          The number of F4 iterations exceeded $iters. 
          Please consider submitting a GitHub issue.""")

# Given the polynomial ring and the arrays of monomials and coefficients,
# initializes and returns the structs that are necessary for calling F4
#
# If `normalize_input=true` is provided, also normalizes the polynomials. 
# If `sort_input=true` is provided, also sorts the polynomials.
@timeit function f4_initialize_structs(
    ring::PolyRing,
    monoms::Vector{Vector{M}},
    coeffs::Vector{Vector{C}},
    params::AlgorithmParameters;
    normalize_input=true,
    sort_input=true
) where {M <: Monom, C <: Coeff}
    @log level = -5 "Initializing structs.."

    tablesize = select_hashtable_size(ring, monoms)
    @log level = -5 "Initial hashtable size is $tablesize"

    # Basis for storing basis elements,
    # Pairset for storing critical pairs of basis elements,
    # Hashtable for hashing monomials stored in the basis
    basis = basis_initialize(ring, length(monoms), C)
    pairset = pairset_initialize(monom_entrytype(M))
    hashtable = initialize_hashtable(ring, params.rng, M, tablesize)

    # Filling the basis and hashtable with the given inputs
    fill_data!(basis, hashtable, monoms, coeffs)
    fill_divmask!(hashtable)

    if sort_input
        permutation = sort_polys_by_lead_increasing!(basis, hashtable)
    else
        permutation = collect(1:(basis.nfilled))
    end

    # Divide each polynomial by the leading coefficient.
    # We do not need normalization in some cases, e.g., when computing the
    # normal forms
    if normalize_input
        basis_normalize!(basis, params.arithmetic)
    end

    basis, pairset, hashtable, permutation
end

# F4 reduction
@timeit function f4_reduction!(
    ring::PolyRing,
    basis::Basis,
    matrix::MacaulayMatrix,
    ht::MonomialHashtable,
    symbol_ht::MonomialHashtable,
    params::AlgorithmParameters
)
    # Re-enumerate matrix columns
    column_to_monom_mapping!(matrix, symbol_ht)
    # Call the linear algebra backend
    linear_algebra!(matrix, basis, params)
    # Extract nonzero rows from the matrix into the basis
    convert_rows_to_basis_elements!(matrix, basis, ht, symbol_ht)
end

# F4 update
@timeit function f4_update!(
    pairset::Pairset,
    basis::Basis,
    ht::MonomialHashtable{M},
    update_ht::MonomialHashtable{M}
) where {M <: Monom}
    # total number of elements in the basis (old + new)
    npivs = basis.nfilled
    # number of potential critical pairs to add
    npairs = basis.nprocessed * npivs + div((npivs + 1) * npivs, 2)

    @invariant basis.nfilled >= basis.nprocessed
    @stat new_basis_elements = basis.nfilled - basis.nprocessed

    # make sure the pairset has enough space
    pairset_resize_if_needed!(pairset, npairs)
    pairset_size = length(pairset.pairs)

    # update pairset:
    # for each new element in basis..
    @inbounds for i in (basis.nprocessed + 1):(basis.nfilled)
        # ..check redundancy of new polynomial..
        basis_is_new_polynomial_redundant!(pairset, basis, ht, update_ht, i) && continue
        pairset_resize_lcms_if_needed!(pairset, basis.nfilled)
        # ..if not redundant, then add new S-pairs to pairset
        pairset_update!(pairset, basis, ht, update_ht, i)
    end

    basis_update!(basis, ht)
    pairset_size
end

# F4 symbolic preprocessing
@timeit function symbolic_preprocessing!(
    basis::Basis,
    matrix::MacaulayMatrix,
    ht::MonomialHashtable,
    symbol_ht::MonomialHashtable
)
    # 1. The matrix already has rows added on the critical pair selection stage.
    #    Here, we find and add polynomial reducers to the matrix.
    # 2. Monomials that represent the columns of the matrix are stored in the
    #    symbol_ht hashtable.
    symbol_load = symbol_ht.load
    ncols = matrix.ncols_left

    resize_matrix_upper_part_if_needed!(matrix, ncols + symbol_load)

    @log level = -5 "Finding reducers in the basis..." basis.nnonredundant

    # 3. Traverse all monomials in symbol_ht and search for a polynomial reducer
    #    for each monomial.
    # NOTE: note that the size of hashtable grows as polynomials with new
    # monomials are added to the matrix, and the loop accounts for that
    i = MonomId(symbol_ht.offset)
    @inbounds while i <= symbol_ht.load
        if symbol_ht.hashdata[i].idx != NON_PIVOT_COLUMN
            i += MonomId(1)
            continue
        end
        resize_matrix_upper_part_if_needed!(matrix, matrix.nrows_filled_upper + 1)

        hashval = symbol_ht.hashdata[i]
        symbol_ht.hashdata[i] =
            Hashvalue(UNKNOWN_PIVOT_COLUMN, hashval.hash, hashval.divmask, hashval.deg)
        matrix.ncols_left += 1
        find_multiplied_reducer!(basis, matrix, ht, symbol_ht, i)
        i += MonomId(1)
    end

    # Shrink the matrix
    resize!(matrix.upper_rows, matrix.nrows_filled_upper)

    nothing
end

# Performs autoreduction of basis elements inplace
function f4_autoreduce!(
    ring::PolyRing,
    basis::Basis,
    matrix::MacaulayMatrix,
    ht::MonomialHashtable{M},
    symbol_ht::MonomialHashtable{M},
    params
) where {M}
    @log level = -5 "Entering autoreduction" basis

    etmp = construct_const_monom(M, ht.nvars)
    # etmp is now set to zero, and has zero hash

    reinitialize_matrix!(matrix, basis.nnonredundant)
    uprows = matrix.upper_rows

    # add all non redundant elements from the basis
    # as matrix upper rows
    @inbounds for i in 1:(basis.nnonredundant) #
        row_idx = matrix.nrows_filled_upper += 1
        uprows[row_idx] = transform_polynomial_multiple_to_matrix_row!(
            matrix,
            symbol_ht,
            ht,
            MonomHash(0),
            etmp,
            basis.monoms[basis.nonredundant[i]]
        )
        matrix.upper_to_coeffs[row_idx] = basis.nonredundant[i]
        matrix.upper_to_mult[row_idx] = insert_in_hashtable!(ht, etmp)
        hv = symbol_ht.hashdata[uprows[row_idx][1]]
        symbol_ht.hashdata[uprows[row_idx][1]] =
            Hashvalue(UNKNOWN_PIVOT_COLUMN, hv.hash, hv.divmask, hv.deg)
    end

    # needed for correct column count in symbol hashtable
    matrix.ncols_left = matrix.ncols_left

    symbolic_preprocessing!(basis, matrix, ht, symbol_ht)
    # set all pivots to unknown
    @inbounds for i in (symbol_ht.offset):(symbol_ht.load)
        hv = symbol_ht.hashdata[i]
        symbol_ht.hashdata[i] = Hashvalue(UNKNOWN_PIVOT_COLUMN, hv.hash, hv.divmask, hv.deg)
    end

    column_to_monom_mapping!(matrix, symbol_ht)

    linear_algebra_autoreduce_basis!(matrix, basis, params)

    convert_rows_to_basis_elements!(matrix, basis, ht, symbol_ht)

    basis.nfilled = matrix.npivots + basis.nprocessed
    basis.nprocessed = matrix.npivots

    # we may have added some multiples of reduced basis polynomials
    # from the matrix, so get rid of them
    k = 0
    i = 1
    @label Letsgo
    @inbounds while i <= basis.nprocessed
        @inbounds for j in 1:k
            if is_monom_divisible(
                basis.monoms[basis.nfilled - i + 1][1],
                basis.monoms[basis.nonredundant[j]][1],
                ht
            )
                i += 1
                @goto Letsgo
            end
        end
        k += 1
        basis.nonredundant[k] = basis.nfilled - i + 1
        basis.divmasks[k] = ht.hashdata[basis.monoms[basis.nonredundant[k]][1]].divmask
        i += 1
    end
    basis.nnonredundant = k
end

function f4_select_tobereduced!(
    basis::Basis,
    tobereduced::Basis,
    matrix::MacaulayMatrix,
    symbol_ht::MonomialHashtable{M},
    ht::MonomialHashtable{M}
) where {M}

    # prepare to load all elems from tobereduced
    # to lower rows of the matrix
    reinitialize_matrix!(matrix, max(basis.nfilled, tobereduced.nfilled))
    resize!(matrix.lower_rows, tobereduced.nfilled)
    resize!(matrix.some_coeffs, tobereduced.nfilled)

    etmp = construct_const_monom(M, ht.nvars)

    @inbounds for i in 1:(tobereduced.nfilled)
        matrix.nrows_filled_lower += 1
        row_idx = matrix.nrows_filled_lower

        gen = tobereduced.monoms[i]
        h = MonomHash(0)
        matrix.lower_rows[row_idx] = transform_polynomial_multiple_to_matrix_row!(
            matrix,
            symbol_ht,
            ht,
            h,
            etmp,
            gen
        )
        matrix.lower_to_coeffs[row_idx] = i
        # TODO: not really needed here
        matrix.lower_to_mult[row_idx] = insert_in_hashtable!(ht, etmp)
        matrix.some_coeffs[row_idx] = tobereduced.coeffs[i]
    end

    basis.nnonredundant = basis.nprocessed = basis.nfilled
    basis.isredundant .= 0
    @inbounds for i in 1:(basis.nnonredundant)
        basis.nonredundant[i] = i
        basis.divmasks[i] = ht.hashdata[basis.monoms[i][1]].divmask
    end

    nothing
end

function find_lead_monom_that_divides_use_divmask(i, divmask, basis)
    lead_divmasks = basis.divmasks
    @inbounds while i <= basis.nnonredundant
        # TODO: rethink division masks to support more variables
        if is_divmask_divisible(divmask, lead_divmasks[i])
            break
        end
        i += 1
    end
    i
end

function find_lead_monom_that_divides(i, monom, basis, ht)
    @inbounds while i <= basis.nnonredundant
        lead_monom = ht.monoms[basis.monoms[basis.nonredundant[i]][1]]
        if is_monom_divisible(monom, lead_monom)
            break
        end
        i += 1
    end
    i
end

# Finds a polynomial from the `basis` with leading term that divides monomial
# `vidx`. If such a polynomial has been found, writes a multiple of it to the
# hashtable `symbol_ht` 
function find_multiplied_reducer!(
    basis::Basis,
    matrix::MacaulayMatrix,
    ht::MonomialHashtable,
    symbol_ht::MonomialHashtable,
    vidx::MonomId;
    sugar::Bool=false
)
    e = symbol_ht.monoms[vidx]
    etmp = ht.monoms[1]
    divmask = symbol_ht.hashdata[vidx].divmask

    # Searching for a poly from basis whose leading monom divides the given
    # exponent e
    i = 1
    @label Letsgo

    if ht.use_divmask
        i = find_lead_monom_that_divides_use_divmask(i, divmask, basis)
    else
        i = find_lead_monom_that_divides(i, e, basis, ht)
    end

    # Reducer is not found, yield
    i > basis.nnonredundant && return nothing

    # Here, found polynomial from basis with leading monom
    # dividing symbol_ht.monoms[vidx]

    # reducers index and exponent in hash table
    @inbounds rpoly = basis.monoms[basis.nonredundant[i]]
    resize_hashtable_if_needed!(ht, length(rpoly))

    @inbounds rexp = ht.monoms[rpoly[1]]

    # precisely, etmp = e .- rexp 
    flag, etmp = is_monom_divisible!(etmp, e, rexp)
    if !flag
        i += 1
        @goto Letsgo
    end
    # now etmp = e // rexp in terms of monomias,
    # (!) hash is linear
    @inbounds h = symbol_ht.hashdata[vidx].hash - ht.hashdata[rpoly[1]].hash

    matrix.upper_rows[matrix.nrows_filled_upper + 1] =
        transform_polynomial_multiple_to_matrix_row!(matrix, symbol_ht, ht, h, etmp, rpoly)
    @inbounds matrix.upper_to_coeffs[matrix.nrows_filled_upper + 1] = basis.nonredundant[i]
    # TODO: this line is here with one sole purpose -- to support tracing.
    # Probably want to factor it out.
    matrix.upper_to_mult[matrix.nrows_filled_upper + 1] = insert_in_hashtable!(ht, etmp)
    # if sugar
    #     # updates sugar
    #     poly = basis.nonredundant[i]
    #     new_poly_sugar = totaldeg(etmp) + basis.sugar_cubes[poly]
    #     matrix.upper_to_sugar[matrix.nrows_filled_upper + 1] = new_poly_sugar
    # end

    hv = symbol_ht.hashdata[vidx]
    symbol_ht.hashdata[vidx] = Hashvalue(PIVOT_COLUMN, hv.hash, hv.divmask, hv.deg)

    matrix.nrows_filled_upper += 1
    i += 1

    nothing
end

# Returns N, the number of critical pairs of the smallest degree.
# Sorts the critical pairs so that the first N pairs are the smallest.
function lowest_degree_pairs!(pairset::Pairset)
    sort_pairset_by_degree!(pairset, 1, pairset.load - 1)
    ps = pairset.pairs
    @inbounds min_deg = ps[1].deg
    min_idx = 1
    @inbounds while min_idx < pairset.load && ps[min_idx + 1].deg == min_deg
        min_idx += 1
    end
    min_idx
end

# Returns N, the number of critical pairs of the smallest sugar.
# Sorts the critical pairs so that the first N pairs are the smallest.
function lowest_sugar_pairs!(pairset::Pairset, sugar_cubes::Vector{SugarCube})
    @log level = -5 "Sugar cubes" sugar_cubes
    sugar = sort_pairset_by_sugar!(pairset, 1, pairset.load - 1, sugar_cubes)
    @inbounds min_sugar = sugar[1]
    min_idx = 1
    @inbounds while min_idx < pairset.load && sugar[min_idx + 1] == min_sugar
        min_idx += 1
    end
    @log level = -5 "Selected pairs sugar" sugar min_idx min_sugar
    min_idx
end

# Discard all S-pairs of the lowest degree of lcm
# from the pairset
function discard_normal!(
    pairset::Pairset,
    basis::Basis,
    matrix::MacaulayMatrix,
    ht::MonomialHashtable,
    symbol_ht::MonomialHashtable;
    maxpairs::Int=typemax(Int)
)
    npairs = pairset.load
    npairs = lowest_degree_pairs!(pairset)
    # @debug "Discarded $(npairs) pairs"

    ps = pairset.pairs

    # if maxpairs is set
    if maxpairs != typemax(Int)
        sort_pairset_by_lcm!(pairset, npairs, ht)

        if npairs > maxpairs
            navailable = npairs
            npairs = maxpairs
            lastlcm = ps[npairs].lcm
            while npairs < navailable && ps[npairs + 1].lcm == lastlcm
                npairs += 1
            end
        end
    end

    @debug "Discarded $(npairs) pairs"

    @inbounds for i in 1:(pairset.load - npairs)
        ps[i] = ps[i + npairs]
    end
    pairset.load -= npairs
end

# F4 critical pair selection.
@timeit function f4_select_critical_pairs!(
    pairset::Pairset,
    basis::Basis,
    matrix::MacaulayMatrix,
    ht::MonomialHashtable,
    symbol_ht::MonomialHashtable,
    selection_strategy::Symbol;
    maxpairs::Int=typemax(Int),
    select_all::Bool=false
)
    # Here, the following happens.
    # 1. The pairset is sorted according to the given selection strategy and the
    #    number of selected critical pairs is decided.

    npairs = pairset.load
    if !select_all
        if selection_strategy === :normal
            npairs = lowest_degree_pairs!(pairset)
        else
            @assert selection_strategy === :sugar
            npairs = lowest_sugar_pairs!(pairset, basis.sugar_cubes)
        end
    end
    npairs = min(npairs, maxpairs)
    @assert npairs > 0
    ps = pairset.pairs
    deg = ps[1].deg

    # 2. Selected pairs in the pairset are sorted once again, now with respect
    #    to a monomial ordering on the LCMs
    sort_pairset_by_lcm!(pairset, npairs, ht)

    # NOTE: when `maxpairs` limits the number of selected pairs, we still add
    # some additional pairs which have the same lcm as the selected ones 
    if npairs > maxpairs
        navailable = npairs
        npairs = maxpairs
        lastlcm = ps[npairs].lcm
        while npairs < navailable && ps[npairs + 1].lcm == lastlcm
            npairs += 1
        end
    end

    # 3. At this stage, we know that the first `npairs` pairs in the pairset are 
    #    selected. We add these pairs to the matrix
    add_critical_pairs_to_matrix!(pairset, npairs, basis, matrix, ht, symbol_ht)

    # 4. Remove selected parirs from the pairset
    @inbounds for i in 1:(pairset.load - npairs)
        ps[i] = ps[i + npairs]
    end
    pairset.load -= npairs

    @log level = -5 "Selected $npairs pairs of degree $deg from pairset, $(pairset.load) pairs left"
    @stat critical_pairs_deg = deg critical_pairs_count = npairs

    deg, npairs
end

# Adds the first `npairs` pairs from the pairset to the matrix
function add_critical_pairs_to_matrix!(
    pairset::Pairset,
    npairs::Int,
    basis::Basis,
    matrix::MacaulayMatrix,
    ht::MonomialHashtable,
    symbol_ht::MonomialHashtable
)

    #
    reinitialize_matrix!(matrix, npairs)
    pairs = pairset.pairs
    uprows = matrix.upper_rows
    lowrows = matrix.lower_rows

    polys = Vector{Int}(undef, 2 * npairs)
    # monomial buffer
    etmp = ht.monoms[1]
    i = 1
    @inbounds while i <= npairs
        matrix.ncols_left += 1
        npolys = 1
        lcm = pairs[i].lcm
        j = i

        while j <= npairs && pairs[j].lcm == lcm
            polys[npolys] = pairs[j].poly1
            npolys += 1
            polys[npolys] = pairs[j].poly2
            npolys += 1
            j += 1
        end
        npolys -= 1

        # sort by the index in the basis (by=identity)
        sort_generators_by_position!(polys, npolys)

        # now we collect reducers and to-be-reduced polynomials

        # first generator index in groebner basis
        prev = polys[1]
        # first generator in hash table
        poly_monoms = basis.monoms[prev]
        # first generator lead monomial index in hash data
        vidx = poly_monoms[1]

        # first generator exponent
        eidx = ht.monoms[vidx]
        # exponent of lcm corresponding to first generator
        elcm = ht.monoms[lcm]
        etmp = monom_division!(etmp, elcm, eidx)
        # now etmp contents complement to eidx in elcm

        # hash of complement
        htmp = ht.hashdata[lcm].hash - ht.hashdata[vidx].hash

        # add row as a reducer
        row_idx = matrix.nrows_filled_upper += 1
        uprows[row_idx] = transform_polynomial_multiple_to_matrix_row!(
            matrix,
            symbol_ht,
            ht,
            htmp,
            etmp,
            poly_monoms
        )
        # map upper row to index in basis
        matrix.upper_to_coeffs[row_idx] = prev
        matrix.upper_to_mult[row_idx] = insert_in_hashtable!(ht, etmp)

        # mark lcm column as reducer in symbolic hashtable
        hv = symbol_ht.hashdata[uprows[row_idx][1]]
        symbol_ht.hashdata[uprows[row_idx][1]] =
            Hashvalue(PIVOT_COLUMN, hv.hash, hv.divmask, hv.deg)

        # over all polys with same lcm,
        # add them to the lower part of matrix
        for k in 1:npolys
            # duplicate generator,
            # we can do so as long as generators are sorted
            if polys[k] == prev
                continue
            end

            # if the table was reallocated
            elcm = ht.monoms[lcm]

            # index in gb
            prev = polys[k]
            # poly of indices of monoms in hash table
            poly_monoms = basis.monoms[prev]
            vidx = poly_monoms[1]
            # leading monom idx
            eidx = ht.monoms[vidx]

            etmp = monom_division!(etmp, elcm, eidx)

            htmp = ht.hashdata[lcm].hash - ht.hashdata[vidx].hash

            # add row to be reduced
            row_idx = matrix.nrows_filled_lower += 1
            lowrows[row_idx] = transform_polynomial_multiple_to_matrix_row!(
                matrix,
                symbol_ht,
                ht,
                htmp,
                etmp,
                poly_monoms
            )
            # map lower row to index in basis
            matrix.lower_to_coeffs[row_idx] = prev
            matrix.lower_to_mult[row_idx] = insert_in_hashtable!(ht, etmp)

            hv = symbol_ht.hashdata[lowrows[row_idx][1]]
            symbol_ht.hashdata[lowrows[row_idx][1]] =
                Hashvalue(PIVOT_COLUMN, hv.hash, hv.divmask, hv.deg)
        end

        i = j
    end

    resize!(matrix.lower_rows, matrix.nrows_filled_lower)
end

# move to basis.jl
function basis_well_formed(key, ring, basis, hashtable)
    if key in (:input_f4!, :input_f4_learn!, :input_f4_apply!)
        (isempty(basis.monoms) || isempty(basis.coeffs)) && return false
        (basis.size == 0 || basis.nfilled == 0) && return false
        !is_sorted_by_lead_increasing(basis, hashtable) && return false
    elseif key in (:output_f4!, :output_f4_learn!, :output_f4_apply!)
        !is_sorted_by_lead_increasing(basis, hashtable) && return false
        basis.nnonredundant ==
        length(basis.coeffs) ==
        length(basis.monoms) ==
        length(basis.divmasks) ==
        length(basis.nonredundant) ==
        length(basis.isredundant) || return false
        basis.nonredundant == collect(1:(basis.nnonredundant)) || return false
        any(!iszero, basis.isredundant) && return false
        any(c -> !isone(c[1]), basis.coeffs) && return false
    else
        return false
    end
    for i in 1:length(basis.coeffs)
        if !isassigned(basis.coeffs, i)
            if isassigned(basis.monoms, i)
                return false
            end
        else
            length(basis.coeffs[i]) == length(basis.monoms[i]) && continue
            if key in (:input_f4_apply!, :output_f4_apply!)
                @log level = 1_000 """
                Unlucky but perhaps not fatal cancellation in polynomial at index $(i) on apply stage.
                The number of monomials (expected): $(length(basis.monoms[i]))
                The number of monomials (got): $(length(basis.coeffs[i]))"""
            else
                return false
            end
        end
    end
    true
end

# F4 algorithm.
#
# Computes a groebner basis of the given `basis` inplace.
#
# Uses `pairset` to store critical pairs, 
# uses `hashtable` for hashing monomials,
# uses `tracer` to record information useful in subsequent runs.
#
# Input ivariants:
# - divmasks in the hashtable are set and correct,
# - basis is filled so that
#     basis.nfilled is the actual number of elements set,
#     basis.nprocessed     = 0,
#     basis.nnonredundant  = 0,
# - basis contains no zero polynomials (!!!).
#
# Output invariants:
# - basis.nprocessed == basis.nfilled == basis.nnonredundant
# - basis.monoms and basis.coeffs are of size basis.nprocessed
# - basis elements are sorted increasingly wrt the term ordering on lead elements
# - divmasks in basis are filled and coincide with divmasks in hashtable
@timeit function f4!(
    ring::PolyRing,
    basis::Basis{C},
    pairset::Pairset,
    hashtable::MonomialHashtable{M},
    tracer::TinyTraceF4,
    params::AlgorithmParameters
) where {M <: Monom, C <: Coeff}
    # @invariant hashtable_well_formed(:input_f4!, ring, hashtable)
    @invariant basis_well_formed(:input_f4!, ring, basis, hashtable)
    # @invariant pairset_well_formed(:input_f4!, pairset, basis, ht)

    @log level = -3 "Entering F4."
    basis_normalize!(basis, params.arithmetic)

    matrix = initialize_matrix(ring, C)

    # initialize hash tables for update and symbolic preprocessing steps
    update_ht = initialize_secondary_hashtable(hashtable)
    symbol_ht = initialize_secondary_hashtable(hashtable)

    # add the first batch of critical pairs to the pairset
    @log level = -4 "Processing initial polynomials, generating first critical pairs"
    pairset_size = f4_update!(pairset, basis, hashtable, update_ht)
    update_tracer_pairset!(tracer, pairset_size)
    @log level = -4 "Out of $(basis.nfilled) polynomials, $(basis.nprocessed) are non-redundant"
    @log level = -4 "Generated $(pairset.load) critical pairs"

    i = 0
    # While there are pairs to be reduced
    while !isempty(pairset)
        i += 1
        @log level = -4 "F4: iteration $i"
        @log level = -4 "F4: available $(pairset.load) pairs"

        @log_memory_locals basis pairset hashtable update_ht symbol_ht

        # if the iteration is redundant according to the previous modular run
        if isready(tracer) && is_iteration_redundant(tracer, i)
            discard_normal!(
                pairset,
                basis,
                matrix,
                hashtable,
                symbol_ht,
                maxpairs=params.maxpairs
            )
            # matrix    = initialize_matrix(ring, C)
            # symbol_ht = initialize_secondary_hashtable(hashtable)
            reinitialize_matrix!(matrix, 0)
            reinitialize_hashtable!(symbol_ht)
            continue
        end

        # selects pairs for reduction from pairset following normal strategy
        # (minimal lcm degrees are selected),
        # and puts these into the matrix rows
        f4_select_critical_pairs!(
            pairset,
            basis,
            matrix,
            hashtable,
            symbol_ht,
            params.selection_strategy,
            maxpairs=params.maxpairs
        )
        @log level = -3 "After normal selection: available $(pairset.load) pairs"

        symbolic_preprocessing!(basis, matrix, hashtable, symbol_ht)

        # reduces polys and obtains new potential basis elements
        f4_reduction!(ring, basis, matrix, hashtable, symbol_ht, params)

        update_tracer_iteration!(tracer, matrix.npivots == 0)

        # update the current basis with polynomials produced from reduction,
        # does not copy,
        # checks for redundancy
        pairset_size = f4_update!(pairset, basis, hashtable, update_ht)
        update_tracer_pairset!(tracer, pairset_size)

        # clear symbolic hashtable
        # clear matrix
        reinitialize_matrix!(matrix, 0)
        reinitialize_hashtable!(symbol_ht)
        # matrix    = initialize_matrix(ring, C)
        # symbol_ht = initialize_secondary_hashtable(hashtable)

        if i > 10_000
            @log level = 1_000 "Something has gone wrong in F4. Error will follow."
            @log_memory_locals
            __throw_maximum_iterations_exceeded(i)
        end
    end

    @stat f4_iterations = i

    set_ready!(tracer)
    set_final_basis!(tracer, basis.nfilled)

    if params.sweep
        @log level = -4 "Sweeping redundant elements in the basis"
        basis_sweep_redundant!(basis, hashtable)
    end

    basis_mark_redundant_elements!(basis)

    if params.reduced
        @log level = -4 "Autoreducing the final basis.."
        f4_autoreduce!(ring, basis, matrix, hashtable, symbol_ht, params)
    end

    basis_standardize!(ring, basis, hashtable, hashtable.ord, params.arithmetic)

    # @invariant hashtable_well_formed(:output_f4!, ring, hashtable)
    @invariant basis_well_formed(:output_f4!, ring, basis, hashtable)

    nothing
end

# Checks that all S-polynomials formed by the elements of the given basis reduce
# to zero.
@timeit function f4_isgroebner!(
    ring,
    basis::Basis{C},
    pairset,
    hashtable::MonomialHashtable{M},
    arithmetic::A
) where {M <: Monom, C <: Coeff, A <: AbstractArithmetic}
    matrix = initialize_matrix(ring, C)
    symbol_ht = initialize_secondary_hashtable(hashtable)
    update_ht = initialize_secondary_hashtable(hashtable)
    @log level = -3 "Forming S-polynomials"
    f4_update!(pairset, basis, hashtable, update_ht)
    isempty(pairset) && return true
    # Fill the F4 matrix
    f4_select_critical_pairs!(
        pairset,
        basis,
        matrix,
        hashtable,
        symbol_ht,
        :normal,
        select_all=true
    )
    symbolic_preprocessing!(basis, matrix, hashtable, symbol_ht)
    # Rename the columns and sort the rows of the matrix
    column_to_monom_mapping!(matrix, symbol_ht)
    # Reduce!
    linear_algebra_isgroebner!(matrix, basis, arithmetic)
end

# Reduces each polynomial in the `tobereduced` by the polynomials from the `basis`.
@timeit function f4_normalform!(
    ring::PolyRing,
    basis::Basis{C},
    tobereduced::Basis{C},
    ht::MonomialHashtable,
    arithmetic::A
) where {C <: Coeff, A <: AbstractArithmetic}
    matrix = initialize_matrix(ring, C)
    symbol_ht = initialize_secondary_hashtable(ht)
    # Fill the matrix
    f4_select_tobereduced!(basis, tobereduced, matrix, symbol_ht, ht)
    symbolic_preprocessing!(basis, matrix, ht, symbol_ht)
    column_to_monom_mapping!(matrix, symbol_ht)
    # Reduce the matrix
    linear_algebra_normalform!(matrix, basis, arithmetic)
    # Export the rows of the matrix back to the basis elements
    convert_rows_to_basis_elements_nf!(matrix, tobereduced, ht, symbol_ht)
    tobereduced
end
