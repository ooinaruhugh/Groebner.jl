
#------------------------------------------------------------------------------
####### Pairset and Basis #######

# s-pair, a pair of polynomials
struct SPair
    # first generator as index from the basis array
    poly1::Int
    # second generator -//-
    poly2::Int
    # index of lcm(poly1, poly2) in hashtable
    lcm::ExponentIdx
    # total degree of lcm
    deg::Degree
end

#=
    Core structure that stores S-pairs
=#
mutable struct Pairset
    pairs::Vector{SPair}
    # number of filled pairs,
    # Initially zero
    load::Int
end

# Initialize and return a pairset with capacity for `initial_size` pairs
function initialize_pairset(; initial_size=2^6) # TODO: fine tune 64
    pairs = Vector{SPair}(undef, initial_size)
    Pairset(pairs, 0)
end

function Base.isempty(ps::Pairset)
    ps.load == 0
end

# checks if it's possible to add `added` number of pairs to the pairset,
# and extend the pairset if not
function check_enlarge_pairset!(ps::Pairset, added::Int)
    sz = length(ps.pairs)
    # TODO: shrink pairset ?
    if ps.load + added >= sz
        newsz = max(2 * sz, ps.load + added)
        resize!(ps.pairs, newsz)
    end
end

#------------------------------------------------------------------------------

#=
    Core structure that stores basis generators and some additional info
=#
mutable struct Basis{T<:Coeff}
    # vector of polynomials, each polynomial is a vector of monomials,
    # each monomial is represented with it's position in hashtable
    gens::Vector{MonomsVector}
    # polynomial coefficients
    coeffs::Vector{CoeffsVector{T}}

    #= Keeping track of sizes   =#
    #=  ndone <= ntotal <= size =#
    # total allocated size,
    # size == length(gens) is always true
    size::Int
    # number of processed polynomials in `gens`
    # Iitially zero
    ndone::Int
    # total number of polys filled in `gens`
    # (these will be handled during next update! call)
    # Iitially zero
    ntotal::Int

    #= Keeping track of redundancy =#
    #= invariant =#
    #= length(lead) == length(nonred) == count(isred) == nlead =#
    # if element of the basis
    # is redundant
    isred::Vector{Int8}
    # positions of non-redundant elements in the basis
    nonred::Vector{Int}
    # division masks of leading monomials of
    # non redundant basis elements
    lead::Vector{DivisionMask}
    # number of filled elements in lead
    nlead::Int

    # characteristic of the ground field
    ch::FieldCharacteristic
end

function initialize_basis(ring::PolyRing, ngens::Int, ::Type{T}) where {T<:Coeff}
    #=
        always true
        length(gens) == length(coeffs) == length(isred) == size
    =#

    sz = ngens * 2 # hmmm
    ndone = 0
    ntotal = 0
    nlead = 0

    gens = Vector{MonomsVector}(undef, sz)
    coeffs = Vector{CoeffsVector{T}}(undef, sz)
    isred = zeros(Int8, sz)
    nonred = Vector{Int}(undef, sz)
    lead = Vector{DivisionMask}(undef, sz)

    ch = ring.ch

    Basis(gens, coeffs, sz, ndone, ntotal, isred, nonred, lead, nlead, ch)
end

function initialize_basis(ring::PolyRing, hashedexps, coeffs::Vector{CoeffsVector{T}}) where {T<:Coeff}
    sz = length(hashedexps) # hmmm
    ndone = 0
    ntotal = 0
    nlead = 0

    isred = zeros(Int8, sz)
    nonred = Vector{Int}(undef, sz)
    lead = Vector{DivisionMask}(undef, sz)

    ch = ring.ch

    Basis(hashedexps, coeffs, sz, ndone, ntotal, isred, nonred, lead, nlead, ch)
end

#------------------------------------------------------------------------------


function copy_basis_thorough(basis::Basis{T}) where {T}
    #  That cost a day of debugging ////
    gens = Vector{MonomsVector}(undef, basis.size)
    coeffs = Vector{CoeffsVector{T}}(undef, basis.size)
    @inbounds for i in 1:basis.ntotal
        gens[i] = MonomsVector(undef, length(basis.gens[i]))
        coeffs[i] = CoeffsVector{T}(undef, length(basis.coeffs[i]))
        @inbounds for j in 1:length(basis.gens[i])
            gens[i][j] = basis.gens[i][j]
            coeffs[i][j] = basis.coeffs[i][j]
        end
    end
    isred = copy(basis.isred)
    nonred = copy(basis.nonred)
    lead = copy(basis.lead)
    Basis(gens, coeffs, basis.size, basis.ndone,
        basis.ntotal, isred, nonred, lead,
        basis.nlead, basis.ch)
end

#------------------------------------------------------------------------------

