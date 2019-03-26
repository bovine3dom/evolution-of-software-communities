module DecompPlots

using Distributed
using Serialization
using JuliaDB
using LightGraphs, MetaGraphs
using Memoize

import Dates
import ScikitLearn
import Plots
import Statistics
import Random

# For the CANDECOMP definition needed for deserializing decomps
import TensorDecompositions

# Maybe comment this out if you're using
include("MatlabDecomp.jl")

const PLATFORMS = readdir("../data/processed/pacman")


### Generate summary statistics

# Both of these are pretty slow and would probably be faster implemented in Julia.
# AMI in particular looks like it might be spending a lot of time converting to python objects?

ScikitLearn.@sk_import metrics: adjusted_mutual_info_score

#= @memoize function amis_from_repeats1(D_s) =#
#=     amis_from_repeats(D_s) =#
#= end =#

# Community membership by max
factors_to_k_memb_by_max(factors) = map(x->x[2],findmax(factors[2];dims=2)[2])[:]

"""
    amis_from_repeats(Ds)

Calculate the Adjusted Mutual Information of an array of decompositions/ktensors.
"""
function amis_from_repeats(D_s)
    D_sfacts = map(x->factors_to_k_memb_by_max(x.factors),D_s)

    # This is a little bit slow.
    # Could filter it first and then randomly sample.

    # Make it triangular
    Ds_filt = values(filter(x->x[1][1] < x[1][2],pairs(IndexCartesian(),Iterators.product(D_sfacts,D_sfacts)|>collect)))

    amis = [adjusted_mutual_info_score(d1,d2) for (d1,d2) in Ds_filt]
end

function _cache_amis(platform, dir, r)
    amis = Dict()
    # Ensure consistent indices by lexically sorting the filenames.
    decomps = vcat([deserialize("$dir/$r/$file") for file in sort(readdir("$dir/$r"))]...)
    amis[parse(Int, r)] = amis_from_repeats(decomps)
    amis
end

function cache_amis(platform)
    # For each r
    # Collect all decomps
    # Calculate AMI
    # Write to a file
    #
    # Not done:
    #   if time in filename is greater or equal to decomp times, then it's valid.
    dir = "../data/processed/pacman/$platform/decomps"
    amidir = "../data/processed/pacman/$platform/amis"
    now = Dates.now()
    rs = readdir(dir) |> Random.shuffle
    amis = @distributed merge for r in rs
        _cache_amis(platform, dir, r)
    end
    run(`mkdir -p $amidir`)
    #= existing = readdir(amidir) =#
    serialize("$amidir/$now.jls", amis)
    #= map(fn->rm("$amidir/$fn"), existing) =#
    amis
end

#= function relerror(adj_mats, decomps) =#
#=     rs = sort([keys(decomps)...]) =#
#=     MatlabDecomp.matlab_load_sptensor(adj_mats) =#
#=     errors = [[MatlabDecomp.relerror_loaded(D) for D in decomps[r]] for r in rs]; =#
#= end =#

function cache_nrss(platform, rs)
    dir = "../data/processed/pacman/$platform"
    rssdir = "$dir/nrss"
    rsss = Dict()

    adj_mats = deserialize("$dir/adj-mats.jls")
    MatlabDecomp.matlab_load_sptensor(adj_mats)

    now = Dates.now()
    for r in rs
        # Ensure consistent indices by lexically sorting the filenames.
        decomps = vcat([deserialize("$dir/decomps/$r/$file") for file in sort(readdir("$dir/decomps/$r"))]...)
        rsss[r] = [MatlabDecomp.relerror_loaded(D) for D in decomps]
    end
    run(`mkdir -p $rssdir`)
    #= existing = readdir(rssdir) =#
    serialize("$rssdir/$now.jls", rsss)
    #= map(fn->rm("$rssdir/$fn"), existing) =#
    rsss
end

