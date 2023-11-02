"""
    remove!([rng], q::Int64, s::Solution, method::Symbol)

Returns solution removing q customer nodes from solution s using the given `method`.

Available methods include,
- Random Customer Node Removal  : `:randomcustomer!`
- Random Route Removal          : `:randomroute!`
- Random Vehicle Removal        : `:randomvehicle!`
- Random Depot Node Removal     : `:randomdepot!` 
- Related Customer Node Removal : `:relatedcustomer!`
- Related Route removal         : `:relatedroute!`
- Related Vehicle Removal       : `:relatedvehicle!`
- Related Depot Node Removal    : `:relateddepot!`
- Worst Customer Node Removal   : `:worstcustomer!`
- Worst Route Removal           : `:worstroute!`
- Worst Vehicle Removal         : `:worstvehicle!`
- Worst Depot NodeRemoval       : `:worstdepot!`

Optionally specify a random number generator `rng` as the first argument
(defaults to `Random.GLOBAL_RNG`).
"""
function remove!(rng::AbstractRNG, q::Int64, s::Solution, method::Symbol)::Solution 
    try return getfield(LRP, method)(rng, q, s) catch end
    return getfield(Main, method)(rng, q, s)
end
remove!(q::Int64, s::Solution, method::Symbol) = remove!(Random.GLOBAL_RNG, q, s, method)

# -------------------------------------------------- NODE REMOVAL --------------------------------------------------
"""
    randomcustomer!(rng::AbstractRNG, q::Int64, s::Solution)

Returns solution `s` after removing `q` customer nodes randomly.
"""
function randomcustomer!(rng::AbstractRNG, q::Int64, s::Solution)
    D = s.D
    C = s.C
    preremove!(s)
    W = isclose.(C)     # W[iⁿ]: selection weight of customer node C[iⁿ]
    # Step 1: Randomly select customer nodes to remove until q customer nodes have been removed
    n = 0
    while n < q
        iⁿ = sample(rng, eachindex(C), OffsetWeights(W))
        c  = C[iⁿ]
        if isopen(c) continue end
        r  = c.r
        nᵗ = isequal(r.iˢ, c.iⁿ) ? D[c.iᵗ] : C[c.iᵗ]
        nʰ = isequal(r.iᵉ, c.iⁿ) ? D[c.iʰ] : C[c.iʰ]
        removenode!(c, nᵗ, nʰ, r, s)
        n += 1
        W[iⁿ] = 0
    end
    postremove!(s)
    # Step 2: Return solution
    return s
end



"""
    relatedcustomer!(rng::AbstractRNG, q::Int64, s::Solution)

Returns solution `s` after removing `q` customer nodes most 
related to a randomly selected pivot customer node.
"""
function relatedcustomer!(rng::AbstractRNG, q::Int64, s::Solution)
    D = s.D
    C = s.C
    preremove!(s)
    X = fill(-Inf, eachindex(C))   # X[iⁿ]: relatedness of customer node C[iⁿ] with pivot customer node C[iᵒ]
    # Step 1: Randomly select a pivot customer node
    iᵒ= rand(rng, eachindex(C))
    # Step 2: For each customer node, evaluate relatedness to this pivot customer node
    for iⁿ ∈ eachindex(C) X[iⁿ] = relatedness(C[iⁿ], C[iᵒ], s) end
    # Step 3: Remove q most related customer nodes
    n = 0
    while n < q
        iⁿ = argmax(X)
        c  = C[iⁿ]
        r  = c.r
        nᵗ = isequal(r.iˢ, c.iⁿ) ? D[c.iᵗ] : C[c.iᵗ]
        nʰ = isequal(r.iᵉ, c.iⁿ) ? D[c.iʰ] : C[c.iʰ]
        removenode!(c, nᵗ, nʰ, r, s)
        n += 1
        X[iⁿ] = -Inf
    end
    # Step 4: Remove redundant vehicles and routes
    postremove!(s)
    # Step 5: Return solution
    return s
end



