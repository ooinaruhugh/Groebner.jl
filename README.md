<div align="left">
    <picture>
        <source media="(prefers-color-scheme: dark)" srcset="https://github.com/sumiya11/Groebner.jl/raw/master/docs/assets/logo-dark-with-text.svg">
      <img alt="Groebner.jl logo" src="https://github.com/sumiya11/Groebner.jl/raw/master/docs/assets/logo-with-text.svg">
    </picture>
</div>

---

[![Runtests](https://github.com/sumiya11/Groebner.jl/actions/workflows/Runtests.yml/badge.svg)](https://github.com/sumiya11/Groebner.jl/actions/workflows/Runtests.yml)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://sumiya11.github.io/Groebner.jl)
[![codecov](https://codecov.io/github/sumiya11/Groebner.jl/graph/badge.svg?token=J1SZT8ED9S)](https://codecov.io/github/sumiya11/Groebner.jl)

Groebner.jl is a Julia package for computing Groebner bases over fields.

For documentation and more please check out https://sumiya11.github.io/Groebner.jl.
For a simple example, see below.

**disclaimer: starting from the upcoming version 0.6, Groebner.jl will be distributed under GNU GPL v2.**

## How to use Groebner.jl?

You can install Groebner.jl using the Julia package manager. From the Julia REPL, type

```julia
import Pkg; Pkg.add("Groebner")
```

Groebner.jl works with polynomials from AbstractAlgebra.jl, DynamicPolynomials.jl, and Nemo.jl. For example, let's create a ring of polynomials in 3 variables

```julia
using AbstractAlgebra

R, (x1, x2, x3) = QQ["x1", "x2", "x3"]
```

Then, we can define a simple polynomial system

```julia
system = [
  x1 + x2 + x3,
  x1*x2 + x1*x3 + x2*x3,
  x1*x2*x3 - 1
]
```

And compute the Groebner basis by passing the system to `groebner`

```julia
using Groebner

G = groebner(system)
```
```julia
# result
3-element Vector{AbstractAlgebra.Generic.MPoly{Rational{BigInt}}}:
 x1 + x2 + x3
 x2^2 + x2*x3 + x3^2
 x3^3 - 1
```


## Contacts

This library is maintained by Alexander Demin (<asdemin_2@edu.hse.ru>).

## Acknowledgement

We would like to acknowledge Jérémy Berthomieu, Christian Eder, and Mohab Safey El Din as this library is inspired by their work ["msolve: A Library for Solving Polynomial Systems"](https://arxiv.org/abs/2104.03572). We are also grateful to The Max Planck Institute for Informatics and The MAX team at l'X for providing computational resources.

Special thanks goes to Vladimir Kuznetsov for providing the sources of his F4 implementation.

## See also

Other software for computing Groebner bases in Julia:

- [AlgebraicSolving.jl](https://github.com/algebraic-solving/AlgebraicSolving.jl): fast F4 implementation, elimination, signature Groebner bases.
- [GroebnerBasis.jl](https://github.com/ederc/GroebnerBasis.jl): deprecated, see [Oscar.jl](https://github.com/oscar-system/Oscar.jl).
- [Singular.jl](https://github.com/oscar-system/Singular.jl)

If you do not see your package here, we either do not know about it, or forgot to include it, sorry! Feel free to open a PR.

## Citing Groebner.jl

If you find Groebner.jl useful in your work, you can cite [this paper](https://arxiv.org/abs/2304.06935)

```
@misc{groebnerjl2023,
  title = {Groebner.jl: A package for Gr\"obner bases computations in Julia}, 
  author = {Alexander Demin and Shashi Gowda},
  year = {2023},
  eprint = {2304.06935},
  url = {https://arxiv.org/abs/2304.06935}
}
```
