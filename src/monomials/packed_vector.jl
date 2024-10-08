# This file is a part of Groebner.jl. License is GNU GPL v2.

###
# PackedTupleN implements the monomial interface.
#
# PackedTupleN packs exponents in integers in a degrevlex-favorable ordering.
# Currently implemented packed monomials support up to 31 variables.

abstract type AbstractPackedTuple{T <: Unsigned, B <: Unsigned} end

struct PackedTuple1{T <: Unsigned, B <: Unsigned} <: AbstractPackedTuple{T, B}
    a1::T
end

struct PackedTuple2{T <: Unsigned, B <: Unsigned} <: AbstractPackedTuple{T, B}
    a1::T
    a2::T
end

struct PackedTuple3{T <: Unsigned, B <: Unsigned} <: AbstractPackedTuple{T, B}
    a1::T
    a2::T
    a3::T
end

struct PackedTuple4{T <: Unsigned, B <: Unsigned} <: AbstractPackedTuple{T, B}
    a1::T
    a2::T
    a3::T
    a4::T
end

monom_max_vars(p::AbstractPackedTuple) = monom_max_vars(typeof(p))

# Checks if there is a risk of exponent overflow. Throws if overflow if possible.
function _monom_overflow_check(a::AbstractPackedTuple{T, B}) where {T, B}
    _monom_overflow_check(monom_totaldeg(a), B)
end

const _defined_packed_tuples =
    ((:PackedTuple1, 1), (:PackedTuple2, 2), (:PackedTuple3, 3), (:PackedTuple4, 4))

# for each PackedTupleI define something..
for (op, n) in _defined_packed_tuples
    @eval begin
        monom_max_vars(::Type{$op{T, B}}) where {T, B} = $n * packed_elperchunk(T, B) - 1
        monom_totaldeg(a::$op{T, B}) where {T, B} = a.a1 >> (8 * (sizeof(T) - sizeof(B)))
        monom_copy(a::$op{T, B}) where {T, B} = a
        monom_copy!(b::$op{T, B}, a::$op{T, B}) where {T, B} = a
        monom_entrytype(a::$op{T, B}) where {T, B} = B
    end

    @eval begin
        function monom_construct_hash_vector(
            rng::AbstractRNG,
            ::Type{$op{T, B}},
            n::Integer
        ) where {T, B}
            rand(rng, MonomHash, $n * packed_elperchunk(T, B))
        end
    end
end

# Creates a packed monomial of the given type from regular vector `ev`
function monom_construct_from_vector(
    ::Type{PackedTuple1{T, B}},
    ev::Vector{U}
) where {T, B, U}
    n = length(ev)
    epc = packed_elperchunk(T, B)
    @invariant n < epc
    indent = sizeof(T) - packed_degsize(T, B, n)
    a1 = zero(T)
    s = zero(T)
    @inbounds for i in n:-1:1
        _monom_overflow_check(ev[i], B)
        d = T(ev[i])
        a1 = a1 << (sizeof(B) * 8)
        a1 = a1 | d
        _monom_overflow_check(s, B)
        s += d
    end
    a1 |= s << (indent * 8)
    PackedTuple1{T, B}(a1)
end
function monom_construct_from_vector(
    ::Type{PackedTuple2{T, B}},
    ev::Vector{U}
) where {T, B, U}
    n = length(ev)
    epc = packed_elperchunk(T, B)
    @invariant n < 2 * epc
    if n < epc
        small = monom_construct_from_vector(PackedTuple1{T, B}, ev)
        return PackedTuple2{T, B}(small.a1, zero(T))
    end
    indent = sizeof(T) - packed_degsize(T, B, n)
    a1, a2 = zero(T), zero(T)
    s = zero(T)
    @inbounds for i in n:-1:1
        _monom_overflow_check(ev[i], B)
        d = T(ev[i])
        if div(i - 1, epc) == 1
            a1 = a1 << (sizeof(B) * 8)
            a1 = a1 | d
        else
            a2 = a2 << (sizeof(B) * 8)
            a2 = a2 | d
        end
        _monom_overflow_check(s, B)
        s += d
    end
    a1 |= s << (indent * 8)
    PackedTuple2{T, B}(a1, a2)
