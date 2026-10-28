# =============================================================================
# The view graph and the tracks of a pure-rotation sequence
# =============================================================================
#
# The frames are the vertices of a Graphs.jl graph, the verified frame pairs its
# edges, each carrying its relative rotation and inlier count; the tracks are the
# connected sets of (frame, keypoint) observations through every pair's inlier
# matches, found with DataStructures.jl's union-find (`IntDisjointSets`).
# =============================================================================

"""
    ViewGraph{K}

The view graph of a sequence: `graph` (a `Graphs.SimpleGraph` on the frames,
vertex `v` the frame `frames[v]`), and per verified pair `(i, j)` (frame keys,
`i < j` in `frames` order) its relative rotation `rotations[(i, j)]` (`f_j =
R_ij·f_i`) and inlier count `inliers[(i, j)]`.
"""
struct ViewGraph{K}
    frames::Vector{K}
    graph::Graphs.SimpleGraph{Int}
    rotations::Dict{Tuple{K, K}, SMatrix{3, 3, Float64, 9}}
    inliers::Dict{Tuple{K, K}, Int}
end

"""
    ViewGraph(frames, pairs) -> ViewGraph

The view graph of `frames` from the verified `pairs`: an `AbstractDict` keyed by
frame pairs `(i, j)` whose values have the fields `rotation` (`R_ij`) and
`inliers` (the count). A sequence whose graph is not connected is an
`ArgumentError` naming its components (`Graphs.connected_components`): its
frames have no common frame.
"""
function ViewGraph(frames::AbstractVector{K}, pairs::AbstractDict{<:Tuple{K, K}}) where {K}
    fr = collect(frames); vid = Dict(k => v for (v, k) in enumerate(fr))
    g = Graphs.SimpleGraph(length(fr))
    rot = Dict{Tuple{K, K}, SMatrix{3, 3, Float64, 9}}(); inl = Dict{Tuple{K, K}, Int}()
    for ((i, j), e) in pairs
        (haskey(vid, i) && haskey(vid, j) && i != j) || throw(ArgumentError("ViewGraph: the pair $((i, j)) names an unknown frame"))
        Graphs.add_edge!(g, vid[i], vid[j])
        rot[(i, j)] = SMatrix{3, 3, Float64, 9}(e.rotation); inl[(i, j)] = Int(e.inliers)
    end
    comps = Graphs.connected_components(g)
    length(comps) == 1 || throw(ArgumentError("ViewGraph: the sequence is not connected; its components are " *
                                              join(["[" * join(string.(fr[c]), ", ") * "]" for c in comps], ", ")))
    return ViewGraph{K}(fr, g, rot, inl)
end

"""
    chain_tracks(matches) -> (tracks, n_dropped)

The tracks of a sequence: the connected sets of observations `(frame, keypoint)`
through every pair's inlier matches, `matches` an `AbstractDict` keyed by frame
pairs `(i, j)` whose value is a vector of keypoint index pairs `(a, b)` (keypoint
`a` of frame `i` ↔ keypoint `b` of frame `j`). Union-find over the observations
(DataStructures.jl's `IntDisjointSets`). A track that holds two different
keypoints of one frame is inconsistent (a wrong match chained through the
graph) and is DROPPED whole; their count is `n_dropped`. Every track returned
has observations in at least two frames, sorted by frame then keypoint.
"""
function chain_tracks(matches::AbstractDict{<:Tuple{K, K}}) where {K}
    obs = Dict{Tuple{K, Int}, Int}(); keyof = Tuple{K, Int}[]
    id(o) = get!(obs, o) do
        push!(keyof, o); length(keyof)
    end
    for ((i, j), ms) in matches, (a, b) in ms
        id((i, a)); id((j, b))
    end
    uf = DataStructures.IntDisjointSets(length(keyof))
    for ((i, j), ms) in matches, (a, b) in ms
        union!(uf, obs[(i, a)], obs[(j, b)])
    end
    groups = Dict{Int, Vector{Tuple{K, Int}}}()
    for (n, o) in enumerate(keyof)
        push!(get!(() -> Tuple{K, Int}[], groups, DataStructures.find_root!(uf, n)), o)
    end
    out = Vector{Vector{Tuple{K, Int}}}(); dropped = 0
    for g in Base.values(groups)
        sort!(g)
        fs = first.(g)
        if length(unique(fs)) < length(fs)
            dropped += 1
        elseif length(fs) >= 2
            push!(out, g)
        end
    end
    sort!(out; by = first)
    return out, dropped
end
