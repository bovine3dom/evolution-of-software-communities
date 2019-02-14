import Pkg
Pkg.activate(".")
Pkg.instantiate()

import HTTP

include("./lib/concordia.jl")