end
function monom_construct_from_vector(
    ::Type{PackedTuple3{T, B}},
    ev::Vector{U}
) where {T, B, U}
    n = length(ev)
    epc = packed_elperchunk(T, B)
    @invariant n < 3 * epc
    if n < 2 * epc
        small = monom_construct_from_vector(PackedTuple2{T, B}, ev)
        return PackedTuple3{T, B}(small.a1, small.a2, zero(T))
    end
    indent = sizeof(T) - packed_degsize(T, B, n)
    a1, a2, a3 = zero(T), zero(T), zero(T)
    s = zero(T)
    @inbounds for i in n:-1:1
        _monom_overflow_check(ev[i], B)
        d = T(ev[i])
        if div(i - 1, epc) == 2
            a1 = a1 << (sizeof(B) * 8)
            a1 = a1 | d
        elseif div(i - 1, epc) == 1
            a2 = a2 << (sizeof(B) * 8)
            a2 = a2 | d
        else
            a3 = a3 << (sizeof(B) * 8)
            a3 = a3 | d
        end
        _monom_overflow_check(s, B)
        s += d
    end
    a1 |= s << (indent * 8)
    PackedTuple3{T, B}(a1, a2, a3)
end
function monom_construct_from_vector(
    ::Type{PackedTuple4{T, B}},
    ev::Vector{U}
) where {T, B, U}
    n = length(ev)
    epc = packed_elperchunk(T, B)
    @invariant n < 4 * epc
    if n < 3 * epc
        small = monom_construct_from_vector(PackedTuple3{T, B}, ev)
        return PackedTuple4{T, B}(small.a1, small.a2, small.a3, zero(T))
    end
    indent = sizeof(T) - packed_degsize(T, B, n)
    a1, a2, a3, a4 = zero(T), zero(T), zero(T), zero(T)
    s = zero(T)
    @inbounds for i in n:-1:1
        _monom_overflow_check(ev[i], B)
        d = T(ev[i])
        if div(i - 1, epc) == 3
            a1 = a1 << (sizeof(B) * 8)
            a1 = a1 | d
        elseif div(i - 1, epc) == 2
            a2 = a2 << (sizeof(B) * 8)
            a2 = a2 | d
        elseif div(i - 1, epc) == 1
            a3 = a3 << (sizeof(B) * 8)
            a3 = a3 | d
        else
            a4 = a4 << (sizeof(B) * 8)
            a4 = a4 | d
        end
        _monom_overflow_check(s, B)
        s += d
    end
    a1 |= s << (indent * 8)
    PackedTuple4{T, B}(a1, a2, a3, a4)
end

# Creates a constant packed monomial of the given type of length n
function monom_construct_const(::Type{PackedTuple1{T, B}}, n::Integer) where {T, B}
    @invariant n < packed_elperchunk(T, B)
    PackedTuple1{T, B}(zero(T))
end
function monom_construct_const(::Type{PackedTuple2{T, B}}, n::Integer) where {T, B}
    @invariant n < 2 * packed_elperchunk(T, B)
    PackedTuple2{T, B}(zero(T), zero(T))
end
function monom_construct_const(::Type{PackedTuple3{T, B}}, n::Integer) where {T, B}
    @invariant n < 3 * packed_elperchunk(T, B)
    PackedTuple3{T, B}(zero(T), zero(T), zero(T))
end
function monom_construct_const(::Type{PackedTuple4{T, B}}, n::Integer) where {T, B}
    @invariant n < 4 * packed_elperchunk(T, B)
    PackedTuple4{T, B}(zero(T), zero(T), zero(T), zero(T))
end

# Hash of a packed monomial
function monom_hash(x::PackedTuple1{T, B}, b::Vector{MH}) where {T, B, MH}
    h = packed_dot_product(x.a1, b, B, 1)
    mod(h, MonomHash)
end
function monom_hash(x::PackedTuple2{T, B}, b::Vector{MH}) where {T, B, MH}
    epc = packed_elperchunk(T, B)
    h = packed_dot_product(x.a2, b, B, 0)
    h =
        h + packed_dot_product(
            x.a1,
            view(b, (epc + 1):length(b)),
            B,
            epc - max(epc - 1, length(b) - epc)
        )
    mod(h, MonomHash)
end
function monom_hash(x::PackedTuple3{T, B}, b::Vector{MH}) where {T, B, MH}
    epc = packed_elperchunk(T, B)
    h = packed_dot_product(x.a3, b, B, 0)
    h = h + packed_dot_product(x.a2, view(b, (epc + 1):(2 * epc)), B, 0)
    h =
        h + packed_dot_product(
            x.a1,
            view(b, (2 * epc + 1):length(b)),
            B,
            epc - max(epc - 1, length(b) - 2 * epc)
        )
    mod(h, MonomHash)
