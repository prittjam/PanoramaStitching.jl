"""
    PanoramaStitching

The panorama of a camera that only rotated (a sweep of a distant scene), seen
through a calibrated lens of any field of view: the rotations of its frames
(`register_rotations` — features, pairwise rotations, the view graph's rotation
averaging, the tracks and the rotation and direction bundle), the world cells
sampled in every frame (`sample_cells`), and the equirectangular panorama of
per-frame values composited in capture order (`render_panorama`).

Built on the VisualGeometryToolkit stack: VisualGeometryToolkitFeatures' ASIFT
detector and LoMa descriptor and matcher, VisualGeometryToolkitEstimation's
`find_rotation` and `fit_rotation_averaging`, VisualGeometryToolkitCore's
cameras, rotation charts and `Equirectangular` projection; Graphs.jl,
DataStructures.jl and NLLSsolver.jl.
"""
module PanoramaStitching

using LinearAlgebra: LinearAlgebra, I, norm, normalize, dot, cross
using Statistics: Statistics, quantile
using Random: Random, AbstractRNG, Xoshiro
using Static: static
using StaticArrays: SVector, SMatrix
using Rotations: RotMatrix
import Graphs
import DataStructures
import NLLSsolver
import VisualGeometryToolkitCore as VgtkCore
import VisualGeometryToolkitEstimation as VgtkEstimation
import VisualGeometryToolkitFeatures as VgtkFeatures

export register_rotations, Registration
export ViewGraph, chain_tracks, refine_rotations, RotationBundleMetadata
export world_cells, world_direction, CellSamples, sample_cells
export true_up, up_frame, render_panorama
public cell_centres, FrameFeatures, detect_features, pair_bearings, LOMA_SIZE

include("view_graph.jl")
include("rotation_bundle.jl")
include("features.jl")
include("registration.jl")
include("cells.jl")
include("panorama.jl")

end # module PanoramaStitching