"""
    worstcustomer!(rng::AbstractRNG, q::Int64, s::Solution)

Returns solution `s` after removing `q` customer nodes with 
highest removal cost (savings).
"""
function worstcustomer!(rng::AbstractRNG, q::Int64, s::Solution)
    D = s.D
    C = s.C
    preremove!(s)
    V = [v for d ∈ D for v ∈ d.V]
    X = fill(-Inf, eachindex(C))    # X[i]: removal cost of customer node C[i]
    ϕ = ones(Int64, eachindex(V))   # ϕ[j]: binary weight for vehicle V[j]
    # Step 1: Iterate until q customer nodes have been removed
    n = 0
    while n < q
        # Step 1.1: For every closed customer node evaluate removal cost
        zᵒ = f(s)
        for (i,c) ∈ pairs(C)
            if isopen(c) continue end
            r = c.r
            d = s.D[r.iᵈ]
            v = d.V[r.iᵛ]
            j = findfirst(isequal(v), V)
            if iszero(ϕ[j]) continue end
            # Step 1.1.1: Remove closed customer node c between tail node nᵗ and head node nʰ in route r
            nᵗ = isequal(r.iˢ, c.iⁿ) ? D[c.iᵗ] : C[c.iᵗ]
            nʰ = isequal(r.iᵉ, c.iⁿ) ? D[c.iʰ] : C[c.iʰ]
            removenode!(c, nᵗ, nʰ, r, s)
            # Step 1.1.2: Evaluate the removal cost
            z⁻ = f(s) * (1 + rand(rng, Uniform(-0.2, 0.2)))
            Δ  = z⁻ - zᵒ
            X[i] = -Δ
            # Step 1.1.3: Re-insert customer node c between tail node nᵗ and head node nʰ in route r
            insertnode!(c, nᵗ, nʰ, r, s)
        end
        # Step 1.2: Remove the customer node with highest removal cost (savings)
        iⁿ = argmax(X)
        c  = C[iⁿ]
        r  = c.r
        d  = s.D[r.iᵈ]
        v  = d.V[r.iᵛ]
        nᵗ = isequal(r.iˢ, c.iⁿ) ? D[c.iᵗ] : C[c.iᵗ]
        nʰ = isequal(r.iᵉ, c.iⁿ) ? D[c.iʰ] : C[c.iʰ]
        removenode!(c, nᵗ, nʰ, r, s)
        n += 1
        # Step 1.3: Update cost and selection weight vectors
        X[iⁿ] = -Inf
        for (j,v) ∈ pairs(V) ϕ[j] = isequal(r.iᵛ, v.iᵛ) ? 1 : 0 end 
    end
    postremove!(s)
    # Step 2: Return solution
    return s
end



# -------------------------------------------------- ROUTE REMOVAL --------------------------------------------------
"""
    randomroute!(rng::AbstractRNG, q::Int64, s::Solution)

Returns solution `s` after iteratively selecting a random route and 
removing customer nodes from it until at least `q` customer nodes 
are removed.
"""
function randomroute!(rng::AbstractRNG, q::Int64, s::Solution)
    D = s.D
    C = s.C
    preremove!(s)
    R = [r for d ∈ D for v ∈ d.V for r ∈ v.R]
    W = isopt.(R)                   # W[iʳ] : selection weight for route R[iʳ]
    # Step 1: Iteratively select a random route and remove customer nodes from it until at least q customer nodes are removed
    n = 0
    while n < q
        if isone(sum(W)) break end
        iʳ = sample(rng, eachindex(R), Weights(W))
        r  = R[iʳ]
        d  = D[r.iᵈ]
        while true
            if n ≥ q break end
            nᵗ = d
            c  = C[r.iˢ]
            nʰ = isequal(r.iᵉ, c.iⁿ) ? D[c.iʰ] : C[c.iʰ]
            removenode!(c, nᵗ, nʰ, r, s)
            n += 1
            if isequal(nʰ, d) break end
        end
        W[iʳ] = 0
    end
    postremove!(s)
    # Step 2: Return solution
    return s
end