end
function monom_hash(x::PackedTuple4{T, B}, b::Vector{MH}) where {T, B, MH}
    epc = packed_elperchunk(T, B)
    h = packed_dot_product(x.a4, b, B, 0)
    h = packed_dot_product(x.a3, view(b, (epc + 1):(2 * epc)), B, 0)
    h = h + packed_dot_product(x.a2, view(b, (2 * epc + 1):(3 * epc)), B, 0)
    h =
        h + packed_dot_product(
            x.a1,
            view(b, (3 * epc + 1):length(b)),
            B,
            epc - max(epc - 1, length(b) - 3 * epc)
        )
    mod(h, MonomHash)
end

# Creates a regular vector from a packed monomial and writes result to `tmp`
function monom_to_vector!(tmp::Vector{I}, pv::PackedTuple1{T, B}) where {I, T, B}
    epc = packed_elperchunk(T, B)
    indent = epc - min(epc - 1, length(tmp))
    packed_unpack!(tmp, pv.a1, B, indent)
    tmp
end
function monom_to_vector!(tmp::Vector{I}, pv::PackedTuple2{T, B}) where {I, T, B}
    epc = packed_elperchunk(T, B)
    (length(tmp) < epc) && return monom_to_vector!(tmp, PackedTuple1{T, B}(pv.a1))
    indent = 0
    packed_unpack!(tmp, pv.a2, B, indent)
    indent = epc - min(epc - 1, length(tmp) - epc)
    packed_unpack!(view(tmp, (epc + 1):length(tmp)), pv.a1, B, indent)
    tmp
end
function monom_to_vector!(tmp::Vector{I}, pv::PackedTuple3{T, B}) where {I, T, B}
    epc = packed_elperchunk(T, B)
    (length(tmp) < 2 * epc) &&
        return monom_to_vector!(tmp, PackedTuple2{T, B}(pv.a1, pv.a2))
    indent = 0
    packed_unpack!(tmp, pv.a3, B, indent)
    indent = 0
    packed_unpack!(view(tmp, (epc + 1):(2 * epc)), pv.a2, B, indent)
    indent = epc - min(epc - 1, length(tmp) - 2 * epc)
    packed_unpack!(view(tmp, (2 * epc + 1):length(tmp)), pv.a1, B, indent)
    tmp
end
function monom_to_vector!(tmp::Vector{I}, pv::PackedTuple4{T, B}) where {I, T, B}
    epc = packed_elperchunk(T, B)
    (length(tmp) < 3 * epc) &&
        return monom_to_vector!(tmp, PackedTuple3{T, B}(pv.a1, pv.a2, pv.a3))
    indent = 0
    packed_unpack!(tmp, pv.a4, B, indent)
    indent = 0
    packed_unpack!(view(tmp, (epc + 1):(2 * epc)), pv.a3, B, indent)
    indent = 0
    packed_unpack!(view(tmp, (2 * epc + 1):(3 * epc)), pv.a2, B, indent)
    indent = epc - min(epc - 1, length(tmp) - 3 * epc)
    packed_unpack!(view(tmp, (3 * epc + 1):length(tmp)), pv.a1, B, indent)
    tmp
end

###
# Monomial orderings for the `PackedTupleI` monomial implementation.

function monom_is_supported_ordering(
    ::Type{APP},
    ::Ord
) where {APP <: AbstractPackedTuple, Ord}
    Ord <: Union{DegRevLex{true}, InputOrdering}
end

# TODO: specialize for T == UInt64
function monom_isless(
    ea::PackedTuple1{T, B},
    eb::PackedTuple1{T, B},
    ::DegRevLex{true}
) where {T, B}
    da, db = monom_totaldeg(ea), monom_totaldeg(eb)
    if da < db
        return true
    end
    if da > db
        return false
    end

    if ea.a1 <= eb.a1
        return false
    else
        return true
    end
end

function monom_isless(
    ea::PackedTuple2{T, B},
    eb::PackedTuple2{T, B},
    ::DegRevLex{true}
) where {T, B}
    da, db = monom_totaldeg(ea), monom_totaldeg(eb)
    if da < db
        return true
    end
    if da > db
        return false
    end

    if ea.a1 == eb.a1
        return !(ea.a2 <= eb.a2)
    else
        return !(ea.a1 <= eb.a1)
    end