function check_enlarge_basis!(basis::Basis{T}, added::Int) where {T}
    if basis.ndone + added >= basis.size
        basis.size = max(basis.size * 2, basis.ndone + added)
        resize!(basis.gens, basis.size)
        resize!(basis.coeffs, basis.size)
        resize!(basis.isred, basis.size)
        basis.isred[basis.ndone+1:end] .= 0
        resize!(basis.nonred, basis.size)
        resize!(basis.lead, basis.size)
    end
end

#------------------------------------------------------------------------------

# Normalize each element of the input basis
# by dividing it by leading coefficient
function normalize_basis!(basis::Basis{<:CoeffFF})
    cfs = basis.coeffs
    @inbounds for i in 1:basis.ntotal
        # mul = inv(cfs[i][1])
        # hack for now, TODODO
        if !isassigned(cfs, i)
            continue
        end
        ch = basis.ch
        mul = invmod(cfs[i][1], ch) % ch
        @inbounds for j in 2:length(cfs[i])
            # cfs[i][j] *= mul
            # TODO: faster division
            cfs[i][j] = cfs[i][j] * mul % ch
        end
        cfs[i][1] = one(cfs[i][1])
    end
    basis
end

# Normalize each element of the input basis
# by dividing it by leading coefficient
function normalize_basis!(basis::Basis{<:CoeffQQ})
    cfs = basis.coeffs
    @inbounds for i in 1:basis.ntotal
        # mul = inv(cfs[i][1])
        # hack for now, TODODO
        if !isassigned(cfs, i)
            continue
        end
        mul = inv(cfs[i][1])
        @inbounds for j in 2:length(cfs[i])
            cfs[i][j] *= mul
        end
        cfs[i][1] = one(cfs[i][1])
    end
    basis
end

#------------------------------------------------------------------------------

function update_pairset!(
    pairset::Pairset,
    basis::Basis,
    ht::MonomialHashtable,
    update_ht::MonomialHashtable,
    idx::Int,
    plcm::Vector{ExponentIdx})

    pl = pairset.load
    bl = idx
    nl = pl + bl
    ps = pairset.pairs

    new_lead = basis.gens[idx][1]

    # @error "" bl
    # initialize new critical lcms
    # plcm = Vector{Int}(undef, bl + 1)

    # for each combination (new_Lead, basis.gens[i][1])
    # generate a pair
    @inbounds for i in 1:bl-1
        plcm[i] = get_lcm(basis.gens[i][1], new_lead, ht, update_ht)
        deg = update_ht.hashdata[plcm[i]].deg
        newidx = pl + i
        # TRACE: move isred above
        if iszero(basis.isred[i])
            ps[newidx] = SPair(i, idx, plcm[i], deg)
        else
            # lcm == 0 will mark redundancy of spair
            ps[newidx] = SPair(i, idx, 0, deg)
        end

    end

    # @error "" one two

    # traverse existing pairs
    @inbounds for i in 1:pl
        j = ps[i].poly1
        l = ps[i].poly2
        m = max(ps[pl+l].deg, ps[pl+j].deg)

        # if an existing pair is divisible by lead of new poly
        # and has a greater degree than newly generated one
        if is_monom_divisible(ps[i].lcm, new_lead, ht) && ps[i].deg > m
            # mark lcm as 0
            ps[i] = SPair(ps[i].poly1, ps[i].poly2, 0, ps[i].deg)
        end
    end
    # TODO: this can be done faster if we
    # create only non-redundant pairs at first

    # traverse new pairs to check for redundancy
    j = 1
    for i in 1:bl-1
        if iszero(basis.isred[i])
            ps[pl+j] = ps[pl+i]
            j += 1
        end
    end

    sort_pairset_by_degree!(pairset, pl + 1, j - 2)

    @inbounds for i in 1:j-1
        plcm[i] = ps[pl+i].lcm
    end
    plcm[j] = 0
    pc = j
    pc -= 1

    # mark redundancy of some pairs from plcm
    @inbounds for j in 1:pc
        # if is not redundant
        if plcm[j] > 0
            check_monomial_division_in_update(plcm, j + 1, pc, plcm[j], update_ht)
        end
    end

    # remove useless pairs from pairset
    # by moving them to the end
    j = 1
    @inbounds for i in 1:pairset.load
        iszero(ps[i].lcm) && continue
        ps[j] = ps[i]
        j += 1
    end

    # assure that basis hashtable can store new lcms
    if ht.size - ht.load <= pc
        enlarge_hash_table!(ht)
    end

    # add new lcms to the basis hashtable,
    # including j and not including pc
    insert_plcms_in_basis_hash_table!(pairset, pl, ht, update_ht, basis, plcm, j, pc + 1)

    # mark redundant elements in masis
    nonred = basis.nonred
    lml = basis.nlead
    @inbounds for i in 1:lml
        if iszero(basis.isred[nonred[i]])
            if is_monom_divisible(basis.gens[nonred[i]][1], new_lead, ht)
                basis.isred[nonred[i]] = 1
            end
        end
    end

