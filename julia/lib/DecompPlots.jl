module DecompPlots

import Dates
import ScikitLearn
using Serialization
import Plots

include("MatlabDecomp.jl")

ScikitLearn.@sk_import metrics: adjusted_mutual_info_score

#= @memoize function amis_from_repeats1(D_s) =#
#=     amis_from_repeats(D_s) =#
#= end =#

"""
    amis_from_repeats(Ds)

Calculate the Adjusted Mutual Information of an array of decompositions/ktensors.
"""
function amis_from_repeats(D_s)
    # Community membership by max
    factors_to_k_memb_by_max(factors) = map(x->x[2],findmax(factors[2];dims=2)[2])[:]

    D_sfacts = map(x->factors_to_k_memb_by_max(x.factors),D_s)

    # This is a little bit slow.
    # Could filter it first and then randomly sample.

    # Make it triangular
    Ds_filt = values(filter(x->x[1][1] < x[1][2],pairs(IndexCartesian(),Iterators.product(D_sfacts,D_sfacts)|>collect)))

    amis = [adjusted_mutual_info_score(d1,d2) for (d1,d2) in Ds_filt]
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
    amis = Dict()
    now = Dates.now()
    for r in readdir(dir)
        # Ensure consistent indices by lexically sorting the filenames.
        decomps = vcat([deserialize("$dir/$r/$file") for file in sort(readdir("$dir/$r"))]...)
        amis[parse(Int, r)] = amis_from_repeats(decomps)
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

function loaddecomps(platform)
    dir = "../data/processed/pacman/$platform/decomps/"
    decomps = Dict()
    for r in readdir(dir)
        # Ensure consistent indices by lexically sorting the filenames.
        decomps[parse(Int, r)] =
        vcat([deserialize("$dir$r/$file") for file in sort(readdir("$dir$r"))]...)
    end
    decomps
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
    serialize("$rssdir/$now.jls", rsss)
    rsss
end

function cache_all()
    platforms = readdir("../data/processed/pacman")
    job1 = @distributed for p in platforms
        DecompPlots.cache_amis(p)
    end
    job2 = @distributed for p in platforms
        DecompPlots.cache_nrss(p)
    end
    job1, job2
end

function get_amis(platform)
    dir = "../data/processed/pacman/$platform/amis/"
    deserialize("$dir/$(sort(readdir(dir))[end])")
end

function get_nrss(platform)
    dir = "../data/processed/pacman/$platform/nrss/"
    deserialize("$dir/$(sort(readdir(dir))[end])")
end

function plot_ami(decomps, rs=sortedkeys(decomps))
    # decomps = d2dict(decomps, rs)
    # rs = setdiff(rs, 1)
    amis = [amis_from_repeats1(decomps[r]) for r in rs];

    errorplot(
        xlabel="Number of communities",
        ylabel="Pairwise AMI",
        rs,
        amis,)
end

end