end

function monom_isless(
    ea::PackedTuple3{T, B},
    eb::PackedTuple3{T, B},
    ::DegRevLex{true}
) where {T, B}
    da, db = monom_totaldeg(ea), monom_totaldeg(eb)
    if da < db
        return true
    end
    if da > db
        return false
    end

    if ea.a1 == eb.a1
        if ea.a2 == eb.a2
            return !(ea.a3 <= eb.a3)
        else
            return !(ea.a2 <= eb.a2)
        end
    else
        return !(ea.a1 <= eb.a1)
    end
end

function monom_isless(
    ea::PackedTuple4{T, B},
    eb::PackedTuple4{T, B},
    ::DegRevLex{true}
) where {T, B}
    da, db = monom_totaldeg(ea), monom_totaldeg(eb)
    if da < db
        return true
    end
    if da > db
        return false
    end

    if ea.a1 == eb.a1
        if ea.a2 == eb.a2
            if ea.a3 == eb.a3
                return !(ea.a4 <= eb.a4)
            else
                return !(ea.a3 <= eb.a3)
            end
        else
            return !(ea.a2 <= eb.a2)
        end
    else
        return !(ea.a1 <= eb.a1)
    end
end

###
# Monomial-Monomial arithmetic.

function monom_lcm!(
    ec::PackedTuple1{T, B},
    ea::PackedTuple1{T, B},
    eb::PackedTuple1{T, B}
) where {T, B}
    x, si = packed_max(ea.a1, eb.a1, B, Val(1))
    x += si << ((sizeof(T) - sizeof(B)) * 8)
    ans = PackedTuple1{T, B}(x)
    _monom_overflow_check(ans)
    ans
end
function monom_lcm!(
    ec::PackedTuple2{T, B},
    ea::PackedTuple2{T, B},
    eb::PackedTuple2{T, B}
) where {T, B}
    x1, si1 = packed_max(ea.a1, eb.a1, B, Val(1))
    x2, si2 = packed_max(ea.a2, eb.a2, B, Val(0))
    x1 = x1 + ((si1 + si2) << ((sizeof(T) - sizeof(B)) * 8))
    ans = PackedTuple2{T, B}(x1, x2)
    _monom_overflow_check(ans)
    ans
end
function monom_lcm!(
    ec::PackedTuple3{T, B},
    ea::PackedTuple3{T, B},
    eb::PackedTuple3{T, B}
) where {T, B}
    x1, si1 = packed_max(ea.a1, eb.a1, B, Val(1))
    x2, si2 = packed_max(ea.a2, eb.a2, B, Val(0))
    x3, si3 = packed_max(ea.a3, eb.a3, B, Val(0))
    x1 = x1 + ((si1 + si2 + si3) << ((sizeof(T) - sizeof(B)) * 8))
    ans = PackedTuple3{T, B}(x1, x2, x3)
    _monom_overflow_check(ans)
    ans
end
function monom_lcm!(
    ec::PackedTuple4{T, B},
    ea::PackedTuple4{T, B},
    eb::PackedTuple4{T, B}
) where {T, B}
    x1, si1 = packed_max(ea.a1, eb.a1, B, Val(1))
    x2, si2 = packed_max(ea.a2, eb.a2, B, Val(0))
    x3, si3 = packed_max(ea.a3, eb.a3, B, Val(0))
    x4, si4 = packed_max(ea.a4, eb.a4, B, Val(0))
    x1 = x1 + ((si1 + si2 + si3 + si4) << ((sizeof(T) - sizeof(B)) * 8))
    ans = PackedTuple4{T, B}(x1, x2, x3, x4)
    _monom_overflow_check(ans)
    ans
end

function monom_is_gcd_const(ea::PackedTuple1{T, B}, eb::PackedTuple1{T, B}) where {T, B}
    if !packed_is_zero_dot_product(ea.a1, eb.a1, B, Val(1))
        return false
    end
    return true
end
function monom_is_gcd_const(ea::PackedTuple2{T, B}, eb::PackedTuple2{T, B}) where {T, B}
    if !packed_is_zero_dot_product(ea.a1, eb.a1, B, Val(1))
        return false
    end
    if !packed_is_zero_dot_product(ea.a2, eb.a2, B, Val(0))
        return false
    end
    return true
