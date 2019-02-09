# Inspired by https://github.com/alessandrobessi/corcondia/blob/master/coreconsistency.py

using LinearAlgebra

δ(args...) = reduce(==,args) |> Int
⊗(a,b) = kron(a,b)

function CONCORDIA(X,factors,R)
    us = []
    ss = []
    vs = []
    for f in factors
        (u,s,v) = svd(f)
        push!(us,u)
        push!(ss,s)
        push!(vs,v)
    end

    y = mapreduce(u -> u |> transpose, ⊗, us)*X[:]
    z = mapreduce(s -> s |> Diagonal |> inv, ⊗, ss)*y
    inds = [R for _ in 1:length(factors)]
    G = reshape(reduce(⊗,vs)*z,inds...)

    # people often do this * 100 "to make it into percent"
    # but I find it easier to read as a decimal
    (1 - mapreduce(k -> (G[k] - δ(Tuple(k)...))^2,+,pairs(IndexCartesian(),G)|>keys)/R)
    # 90%+ is great
    # 50%- is a bit lame
    # Negative is really bad.
end