end

#------------------------------------------------------------------------------

function update_basis!(
    basis::Basis,
    ht::MonomialHashtable,
    update_ht::MonomialHashtable)

    # here we could check overall redundancy and update basis.lead

    k = 1
    lead = basis.lead
    nonred = basis.nonred

    for i in 1:basis.nlead
        if basis.isred[nonred[i]] == 0
            basis.lead[k] = lead[i]
            basis.nonred[k] = nonred[i]
            k += 1
        end
    end
    basis.nlead = k - 1

    for i in basis.ndone+1:basis.ntotal
        if basis.isred[i] == 0
            lead[k] = ht.hashdata[basis.gens[i][1]].divmask
            nonred[k] = i
            k += 1
        end
    end

    basis.nlead = k - 1
    basis.ndone = basis.ntotal
end

# checks if element of basis at position idx is redundant
function is_redundant!(
    pairset::Pairset, basis::Basis, ht::MonomialHashtable, 
    update_ht::MonomialHashtable, idx::Int)

    # TODO
    if 2 * update_ht.load > update_ht.size
        enlarge_hash_table!(update_ht)
    end
    # reinitialize_hash_table!(update_ht, 2*idx)

    ps = pairset.pairs

    # lead of new polynomial
    lead_new = basis.gens[idx][1]
    # degree of lead
    lead_deg = ht.hashdata[lead_new].deg

    for i in idx+1:basis.ntotal
        i == idx && continue
        if basis.isred[i] == 1
            continue
        end

        lead_i = basis.gens[i][1]

        if is_monom_divisible(lead_new, lead_i, ht)
            lcm_new = get_lcm(lead_i, lead_new, ht, ht)

            psidx = pairset.load + 1
            ps[psidx] = SPair(i, idx, lcm_new, ht.hashdata[lcm_new].deg)

            basis.isred[idx] = 1
            pairset.load += 1

            return true
        end
    end

    return false
end

#------------------------------------------------------------------------------


function update!(
    pairset::Pairset,
    basis::Basis,
    ht::MonomialHashtable,
    update_ht::MonomialHashtable,
    plcm::Vector{ExponentIdx})

    #=
        Always check redundancy, for now
    =#

    # number of added elements
    npivs = basis.ntotal

    # number of potential critical pairs to add
    npairs = basis.ndone * npivs
    for i in 1:npivs
        npairs += i
    end

    # make sure pairset and update hashtable have enough
    # space to store new pairs
    # TODO: we create too big array, can be fixed
    # @error "before" pairset.load npairs pairset.load+npairs length(pairset.pairs)
    check_enlarge_pairset!(pairset, npairs)
    pairset_size = length(pairset.pairs)
    # @error "after enlarge" length(pairset.pairs)

    # @error "" basis.ndone+1 basis.ntotal

    if basis.ndone + 1 <= basis.ntotal
        # red = 0
        # for each new element in basis
        # @error pairset.load basis.ndone+1 basis.ntotal
        for i in basis.ndone+1:basis.ntotal
            # check redundancy of new poly
            if is_redundant!(pairset, basis, ht, update_ht, i)
                continue
            end
            if length(plcm) < basis.ntotal + 1
                resize!(plcm, floor(Int, basis.ntotal * 1.1) + 1)
            end
            update_pairset!(pairset, basis, ht, update_ht, i, plcm)
        end
        # @error pairset.load
    end

    # @error "" red basis.ntotal-basis.ndone
    # println("--------------------------")
    # @error "after update" pairset.load length(pairset.pairs)

    update_basis!(basis, ht, update_ht)

    pairset_size
end

#------------------------------------------------------------------------------

# given input exponent and coefficient vectors hashes exponents into `ht`
# and then constructs hashed polynomial vectors for `basis`
function fill_data!(basis::Basis, ht::MonomialHashtable, 
        exponents::Vector{Vector{ExponentVector}}, coeffs::Vector{CoeffsVector{T}}) where {T}
    ngens = length(exponents)

    for i in 1:ngens
        while length(exponents[i]) >= ht.size - ht.load
            enlarge_hash_table!(ht)
        end
        # ht.exponents one can be reallocated together with ht,
        # so we need to reset it on each iteration
        etmp = ht.exponents[1]

        nterms = length(coeffs[i])
        basis.coeffs[i] = coeffs[i]
        basis.gens[i] = Vector{ExponentIdx}(undef, nterms)
        poly = basis.gens[i]
        for j in 1:nterms
            poly[j] = insert_in_hash_table!(ht, exponents[i][j])
        end

        # sort terms (not needed),
        # beautify coefficients (not needed),
        # and all
    end

    # the initial update traverses all elements in
    # basis.ndone+1:basis.ntotal
    # which is 1:ngens
    basis.ntotal = ngens
