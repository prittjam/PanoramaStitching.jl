# =============================================================================
# The equirectangular panorama of per-frame cell values
# =============================================================================

"""
    true_up(up_pitch, up_roll) -> SVector{3}

The true up direction in the common (first-frame) frame: `Rz(roll)·(0, −cos p, −sin p)`,
`p` the first frame's pitch-down against the true horizon and `roll` its roll, in
degrees.
"""
function true_up(pitch::Real, roll::Real)
    p, r = deg2rad(pitch), deg2rad(roll)
    u0 = SVector(0.0, -cos(p), -sin(p))
    return SVector(u0[1] * cos(r) - u0[2] * sin(r), u0[1] * sin(r) + u0[2] * cos(r), u0[3])
end

"""
    up_frame(up_pitch, up_roll) -> SMatrix{3,3}

`R` with `d = R·d_true`: the true-up frame (its −y the [`true_up`](@ref)
direction, its forward the common frame's forward projected onto the horizontal).
"""
function up_frame(pitch::Real, roll::Real)
    u = normalize(true_up(pitch, roll)); z = SVector(0.0, 0.0, 1.0)
    zt = normalize(z - dot(z, u) * u); yt = -u
    return hcat(cross(yt, zt), yt, zt)
end

# The index of the world cell of the grid (`world_cells`) holding (lat, lon), degrees.
function _cell_lookup(cells::AbstractMatrix)
    lo = cells[:, 1]; bands = sort(unique(lo)); cell = bands[2] - bands[1]
    start = [searchsortedfirst(lo, b - 1.0e-9) for b in bands]; nb = diff(vcat(start, size(cells, 1) + 1))
    return function (lat, lon)
        b = clamp(floor(Int, (lat - bands[1]) / cell), 0, length(bands) - 1) + 1
        return start[b] + clamp(floor(Int, (lon + 180) / (360 / nb[b])), 0, nb[b] - 1)
    end
end

"""
    render_panorama(cells, values, ok, gains; up = I) -> (image, extent, composite)

The equirectangular panorama of per-frame cell values, composited in capture order:
each cell takes the value of the LAST frame `k` that saw it (`ok[k, i]`), divided by
that frame's gain `exp(gains[k, c])` (`values` is K × N × C linear, `gains` K × C in
ln; the frames' own corrections, a vignetting for one, are the caller's, applied to
`values`). The raster is in the frame `up` (`d = up·d_up`: [`up_frame`](@ref) for a
true-up panorama), its rows the elevation from the top, its columns the azimuth, one
pixel per cell size, the nearest world cell (Core's `Equirectangular` for both
directions), spanning the cells seen plus one cell; NaN where no frame saw the cell.
`extent` is `(lon₀, lon₁, lat₀, lat₁)` in degrees, `composite` the N × C per-cell
values.
"""
function render_panorama(cells::AbstractMatrix, values::AbstractArray{<:Real, 3}, ok::AbstractMatrix{Bool}, gains::AbstractMatrix{<:Real};
                         up::AbstractMatrix = SMatrix{3, 3}(1.0I))
    K, N, C = size(values)
    size(ok) == (K, N) && size(gains) == (K, C) && size(cells, 1) == N || throw(DimensionMismatch("render_panorama: cells, values, ok and gains disagree"))
    R = SMatrix{3, 3, Float64, 9}(up); E = VgtkCore.Equirectangular()
    cell = cells[1, 2] - cells[1, 1]
    seen = vec(any(ok; dims = 1))
    composite = fill(NaN, N, C)
    for i in findall(seen)
        k = findlast(view(ok, :, i))
        for c in 1:C
            composite[i, c] = values[k, i, c] / exp(gains[k, c])
        end
    end
    lat, lon = cell_centres(cells)
    pt = [VgtkCore.project(E, R' * world_direction(a, b)) for (a, b) in zip(lat[seen], lon[seen])]
    lat_rng = (minimum(p -> rad2deg(p[2]), pt) - cell, maximum(p -> rad2deg(p[2]), pt) + cell)
    lon_rng = (minimum(p -> rad2deg(p[1]), pt) - cell, maximum(p -> rad2deg(p[1]), pt) + cell)
    lats = collect((lat_rng[2] - cell / 2):(-cell):lat_rng[1]); lons = collect((lon_rng[1] + cell / 2):cell:lon_rng[2])
    lats = lats[lats .> lat_rng[1]]; lons = lons[lons .< lon_rng[2]]
    lookup = _cell_lookup(cells)
    idx = [(p = VgtkCore.project(E, R * world_direction(la, lo)); lookup(rad2deg(p[2]), rad2deg(p[1]))) for la in lats, lo in lons]
    image = cat([composite[idx, c] for c in 1:C]...; dims = 3)
    return image, (lons[1] - cell / 2, lons[end] + cell / 2, lats[end] - cell / 2, lats[1] + cell / 2), composite
end
