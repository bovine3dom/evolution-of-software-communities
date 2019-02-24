# include("init.jl")

using Rebugger
using JuliaDB

include("lib/process-libraries-io.jl")

versions = loadtable("../data/playground/elm_versions-1.2.0-2018-03-12.csv")
dependencies = loadtable("../data/playground/elm_dependencies-1.2.0-2018-03-12.csv")

depversions = ProcessLibrariesIO.dependencies_by_month(versions, dependencies)
adj_mats = ProcessLibrariesIO.monthly_adjacency_matrices(depversions)
months = depversions.columns.Month|>unique|>sort

#= using Serialization =#
#= serialize("../data/processed/elm-adj-mats.jls", adj_mats) =#

#= X = ProcessLibrariesIO.tensor(adj_mats) =#

# using TensorDecompositions

# General method: try for increasing ranks until candecomp gives a bad result
# D = nncp(X, 7)

### Plot the adjacency matrix each month:

#= using Plots =#

#= @animate for month in deps.columns.Month |> unique |> sort =#
#=     nnodes = number_of_nodes(deps) =#
#=     g = latest_at_month(deps, month) |> t->graph_from_table(t, nnodes) =#
#=     heatmap(g |> LightGraphs.adjacency_matrix, title=string(month)) =#
#=     println(g) =#
#=     readline() =#
#= end =#
