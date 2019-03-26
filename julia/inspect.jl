# I include here because Revise doesn't work with local modules or something.
# This way I can redefine them easily.
include("lib/MatlabDecomp.jl")
mld = MatlabDecomp
include("lib/ProcessLibrariesIO.jl")
get_depversions_and_adj_mats = ProcessLibrariesIO.get_depversions_and_adj_mats
include("lib/InspectDGraph.jl")

## Generate decompositions and inspect them for any non-NPM thing

platform = "Elm"
depversions, adj_mats = get_depversions_and_adj_mats(platform);

# Load adj_mats into matlab: this tells matlab what tensor to decompose.
mld.matlab_load_sptensor(adj_mats)

# Quickly generate some tensors:
Ds = [mld.matlab_nncp_loaded_spt(r) for r in 2:10]

# ANLS is a bit faster but a lot less stable
@time apgDs = [mld.matlab_ncp_loaded_spt(r) for r in 2:10]
@time anls_bppDs = [mld.matlab_ncp_loaded_spt(r, "anls_bpp") for r in 2:10]

apgs = [mld.matlab_ncp_loaded_spt(4, "apg") for i in 1:10]
[ins.plot_time(ins.DGraph(depversions, adj_mats, apgs[i]),true)|>display for i in 1:10]

anlss = [mld.matlab_ncp_loaded_spt(4, "anls_bpp") for i in 1:10]
[ins.plot_time(ins.DGraph(depversions, adj_mats, anlss[i]),true)|>display for i in 1:10]

r = 5
apgdg2 = ins.DGraph(depversions, adj_mats, apgDs[r])
anls_bppdg2 = ins.DGraph(depversions, adj_mats, anls_bppDs[r])

# Serialize them after, if you like.
using Serialization

platforms = ["Cargo", "CRAN", "Pypi", "Maven"]

for platform in platforms
    adj_mats = deserialize("../data/processed/$(platform)-adj-mats.jls");

    @info "Loading $platform tensor..."
    @time mld.matlab_load_sptensor(adj_mats)
    @info "Decomposing $platform tensor..."
    @time Ds = [mld.matlab_nncp_loaded_spt(r) for r in 2:30]

    serialize("../data/processed/$platform-Ds.jls", Ds)
    @info "Done!"
end

cargods = deserialize("../data/processed/Cargo-Ds.jls")
cmeta, cadj_mats = get_depversions_and_adj_mats("Cargo");
cargo = [ins.DGraph(cmeta, cadj_mats, D) for D in cargods];

ncp2(r) = begin
    mld.mat"[$D, $i, $info] = ncp(spt, $r)"
    D, info
end

Ds = [(D,d) = ncp2(r) for r in 2:36]
rele = [D[2]["final"]["rel_Error"] for D in Ds]

using JuliaDB
using JuliaDBMeta

# CSVFiles can't read it
import CSV
df = CSV.read("../data/sample-1.4/Cargo_projects_with_repository_fields-1.4.0-2018-12-22.csv")
projmeta = table([df[c] for c in names(df)]...; names = names(df))

projmeta = ins.get_projmeta(cargo[1], projmeta)

for dg in cargo[1:10]
    ins.plot_time(dg, true) |> display
end

using Plots
Plots.gr()

plot_time(dg) =
    Plots.plot(
        dg.D.factors[3],
        legend=:topleft,
        xlabel="Time",
        ylabel="Activity",
    )

plts = [ins.plot_time(dg) for dg in cargo[1:10]]
savefig(plot(plts..., layout=(5,2)), "panel.png")


# InspectDGraph gives a type called DGraph that makes analysis a bit easier

r = 5
dg = ins.DGraph(depversions, adj_mats, Ds[r])
# This loads the project metadata from disk, so it'll be a little slow.
projmeta = ins.get_projmeta(dg, platform)

# Reimport and redo this after modifying the lib:
#= include("lib/InspectDGraph.jl"); dg = ins.DGraph(depversions, adj_mats, Ds[r]); ins.get_projmeta(dg, projmeta); =#

# Plot components
ins.plot_time(dg)
ins.plot_degree(dg, 2)

using JuliaDB
using JuliaDBMeta

# Look at a particular component.
ins.contributing_nodes(dg, 1)

# Add another column, if you want:
t = ins.contributing_nodes(dg,5)
nodes = sort(@select t :Node)
@transform_vec t (
    FstRelease = ins.first_appearances(dg)[nodes],
    NumContributors = rows(dg.projmeta[nodes]).Repository_Contributors_Count,)


# Top N names by sourcerank for all known projects
x = @select projmeta[sortperm(projmeta.columns.SourceRank) |> sort] :Name
y = @select projmeta[sortperm(projmeta.columns.Repository_SourceRank) |> sort] :Name
z = @select projmeta[sortperm(projmeta.columns.Repository_Stars_Count) |> sort] :Name
x == y == z


## Misc plotting

using Plots
unicodeplots()

using LightGraphs
import UnicodePlots

histogram(indegree(dg.g))
UnicodePlots.histogram(indegree(dg.g))
UnicodePlots.histogram(outdegree(dg.g))

plot_component_distribution(f, c) = UnicodePlots.histogram(f[1:end,c])

map(c -> plot_component_distribution(fs[1], c), 1:4)
map(c -> plot_component_distribution(fs[2], c), 1:4)
