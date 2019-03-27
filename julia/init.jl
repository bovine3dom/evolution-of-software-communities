import Pkg
Pkg.activate(".")
Pkg.instantiate()

using Rebugger

# This doesn't work with Revise, so it's pretty useless.
# push!(LOAD_PATH, pwd() * "/lib")
