using Documenter, PanoramaStitching

# No remote until the owner publishes the repository: `remotes = nothing` (no source links).
makedocs(; sitename = "PanoramaStitching.jl", modules = [PanoramaStitching], pages = ["Home" => "index.md"], remotes = nothing, format = Documenter.HTML(; edit_link = nothing))
