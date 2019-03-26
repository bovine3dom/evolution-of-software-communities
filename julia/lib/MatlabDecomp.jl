module MatlabDecomp

using MATLAB: @mat_str
using TensorDecompositions: CANDECOMP

import SparseArrays

export
matlab_load_sptensor,
matlab_nncp_loaded_spt,
@mat_str,
put_adj_mat_mat


# Performance
# Runs NPM iterations at about 0.5 to 1 per minute

## using an attached matlab session
#
# This way is a bit clunky and slow compared to just using files.

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

"""
    ncp(r, method="apg")

'apg' is the 'apg-tf' method from Xu and Yin 2013.

"""
function matlab_ncp_loaded_spt(r, method="apg")
    if method == "apg"
        mat"$D = ncp_apg(spt, $r, {});"
    end
    _matlab_dict_to_cp(D, r)
end

function relerror_loaded(D)
    D = Dict(("lambda" => D.lambdas, "u" => Any[D.factors...]))
    mat"relerror(spt, $D)"
end

matlab_nncp_loaded_spt(r) = matlab_ncp_loaded_spt(r, "apg")

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

matlab_load_npm_decomps(r) = begin
    platform = "NPM"
    D = MAT.matread("../data/processed/$platform-D$r.mat")["D"]
    # This might not work for r = 1; but who cares
    D = CANDECOMP(D["u"]|>Tuple, D["lambda"][:])
end

end