"""
    relatedroute!(rng::AbstractRNG, q::Int64, s::Solution)

Returns solution `s` after removing `q` customer nodes from 
the routes most related to a randomly selected pivot route.
"""
function relatedroute!(rng::AbstractRNG, q::Int64, s::Solution)
    D = s.D
    C = s.C
    preremove!(s)
    R = [r for d ∈ D for v ∈ d.V for r ∈ v.R]
    X = fill(-Inf, eachindex(R))    # X[iʳ]: relatedness of route R[iʳ] with pivot route R[iᵒ]
    W = isopt.(R)                   # W[iʳ] : selection weight for route R[iʳ]
    # Step 1: Randomly select a pivot route
    iᵒ= sample(rng, eachindex(R), Weights(isopt.(R)))  
    # Step 2: For each route, evaluate relatedness to this pivot route
    for iʳ ∈ eachindex(R) X[iʳ] = relatedness(R[iʳ], R[iᵒ], s) end
    # Step 3: Remove at least q customers from most related route to this pivot route
    n = 0
    while n < q
        if isone(sum(W)) break end
        iʳ = argmax(X)
        r  = R[iʳ]
        d  = D[r.iᵈ]
        while true
            if n ≥ q break end
            nᵗ = d
            c  = C[r.iˢ]
            nʰ = isequal(r.iᵉ, c.iⁿ) ? D[c.iʰ] : C[c.iʰ]
            removenode!(c, nᵗ, nʰ, r, s)
            n += 1
            if isequal(nʰ, d) break end
        end 
        X[iʳ] = -Inf
        W[iʳ] = 0
    end
    postremove!(s)
    # Step 4: Return solution
    return s
end



"""
    worstroute!(rng::AbstractRNG, q::Int64, s::Solution)

Returns solution `s` after removing at least `q` customer nodes from low-utilization routes.
"""
function worstroute!(rng::AbstractRNG, q::Int64, s::Solution)
    D = s.D
    C = s.C
    preremove!(s)
    R = [r for d ∈ D for v ∈ d.V for r ∈ v.R]
    X = fill(Inf, eachindex(R))     # X[iʳ] : utilization of route R[iʳ]
    W = isopt.(R)                   # W[iʳ] : selection weight for route R[iʳ]
    # Step 1: Evaluate utilization of each route
    for (iʳ,r) ∈ pairs(R)
        if !isopt(r) continue end
        d = s.D[r.iᵈ]
        v = d.V[r.iᵛ]
        X[iʳ] = r.q/v.qᵛ
    end
    # Step 2: Iteratively select low-utilization route and remove customer nodes from it until at least q customer nodes are removed
    n = 0
    while n < q
        if isone(sum(W)) break end
        iʳ = argmin(X)
        r  = R[iʳ]
        d  = D[r.iᵈ]
        while true
            if n ≥ q break end
            nᵗ = d
            c  = C[r.iˢ]
            nʰ = isequal(r.iᵉ, c.iⁿ) ? D[c.iʰ] : C[c.iʰ]
            removenode!(c, nᵗ, nʰ, r, s)
            n += 1
            if isequal(nʰ, d) break end
        end
        X[iʳ] = Inf
        W[iʳ] = 0
    end
    postremove!(s)
    # Step 3: Return solution
    return s
end    



# -------------------------------------------------- VEHICLE REMOVAL --------------------------------------------------
"""
    randomvehicle!(rng::AbstractRNG, q::Int64, s::Solution)

Returns solution `s` after iteratively selecting a random vehicle and 
removing customer nodes from its routes until at least `q` customer nodes 
are removed.
"""
function randomvehicle!(rng::AbstractRNG, q::Int64, s::Solution)
    D = s.D
    C = s.C
    preremove!(s)
    V = [v for d ∈ D for v ∈ d.V]
    W = ones(Int64, eachindex(V))   # W[iᵛ] : selection weight for vehicle V[iᵛ]
    # Step 1: Iteratively select a random vehicle and remove customer nodes from it until at least q customer nodes are removed
    n = 0
    while n < q
        if isone(sum(W)) break end
        iᵛ = sample(rng, eachindex(V), Weights(W))
        v  = V[iᵛ]
        d  = D[v.iᵈ]
        for r ∈ v.R
            if n ≥ q break end
            if !isopt(r) continue end
            while true
                nᵗ = d
                c  = C[r.iˢ]
                nʰ = isequal(r.iᵉ, c.iⁿ) ? D[c.iʰ] : C[c.iʰ] 
                removenode!(c, nᵗ, nʰ, r, s)
                n += 1
                if isequal(nʰ, d) break end
            end
        end
        W[iᵛ] = 0
    end
    postremove!(s)
    # Step 2: Return solution
    return s
