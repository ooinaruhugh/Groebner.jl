# Precompile some calls for better ttfx

@assert VERSION >= v"1.6.0-DEV.154"

@setup_workload begin
    # Putting some things in `setup` can reduce the size of the
    # precompile file and potentially make loading faster.
    @compile_workload begin
        # all calls in this block will be precompiled, regardless of whether
        # they belong to your package or not (on Julia 1.8 and higher)
        R, (x, y) =
            AbstractAlgebra.polynomial_ring(AbstractAlgebra.QQ, ["x", "y"], ordering=:lex)
        arr = [x, y]
        gb = groebner(arr)
        isgroebner(arr)
        normalform(arr, arr)

        R, (x, y) =
            AbstractAlgebra.polynomial_ring(AbstractAlgebra.GF(2^31 - 1), ["x", "y"])
        arr = [x^2 * y + 1, x * y^2 + 1]
        gb = groebner(arr, ordering=DegRevLex())

        trace, gb = groebner_learn(arr, ordering=DegRevLex())
        flag, gb = groebner_apply!(trace, arr, ordering=DegRevLex())
    end
end

precompile(
    groebner,
    (Vector{AbstractAlgebra.Generic.MPoly{AbstractAlgebra.Rational{BigInt}}},)
)
