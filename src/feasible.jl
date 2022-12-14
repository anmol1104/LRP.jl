"""
    isfeasible(s::Solution)

Returns true if 
node service, node flow, and sub-tour elimination constraints; 
depot and vehicle capacity constriants; 
vehicle range and working-hours constraints; and
time-window constraints
are not violated.
"""
function isfeasible(s::Solution)
    X = zeros(Int64, eachindex(s.C))
    for d ∈ s.D
        qᵈ = 0
        nᵈ = 0.
        for v ∈ d.V
            for r ∈ v.R
                if !isopt(r) continue end
                qᵛ = r.q
                lᵛ = r.l
                if qᵛ > v.q return false end                                # Vehicle capacity constraint
                if lᵛ > v.l return false end                                # Vehicle range constraint
                qᵈ += r.q
                nᵈ += r.n
                cˢ = s.C[r.iˢ]
                cᵉ = s.C[r.iᵉ]
                cᵒ = cˢ
                while true
                    if cᵒ.tᵃ > cᵒ.tˡ return false end                       # Time-window constraint
                    X[cᵒ.iⁿ] += 1
                    if isequal(cᵒ, cᵉ) break end
                    cᵒ = s.C[cᵒ.iʰ]
                end
            end
            if d.tˢ > v.tˢ return false end                                 # Working-hours constraint (start time)
            if v.tᵉ > d.tᵉ return false end                                 # Working-hours constraint (end time)
            if v.tᵉ - v.tˢ > v.τʷ return false end                          # Working-hours constraint (duration)
        end
        pᵈ = nᵈ/length(s.C)
        if (isone(d.φ) && !isopt(d)) return false end                       # Depot use constraint
        if qᵈ > d.q return false end                                        # Depot capacity constraint
        if !(d.pˡ ≤ pᵈ ≤ d.pᵘ) return false end                             # Depot customer share constraint
    end
    if any(!isone, X) return false end                                      # Node service, customer flow, and sub-tour elimination constrinat
    return true
end