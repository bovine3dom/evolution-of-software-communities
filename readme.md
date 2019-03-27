# Evolution of communities of software: using tensor decompositions to compare software ecosystems

This code was written as part of a paper titled "Evolution of communities of software: using tensor decompositions to compare software ecosystems".

## Reproduce our results

You need to:

1. Download [libraries-1.4.0-2018-12-22](https://zenodo.org/record/2536573/files/Libraries.io-open-data-1.4.0.tar.gz)
2. Run `get_platform` to roughly extract platform subsets
3. Pre-process the data for each platform with `get_depversions_and_adj_mats` - this requires ~50GiB of RAM for the NPM dataset.
4. Perform some decompositions with `get-r.jl` - this requires ~30GiB of RAM for the NPM dataset
5. Calculate summary statistics, etc, for those decompositions with `lib/DecompPlots.jl`

Our rough process:

```
$ for p in Elm CRAN Pypi Maven Cargo; do ./get_platform $p data/sample-1.4 data/libraries-1.4.0-2018-12-22/*.csv &; done
```

```
$ cd julia
$ julia -L init.jl
julia> pl = include("lib/ProcessLibrariesIO.jl")
julia> pl.get_depversions_and_adj_mats("Elm")
```

```
$ cd julia
$ julia get-r.jl 2 13 Elm
```

```
$ cd julia
$ julia -L init.jl
julia> dp = include("lib/DecompPlots.jl")
julia> dp.cache_amis("Elm")
julia> dp.cache_nrss("Elm")
julia> # etc.
```
