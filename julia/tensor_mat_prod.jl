include("init.jl")
using TensorOperations
using TensorDecompositions
using TensorToolbox
import Random
Random.seed!(1337)

R = 2 # number of columns in each factor
#dims = [1000,1000,20]
dims = [4,3,2]
X = rand(dims...)
F = nncp(X,R)
(A,B,C) = [svd(f).U for f in F.factors] # number of factors is determined by rank, dims |> size
us = []
ss = []
vs = []
for f in F.factors
    (u,s,v) = svd(f)
    push!(us,u)
    push!(ss,s)
    push!(vs,v)
end
#@show us |> size
#
##@show y = mapreduce(transpose, ⊗, us)*X[:]
#@show (A' ⊗ B' ⊗ C') * X[:]

#    function C = kron_mat_vec(Alist,X)
#    K = length(Alist);
#    for k = K:-1:1
#        A = Alist{k};
#        Y = ttm(X,A,k);
#        X = Y;
#        X = permute(X,[3 2 1]);
#    end
#    C = Y;
#    end

function quick_kron(ts,X)
    i_x = 1:(size(X) |> length) |> collect
    Y = similar(X)
    for (k,t) in reverse(ts |> enumerate |> collect)
        Y = ttm(X,t,k)
        X = permutedims(Y,reverse(i_x))
    end
    Y
end
@show quick_kron([A',B',C'],X) # is exactly the same if you reverse the order of input
@show mapreduce(transpose, ⊗, reverse(us))*X[:]
# doesn't work for rank-4 tensors

#using BenchmarkTools
#@show @benchmark quick_kron([A',B',C'],X) # so it's similar but not actually the same. Great.
## but it is faster, and is usable for large matrices without running out of memory
##@show @benchmark mapreduce(transpose, ⊗, us)*X[:]

#rest = join(string.(1:length(size(X))-1),",")
#for a in reverse(A)
#    eval(Meta.parse("@tensor Y[i,$rest] := a[i,l] * X[l,$rest]"))
#    eval(Meta.parse("@tensor X[i,$rest] = Y[$rest,i]"))
#end

#@tensor Y[b,a,i] := A[i,l] * X[l, a, b]
#@tensor Y[b,a,i] = B[i,l] * Y[l, a, b]
#@tensor Y[b,a,i] = C[i,l] * Y[l, a, b]
#@show Y
function corcondia(X,F,R)
    us = []
    ss = []
    vs = []
    for f in F.factors
        (u,s,v) = svd(f)
        push!(us,u)
        push!(ss,s)
        push!(vs,v)
    end
    y = quick_kron(transpose.(us),X)
    z = quick_kron((pinv ∘ Diagonal).(ss),y)
    G = quick_kron(vs, z)
    (1 - mapreduce(k -> (G[k] - δ(Tuple(k)...))^2,+,pairs(IndexCartesian(),G)|>keys)/R)
end

#@show corcondia(X,F,R)
