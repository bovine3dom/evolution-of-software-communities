module ins

using LightGraphs
using JuliaDB
using JuliaDBMeta
using TensorDecompositions: CANDECOMP
using IndexedTables: IndexedTable

using StatsBase: countmap

import SparseArrays
import Dates
import Plots

#= struct D =#
#=     indegree::Any, =#
#=     outdegree::Any, =#
#=     time::Any, =#
#= end =#

mutable struct DGraph
    meta::IndexedTable
    adj_mats::Array{SparseArrays.SparseMatrixCSC{Int64,Int64}}
    D::CANDECOMP
    g::LightGraphs.AbstractGraph
    n::Int
    r::Int
    nlookup::Vector{Int}
    projmeta

    DGraph(meta, adj_mats, D) = begin
        n, r = size(D.factors[1])
        g = _digraph(adj_mats[end])
        nlookup = (@groupby meta :Project_Node {ID=:Project_ID[1]}) |>
            @select :ID 
        new(meta, adj_mats, D, g, n, r, nlookup, missing)
    end
end

"I made the graphs backwards in ProcessLibrariesIO.jl so reverse that."
_digraph(adj_mat) = DiGraph(adj_mat |> permutedims)

months(dg) = begin
    months = select(dg.meta, :Month)
    minimum(months):Dates.Month(1):maximum(months)
end

activity(dg, component, factor=2) =
    dg.D.factors[factor][1:end,component]

node_viewer(dg, component, nodes) = begin
    # TODO: Look at activities across all components in factor 2 instead.
    nodes = sort(nodes)
    activities = [activity(dg, component, f)[nodes] for f in 1:2]
    res = select(dg.projmeta[nodes], (:Name, :SourceRank))
    #= res = @transform_vec res ( =#
    #=     Activity_k=activities[2], =#
    #=     Activity_h=activities[1], =#
    #=     Node=nodes) =#
    res = setcol(res, :Activity_k, activities[2])
    res = setcol(res, :Activity_h, activities[1])
    res = reindex(res, :SourceRank)
    sort(res, rev=true)
end

contributing_nodes(dg, component, pct=2) = begin
    nodes = top_percentile(dg, component, pct)
    node_viewer(dg, component, nodes)
end

function rank(dg::DGraph, component)
    fs = dg.D.factors
    ranks = [sortperm(f[1:end,component], rev=true) for f in fs[1:2]]
end

function top_n(dg::DGraph, component, n)
    ranks = rank(dg, component)
    ranks = ranks[2:2] # ignore factor 1
    vcat([rank[1:min(n, length(rank))] for rank in ranks]...) |> unique
end

function top_percentile(dg::DGraph, component, pct)
    top_n(dg, component, Int(dg.n ÷ (100/pct)))
end

function links_over_time(dg)
    table((Month=ins.months(dg), nlinks=[SparseArrays.nnz(a) for a in dg.adj_mats]))
end

function get_projmeta(dg, platform::AbstractString = platform(dg))
    projmeta = loadtable("../data/sample-1.4/$(platform)_projects_with_repository_fields-1.4.0-2018-12-22.csv")
    get_projmeta(dg, projmeta)
end

function get_projmeta(dg, projmeta)
    project_ids = vcat(
        select(dg.meta, :Project_ID),
        select(dg.meta, :Dependency_Project_ID)) |>
        unique
    node_numbers = Dict(project_ids[i] => i for i in 1:length(project_ids))
    projmeta = setcol(projmeta, :Node, :ID => pid->getkey(node_numbers, pid, missing))
    dg.projmeta = reindex(projmeta, :Node)
end

function first_appearance(dg, node)
    (@filter dg.meta :Project_Node == node) |>
        @with minimum(:Month)
end

function first_appearances(dg)
    (@groupby dg.meta :Project_Node minimum(:Month)) |> @select _[2]
end

function platform(dg)
    platform_freq = dg.meta.columns.Platform |> countmap |> collect
    sort(platform_freq, by = x -> x[2])[end][1]
end

function name_pkg(dg::DGraph, node::Int)
    if ismissing(dg.projmeta) || node > length(dg.projmeta)
        (@filter dg.meta node in (:Project_Node, :Dependency_Project_Node)) |>
            @with ((node == :Project_Node[1] ? :Project_Name : :Dependency_Name) |> unique)[1]
    else
        dg.projmeta[node].Name
    end
end

Base.display(dg::DGraph) = begin
    println("""DGraph(platform = $(platform(dg)), n = $(dg.n), r = $(dg.r))

    Top packages degree:

        $(join(
            map(n -> name_pkg(dg ,n) * "  --  $n", sortperm(indegree(dg.g), rev=true)[1:5]),
            "\n        "))""")
end

"Component activity over time"
plot_time(dg, nox=false) = begin
    if nox
        #= cs = dg.D.factors[3] |> eachcol |> collect =#
        #= plt = UnicodePlots.lineplot(cs[1]) =#
        #= [UnicodePlots.lineplot!(plt, cs[c]) for c in 2:length(cs)] =#
        #= plt =#
        Plots.unicodeplots()
        Plots.plot(
            dg.D.factors[3],
            legend=:topleft,
            xlabel="Time",
            size=(600,400),
        )
    else
        Plots.plot(
            dg.D.factors[3],
            legend=:topleft,
            xlabel="Time",
            ylabel="Activity",
        )
    end
end

"Component heatmaps by degree"
plot_degree(dg, factor, nox=false) = begin
    nox ? Plots.gr() : missing
    plt = Plots.heatmap(dg.D.factors[factor], xlabel="Component", ylabel="Project", size=(1366,768))
    if nox
        filename = "/tmp/heatmap-$(rand()).png"
        Plots.savefig(plt, filename)
        run(`fake_browser_copy_to $filename`)
    else
        plt
    end
end

end