end
function monom_is_gcd_const(ea::PackedTuple3{T, B}, eb::PackedTuple3{T, B}) where {T, B}
    if !packed_is_zero_dot_product(ea.a1, eb.a1, B, Val(1))
        return false
    end
    if !packed_is_zero_dot_product(ea.a2, eb.a2, B, Val(0))
        return false
    end
    if !packed_is_zero_dot_product(ea.a3, eb.a3, B, Val(0))
        return false
    end
    return true
end
function monom_is_gcd_const(ea::PackedTuple4{T, B}, eb::PackedTuple4{T, B}) where {T, B}
    if !packed_is_zero_dot_product(ea.a1, eb.a1, B, Val(1))
        return false
    end
    if !packed_is_zero_dot_product(ea.a2, eb.a2, B, Val(0))
        return false
    end
    if !packed_is_zero_dot_product(ea.a3, eb.a3, B, Val(0))
        return false
    end
    if !packed_is_zero_dot_product(ea.a4, eb.a4, B, Val(0))
        return false
    end
    return true
end

function monom_product!(
    ec::PackedTuple1{T, B},
    ea::PackedTuple1{T, B},
    eb::PackedTuple1{T, B}
) where {T, B}
    x = ea.a1 + eb.a1
    ans = PackedTuple1{T, B}(x)
    _monom_overflow_check(ans)
    ans
end
function monom_product!(
    ec::PackedTuple2{T, B},
    ea::PackedTuple2{T, B},
    eb::PackedTuple2{T, B}
) where {T, B}
    x1 = ea.a1 + eb.a1
    x2 = ea.a2 + eb.a2
    ans = PackedTuple2{T, B}(x1, x2)
    _monom_overflow_check(ans)
    ans
end
function monom_product!(
    ec::PackedTuple3{T, B},
    ea::PackedTuple3{T, B},
    eb::PackedTuple3{T, B}
) where {T, B}
    x1 = ea.a1 + eb.a1
    x2 = ea.a2 + eb.a2
    x3 = ea.a3 + eb.a3
    ans = PackedTuple3{T, B}(x1, x2, x3)
    _monom_overflow_check(ans)
    ans
end
function monom_product!(
    ec::PackedTuple4{T, B},
    ea::PackedTuple4{T, B},
    eb::PackedTuple4{T, B}
) where {T, B}
    x1 = ea.a1 + eb.a1
    x2 = ea.a2 + eb.a2
    x3 = ea.a3 + eb.a3
    x4 = ea.a4 + eb.a4
    ans = PackedTuple4{T, B}(x1, x2, x3, x4)
    _monom_overflow_check(ans)
    ans
end

function monom_division!(
    ec::PackedTuple1{T, B},
    ea::PackedTuple1{T, B},
    eb::PackedTuple1{T, B}
) where {T, B}
    x = ea.a1 - eb.a1
    ans = PackedTuple1{T, B}(x)
    ans
end
function monom_division!(
    ec::PackedTuple2{T, B},
    ea::PackedTuple2{T, B},
    eb::PackedTuple2{T, B}
) where {T, B}
    x1 = ea.a1 - eb.a1
    x2 = ea.a2 - eb.a2
    ans = PackedTuple2{T, B}(x1, x2)
    ans
end
function monom_division!(
    ec::PackedTuple3{T, B},
    ea::PackedTuple3{T, B},
    eb::PackedTuple3{T, B}
) where {T, B}
    x1 = ea.a1 - eb.a1
    x2 = ea.a2 - eb.a2
    x3 = ea.a3 - eb.a3
    ans = PackedTuple3{T, B}(x1, x2, x3)
    ans
end
function monom_division!(
    ec::PackedTuple4{T, B},
    ea::PackedTuple4{T, B},
    eb::PackedTuple4{T, B}
) where {T, B}
    x1 = ea.a1 - eb.a1
    x2 = ea.a2 - eb.a2
    x3 = ea.a3 - eb.a3
    x4 = ea.a4 - eb.a4
    ans = PackedTuple4{T, B}(x1, x2, x3, x4)
    ans
end

function monom_is_divisible(ea::PackedTuple1{T, B}, eb::PackedTuple1{T, B}) where {T, B}
    if !packed_ge(ea.a1, eb.a1, B, Val(1))
        return false
    end
    return true