function cache_nrss(platform)
    dir = "../data/processed/pacman/$platform"
    rssdir = "$dir/nrss"
    rsss = Dict()

    adj_mats = deserialize("$dir/adj-mats.jls")
    MatlabDecomp.matlab_load_sptensor(adj_mats)

    now = Dates.now()
    for r in readdir("$dir/decomps")
        # Ensure consistent indices by lexically sorting the filenames.
        decomps = vcat([deserialize("$dir/decomps/$r/$file") for file in sort(readdir("$dir/decomps/$r"))]...)
        rsss[parse(Int, r)] = [MatlabDecomp.relerror_loaded(D) for D in decomps]
    end
    run(`mkdir -p $rssdir`)
    existing = readdir(rssdir)
    serialize("$rssdir/$now.jls", rsss)
    map(fn->rm("$rssdir/$fn"), existing)
    rsss
end

function cache_ami_rss(platforms = PLATFORMS)
    job1 = @distributed for p in platforms
        DecompPlots.cache_amis(p)
    end
    job2 = @distributed for p in platforms
        DecompPlots.cache_nrss(p)
    end
    job1, job2
end


### Retrieve cached data

function loaddecomps(platform, r)
    dir = "../data/processed/pacman/$platform/decomps/"
    # Ensure consistent indices by lexically sorting the filenames.
    vcat([deserialize("$dir$r/$file") for file in sort(readdir("$dir$r"))]...)
end

function loaddecomps(platform)
    dir = "../data/processed/pacman/$platform/decomps/"
    decomps = Dict()
    for r in readdir(dir)
        decomps[parse(Int, r)] = loaddecomps(platform, r)
    end
    decomps
end

function get_amis(platform)
    dir = "../data/processed/pacman/$platform/amis/"
    deserialize("$dir/$(sort(readdir(dir))[end])")
end

function get_nrss(platform)
    dir = "../data/processed/pacman/$platform/nrss/"
    deserialize("$dir/$(sort(readdir(dir))[end])")
end


### indegree and outdegree

function get_graph(platform)
    adj_mats = deserialize("../data/processed/pacman/$platform/adj-mats.jls")
    DiGraph(adj_mats[end])
end


### Plot helpers

@memoize function name_lookup(platform::AbstractString)
    meta = deserialize("../data/processed/pacman/$platform/meta.jls")
    name_lookup(meta)
end

@memoize function name_lookup(meta)
    merge(
        groupby(x -> x[1], meta, :Project_Node, select=:Project_Name) |>
            Dict{Int, String},
        groupby(x -> x[1], meta, :Dependency_Project_Node, select=:Dependency_Name) |>
            Dict{Int, String})
end

name_components(factors, names) = begin
    hubs, followers, time = factors

    hubs.*=(hubs.==maximum(hubs,dims=2))

    hubnames = map(component -> findmax(component)[2], hubs |> eachcol) |>
        hubprojs -> map(p -> names[p], hubprojs)
end

function check_names(decomps, names)
    cnames = [name_components(decomps[i].factors, names) |> sort for i in 1:length(decomps)]
    hcat(cnames...) |> permutedims
end

function plot_times(decomps; fudge=1)
    Plots.plot(
        [DecompPlots.plot_time(ds[1]; legend=false) for ds in values(sort(decomps))]...)
end

function plot_time_fudge_panel(decomps)
    Plots.plot(
        [DecompPlots.plot_time(decomps[f]; legend=false) for f in 1:length(decomps)]...)
end

sortedkeys(d) = sort([keys(d)...])


### Plotting

"""
    errorplot(xs, ys; kwargs...)

Plot 2 * (standard error of the mean of `ys`).
"""
errorplot(xs, ys; kwargs...) = Plots.plot(
    xs,
    Statistics.mean.(ys);
    ribbon=(Statistics.std.(ys) .* 2) ./ sqrt(length(ys[1])),
    fillalpha=0.3,
    xticks=xs,
    legend=false,
    kwargs...)

function plot_ami(amis, rs=sortedkeys(amis))
    amis = [amis[r] for r in rs]
    errorplot(
        xlabel="Number of communities",
        ylabel="Pairwise AMI",
        rs,
        amis,)
end

