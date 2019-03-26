include("init.jl")
include("lib/MatlabDecomp.jl")
mld = MatlabDecomp
include("lib/ProcessLibrariesIO.jl")

using Serialization

import ProgressMeter
import Dates

getr(rs, platform, repeats=10) = begin
    @info "Deserialising adjacency matrices"
    adj_mats = ProcessLibrariesIO.get_adj_mats(platform)
    @info "Loading adjacency matrices into matlab"
    mld.matlab_load_sptensor(adj_mats)
    adj_mats = nothing

    ProgressMeter.@showprogress for r in rs
        @info "Computing $repeats decompositions with r = $r"
        Ds = [mld.matlab_nncp_loaded_spt(r) for i in 1:repeats]
        dir = "../data/processed/pacman/$platform/decomps/$r/"
        run(`mkdir -p $dir`)
        serialize("$dir/$(Dates.now()).jls", Ds)
        @info "Component $r is done $(Dates.now())"
    end
    @info "All $rs × $repeats for $platform done!"
end

repeats = 10

if length(ARGS) > 3
    rstart = parse(Int, ARGS[1])
    rstep = parse(Int, ARGS[2])
    rend = parse(Int, ARGS[3])
    rs = range(rstart, rend, step=rstep)
    if length(ARGS) > 4
        repeats = parse(Int, ARGS[4])
        platform = ARGS[5]
    else
        platform = ARGS[4]
    end
else
    rstart = parse(Int, ARGS[1])
    rend = parse(Int, ARGS[2])
    rs = range(rstart, stop=rend)
    platform = ARGS[3]
end


getr(rs, platform, repeats)
