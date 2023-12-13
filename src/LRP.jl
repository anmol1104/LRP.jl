module LRP

using Clustering
using CSV
using DataFrames
using Distributions
using ElasticArrays
using OffsetArrays
using Plots
using ProgressMeter
using Random
using StatsBase

ElasticArrays.ElasticMatrix(A::OffsetMatrix) = OffsetMatrix(ElasticArray(A), A.offsets)
Base.append!(A::OffsetMatrix, items) = (append!(A.parent, items); A)

global φᵀ = false::Bool

include("sample.jl")
include("datastructure.jl")
include("functions.jl")
include("initialize.jl")
include("operations.jl")
include("remove.jl")
include("insert.jl")
include("localsearch.jl")
include("parameters.jl")
include("ALNS.jl")
include("visualize.jl")

export  build, cluster, initialize, 
        vectorize, f, isfeasible, 
        ALNSparameters, ALNS, 
        visualize, animate, pltcnv

end

# -------------------------------------------------- TODO LIST (no particular order) --------------------------------------------------
# TODO: Identify and if possible improve order of complexity of local search methods.
# TODO: Test randomizing depot insertion position in a route. (swapdepot!(rng, k̅, s)).
# TODO: Test greedy vs. best clustering (initial solution run-time and final solution quality).
# TODO: Calibrate ALNS parameters for improved solution quality as well as run time.