function plot_rss(nrsss, rs=sortedkeys(nrsss))
    nrsss = [nrsss[r] for r in rs]
    errorplot(
        rs,
        nrsss;
        xlabel="Number of communities",
        ylabel="NRSS",)
end

plot_time(D, names; kwargs...) = begin
    hubs, followers, time = D.factors
    # Normalise time factor to between 0 and 1 because
    # absolute magnitude is meaningless without context
    time = time .- minimum(time)
    time = time ./ maximum(time)

    hubnames = name_components(D.factors, names)

    # sort time component by hubnames
    time = time[1:end,sortperm(hubnames)]
    hubnames = sort(hubnames)

    Plots.plot(time; legend=:topleft, labels=hubnames, yticks=[0,1], xlabel="Month", ylabel="Relative activity", kwargs...)
end

plot_time(D; kwargs...) = begin
    hubs, followers, time = D.factors
    # Normalise time factor to between 0 and 1 because
    # absolute magnitude is meaningless without context
    time = time .- minimum(time)
    time = time ./ maximum(time)

    Plots.plot(time, legend=:topleft; kwargs...)
end

# Probably broken!
function plot_time_grid(decomps; kwargs...)
    plts = [plot_time(Ds[1]) for Ds in decomps]
    plot(plts..., layout=(5,2), size=(700,600), legend=false, yticks=0:1; kwargs...)
end


### Gephi plot

function gephi_viz(r=4, fudge=10)
    # Use decomps[4][10] as a representative sample
    # Add component numbers, h and k, names

    meta = deserialize("../data/processed/pacman/Elm/meta.jls")
    adj_mats = deserialize("../data/processed/pacman/Elm/adj-mats.jls")

    g = MetaDiGraph(adj_mats[end])
    decomps = loaddecomps("Elm")
    names = name_lookup(meta)

    [set_prop!(g, i, :name, name) for (i,name) in enumerate([values(sort(names))...][1:1462])]
    [set_prop!(g, i, :component, c) for (i,c) in enumerate(DecompPlots.factors_to_k_memb_by_max(decomps[r][fudge].factors))]

    g # Save with MetaGraphs.savedot, if you like.
end


### Save plots

GOOD_DECOMPS = Dict(
        "Cargo" => (8, 5),
        "NPM" => (3, 1),
        "Elm" => (4, 10), # 10, 2
        "CRAN" => (7, 1), # 2, 1
        "Pypi" => (6, 2), # 18, 1
        "Maven" => (5, 1),
        )

function pick_fudge(platform, r)
    decomps = loaddecomps(platform, r)
    names = name_lookup(platform)

    backend = Plots.backend()
    Plots.unicodeplots()

    display(plot_time_fudge_panel(decomps))
    Plots.backend(backend)
    display(check_names(decomps, names))

end

function save_ami_rss(platforms = PLATFORMS)
    for platform in platforms
        @info platform
        amis = get_amis(platform)
        if platform == "NPM"
            Plots.savefig(plot_ami(amis, 2:14), "../figures/results/$platform-ami.pdf")
        else
            nrss = get_nrss(platform)
            Plots.savefig(Plots.plot(plot_ami(amis), plot_rss(nrss), size=(1200,400)), "../figures/results/$platform-ami-rss.pdf")
            #= Plots.savefig(plot_ami(amis), "../figures/results/$platform-ami.pdf") =#
            #= Plots.savefig(plot_rss(nrss), "../figures/results/$platform-rss.pdf") =#
        end
        @info "done"
    end
end

function update_ami_rss(platforms = PLATFORMS)
    for p in platforms
        cache_amis(p)
        cache_nrss(p)
    end
    save_ami_rss(platforms)
end

function save_time_plots(platform, r, fudge=1; filename="../figures/results/$platform-best-r-time.pdf", kwargs...)
    decomps = loaddecomps(platform, r)
    names = name_lookup(platform)

    Plots.savefig(
        plot_time(decomps[fudge], names; kwargs...), filename)
end

function save_time_plots(platforms=PLATFORMS)
    for p in platforms
        r, f = GOOD_DECOMPS[p]
        save_time_plots(p, r, f)
    end
end


end
