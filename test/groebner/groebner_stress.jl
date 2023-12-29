import Random
using AbstractAlgebra

function test_params(
    rng,
    nvariables,
    exps,
    nterms,
    npolys,
    grounds,
    coeffssize,
    orderings,
    linalgs,
    monoms,
    homogenizes
)
    for n in nvariables
        for e in exps
            for nt in nterms
                for np in npolys
                    for gr in grounds
                        for ord in orderings
                            for csz in coeffssize
                                for linalg in linalgs
                                    for monom in monoms
                                        for homogenize in homogenizes
                                            set = Groebner.generate_set(
                                                n,
                                                e,
                                                nt,
                                                np,
                                                csz,
                                                rng,
                                                gr,
                                                ord
                                            )
                                            isempty(set) && continue

                                            try
                                                gb = Groebner.groebner(
                                                    set,
                                                    linalg=linalg,
                                                    monoms=monom,
                                                    homogenize=homogenize
                                                )
                                                @test Groebner.isgroebner(gb)
                                                @test all(isone ∘ leading_coefficient, gb)
                                            catch err
                                                @error "Beda!" n e nt np gr ord monom
                                                println(err)
                                                println("Rng:\n", rng)
                                                println("Set:\n", set)
                                                rethrow(err)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

@testset "groebner random stress tests" begin
    rng = Random.MersenneTwister(42)

    nvariables = [2, 3]
    exps       = [1:2, 2:4]
    nterms     = [1:1, 1:2, 3:4]
    npolys     = [1:1, 3:4, 100:110]
    grounds    = [GF(1031), GF(2^50 + 55), AbstractAlgebra.QQ]
    coeffssize = [3, 1000, 2^31 - 1]
    orderings  = [:degrevlex, :lex, :deglex]
    linalgs    = [:deterministic, :randomized]
    monoms     = [:auto, :dense, :packed]
    homogenize = [:yes, :auto]
    p          = prod(map(length, (nvariables, exps, nterms, npolys, grounds, orderings, coeffssize, linalgs, monoms, homogenize)))
    @info "Producing $p random small tests for groebner. This may take a minute"
    test_params(
        rng,
        nvariables,
        exps,
        nterms,
        npolys,
        grounds,
        coeffssize,
        orderings,
        linalgs,
        monoms,
        homogenize
    )
end
