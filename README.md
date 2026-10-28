# PanoramaStitching.jl

The panorama of a camera that only rotated — a sweep of a distant scene — through a calibrated lens of any field of view,
fisheyes past 90° included, on the [VisualGeometryToolkit](https://github.com/VisualGeometryToolkit) stack:

- `register_rotations(frames, camera; …)` — the rotations of the frames: ASIFT keypoints described by DeDoDe and matched by
  LoMa (VisualGeometryToolkitFeatures), the rotation of every frame pair by RANSAC on bearings
  (VisualGeometryToolkitEstimation's `find_rotation`), the view graph's robust rotation averaging
  (`fit_rotation_averaging`), the tracks, and the bundle of the rotations and the track directions (NLLSsolver, the pixel
  reprojection error through the fixed camera).
- `sample_cells(frames, saturated, rotations, camera; …)` — a near-equal-area grid of world cells sampled in every frame.
- `render_panorama(cells, values, ok, gains; up)` — the equirectangular panorama of per-frame cell values, composited in capture
  order.

MIT licence.