end

function filter_redundant!(basis::Basis)
    j = 1
    for i in 1:basis.nlead
        if basis.isred[basis.nonred[i]] == 0
            basis.lead[j] = basis.lead[i]
            basis.nonred[j] = basis.nonred[i]
            #=
            basis.coeffs[j] = basis.coeffs[basis.nonred[i]]
            basis.gens[j] = basis.gens[basis.nonred[i]]
            =#
            j += 1
        end
    end
    basis.nlead = j - 1
    @assert basis.ndone == basis.ntotal
    # basis.ndone = basis.ntotal = basis.nlead
    basis
end

function standardize_basis!(basis::Basis, ht::MonomialHashtable, ord)
    for i in 1:basis.nlead
        idx = basis.nonred[i]
        # basis.lead[i] = basis.lead[idx]
        basis.nonred[i] = i
        basis.isred[i] = 0
        basis.coeffs[i] = basis.coeffs[idx]
        basis.gens[i] = basis.gens[idx]
    end
    basis.size = basis.ndone = basis.ntotal = basis.nlead
    resize!(basis.coeffs, basis.ndone)
    resize!(basis.gens, basis.ndone)
    resize!(basis.lead, basis.ndone)
    resize!(basis.nonred, basis.ndone)
    resize!(basis.isred, basis.ndone)

    sort_gens_by_lead_increasing_in_standardize!(basis, ht, ord)
    normalize_basis!(basis)
end

function export_basis_data(basis::Basis{C}, ht::MonomialHashtable) where {C<:Coeff}
    exps = Vector{Vector{ExponentVector}}(undef, basis.nlead)
    coeffs = Vector{Vector{C}}(undef, basis.nlead)

    for i in 1:basis.nlead
        idx = basis.nonred[i]
        poly = basis.gens[idx]
        exps[i] = Vector{ExponentVector}(undef, length(poly))
        for j in 1:length(poly)
            exps[i][j] = ht.exponents[poly[j]]
        end
        coeffs[i] = basis.coeffs[idx]
    end

    exps, coeffs
end

function hash_to_exponents(basis::Basis, ht::MonomialHashtable)
    exps = Vector{Vector{ExponentVector}}(undef, basis.nlead)
    for i in 1:basis.nlead
        idx = basis.nonred[i]
        poly = basis.gens[idx]
        exps[i] = Vector{ExponentVector}(undef, length(poly))
        @inbounds for j in 1:length(poly)
            exps[i][j] = ht.exponents[poly[j]]
        end
    end
    exps
end

function insert_plcms_in_basis_hash_table!(
    pairset::Pairset,
    off::Int,
    ht::MonomialHashtable,
    update_ht::MonomialHashtable,
    basis::Basis,
    plcm::Vector{ExponentIdx},
    ifirst::Int, ilast::Int)

    # including ifirst and not including ilast

    gens = basis.gens
    mod = UInt32(ht.size - 1)
    ps = pairset.pairs

    m = ifirst
    l = 1
    @label Letsgo
    while l < ilast
        if plcm[l] == 0
            l += 1
            continue
        end

        if is_gcd_const(gens[ps[off+l].poly1][1], gens[ps[off+1].poly2][1], ht)
            l += 1
            continue
        end

        ps[m] = ps[off+l]

        # TODO: IT IS NOT CORRECT
        # upd: it is, but it can be done better
        h = update_ht.hashdata[plcm[l]].hash
        ht.exponents[ht.load+1] = copy(update_ht.exponents[plcm[l]])
        n = ht.exponents[ht.load+1]

        k = h
        i = UInt32(1)
        @label Restart
        while i <= ht.size
            k = hashnextindex(h, i, mod)
            hm = ht.hashtable[k]

            hm == 0 && break
            if ht.hashdata[hm].hash != h
                i += UInt32(1)
                continue
            end

            ehm = ht.exponents[hm]

            # @info "SO, we have " n ehm m
            for j in 1:ht.explen
                if ehm[j] != n[j]
                    i += ExponentHash(1)
                    @goto Restart
                end
            end

            ps[m] = SPair(ps[m].poly1, ps[m].poly2, hm, ps[m].deg)
            m += 1
            l += 1
            @goto Letsgo
        end

        ht.hashtable[k] = pos = ht.load + 1

        uhd = update_ht.hashdata

        ll = plcm[l]
        ht.hashdata[ht.load+1] = Hashvalue(h, uhd[ll].divmask, 0, uhd[ll].deg)

        ht.load += 1
        ps[m] = SPair(ps[m].poly1, ps[m].poly2, pos, ps[m].deg)
        m += 1
        l += 1
    end

    pairset.load = m - 1
end
