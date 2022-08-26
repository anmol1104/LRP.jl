# Initial solution
"""
    initialsolution([rng], instance, method)

Returns initial LRP solution for the given `instance` using the given `method`.

Available methods include,
- Random Initialization                 : `:random`

Optionally specify a random number generator `rng` as the first argument
(defaults to `Random.GLOBAL_RNG`).
"""
initialsolution(rng::AbstractRNG, instance, method::Symbol)::Solution = getfield(LRP, method)(rng, instance)
initialsolution(instance, method::Symbol) = initialsolution(Random.GLOBAL_RNG, instance, method)

# Random Initialization
# Create initial solution with randomly selcted node-route combination until all customer nodes have been added to the solution
function random(rng::AbstractRNG, instance)
    G = build(instance)
    s = Solution(G...)
    D = s.D
    C = s.C
    V = s.V
    # Step 1: Initialize an empty route for every vehicle
    R = Route[]
    for v ∈ V
        d = D[v.o]
        r = Route(rand(rng, 1:M), v, d)
        push!(v.R, r) 
        append!(R, v.R)
    end
    I = eachindex(C)
    J = eachindex(R)
    w = ones(Int64, I)                      # w[i]: selection weight for customer node C[i]
    # Step 2: Iteratively append randomly selected customer node in randomly selected route
    for _ ∈ I
        i = sample(rng, I, OffsetWeights(w))
        j = sample(rng, J)
        c = C[i]
        r = R[j]
        v = V[r.o]
        d = D[v.o]
        nₜ = d
        nₕ = isopt(r) ? C[r.s] : D[r.s]
        insertnode!(c, nₜ, nₕ, r, s)
        w[i] = 0
    end
    # Step 3: Return initial solution
    for v ∈ V deleteat!(v.R, findall(!isopt, v.R)) end
    return s
end
