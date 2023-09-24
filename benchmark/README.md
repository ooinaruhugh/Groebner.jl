## Benchmarks for `Groebner.jl`

This directory contains benchmark systems and scripts to run benchmarks.

Almost all of the benchmarks are reproducible; the instructions to run benchmarks are listed in the corresponding directories.

- The `arxiv_preprint` directory is used to produce tables from the arxiv preprint "Groebner.jl: A package for Gr\"obner bases computations in Julia". **In this directory, you can find instructions to reproduce the benchmarks**;

- The file `benchmarks.jl` is used for CI benchmarking **for Github only**;

- The `experiments` directory is used for development purposes. Benchmarks there are not reproducible;

- The `benchmark_systems` directory contains benchmark systems sources. Those include: 

    - `systems/biomodels`, polynomial chemical reaction network models obtained from https://odebase.org/;

    - `systems/standard`, a short list of well-known mostly zero-dimensional systems obtained from various sources;

    - `systems/MQ`, a set of MQ problems obtained from https://www.mqchallenge.org/;

    - `systems/for_gleb`, a couple of systems used in structural identifiability problems (see https://github.com/SciML/StructuralIdentifiability.jl/ for details). NOTE: these can be very large, so the sources are not stored in git. Contact the author to get a copy.
