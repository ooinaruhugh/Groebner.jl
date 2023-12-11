using SIMD, BenchmarkTools

function add_mul!(v1::Vector{T}, c, v2) where {T}
    @inbounds for i in 1:length(v1)
        v1[i] += T(c) * T(v2[i])
    end
    nothing
end

@code_native debuginfo = :none add_mul([1, 2], UInt32(1), UInt32[3, 4])

function reduce_dense_row_by_sparse_row_no_remainder!(
    row::Vector{T},
    indices::Vector{I},
    coeffs,
    mul
) where {I, T}
    @inbounds for j in 1:length(indices)
        idx = indices[j]
        row[idx] = row[idx] + mul * coeffs[j]
    end

    row
end

function reduce_dense_row_by_sparse_row_no_remainder_2!(
    row::Vector{T},
    indices::Vector{I},
    coeffs,
    mul,
    ::Val{N}
) where {I, T, N}
    @inbounds for j in 1:N:length(indices)
        idx1 = indices[j]
        idx2 = indices[j + 1]
        # idx3 = indices[j + 2]
        # idx4 = indices[j + 3]
        # c1, c2, c3, c4 = coeffs[j], coeffs[j + 1], coeffs[j + 2], coeffs[j + 3]
        c1, c2 = coeffs[j], coeffs[j + 1]
        # b1, b2, b3, b4 = row[idx1], row[idx2], row[idx3], row[idx4]
        b1, b2 = row[idx1], row[idx2]
        a1 = b1 + T(mul) * T(c1)
        a2 = b2 + T(mul) * T(c2)
        # a3 = b3 + T(mul) * T(c3)
        # a4 = b4 + T(mul) * T(c4)
        # (a1, a2, a3, a4) = (b1, b2, b3, b4) .+ T(mul) .* (T(c1), T(c2), T(c3), T(c4))
        row[idx1] = a1
        row[idx2] = a2
        # row[idx3] = a3
        # row[idx4] = a4
    end

    row
end

function reduce_dense_row_by_sparse_row_no_remainder_vec!(
    row::Vector{T},
    indices::Vector{I},
    coeffs::Vector{C},
    mul::C,
    ::Val{N}
) where {I, T, N, C}
    mul_vec = Vec{N, UInt64}(mul)

    @inbounds for j in 1:N:length(indices)
        idx_vec = SIMD.vload(Vec{N, I}, indices, j)

        cfs_vec = SIMD.vload(Vec{N, C}, coeffs, j)
        cfs_vec_ext = Vec(SIMD.Intrinsics.zext(SIMD.LVec{N, T}, cfs_vec.data))

        row_vec = SIMD.vgather(row, idx_vec)

        # @info "" idx_vec cfs_vec row_vec

        # @info "" cfs_vec_ext

        row_vec_inc = row_vec + mul_vec * cfs_vec_ext

        # @info "" row_vec_inc

        SIMD.vscatter(row_vec_inc, row, idx_vec)
    end

    row
end

@assert reduce_dense_row_by_sparse_row_no_remainder!(
            UInt64[1, 2, 3, 4],
            [1, 2, 3, 4],
            UInt32[3, 1, 0, 10],
            UInt32(8)
        ) ==
        reduce_dense_row_by_sparse_row_no_remainder_vec!(
            UInt64[1, 2, 3, 4],
            [1, 2, 3, 4],
            UInt32[3, 1, 0, 10],
            UInt32(8),
            Val(2)
        ) ==
        reduce_dense_row_by_sparse_row_no_remainder_2!(
            UInt64[1, 2, 3, 4],
            [1, 2, 3, 4],
            UInt32[3, 1, 0, 10],
            UInt32(8),
            Val(2)
        )

@code_native debuginfo = :none add_mul!(UInt64[1, 2, 3, 4], UInt32(8), UInt32[3, 1, 0, 10])

@code_native debuginfo = :none reduce_dense_row_by_sparse_row_no_remainder_2!(
    UInt64[1, 2, 3, 4],
    [1, 2, 3, 4],
    UInt32[3, 1, 0, 10],
    UInt32(8),
    Val(2)
)

@code_native debuginfo = :none reduce_dense_row_by_sparse_row_no_remainder_vec!(
    UInt64[1, 2, 3, 4],
    [1, 2, 3, 4],
    UInt32[3, 1, 0, 10],
    UInt32(8),
    Val(32)
)

n = 100 * 2^10
k = n >> 3
@benchmark reduce_dense_row_by_sparse_row_no_remainder!(v1, i2, v2, c) setup = begin
    v1 = rand(UInt, n)
    c = rand(UInt32)
    v2 = rand(UInt32, k)
    i2 = rand(Int(1):Int(n), k)
end

@benchmark reduce_dense_row_by_sparse_row_no_remainder_2!(v1, i2, v2, c, Val(2)) setup =
    begin
        v1 = rand(UInt, n)
        c = rand(UInt32)
        v2 = rand(UInt32, k)
        i2 = rand(Int(1):Int(n), k)
    end

@benchmark add_mul!(v1, c, v2) setup = begin
    v1 = rand(UInt, n)
    c = rand(UInt32)
    v2 = rand(UInt32, n)
end
