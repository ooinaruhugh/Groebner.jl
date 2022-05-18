
#=
    Same as f4.jl, but with tracing.
=#

mutable struct Tracer

    iteration_info::Vector{Int}
    ready::Bool

    function Tracer()
        new(Vector{Int}(undef, 0), false)
    end
end

#------------------------------------------------------------------------------

#=
    Input ivariants:
        - ring is set, and ring.ch == basis.ch, and ring ~ ht
        - divmasks in ht are set
        - basis is filled so that
            basis.ntotal = actual number of elements
            basis.ndone  = 0
            basis.nlead  = 0

    Output invariants:
        - basis.ndone == basis.ntotal == basis.nlead
        - basis.gens and basis.coeffs of size basis.ndone
        - basis elements are sorted increasingly wrt ordering on lead elements
        - divmasks in basis are filled and coincide to divmasks in hashtable

=#
function f4trace!(ring::PolyRing,
             basis::Basis{Coefftype},
             tracer::Tracer,
             ht,
             reduced,
             linalg) where {Coefftype<:Coeff}

    # print("input: $(basis.ntotal) gens, $(ring.nvars) vars. ")

    @assert ring.ch == basis.ch
    @assert ring.ord == ht.ord && ring.nvars == ht.nvars && ring.explen == ht.explen
    # @error "hashtable divmasks"
    # println(ht.exponents[2:ht.load])
    # println("###########")
    # println(map(x->bitstring(x.divmask), ht.hashdata[2:ht.load]))
    # println("###########")
    @assert basis.ndone == 0

    # matrix storing coefficients in rows
    # wrt columns representing the current monomial basis
    matrix = initialize_matrix(ring, Coefftype)

    # initialize hash tables for update and symbolic preprocessing steps
    update_ht  = initialize_secondary_hash_table(ht)
    symbol_ht  = initialize_secondary_hash_table(ht)

    # a set to store critical pairs of polynomials to be reduced
    pairset = initialize_pairset()

    # @warn "ht initialily" ht.load ht.size

    # makes basis fields valid,
    # does not copy,
    # checks for redundancy of new elems
    plcm = Vector{Int}(undef, 0)
    update!(pairset, basis, ht, update_ht, plcm)

    # @warn "ht update" ht.load ht.size

    d = 0
    # while there are pairs to be reduced
    while !isempty(pairset)
        d += 1
        @debug "F4 ITER $d"
        @debug "Available $(pairset.load) pairs"

        # TODO: learn, and select\discard S-polynomials
        if tracer.ready && tracer.iteration_info[d] == 0
            select_normal_and_discard!(pairset, basis, matrix, ht, symbol_ht)
            matrix    = initialize_matrix(ring, Coefftype)
            symbol_ht = initialize_secondary_hash_table(ht)
            continue
        end

        # selects pairs for reduction from pairset following normal strategy
        # (minimal lcm degrees are selected),
        # and puts these into the matrix rows
        select_normal!(pairset, basis, matrix, ht, symbol_ht)

        # @warn "ht select" ht.load ht.size

        symbolic_preprocessing!(basis, matrix, ht, symbol_ht)
        # symbolic_preprocessing_relaxed!(basis, matrix, ht, symbol_ht)
        @debug "Matrix of size $((matrix.nrows, matrix.ncols)), density TODO"

        # @warn "ht symbolic" ht.load ht.size

        # reduces polys and obtains new potential basis elements
        reduction!(basis, matrix, ht, symbol_ht, linalg)
        @debug "Matrix reduced, density TODO"

        if !tracer.ready
            push!(tracer.iteration_info, 0)
            if matrix.npivots != 0
                tracer.iteration_info[end] = 1
            end
        end

        #=
        if tracer.ready && length(tracer.iteration_info) > d
            if tracer.iteration_info[d + 1] == 0
                matrix    = initialize_matrix(ring, Coefftype)
                symbol_ht = initialize_secondary_hash_table(ht)
                continue
            end
        end
        =#

        # update the current basis with polynomials produced from reduction,
        # does not copy,
        # checks for redundancy
        update!(pairset, basis, ht, update_ht, plcm)

        # @warn "ht update" ht.load ht.size

        # TODO: is this okay hm ?
        # to be changed
        # TODO: clean hashtable
        matrix    = initialize_matrix(ring, Coefftype)
        symbol_ht = initialize_secondary_hash_table(ht)
        # clear symbolic hashtable
        # clear matrix

        if d > 10000
            @error "Something is probably wrong in f4. Please submit an issue."
            break
        end
    end

    # remove redundant elements
    filter_redundant!(basis)

    if reduced
        reducegb_f4!(basis, matrix, ht, symbol_ht)
    end

    standardize_basis!(basis, ht, ht.ord)

    tracer.ready = true

    # assertion
    #=
    println("#####")
    println(basis.lead)
    println(map(x->bitstring(x.divmask), ht.hashdata[2:ht.load]))
    println("#####")
    =#
    #=
    for i in 1:basis.nlead
        #=
        println(basis.lead[i])
        println(basis.gens[i][1])
        println(ht.exponents[basis.gens[i][1]])
        println(UInt32(ht.hashdata[basis.gens[i][1]].divmask))
        =#
        @assert basis.lead[i] == ht.hashdata[basis.gens[i][1]].divmask
    end
    =#
    # println("HT: $(ht.load)/$(ht.size)")

    nothing
end
