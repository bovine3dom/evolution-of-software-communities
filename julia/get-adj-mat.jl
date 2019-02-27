# include("init.jl")

# I use this with IronRepl, but e.g. Juno or Jupyter Lab would also be fine.

using Rebugger
using JuliaDB
using Serialization

include("lib/process-libraries-io.jl")

depversions, adj_mats = get_depversions_and_adj_mats("Elm");

### Experiments ###

## Decomposition with matlab ##

# Performance
# Runs NPM iterations at about 0.5 to 1 per minute

## using an attached matlab session
#
# This way is a bit clunky and slow compared to just using files.

using MATLAB: @mat_str
using TensorDecompositions: CANDECOMP

mat"""
addpath ../matlab
addpath ../matlab/tensor_toolbox
"""

function matlab_load_sptensor(adj_mats)
    sparsefloat(am1) =
        convert(SparseArrays.SparseMatrixCSC{Float64,Int64}, am1)
    adj_mats = map(sparsefloat, adj_mats)
    mat"spt = sparse_matrix_list_to_sptensor($adj_mats)"
end

"Convert dict from matlab to CANDECOMP struct"
function _matlab_dict_to_cp(D, r)
    if r == 1
        lmbda = Array{Float64}(undef, r)
        lmbda .= D["lambda"]
        # Make it a 10x1 array, not a 10x0 array
        factors = map(permutedims ∘ permutedims, D["u"]|>Tuple)
        CANDECOMP(factors, lmbda)
    else
        CANDECOMP(D["u"]|>Tuple, D["lambda"])
    end
end

function matlab_nncp_loaded_spt(r)
    mat"$D = ncp(spt, $r, {});"
    _matlab_dict_to_cp(D, r)
end

function matlab_nncp(X, r)
    mat"""
    X = tensor($X);
    $D = ncp(X, $r, {});
    """
    _matlab_dict_to_cp(D, r)
end

## Trade .mat files

import MAT

function put_adj_mat_mat(platform, adj_mats=missing)
    filename = "../data/processed/$platform-adj-mats.mat"
    if isfile(filename)
        @info "Assuming pre-existing file is fine"
    else
        if ismissing(adj_mats)
            _, adj_mats = get_depversions_and_adj_mats(platform)
        end
        MAT.matwrite(filename, Dict("adj_mats"=>adj_mats,))
    end

    println("""
        Feed matlab something like this:

load('$filename')
X = sparse_matrix_list_to_sptensor(adj_mats);
r = 4;
D = ncp(X, r, {});
save(sprintf('data/processed/$platform-D%d.mat', r))
""")
end

# These are the same size and basically the same content as adj-mats.jls
#
# We could just write .mat initially if we wanted: julia reads mat fine, but
# matlab doesn't like jls.
put_adj_mat_mat(platform)

# Left to run overnight. I don't expect it to get far.
"""
for r = 5:100
    D = ncp(X, r, {}); disp(sprintf("\n\nr=%d done!\n\n", r))
    save(sprintf('data/processed/NPM-D%d', r), 'D');
end
"""

# Read the decomp back
r = 4
D = MAT.matread("../data/processed/$platform-D$r.mat")["D"]
# This might not work for r = 1; but who cares
# D = CANDECOMP(D["u"]|>Tuple, D["lambda"][:])
factors = D["u"]

platform = "NPM"
Ds = [MAT.matread("../data/processed/$platform-D$r.mat")["D"]["u"] for r in 4:8]

### Visualise and inspect results

# Use this to get the name and so on for a given project node number.
# Quick example for Olie
which_proj(proj, meta=depversions) = begin
    # select=:Project_Node speeds this up a lot.
    meta = filter(node_number -> node_number == proj, meta, select=:Project_Node)
    meta = select(meta, (:Project_Name, :Version_Number, :Project_ID,))[end]
end

using Plots

unicodeplots()
plotly()
ENV["BROWSER"]="~/fake_browser_copy_to"

"Component activity over time"
bytime(factors) =
    Plots.plot(
        factors[3];
        legend=:topleft,
        xlabel="Time",
        ylabel="Activity",
        size=(1340, 740),
    )

bydegree(factor) = begin
    gr()
    filename = "/tmp/heatmap-$(rand()).png"
    savefig(
        heatmap(factor, xlabel="Component", ylabel="Project", size=(1366,768)),
        filename)
    run(`fake_browser_copy_to $filename`)
end

# Component activity over time
bytime(factors)
# Component activity for indegree/outdegree
# Probably a bad time for large degree?
bydegree(factors[2]) # indegree
bydegree(factors[1]) # outdegree

# By time, but not interesting
heatmap(D.factors[3], xlabel="Component", ylabel="Month")

# Plot the adjacency matrix each month
#
# This is really slow -- heatmap is probably doing a load of work it doesn't need to.
# Looks like Plots is just real slow at heatmaps and images.
import Dates

months = depversions.columns.Month;
months = minimum(months):Dates.Month(1):maximum(months)

@animate for (adj_mat, month) in zip(adj_mats, months)
    heatmap(adj_mat, title=string(Dates.format(month, "U Y")), size=(1366,768))
end

#= run(`firefox $(ans.filename)`) =#
#= run(`feh $(ans.dir)`) =#

#= X = ProcessLibrariesIO.tensor(adj_mats); =#

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

# Don't try this on a big tensor...
undir = X -> begin X = BitArray(X); (X .| X') |> Array{Float64} end
Xundir = similar(X);
[Xundir[:,:,i] = undir(X[:,:,i]) for i in 1:size(X)[3]];


# Plot component activity in a COSE graph
# Not working now I've made the graph more connected. Probably need to tweak spring strengths or whatever.
show_communities(X, D, 4)
show_communities(Xundir, D, 4)
