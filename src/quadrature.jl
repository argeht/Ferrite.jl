include("quadrature_tables/gaussquad_tri_table.jl")
include("quadrature_tables/gaussquad_tet_table.jl")

import Base.Cartesian: @nloops, @nref, @ntuple, @nexprs

"""
A `QuadratureRule` is a way to approximate an integral on a domain by a weighted sum of
function values at specific points:

``\\int\\limits_\\Omega f(\\mathbf{x}) d \\Omega \\approx \\sum\\limits_{q = 1}^{n_q} f(\\mathbf{x}_q) w_q``

The quadrature rule consists of ``n_q`` points in space ``\\mathbf{x}_q`` with corresponding weights ``w_q``.

 In `JuaFEM`, the `QuadratureRule` type is mostly used as one of the components to create a [`FEValues`]({ref}) object.

**Constructors:**

    QuadratureRule([quad_rule_type::Symbol], ::Dim{dim}, ref_shape::Shape, order::Int)

**Arguments:**

* `quad_rule_type`: The type of the quadrature rule. Currently only `:legendre` or `:lobatto` types are supported where
`:lobatto` is only supported for `RefCube`. If the quadrature rule type is left out, `:legendre` is used.
* `::Dim{dim}` the dimension of the reference shape
* `ref_shape`: the reference shape
* `order`: the order of the quadrature rule

**Common methods:**

* [`points`]({ref}) : the points of the quadrature rule
* [`weights`]({ref}) : the weights of the quadrature rule

**Example:**

```julia
julia> QuadratureRule(Dim{2}, RefTetrahedron(), 1)
JuAFEM.QuadratureRule{2,Float64}([0.5],[[0.33333333333333,0.33333333333333]])

julia> QuadratureRule(:lobatto, Dim{1}, RefCube(), 2)
JuAFEM.QuadratureRule{1,Float64}([1.0,1.0],[[-1.0],[1.0]])
```
"""
type QuadratureRule{dim, T}
    weights::Vector{T}
    points::Vector{Vec{dim, T}}
end

"""

The weights of the quadrature rule.

    weights(qr::QuadratureRule) = qr.weights

**Arguments:**

* `qr`: the quadrature rule

**Example:**

```julia
julia> weights(QuadratureRule(:legendre, Dim{2}, RefTetrahedron(), 2))
3-element Array{Float64,1}:
 0.166667
 0.166667
 0.166667
```

"""
weights(qr::QuadratureRule) = qr.weights


"""
The points of the quadrature rule.

    points(qr::QuadratureRule)

**Arguments:**

* `qr`: the quadrature rule

**Example:**

```julia
julia> points(QuadratureRule(:legendre, Dim{2}, RefTetrahedron(), 2))
3-element Array{ContMechTensors.Tensor{1,2,Float64,2},1}:
 [0.166667,0.166667]
 [0.166667,0.666667]
 [0.666667,0.166667]
```
"""
points(qr::QuadratureRule) = qr.points

QuadratureRule{dim}(::Type{Dim{dim}}, shape::AbstractRefShape, order::Int) = QuadratureRule(:legendre, Dim{dim}, shape, order)

# Generate Gauss quadrature rules on cubes by doing an outer product
# over all dimensions

for dim in (1,2,3)
    @eval begin
        function QuadratureRule(quad_type::Symbol, ::Type{Dim{$dim}}, ::RefCube, order::Int)
            if quad_type == :legendre
                p, w = gausslegendre(order)
            elseif quad_type == :lobatto
                p, w = gausslobatto(order)
            else
                throw(ArgumentError("unsupported quadrature rule"))
            end
            weights = Vector{Float64}(order^($dim))
            points = Vector{Vec{$dim, Float64}}(order^($dim))
            count = 1
            @nloops $dim i j->(1:order) begin
                t = @ntuple $dim q-> p[$(symbol("i"*"_q"))]
                points[count] = Vec{$dim, Float64}(t)
                weight = 1.0
                @nexprs $dim j->(weight *= w[i_{j}])
                weights[count] = weight
                count += 1
            end
            return QuadratureRule(weights, points)
        end
    end
end

for dim in (2, 3)
    @eval begin
        function QuadratureRule(quad_type::Symbol, ::Type{Dim{$dim}}, ::RefTetrahedron, order::Int)
            if $dim == 2 && quad_type == :legendre
                data = _get_gauss_tridata(order)
            elseif $dim == 3 && quad_type == :legendre
                data = _get_gauss_tetdata(order)
            else
                throw(ArgumentError("unsupported quadrature rule"))
            end
            n_points = size(data,1)
            weights = Array(Float64, n_points)
            points = Array(Vec{$dim, Float64}, n_points)

            for p in 1:size(data, 1)
                points[p] = Vec{$dim, Float64}(@ntuple $dim i -> data[p, i])
            end
            weights = data[:, $dim + 1]
            QuadratureRule(weights, points)
        end
    end
end
