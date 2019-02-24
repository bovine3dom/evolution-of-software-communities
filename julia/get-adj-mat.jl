include("init.jl")

using Rebugger
using JuliaDB
import Dates

versions = loadtable("../data/playground/elm_versions-1.2.0-2018-03-12.csv")

# Filter versions as a timeseries to get the desired version_IDs for the dependency table
# Then extract Dependency Project IDs for each matching version_id

# Parse the dates
versions_date_format = Dates.dateformat"y-m-d H:M:S \U\T\C"
parsed_dates = select(versions, :Published_Timestamp) .|>
    x -> Dates.DateTime(x, versions_date_format)
versions = setcol(versions, :Timestamp, parsed_dates)
versions = setcol(versions, :Month, :Timestamp => ts -> floor(ts, Dates.Month))

# Latest ID for each project for each month:
# groupby will pass a StructArray to the first argument and that will be sorted by the first column, then the second if necessary.
latest_version_each_month = groupby((Version_ID=x->sort(x)[1].ID,), versions, (:Project_ID, :Month), select=(:Timestamp, :ID))

# Group
deps = loadtable("../data/playground/elm_dependencies-1.2.0-2018-03-12.csv")

# Inner join to get only the deps that match a selected versionID
depversion = join(select(latest_version_each_month, (:Version_ID, :Month)), deps, lkey=:Version_ID, rkey=:Version_ID)

# Just need to rekey all project_ids to natural numbers:

"""Add Project_Node and Dependency_Project_Node columns to `deps`

Node IDs are natural numbers between 1 and {number of unique IDs}
"""
function IDs_to_nodes(deps)
    project_ids = vcat(select(deps, :Project_ID), select(deps, :Dependency_Project_ID)) |> unique
    node_numbers = Dict(project_ids[i] => i for i in 1:length(project_ids))

    deps = setcol(deps, :Project_Node, :Project_ID => pid->node_numbers[pid])
    setcol(deps, :Dependency_Project_Node, :Dependency_Project_ID => pid->node_numbers[pid])
end

# For checking hypothesis that pattern was due to ID number-time correlation (it was)
function IDs_to_nodes_shuf(deps)
    project_ids = vcat(select(deps, :Project_ID), select(deps, :Dependency_Project_ID)) |> unique
    node_numbers = Dict(proj => index for (proj, index) in
                        zip(project_ids, Random.randperm(length(project_ids))))
    deps = setcol(deps, :Project_Node, :Project_ID => pid->node_numbers[pid])
    setcol(deps, :Dependency_Project_Node, :Dependency_Project_ID => pid->node_numbers[pid])
end

# And make a graph or sparsearray. LG is fast enough, tho
import LightGraphs

number_of_nodes = depversion ->
    select(depversion, (:Project_Node, :Dependency_Project_Node)) |> maximum ∘ maximum

function graph_from_table(depversion,
                          nnodes = number_of_nodes(depversion))
    g = LightGraphs.SimpleDiGraph(nnodes)
    for row in depversion
        # Create edge from dependency to dependent
        LightGraphs.add_edge!(g, row.Dependency_Project_Node, row.Project_Node)
    end
    return g
end

"""
Make an adjacency matrix from each month.

The nth column contains the dependents of package n. The nth row contains the dependees.
If a column is empty, that means that project did not have any release this month (or its release had no dependencies). We can't just copy the column from the previous month because it may be a legitimate new release with 0 dependencies where the last month had >0 dependencies.

Anyway, for each month, filter to all packages with months <= m then take the max month:
"""
function latest_at_month(deps, month)
    deps = filter(row->row.Month <= month, deps)
    groupby(row->sort(row)[1] |> x->NamedTuple{keys(x)[3:end]}(x), deps, (:Month, :Project_Node),
            select=(:Month, :Project_Node, :Dependency_Project_Node))
end

deps = depversion |> IDs_to_nodes
# This happens to be contiguous. Should have months_between function or something.
months = deps.columns.Month |>unique|>sort
nnodes = number_of_nodes(deps)
graphs = [latest_at_month(deps, month)|>t->graph_from_table(t, nnodes) for month in months]
adj_mats = map(LightGraphs.adjacency_matrix, graphs)

using Serialization
serialize("../data/processed/elm-adj-mats.jls", adj_mats)

X = Array{Int}(undef, (size(adj_mats[1])..., length(adj_mats)))
[X[:,:,i]=f for (i,f) in adj_mats|>enumerate]

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

# (Project, version) -> (Project, Dependency[])
#                        ^ forward adjacency list
#= groupby(Tuple, deps, (:Project_ID, :Version_ID), select = :Dependency_Project_ID) =#

#= using SparseArrays =#

#= function adjacency_from_table(depversion) =#
#=     nnodes = select(depversion, :Project_Node) |> length =#
#=     adj_mat = spzeros(nnodes, nnodes) =#
#=     for row in depversion =#
#=         # Create edge from dependency to dependent =#
#=         # a[i,j] = link from j to i, we want flow of code represented, so link goes from dependency to dependent =#
#=         adj_mat[row.Project_Node, row.Dependency_Project_Node] += 1 =#
#=     end =#
#=     return adj_mat =#
#= end =#