end
function monom_is_divisible(ea::PackedTuple2{T, B}, eb::PackedTuple2{T, B}) where {T, B}
    if !packed_ge(ea.a1, eb.a1, B, Val(1))
        return false
    end
    if !packed_ge(ea.a2, eb.a2, B, Val(0))
        return false
    end
    return true
end
function monom_is_divisible(ea::PackedTuple3{T, B}, eb::PackedTuple3{T, B}) where {T, B}
    if !packed_ge(ea.a1, eb.a1, B, Val(1))
        return false
    end
    if !packed_ge(ea.a2, eb.a2, B, Val(0))
        return false
    end
    if !packed_ge(ea.a3, eb.a3, B, Val(0))
        return false
    end
    return true
end
function monom_is_divisible(ea::PackedTuple4{T, B}, eb::PackedTuple4{T, B}) where {T, B}
    if !packed_ge(ea.a1, eb.a1, B, Val(1))
        return false
    end
    if !packed_ge(ea.a2, eb.a2, B, Val(0))
        return false
    end
    if !packed_ge(ea.a3, eb.a3, B, Val(0))
        return false
    end
    if !packed_ge(ea.a4, eb.a4, B, Val(0))
        return false
    end
    return true
end

function monom_is_divisible!(
    ec::PackedTuple1{T, B},
    ea::PackedTuple1{T, B},
    eb::PackedTuple1{T, B}
) where {T, B}
    ans = monom_is_divisible(ea, eb)
    e = ec
    ans && (e = monom_division!(ec, ea, eb))
    ans, e
end
function monom_is_divisible!(
    ec::PackedTuple2{T, B},
    ea::PackedTuple2{T, B},
    eb::PackedTuple2{T, B}
) where {T, B}
    ans = monom_is_divisible(ea, eb)
    e = ec
    ans && (e = monom_division!(ec, ea, eb))
    ans, e
end
function monom_is_divisible!(
    ec::PackedTuple3{T, B},
    ea::PackedTuple3{T, B},
    eb::PackedTuple3{T, B}
) where {T, B}
    ans = monom_is_divisible(ea, eb)
    e = ec
    ans && (e = monom_division!(ec, ea, eb))
    ans, e
end
function monom_is_divisible!(
    ec::PackedTuple4{T, B},
    ea::PackedTuple4{T, B},
    eb::PackedTuple4{T, B}
) where {T, B}
    ans = monom_is_divisible(ea, eb)
    e = ec
    ans && (e = monom_division!(ec, ea, eb))
    ans, e
end

function monom_is_equal(ea::PackedTuple1{T, B}, eb::PackedTuple1{T, B}) where {T, B}
    ea.a1 == eb.a1
end
function monom_is_equal(ea::PackedTuple2{T, B}, eb::PackedTuple2{T, B}) where {T, B}
    ea.a1 == eb.a1 && ea.a2 == eb.a2
end
function monom_is_equal(ea::PackedTuple3{T, B}, eb::PackedTuple3{T, B}) where {T, B}
    ea.a1 == eb.a1 && ea.a2 == eb.a2 && ea.a3 == eb.a3
end
function monom_is_equal(ea::PackedTuple4{T, B}, eb::PackedTuple4{T, B}) where {T, B}
    ea.a1 == eb.a1 && ea.a2 == eb.a2 && ea.a3 == eb.a3 && ea.a4 == eb.a4
end

###
# Monomial division masks.

function monom_create_divmask(
    e::PackedTuple1{T, B},
    DM::Type{Mask},
    ndivvars,
    divmap,
    ndivbits,
    compressed
) where {T, B, Mask}
    @invariant !compressed
    ctr = one(Mask)
    res = zero(Mask)
    o = one(Mask)
    a1 = e.a1
    for i in 1:ndivvars
        ei = mod(a1, B)
        a1 = a1 >> (sizeof(B) * 8)
        for j in 1:ndivbits
            @inbounds if ei >= divmap[ctr]
                res |= o << (ctr - 1)
            end
            ctr += o
        end
    end

    res
end

