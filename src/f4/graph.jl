
# Information about F4 execution flow that can be later used for speeding up
# subsequent analogous computations.
mutable struct ComputationGraphF4{C, M, Ord, Ord2}
    time_spent::UInt64
    ring::PolyRing{Ord}
    input_basis::Basis{C}
    buf_basis::Basis{C}
    gb_basis::Basis{C}
    hashtable::MonomialHashtable{M, Ord}
    input_permutation::Vector{Int}
    matrix_infos::Vector{NamedTuple{(:nup, :nlow, :ncols), Tuple{Int64, Int64, Int64}}}
    matrix_nonzeroed_rows::Vector{Vector{Int}}
    matrix_upper_rows::Vector{Tuple{Vector{Int}, Vector{MonomIdx}}}
    matrix_lower_rows::Vector{Tuple{Vector{Int}, Vector{MonomIdx}}}
    # matrix_upper_rows_buffers::Vector{Vector{Vector{Int32}}}
    # matrix_lower_rows_buffers::Vector{Vector{Vector{Int32}}}
    output_nonredundant_indices::Vector{Int}
    nonredundant_indices_before_reduce::Vector{Int}
    output_sort_indices::Vector{Int}
    matrix_sorted_columns::Vector{Vector{Int}}
    params::AlgorithmParameters
    sweep_output::Bool
    representation::PolynomialRepresentation
    original_ord::Ord2
    term_sorting_permutations::Vector{Vector{Int}}
    term_homogenizing_permutations::Vector{Vector{Int}}
    homogenize::Bool
end

function initialize_computation_graph_f4(
    ring,
    input_basis,
    gb_basis,
    hashtable,
    permutation,
    params
)
    @log level = -4 "Initializing computation graph"
    ComputationGraphF4(
        time_ns(),
        ring,
        input_basis,
        deepcopy_basis(gb_basis),
        gb_basis,
        hashtable,
        permutation,
        Vector{NamedTuple{(:nup, :nlow, :ncols), Tuple{Int64, Int64, Int64}}}(),
        Vector{Vector{Int}}(),
        Vector{Tuple{Vector{Int}, Vector{MonomIdx}}}(),
        Vector{Tuple{Vector{Int}, Vector{MonomIdx}}}(),
        # Vector{Vector{Vector{Int32}}}(),
        # Vector{Vector{Vector{Int32}}}(),
        Vector{Int}(),
        Vector{Int}(),
        Vector{Int}(),
        Vector{Vector{Int}}(),
        params,
        params.sweep,
        PolynomialRepresentation(ExponentVector{UInt64}, UInt64),
        params.original_ord,
        Vector{Vector{Int}}(),
        Vector{Vector{Int}}(),
        params.homogenize
    )
end

function finalize_graph!(graph::ComputationGraphF4)
    # TODO: trim sizes
    graph.buf_basis = deepcopy_basis(graph.gb_basis)
    graph.buf_basis.nnonredundant = graph.input_basis.nnonredundant
    graph.buf_basis.nprocessed = graph.input_basis.nprocessed
    graph.buf_basis.nfilled = graph.input_basis.nfilled
    graph.time_spent = time_ns() - graph.time_spent
    nothing
end

function Base.show(io::IO, ::MIME"text/plain", graph::ComputationGraphF4)
    sz = round((Base.summarysize(graph) / 2^20), digits=2)
    println(
        io,
        "Computation graph of F4 ($sz MiB) recorded in $(round(graph.time_spent / 10^9, digits=3)) s."
    )
    println(
        io,
        """

        Ordering: $(graph.ring.ord)
        Monom. representation: $(graph.representation.monomtype)
        Coeff. representation: $(graph.representation.coefftype)
        Sweep output: $(graph.sweep_output)"""
    )
    total_iterations = length(graph.matrix_infos)
    total_matrix_low_rows = sum(x -> x.nlow, graph.matrix_infos)
    total_matrix_up_rows = sum(x -> x.nup, graph.matrix_infos)
    total_matrix_up_rows_useful = sum(length ∘ first, graph.matrix_upper_rows)
    total_matrix_low_rows_useful = sum(length ∘ first, graph.matrix_lower_rows)
    println(
        io,
        """

        Iterations of F4: $(total_iterations)
        Hashtable: $(graph.hashtable.load) / $(graph.hashtable.size) monomials filled
        Total upper matrix rows: $(total_matrix_up_rows) ($(round(total_matrix_up_rows_useful / total_matrix_up_rows * 100, digits=2)) % are useful)
        Total lower matrix rows: $(total_matrix_low_rows) ($(round(total_matrix_low_rows_useful / total_matrix_low_rows * 100, digits=2)) % are useful)"""
    )
end
