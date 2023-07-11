using DynamicPolynomials, Nemo
using Groebner
using Printf

include((@__DIR__) * "/rss_tracker.jl")
include((@__DIR__) * "/aa-runge-kutta-6-6.jl");

setup_memuse_tracker()

const maxpairs = typemax(Int)

# Compile
n = Groebner.noonn(3);
Groebner.groebner(n, ordering=Groebner.DegRevLex(), maxpairs=maxpairs);

# Run!
@time gb = Groebner.groebner(system, ordering=Groebner.DegRevLex(), maxpairs=maxpairs);

GC.gc()