function monom_create_divmask(
    e::PackedTuple2{T, B},
    DM::Type{Mask},
    ndivvars,
    divmap,
    ndivbits,
    compressed
) where {T, B, Mask}
    @invariant !compressed

    epc = div(sizeof(T), sizeof(B))

    if ndivvars < epc
        return monom_create_divmask(
            PackedTuple1{T, B}(e.a1),
            DM,
            ndivvars,
            divmap,
            ndivbits,
            compressed
        )
    end

    ctr = one(Mask)
    res = zero(Mask)
    o = one(Mask)

    a2 = e.a2
    for i in 1:epc
        ei = mod(a2, B)
        a2 = a2 >> (sizeof(B) * 8)
        for j in 1:ndivbits
            @inbounds if ei >= divmap[ctr]
                res |= o << (ctr - 1)
            end
            ctr += o
        end
    end

    a1 = e.a1
    for i in (epc + 1):min(2 * epc - 1, ndivvars)
        ei = mod(a1, B)
        a1 = a1 >> (sizeof(B) * 8)
        for j in 1:ndivbits
            @inbounds if ei >= divmap[ctr]
                res |= o << (ctr - 1)
            end
            ctr += o
        end
    end

    res
end

function monom_create_divmask(
    e::PackedTuple3{T, B},
    DM::Type{Mask},
    ndivvars,
    divmap,
    ndivbits,
    compressed
) where {T, B, Mask}
    @invariant !compressed

    epc = packed_elperchunk(T, B)

    if ndivvars < 2 * epc
        return monom_create_divmask(
            PackedTuple2{T, B}(e.a1, e.a2),
            DM,
            ndivvars,
            divmap,
            ndivbits,
            compressed
        )
    end

    ctr = one(Mask)
    res = zero(Mask)
    o = one(Mask)

    a3 = e.a3
    for i in 1:epc
        ei = mod(a3, B)
        a3 = a3 >> (sizeof(B) * 8)
        for j in 1:ndivbits
            @inbounds if ei >= divmap[ctr]
                res |= o << (ctr - 1)
            end
            ctr += o
        end
    end

    a2 = e.a2
    for i in (epc + 1):(2 * epc)
        ei = mod(a2, B)
        a2 = a2 >> (sizeof(B) * 8)
        for j in 1:ndivbits
            @inbounds if ei >= divmap[ctr]
                res |= o << (ctr - 1)
            end
            ctr += o
        end
    end

    a1 = e.a1
    for i in (2 * epc + 1):min(3 * epc - 1, ndivvars)
        ei = mod(a1, B)
        a1 = a1 >> (sizeof(B) * 8)
        for j in 1:ndivbits
            @inbounds if ei >= divmap[ctr]
                res |= o << (ctr - 1)
            end
            ctr += o
        end
    end

    res
end

function monom_create_divmask(
    e::PackedTuple4{T, B},
    DM::Type{Mask},
    ndivvars,
    divmap,
    ndivbits,
    compressed
) where {T, B, Mask}
    @invariant !compressed

    epc = packed_elperchunk(T, B)

    if ndivvars < 3 * epc
        return monom_create_divmask(
            PackedTuple3{T, B}(e.a1, e.a2, e.a3),
            DM,
            ndivvars,
            divmap,
            ndivbits,
            compressed
        )
    end

    ctr = one(Mask)
    res = zero(Mask)
    o = one(Mask)

    a4 = e.a4
    for i in 1:epc
        ei = mod(a4, B)
        a4 = a4 >> (sizeof(B) * 8)
        for j in 1:ndivbits
            @inbounds if ei >= divmap[ctr]
                res |= o << (ctr - 1)
            end
            ctr += o
        end
    end

    a3 = e.a3
    for i in (epc + 1):(2 * epc)
        ei = mod(a3, B)
        a3 = a3 >> (sizeof(B) * 8)
        for j in 1:ndivbits
            @inbounds if ei >= divmap[ctr]
                res |= o << (ctr - 1)
            end
            ctr += o
        end
    end

    a2 = e.a2
    for i in (2 * epc + 1):(3 * epc)
        ei = mod(a2, B)
        a2 = a2 >> (sizeof(B) * 8)
        for j in 1:ndivbits
            @inbounds if ei >= divmap[ctr]
                res |= o << (ctr - 1)
            end
            ctr += o
        end
    end

    a1 = e.a1
    for i in (3 * epc + 1):min(4 * epc - 1, ndivvars)
        ei = mod(a1, B)
        a1 = a1 >> (sizeof(B) * 8)
        for j in 1:ndivbits
            @inbounds if ei >= divmap[ctr]
                res |= o << (ctr - 1)
            end
            ctr += o
        end
    end

    res
end
