
##################
##### Meshes #####
##################

"""
    colors(mesh::PGP.Mesh)

Extract the colors properties from a given mesh.

# Arguments
- `mesh::PGP.Mesh`: The mesh object from which to extract material properties.

# Returns
- A dictionary containing the material properties of the mesh.

# Examples
```jldoctest

julia> using PlantGeomPrimitives;

julia> import ColorTypes: RGB;

julia> r = Rectangle();

julia> add_property!(r, :colors, RGB(1.0, 0.0, 0.0));

julia> colors(r);
```
"""
function colors(mesh::PGP.Mesh)
    return PGP.properties(mesh)[:colors]
end

# Basic rendering of a triangular mesh that is already in the right format
function render(
    m::GeometryBasics.Mesh;
    color = :green,
    normals::Bool = false,
    wireframe::Bool = false,
    axes::Bool = true,
    size = (1920, 1080),
    kwargs...,
)
    fig = Makie.Figure(size = size)
    lscene = Makie.LScene(fig[1, 1], show_axis = axes)
    Makie.cam3d!(lscene; clipping_mode = :adaptive)
    Makie.mesh!(lscene, m, color = color; kwargs...)
    scene_additions!(m, normals, wireframe)
    fig
end
function render!(
    m::GeometryBasics.Mesh;
    color = :green,
    normals::Bool = false,
    wireframe::Bool = false,
    kwargs...,
)
    Makie.mesh!(m, color = color; kwargs...)
    scene_additions!(m, normals, wireframe)
end

"""
    render(mesh::Mesh; normals::Bool = false, wireframe::Bool = false, kwargs...)

Render a `Mesh` object. This will create a new visualization (see
Documentation for details). `normals = true` will draw arrows in the direction
of the normal vector for each triangle in the mesh, `wireframe = true` will draw
the edges of each triangle with black lines. Keyword arguments are passed to
`Makie.mesh()`. The actual color of each triangle depends on the illumination of the scene
but it is possible to turn this off by passing `shading = false`. This will use the exact
colors specified in the `Scene` object.
"""
function render(mesh::PGP.Mesh; normals::Bool = false, wireframe::Bool = false, kwargs...)
    render(
        PGP.GLMesh(mesh);
        color = repeat(colors(mesh), inner = 3),
        normals = normals,
        wireframe = wireframe,
        kwargs...,
    )
end


#################################
##### Sources & grid cloner #####
#################################

"""
    render!(source::Source{G, A, nw}; n = 20, alpha = 0.2, point = false,
            scale = 0.2)

Add a mesh representing the light source to a 3D scene (if `point = false`) or
a series of points representing the center of the light sources (if
`point = true`). When `point = false`, for each type of light source a
triangular mesh will be created, where `n` is the number of triangles (see
documentation of geometric primitives for details) and `alpha` is the
transparency to be used for each triangle. When `point = true`, only the center
of the light source is rendered along with the normal vector at that point
(representative of the direction at which rays are generated). In the current
version, `point = true` is only possible for directional light sources.
"""
function render!(
    sources::Vector{PRT.Source{G,A,nw}};
    n = 20,
    alpha = 0.2,
    scale = 0.2,
) where {G<:PRT.Directional,A<:PRT.FixedSource,nw}
    FT = eltype(sources[1].geom.xmin)
    # Compute point and arrow for each light source
    temp = compute_dir_p.(sources)
    origins, norms = Tuple(getindex.(temp, i) for i = 1:2)
    # Render the points and scaled normal vectors
    Makie.scatter!(origins)
    Makie.linesegments!(norms)

end

# Compute a point to represent a directional light source
function compute_dir_p(s)
    # Point in the center of the AABB
    p = PGP.Vec((s.geom.xmin + s.geom.xmax) / 2, (s.geom.ymin + s.geom.ymax) / 2, s.geom.zmax)
    # Normal vector
    n = s.angle.dir
    # Scaling
    Δx = s.geom.xmax - s.geom.xmin
    Δy = s.geom.ymax - s.geom.ymin
    s = max(Δx, Δy)
    # Possible origin of source
    point = p .- n .* s
    # Arrow
    arrow = point => point .+ n .* s ./ 5
    # Return the point and arrow
    return point, arrow
end


function render!(
    sources::PRT.Source{G,A,nw};
    kwargs...,
) where {G<:PRT.Directional,A<:PRT.FixedSource,nw}
    render!([sources]; kwargs...)
end

"""
    render!(grid::GridCloner; alpha = 0.2)

Add a mesh representing the bounding boxes of the grid cloner to a 3D scene,
where `alpha` represents the transparency of each box.
"""
function render!(grid::PRT.GridCloner; alpha = 0.2)
    leaf_nodes = filter(x -> x.leaf, grid.nodes.data)
    AABBs = getfield.(leaf_nodes, :box)
    mesh = PGP.Mesh([PGP.BBox(box.min, box.max) for box in AABBs])
    render!(PGP.GLMesh(mesh), color = CT.RGBA(0.0, 0.0, 0.0, alpha), transparency = true)
end

#######################
##### Save output #####
#######################

"""
    export_scene(;scene, filename, kwargs...)

Export a screenshot of the current visualization (stored as `scene` as output of
a call to `render`) as a PNG file store in the path given by `filename`
(including `.png` extension). Keyword arguments will be passed along to the
corresponding `save` method from Makie (see VPL documentation for details).
"""
function export_scene(; scene, filename, kwargs...)
    FileIO.save(filename, scene; kwargs...)
end