end



"""
    relatedvehicle!(rng::AbstractRNG, q::Int64, s::Solution)

Returns solution `s` after removing `q` customer nodes from 
the routes of the vehicles most related to a randomly selected 
pivot vehicle.
"""
function relatedvehicle!(rng::AbstractRNG, q::Int64, s::Solution)
    D = s.D
    C = s.C
    preremove!(s)
    V = [v for d ∈ D for v ∈ d.V]
    X = fill(-Inf, eachindex(V))    # X[iᵛ]: relatedness of vehicle V[iᵛ] with pivot vehicle V[iᵒ]
    W = ones(Int64, eachindex(V))   # W[iᵛ] : selection weight for vehicle V[iᵛ]
    # Step 1: Select a random closed depot node
    iᵒ= sample(rng, eachindex(V), Weights(isopt.(V)))
    # Step 2: For each vehicle, evaluate relatedness to this pivot vehicle
    for iᵛ ∈ eachindex(V) X[iᵛ] = relatedness(V[iᵛ], V[iᵒ], s) end
    # Step 3: Remove at least q customers from the most related vehicles to this pivot vehicle
    n = 0
    while n < q
        if isone(sum(W)) break end
        iᵛ = argmax(X)
        v  = V[iᵛ]
        d  = D[v.iᵈ] 
        for r ∈ v.R
            if n ≥ q break end
            if !isopt(r) continue end
            while true
                nᵗ = d
                c  = C[r.iˢ]
                nʰ = isequal(r.iᵉ, c.iⁿ) ? D[c.iʰ] : C[c.iʰ]
                removenode!(c, nᵗ, nʰ, r, s)
                n += 1
                if isequal(nʰ, d) break end
            end
        end
        X[iᵛ] = -Inf
        W[iᵛ] = 0
    end
    postremove!(s)
    # Step 4: Return solution
    return s
end



"""
    worstvehicle!(rng::AbstractRNG, q::Int64, s::Solution)

Returns solution `s` after removing at least `q` customer 
nodes from routes of low-utilization vehicles.
"""
function worstvehicle!(rng::AbstractRNG, q::Int64, s::Solution)
    D = s.D
    C = s.C
    preremove!(s)
    V = [v for d ∈ D for v ∈ d.V]
    X = fill(Inf, eachindex(V))     # X[iʳ] : utilization of vehicle V[iᵛ]
    W = ones(Int64, eachindex(V))   # W[iᵛ] : selection weight for vehicle V[iᵛ]
    # Step 1: Evaluate utilization for each vehicle
    for (iᵛ,v) ∈ pairs(V) X[iᵛ] = v.q/(length(v.R) * v.qᵛ) end
    # Step 2: Iteratively select low-utilization route and remove customer nodes from it until at least q customer nodes are removed
    n = 0
    while n < q
        if isone(sum(W)) break end
        iᵛ = argmin(X)
        v  = V[iᵛ]
        d  = D[v.iᵈ]
        for r ∈ v.R
            if n ≥ q break end
            if !isopt(r) continue end
            while true
                nᵗ = d
                c  = C[r.iˢ]
                nʰ = isequal(r.iᵉ, c.iⁿ) ? D[c.iʰ] : C[c.iʰ]
                removenode!(c, nᵗ, nʰ, r, s)
                n += 1
                if isequal(nʰ, d) break end
            end
        end
        X[iᵛ] = Inf
        W[iᵛ] = 0
    end
    postremove!(s)
    # Step 3: Return solution
    return s
end



