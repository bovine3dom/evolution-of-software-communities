import Pkg
Pkg.activate(".")
Pkg.instantiate()

using Rebugger

push!(LOAD_PATH, pwd() * "/lib")

include("./lib/corcondia.jl")
