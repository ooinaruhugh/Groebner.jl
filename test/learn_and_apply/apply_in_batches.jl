import Primes

@testset "learn & apply, in batches" begin
    # Simple sanity checks
    ks = map(GF, Primes.nextprimes(2^30, 40))

    @test_broken false # broken for ordering=:lex

    R, (x, y) = polynomial_ring(AbstractAlgebra.ZZ, ["x", "y"], ordering=:degrevlex)
    sys_qq = [44x^2 + x + 2^50, y^10 - 10 * y^5 - 99]
    sys_gf = map(
        j -> map(poly -> map_coefficients(c -> (k = ks[j]; k(c)), poly), sys_qq),
        1:length(ks)
    )

    trace, gb = Groebner.groebner_learn(sys_gf[1])

    flag1, gb1 = Groebner.groebner_apply!(trace, sys_gf[1])
    flag2, gb2 = Groebner.groebner_apply!(trace, sys_gf[2])
    flag3, (gb3, gb4) = Groebner.groebner_apply!(trace, (sys_gf[3], sys_gf[4]))
    flag4, (gb5, gb6, gb7, gb8) =
        Groebner.groebner_apply!(trace, (sys_gf[3], sys_gf[4], sys_gf[5], sys_gf[6]))
    flag5, (gb9, gb10, gb11, gb12, gb13, gb14, gb15, gb16) = Groebner.groebner_apply!(
        trace,
        (
            sys_gf[3],
            sys_gf[4],
            sys_gf[5],
            sys_gf[6],
            sys_gf[7],
            sys_gf[8],
            sys_gf[9],
            sys_gf[10]
        )
    )
    # he-he
    flag6, gbs = Groebner.groebner_apply!(trace, (sys_gf[3:18]...,))

    @test flag1 && flag2 && flag3 && flag4 && flag5 && flag6

    true_gb = map(Groebner.groebner, sys_gf)
    @test [gb1, gb2, gb3, gb4] == true_gb[1:4]
    @test [gb5, gb6, gb7, gb8] == true_gb[3:6]
    @test [gb9, gb10, gb11, gb12, gb13, gb14, gb15, gb16] == true_gb[3:10]
    @test collect(gbs) == true_gb[3:18]

    function test_learn_apply(system, primes)
        @assert length(primes) > 4
        systems_zp = map(p -> map(f -> map_coefficients(c -> GF(p)(c), f), system), primes)

        trace, gb_0 = Groebner.groebner_learn(systems_zp[1])

        flag, gb = Groebner.groebner_apply!(trace, systems_zp[2])
        @test gb == Groebner.groebner(systems_zp[2])

        flag, (gb,) = Groebner.groebner_apply!(trace, (systems_zp[2],))
        @test gb == Groebner.groebner(systems_zp[2])

        flag, gbs = Groebner.groebner_apply!(trace, (systems_zp[2:5]...,))
        @test collect(gbs) == map(Groebner.groebner, systems_zp[2:5])
    end

    kat = Groebner.katsuran(8, ground=ZZ, ordering=:degrevlex)
    cyc = Groebner.cyclicn(6, ground=ZZ, ordering=:degrevlex)

    ps1 = Primes.nextprimes(2^30, 5)
    ps2 = [2^31 - 1, 2^30 + 3, 2^32 + 15, 2^40 + 15, 2^30 + 3]

    test_learn_apply(kat, ps1)
    test_learn_apply(kat, ps2)
    test_learn_apply(cyc, ps2)
end