# -------------------------------------------------- DEPOT REMOVAL --------------------------------------------------
"""
    randomdepot!(rng::AbstractRNG, q::Int64, s::Solution)

Returns solution `s` after iteratively selecting a random depot node and 
removing customer nodes from its routes until at least `q` customer nodes 
are removed.
"""
function randomdepot!(rng::AbstractRNG, q::Int64, s::Solution)
    D = s.D
    C = s.C
    preremove!(s)
    W = ones(Int64, eachindex(D))   # W[iᵈ] : selection weight for depot node D[iᵈ]
    # Step 1: Iteratively select a random depot and remove customer nodes from it until at least q customer nodes are removed
    n = 0
    while n < q
        if isone(sum(W)) break end
        iᵈ = sample(rng, eachindex(D), Weights(W))
        d  = D[iᵈ]
        for v ∈ d.V
            if n ≥ q break end
            for r ∈ v.R
                if !isopt(r) continue end
                while true
                    nᵗ = d
                    c  = C[r.iˢ]
                    nʰ = isequal(r.iᵉ, c.iⁿ) ? D[c.iʰ] : C[c.iʰ]
                    removenode!(c, nᵗ, nʰ, r, s)
                    n += 1
                    if isequal(nʰ, d) break end
                end
            end
        end
        W[iᵈ] = 0
    end
    postremove!(s)
    # Step 2: Return solution
    return s
end



"""
    relateddepot!(rng::AbstractRNG, q::Int64, s::Solution)

Returns solution `s` after removing `q` customer nodes most 
related to a randomly selected pivot depot node.
"""
function relateddepot!(rng::AbstractRNG, q::Int64, s::Solution)
    D = s.D
    C = s.C
    preremove!(s)
    X = fill(-Inf, eachindex(C))   # X[iᵛ]: relatedness of customer node C[iⁿ] with pivot depot node D[iᵒ]
    # Step 1: Select a random closed depot node
    iᵒ= sample(rng, eachindex(D), Weights(isclose.(D)))
    # Step 2: Evaluate relatedness of this depot node to every customer node
    for iⁿ ∈ eachindex(C) X[iⁿ] = relatedness(C[iⁿ], D[iᵒ], s) end
    # Step 3: Remove at least q customer nodes most related to this pivot depot node
    n = 0
    while n < q 
        iⁿ = argmax(X)
        c  = C[iⁿ]
        r  = c.r
        nᵗ = isequal(r.iˢ, c.iⁿ) ? D[c.iᵗ] : C[c.iᵗ]
        nʰ = isequal(r.iᵉ, c.iⁿ) ? D[c.iʰ] : C[c.iʰ] 
        removenode!(c, nᵗ, nʰ, r, s)
        n += 1
        X[iⁿ] = -Inf
    end
    postremove!(s)
    # Step 4: Return solution
    return s
end



"""
    worstdepot!(rng::AbstractRNG, q::Int64, s::Solution)

Returns solution `s` after removing at least `q` customer 
nodes from routes of low-utilization depot nodes.
"""
function worstdepot!(rng::AbstractRNG, q::Int64, s::Solution)
    D = s.D
    C = s.C
    preremove!(s)
    X = fill(Inf, eachindex(D))     # X[iᵈ] : utilization of vehicle D[iᵈ]
    W = ones(Int64, eachindex(D))   # W[iᵈ] : selection weight for vehicle D[iᵈ]
    # Step 1: Evaluate utilization for each depot
    for (iᵈ,d) ∈ pairs(D) X[iᵈ] = d.q/d.qᵈ end
    # Step 2: Iteratively select low-utilization route and remove customer nodes from it until at least q customer nodes are removed
    n = 0
    while n < q
        if isone(sum(W)) break end
        iᵈ = argmin(X)
        d  = D[iᵈ]
        for v ∈ d.V
            if n ≥ q break end
            for r ∈ v.R
                if !isopt(r) continue end
                while true
                    nᵗ = d
                    c  = C[r.iˢ]
                    nʰ = isequal(r.iᵉ, c.iⁿ) ? D[c.iʰ] : C[c.iʰ]
                    removenode!(c, nᵗ, nʰ, r, s)
                    n += 1
                    if isequal(nʰ, d) break end
                end
            end
        end
        X[iᵈ] = Inf
        W[iᵈ] = 0
    end
    postremove!(s)
    # Step 3: Return solution
    return s
end