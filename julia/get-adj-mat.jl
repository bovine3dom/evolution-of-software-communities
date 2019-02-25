# include("init.jl")

# I use this with IronRepl, but e.g. Juno or Jupyter Lab would also be fine.

using Rebugger
using JuliaDB
using Serialization

include("lib/process-libraries-io.jl")

versions = loadtable("../data/playground/elm_versions-1.2.0-2018-03-12.csv")
dependencies = loadtable("../data/playground/elm_dependencies-1.2.0-2018-03-12.csv")

depversions = ProcessLibrariesIO.dependencies_by_month(versions, dependencies)
adj_mats = ProcessLibrariesIO.monthly_adjacency_matrices(depversions);

serialize("../data/processed/elm-depversions.jls", depversions)
serialize("../data/processed/elm-adj-mats.jls", adj_mats)


### Experiments ###


using Plots
import Dates

# Use this to get the name and so on for a given project node number.
# Quick example for Olie
which_proj(proj, meta=depversions) = begin
    meta = filter(row -> row.Project_Node == proj, meta)
    meta = select(meta, (:Project_Name, :Version_Number, :Project_ID,))[end]
end

months = depversions.columns.Month;
months = minimum(months):Dates.Month(1):maximum(months)

# Plot the adjacency matrix each month
#
# This is really slow -- heatmap is probably doing a load of work it doesn't need to.
# Looks like Plots is just real slow at heatmaps and images.
@animate for (adj_mat, month) in zip(adj_mats, months)
    heatmap(adj_mat, title=string(Dates.format(month, "U Y")), size=(1366,768))
end

#= run(`firefox $(ans.filename)`) =#
#= run(`feh $(ans.dir)`) =#

#= using Query =#

#= depversions |> =#
#=     @groupby(_.Project_ID, _.Month) |> =#
#=     @filter(_.Month == max(_.Month)) |> =#
#=     DataFrame =#

#= group = 0 =#

#= JuliaDB.groupby( =#
#=                 grp -> filter(x -> x.Dependency_Project_Node == maximum(grp.Dependency_Project_Node), grp)[1].Dependency_Project_Node, =#
#=         depversions, =#
#=         (:Project_ID, :Month)) =#

### Inspect decomposition

X = ProcessLibrariesIO.tensor(adj_mats);

import Colors
import GraphPlot
import LightGraphs

function show_communities(X, F, r)
    N = size(X)[1]
    u = F.factors[2]
    adj = X[:,:,size(X)[3]] |> BitArray

    if ((adj .| adj') .== adj) |> all
        g = LightGraphs.Graph(adj)
    else
        g = LightGraphs.DiGraph(adj)
    end

    colours = Colors.distinguishable_colors(r,Colors.colorant"blue")
    nodefillarr = []
    for n in 1:N
        ind = findmax(u[n,:])[2]
        push!(nodefillarr,colours[ind])
    end

    if N > 300
        proc = GraphPlot.gplothtml(g; nodefillc=nodefillarr)
        print("http://blanthornpc:2015/", split(proc.cmd.exec[2], "/")[3])
    else
        GraphPlot.gplot(g;nodefillc=nodefillarr)
    end
end

# Other layout still bad. Probably just bugs in GraphPlot.
g = LightGraphs.DiGraph(adj_mats[end])
GraphPlot.gplothtml(g; layout=GraphPlot.stressmajorize_layout)

undir = X -> begin X = BitArray(X); (X .| X') |> Array{Float64} end
Xundir = similar(X);
[Xundir[:,:,i] = undir(X[:,:,i]) for i in 1:size(X)[3]];

using TensorDecompositions

# General method: try for increasing ranks until candecomp gives a bad result
D = nncp(X, 4)

# Component activity over time:
Plots.plot(
    D.factors[3];
    legend=:topleft,
    xlabel="Time",
    ylabel="Activity",
)
heatmap(D.factors[3], xlabel="Component", ylabel="Month")

# Component activity for indegree/outdegree
heatmap(D.factors[1], xlabel="Component", ylabel="Project")
heatmap(D.factors[2], xlabel="Component", ylabel="Project")

# Plot component activity in a COSE graph
# Not working now I've made the graph more connected. Probably need to tweak spring strengths or whatever.
show_communities(X, D, 4)
show_communities(Xundir, D, 4)
