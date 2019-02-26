module ProcessLibrariesIO

export dependencies_by_month, monthly_adjacency_matrices

using JuliaDB

import Dates
import LightGraphs

"""Add Project_Node and Dependency_Project_Node columns to `deps`

Node IDs are natural numbers between 1 and {number of unique IDs}
"""
function _IDs_to_nodes(deps)
    project_ids = vcat(select(deps, :Project_ID), select(deps, :Dependency_Project_ID)) |> unique
    node_numbers = Dict(project_ids[i] => i for i in 1:length(project_ids))

    deps = setcol(deps, :Project_Node, :Project_ID => pid->node_numbers[pid])
    setcol(deps, :Dependency_Project_Node, :Dependency_Project_ID => pid->node_numbers[pid])
end

"""All dependencies of the latest version of each project in each month"""
function dependencies_by_month(versions, dependencies)
    parsed_dates = select(versions, :Published_Timestamp) .|>
        x -> Dates.DateTime(x, Dates.dateformat"y-m-d H:M:S \U\T\C")
    versions = setcol(versions, :Timestamp, parsed_dates)
    versions = setcol(versions, :Month, :Timestamp => ts -> floor(ts, Dates.Month))

    # Latest ID for each project for each month:
    # Sort by timestamp, then number
    latest_version_each_month = groupby(
        (Version_ID=x->sort(x)[end].ID,),
        versions, (:Project_ID, :Month),
        select=(:Timestamp, :Number, :ID))

    # Inner join to get only the deps that match a selected versionID
    # We lose packages here if they don't have any dependents and aren't depended on by anything.
    lonely_packages = setdiff(
        versions.columns.Project_ID,
        dependencies.columns.Project_ID,
        dependencies.columns.Dependency_Project_ID)

    if length(lonely_packages) > 0
        @warn "$(length(lonely_packages)) unconnected packages omitted"
    end

    depversions = join(
        select(latest_version_each_month, (:Version_ID, :Month)),
        dependencies, lkey=:Version_ID, rkey=:Version_ID)

    # Just need to rekey all project_ids to natural numbers and reindex
    depversions |> _IDs_to_nodes |> t -> reindex(t, :Project_Node)
end

"Number of projects in the table"
function number_of_nodes(depversion)
    select(depversion, (:Project_Node, :Dependency_Project_Node)) |>
        maximum ∘ maximum
end

"DiGraph from dependency table"
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
"""
function latest_at_month(deps, month)
    deps = filter(row->row.Month <= month, deps)
    # This allocates memory. Could compute row indexes if we need to.
    groupby(
        (x = grp -> filter!(row -> row.Month == maximum(grp.Month), grp),),
        deps, :Project_Node) |> flatten
end

"One project adjacency matrix for each month in deps"
function monthly_adjacency_matrices(deps)
    months = deps.columns.Month
    months = minimum(months):Dates.Month(1):maximum(months)
    nnodes = number_of_nodes(deps)

    # This is slow - do it in parallel

    # optimize grouping in latest_at_month
    if colnames(deps)[1] !== :Project_Node
        deps = reindex(deps, :Project_Node)
    end

    # Drop columns we don't need to avoid allocating excess memory
    deps = select(deps, (:Project_Node, :Month, :Dependency_Project_Node))

    # pre-allocate
    result = Array{Any}(undef, length(months))

    Threads.@threads for i in 1:length(months)
        # Can't use enumerate with @threads
        month = months[i]
        result[i] = latest_at_month(deps, month) |>
            t -> graph_from_table(t, nnodes) |>
            LightGraphs.adjacency_matrix
    end
    result
end

function tensor(adj_mats)
    # Guessing that float float calculations are faster, but haven't checked.
    X = Array{Float64}(undef, (size(adj_mats[1])..., length(adj_mats)))
    [X[:,:,i]=f for (i,f) in adj_mats|>enumerate]
    X
end

end
