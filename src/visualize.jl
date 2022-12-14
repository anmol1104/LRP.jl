"""
    visualize(instance; root=joinpath(dirname(@__DIR__), "instances"), backend=gr)

Plots `instance`.
Uses given `backend` to plot (defaults to `gr`).
"""
function visualize(instance; root=joinpath(dirname(@__DIR__), "instances"), backend=gr)
    backend()
    D, C, _ = build(instance; root=root)
    fig = plot(legend=:none)
    K = length(D)+length(C)
    X = zeros(Float64, K)
    Y = zeros(Float64, K)
    M₁= fill("color", K)
    M₂= zeros(Int64, K)
    M₃= fill(:shape, K)
    # Depot nodes
    for (k,d) ∈ pairs(D)
        X[k] = d.x
        Y[k] = d.y
        M₁[k] = "#b4464b"
        M₂[k] = 6
        M₃[k] = :rect
    end
    # Customer nodes
    for (k,c) ∈ pairs(C)
        X[k] = c.x
        Y[k] = c.y
        M₁[k] = "#d1e0ec"
        M₂[k] = 5
        M₃[k] = :circle
    end
    scatter!(X, Y, color=M₁, markersize=M₂, markershape=M₃, markerstrokewidth=0)
    return fig
end
"""
    visualize(s::Solution; backend=gr)

Plots solution `s` depicting routes and unvisited nodes (if any).
Uses given `backend` to plot (defaults to `gr`).
"""
function visualize(s::Solution; backend=gr)
    backend()
    D = s.D
    C = s.C
    fig = plot(legend=:none)
    # Operational nodes: open depot nodes and closed customer nodes
    for Z ∈ vectorize(s)
        K = length(Z)
        X = zeros(Float64, K)
        Y = zeros(Float64, K)
        M₁= fill("color", K)
        M₂= zeros(Int64, K)
        M₃= fill(:shape, K)
        for k ∈ 1:K
            i = Z[k]
            n = i ≤ length(D) ? D[i] : C[i]
            X[k] = n.x
            Y[k] = n.y
            if isdepot(n) 
                M₁[k] = "#82b446"
                M₂[k] = 6
                M₃[k] = :rect
            else 
                M₁[k] = "#4682b4"
                M₂[k] = 5
                M₃[k] = :circle
            end
        end
        scatter!(X, Y, color=M₁, markersize=M₂, markershape=M₃, markerstrokewidth=0)
        plot!(X, Y, color="#23415a")
    end
    # Non-operational nodes: closed depot nodes and open customer nodes
    Z = Int64[] 
    for d ∈ D if !isopt(d) push!(Z, d.iⁿ) end end
    for c ∈ C if isopen(c) push!(Z, c.iⁿ) end end
    K = length(Z)
    X = zeros(Float64, K)
    Y = zeros(Float64, K)
    M₁= fill("color", K)
    M₂= zeros(Int64, K)
    M₃= fill(:shape, K)
    for k ∈ 1:K
        i = Z[k]
        n = i ≤ length(D) ? D[i] : C[i]
        X[k] = n.x
        Y[k] = n.y
        if isdepot(n) 
            M₁[k] = "#b4464b"
            M₂[k] = 6
            M₃[k] = :rect
        else 
            M₁[k] = "#d1e0ec"
            M₂[k] = 5
            M₃[k] = :circle
        end
    end
    scatter!(X, Y, color=M₁, markersize=M₂, markershape=M₃, markerstrokewidth=0)
     # Annotation
     x = min(minimum(getproperty.(C, :x)), minimum(getproperty.(D, :x)))
     y = max(maximum(getproperty.(C, :y)), maximum(getproperty.(D, :y)))
     annotate!(x, y, text("f(s): $(Int64(round(f(s))))", :left, 10))
    return fig
end

"""
    vectorize(s::Solution)

Returns solution as a sequence of nodes in the order of visits.
"""
function vectorize(s::Solution)
    D = s.D
    C = s.C
    Z = [Int64[] for _ ∈ D]
    for d ∈ D
        iⁿ = d.iⁿ
        if !isopt(d) continue end
        for v ∈ d.V
            if !isopt(v) continue end
            for r ∈ v.R
                if !isopt(r) continue end
                cˢ, cᵉ = C[r.iˢ], C[r.iᵉ] 
                push!(Z[iⁿ], d.iⁿ)
                c = cˢ
                while true
                    push!(Z[iⁿ], c.iⁿ)
                    if isequal(c, cᵉ) break end
                    c = C[c.iʰ]
                end
            end
        end
        push!(Z[iⁿ], d.iⁿ)
    end
    return Z
end

"""
    animate(S::Vector{Solution}; fps=10)

Iteratively plots solutions in `S` to develop a gif at given `fps`.
"""
function animate(S::Vector{Solution}; fps=10)
    K = 0:(length(S)-1)
    figs = Vector(undef, length(S))
    for (k, s) ∈ enumerate(S)
        fig = visualize(s, backend=gr)
        plot!(title="Iteration #$(K[k])", titlefontsize=11)
        figs[k] = fig
    end
    anim = @animate for fig in figs
        plot(fig)
    end
    gif(anim, fps=fps, show_msg=false)
end

"""
    pltcnv(S::Vector{Solution}; penalty=true, backend=gr)

Plots objective function values for solutions in `S` accounting 
for penalty by default.
Uses given `backend` to plot (defaults to `gr`).
"""
function pltcnv(S::Vector{Solution}; penalty=true, backend=gr)
    backend()
    Y = [f(s; penalty=penalty) for s ∈ S]
    X = 0:(length(S)-1)
    fig = plot(legend=:none)
    plot!(X,Y, xlabel="iterations", ylabel="objective function value")
    return fig
end