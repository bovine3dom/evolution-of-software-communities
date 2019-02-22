# Inspired by https://github.com/alessandrobessi/corcondia/blob/master/coreconsistency.py

using LinearAlgebra
using TensorToolbox

δ(args...) = reduce(==,args) |> Int
⊗(a,b) = kron(a,b)

function quick_kron(ts,X)
    i_x = 1:(size(X) |> length) |> collect
    Y = similar(X)
    for (k,t) in reverse(ts |> enumerate |> collect)
        Y = ttm(X,t,k)
        X = permutedims(Y,reverse(i_x))
    end
    Y
end

function CORCONDIA(X,factors,R)
    us = []
    ss = []
    vs = []
    for f in factors
        (u,s,v) = svd(f)
        push!(us,u)
        push!(ss,s)
        push!(vs,v)
    end

#    y = mapreduce(transpose, ⊗, us)*X[:]
#    z = mapreduce(inv ∘ Diagonal, ⊗, ss)*y
#    inds = [R for _ in 1:length(factors)]
#    G = reshape(reduce(⊗,vs)*z,inds...)
#    G = G./maximum(G) # Not sure this is justified

# Known issues:
#   - only supports 3-mode or fewer tensors

    y = quick_kron(transpose.(us),X)
    z = quick_kron((pinv ∘ Diagonal).(ss),y)
    G = quick_kron(vs, z)

    # people often do this * 100 "to make it into percent"
    # but I find it easier to read as a decimal
    (1 - mapreduce(k -> (G[k] - δ(Tuple(k)...))^2,+,pairs(IndexCartesian(),G)|>keys)/R)
    # 90%+ is great
    # 50%- is a bit lame
    # Negative is really bad.
end
