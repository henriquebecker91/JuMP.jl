#  Copyright 2017, Iain Dunning, Joey Huchette, Miles Lubin, and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.
#############################################################################
# JuMP
# An algebraic modeling language for Julia
# See http://github.com/jump-dev/JuMP.jl
#############################################################################
# test/variable.jl
# Testing for VariableRef
#############################################################################

using JuMP

import LinearAlgebra: Symmetric
using Test

include("utilities.jl")
@static if !(:JuMPExtension in names(Main))
    include("JuMPExtension.jl")
end

function test_variable_name(variable, name)
    @test name == @inferred JuMP.name(variable)
    @test variable == JuMP.variable_by_name(JuMP.owner_model(variable), name)
end

# Slices three-dimensional DenseAxisArray x[I,J,K]
# I,J,K can be singletons, ranges, colons, etc.
function sliceof(VariableRefType, x, I, J, K)
    y = Array{VariableRefType}(undef, length(I), length(J), length(K))

    ii = 1
    jj = 1
    kk = 1
    for i in I
        for j in J
            for k in K
                y[ii,jj,kk] = x[i,j,k]
                kk += 1
            end
            jj += 1
            kk = 1
        end
        ii += 1
        jj = 1
    end
    idx = [length(I)==1, length(J)==1, length(K)==1]
    dropdims(y, dims=tuple(findall(idx)...))
end

function test_variable_no_bound(ModelType, VariableRefType)
    model = ModelType()
    @variable(model, nobounds)
    @test !JuMP.has_lower_bound(nobounds)
    @test !JuMP.has_upper_bound(nobounds)
    @test !JuMP.is_fixed(nobounds)
    test_variable_name(nobounds, "nobounds")
    @test zero(nobounds) isa JuMP.GenericAffExpr{Float64, VariableRefType}
    @test one(nobounds) isa JuMP.GenericAffExpr{Float64, VariableRefType}
end

function test_variable_lower_bound_rhs(ModelType)
    model = ModelType()
    @variable(model, lbonly >= 0, Bin)
    @test JuMP.has_lower_bound(lbonly)
    @test 0.0 == @inferred JuMP.lower_bound(lbonly)
    @test !JuMP.has_upper_bound(lbonly)
    @test !JuMP.is_fixed(lbonly)
    @test JuMP.is_binary(lbonly)
    @test !JuMP.is_integer(lbonly)
    @test isequal(model[:lbonly], lbonly)
    JuMP.delete_lower_bound(lbonly)
    @test !JuMP.has_lower_bound(lbonly)
    # Name already used
    @test_throws ErrorException @variable(model, lbonly)
end

function test_variable_lower_bound_lhs(ModelType)
    model = ModelType()
    @variable(model, 0 <= lblhs, Bin)
    @test JuMP.has_lower_bound(lblhs)
    @test 0.0 == @inferred JuMP.lower_bound(lblhs)
    @test !JuMP.has_upper_bound(lblhs)
    @test !JuMP.is_fixed(lblhs)
    @test JuMP.is_binary(lblhs)
    @test !JuMP.is_integer(lblhs)
    @test isequal(model[:lblhs], lblhs)
end

function test_variable_upper_bound_rhs(ModelType)
    model = ModelType()
    @variable(model, ubonly <= 1, Int)
    @test !JuMP.has_lower_bound(ubonly)
    @test JuMP.has_upper_bound(ubonly)
    @test 1.0 == @inferred JuMP.upper_bound(ubonly)
    @test !JuMP.is_fixed(ubonly)
    @test !JuMP.is_binary(ubonly)
    @test JuMP.is_integer(ubonly)
    @test isequal(model[:ubonly], ubonly)
    JuMP.delete_upper_bound(ubonly)
    @test !JuMP.has_upper_bound(ubonly)
end

function test_variable_upper_bound_lhs(ModelType)
    model = ModelType()
    @variable(model, 1 >= ublhs, Int)
    @test !JuMP.has_lower_bound(ublhs)
    @test JuMP.has_upper_bound(ublhs)
    @test 1.0 == @inferred JuMP.upper_bound(ublhs)
    @test !JuMP.is_fixed(ublhs)
    @test !JuMP.is_binary(ublhs)
    @test JuMP.is_integer(ublhs)
    @test isequal(model[:ublhs],ublhs)
end

function test_variable_interval(ModelType)
    function has_bounds(var, lb, ub)
        @test JuMP.has_lower_bound(var)
        @test lb == @inferred JuMP.lower_bound(var)
        @test JuMP.has_upper_bound(var)
        @test ub == @inferred JuMP.upper_bound(var)
        @test !JuMP.is_fixed(var)
    end
    model = ModelType()
    @variable(model, 0 <= bothb1 <= 1)
    has_bounds(bothb1, 0.0, 1.0)
    @variable(model, 0 ≤  bothb2 ≤  1)
    has_bounds(bothb2, 0.0, 1.0)
    @variable(model, 1 >= bothb3 >= 0)
    has_bounds(bothb3, 0.0, 1.0)
    @variable(model, 1 ≥  bothb4 ≥  0)
    has_bounds(bothb4, 0.0, 1.0)
    @test_macro_throws ErrorException @variable(model, 1 ≥ bothb5 ≤ 0)
    @test_macro_throws ErrorException @variable(model, 1 ≤ bothb6 ≥ 0)
end

function test_variable_fix(ModelType)
    model = ModelType()
    @variable(model, fixed == 1.0)
    @test !JuMP.has_lower_bound(fixed)
    @test !JuMP.has_upper_bound(fixed)
    @test JuMP.is_fixed(fixed)
    @test 1.0 == @inferred JuMP.fix_value(fixed)
    JuMP.unfix(fixed)
    @test !JuMP.is_fixed(fixed)
    JuMP.set_lower_bound(fixed, 0.0)
    @test_throws Exception JuMP.fix(fixed, 1.0)
    JuMP.fix(fixed, 1.0; force = true)
    @test !JuMP.has_lower_bound(fixed)
    @test !JuMP.has_upper_bound(fixed)
    @test JuMP.is_fixed(fixed)
    @test 1.0 == @inferred JuMP.fix_value(fixed)
end

function test_variable_custom_index_sets(ModelType)
    model = ModelType()
    @variable(model, onerangeub[-7:1] <= 10, Int)
    @variable(model, manyrangelb[0:1, 10:20, 1:1] >= 2)
    @test JuMP.has_lower_bound(manyrangelb[0, 15, 1])
    @test 2 == @inferred JuMP.lower_bound(manyrangelb[0, 15, 1])
    @test !JuMP.has_upper_bound(manyrangelb[0, 15, 1])

    s = ["Green","Blue"]
    @variable(model, x[i=-10:10, s] <= 5.5, Int, start=i+1)
    @test 5.5 == @inferred JuMP.upper_bound(x[-4, "Green"])
    test_variable_name(x[-10, "Green"], "x[-10,Green]")
    @test JuMP.start_value(x[-3, "Blue"]) == -2
    @test isequal(model[:onerangeub][-7], onerangeub[-7])
    @test_throws KeyError model[:foo]
end

function test_variable_anonymous(ModelType)
    model = ModelType()
    @test_throws ErrorException @variable(model, [(0, 0)])  # #922
    x = @variable(model, [(0, 2)])
    @test "" == @inferred JuMP.name(x[0])
    @test "" == @inferred JuMP.name(x[2])
end

function test_variable_is_valid_delete(ModelType)
    model = ModelType()
    @variable(model, x)
    @test JuMP.is_valid(model, x)
    JuMP.delete(model, x)
    @test !JuMP.is_valid(model, x)
    second_model = ModelType()
    @test_throws Exception JuMP.delete(second_model, x)
end

function test_variable_bounds_set_get(ModelType)
    model = ModelType()
    @variable(model, 0 <= x <= 2)
    @test 0 == @inferred JuMP.lower_bound(x)
    @test 2 == @inferred JuMP.upper_bound(x)
    set_lower_bound(x, 1)
    @test 1 == @inferred JuMP.lower_bound(x)
    set_upper_bound(x, 3)
    @test 3 == @inferred JuMP.upper_bound(x)
    @variable(model, q, Bin)
    @test !JuMP.has_lower_bound(q)
    @test !JuMP.has_upper_bound(q)

    @variable(model, 0 <= y <= 1, Bin)
    @test 0 == @inferred JuMP.lower_bound(y)
    @test 1 == @inferred JuMP.upper_bound(y)

    @variable(model, fixedvar == 2)
    @test 2.0 == @inferred JuMP.fix_value(fixedvar)
    JuMP.fix(fixedvar, 5)
    @test 5 == @inferred JuMP.fix_value(fixedvar)
    @test_throws Exception JuMP.lower_bound(fixedvar)
    @test_throws Exception JuMP.upper_bound(fixedvar)
end

function test_variable_starts_set_get(ModelType)
    model = ModelType()
    @variable(model, x[1:3])
    x0 = collect(1:3)
    JuMP.set_start_value.(x, x0)
    @test JuMP.start_value.(x) == x0
    @test JuMP.start_value.([x[1],x[2],x[3]]) == x0

    @variable(model, y[1:3,1:2])
    @test_throws DimensionMismatch JuMP.set_start_value.(y, collect(1:6))
end

function test_variable_integrality_set_get(ModelType)
    model = ModelType()
    @variable(model, x[1:3])

    JuMP.set_integer(x[2])
    JuMP.set_integer(x[2])  # test duplicated call
    @test JuMP.is_integer(x[2])
    JuMP.unset_integer(x[2])
    @test !JuMP.is_integer(x[2])

    JuMP.set_binary(x[1])
    JuMP.set_binary(x[1])  # test duplicated call
    @test JuMP.is_binary(x[1])
    @test_throws Exception JuMP.set_integer(x[1])
    JuMP.unset_binary(x[1])
    @test !JuMP.is_binary(x[1])

    @variable(model, y, binary = true)
    @test JuMP.is_binary(y)
    @test_throws Exception JuMP.set_integer(y)
    JuMP.unset_binary(y)
    @test !JuMP.is_binary(y)

    @variable(model, z, integer = true)
    @test JuMP.is_integer(z)
    @test_throws Exception JuMP.set_binary(z)
    JuMP.unset_integer(z)
    @test !JuMP.is_integer(z)
end

function test_variable_repeated_elements(ModelType)
    # Tests repeated elements in index set throw error (JuMP issue #199).
    model = ModelType()
    index_set = [:x,:x,:y]
    @test_throws ErrorException (
        @variable(model, unused_variable[index_set], container=DenseAxisArray))
    @test_throws ErrorException (
        @variable(model, unused_variable[index_set], container=SparseAxisArray))
    @test_throws ErrorException (
        @variable(model, unused_variable[index_set, [1]], container=DenseAxisArray))
    @test_throws ErrorException (
        @variable(model, unused_variable[index_set, [1]], container=SparseAxisArray))
end

function test_variable_oneto_index_set(ModelType, VariableRefType)
    # Tests that Base.OneTo can be used in index set (JuMP issue #933).
    model = ModelType()
    auto_var = @variable(model, [Base.OneTo(3), 1:2], container=Auto)
    @test auto_var isa Matrix{VariableRefType}
    @test (3, 2) == @inferred size(auto_var)
    array_var = @variable(model, [Base.OneTo(3), 1:2], container=Array)
    @test array_var isa Matrix{VariableRefType}
    @test (3, 2) == @inferred size(array_var)
    denseaxisarray_var = @variable(model, [Base.OneTo(3), 1:2], container=DenseAxisArray)
    @test denseaxisarray_var isa JuMP.Containers.DenseAxisArray{VariableRefType}
    @test length.(axes(denseaxisarray_var)) == (3, 2)
end

function test_variable_base_name_in_macro(ModelType)
    model = ModelType()
    @variable(model, normal_var)
    test_variable_name(normal_var, "normal_var")
    no_indices = @variable(model, base_name="foo")
    test_variable_name(no_indices, "foo")
    # Note that `z` will be ignored in name.
    indices = @variable(model, z[i=2:3], base_name="t")
    test_variable_name(indices[2], "t[2]")
    test_variable_name(indices[3], "t[3]")
end

function test_variable_name(ModelType)
    model = ModelType()
    @variable(model, x)
    test_variable_name(x, "x")
    JuMP.set_name(x, "y")
    @test JuMP.variable_by_name(model, "x") isa Nothing
    test_variable_name(x, "y")
    y = @variable(model, base_name="y")
    err(name) = ErrorException("Multiple variables have the name $name.")
    @test_throws err("y") JuMP.variable_by_name(model, "y")
    JuMP.set_name(y, "x")
    test_variable_name(x, "y")
    test_variable_name(y, "x")
    JuMP.set_name(x, "x")
    @test_throws err("x") JuMP.variable_by_name(model, "x")
    @test JuMP.variable_by_name(model, "y") isa Nothing
    JuMP.set_name(y, "y")
    test_variable_name(x, "x")
    test_variable_name(y, "y")
end

function test_variable_condition_in_indexing(ModelType)
    function test_one_dim(x)
        @test 5 == @inferred length(x)
        for i in 1:10
            if iseven(i)
                @test haskey(x, i)
            else
                @test !haskey(x, i)
            end
        end
    end

    function test_two_dim(y)
        @test 15 == @inferred length(y)
        for j in 1:10, k in 3:2:9
            if isodd(j+k) && k <= 8
                @test haskey(y, (j,k))
            else
                @test !haskey(y, (j,k))
            end
        end
    end

    model = ModelType()
    # Parses as ref on 0.7.
    @variable(model, named_one_dim[i=1:10; iseven(i)])
    test_one_dim(named_one_dim)
    # Parses as vcat on 0.7.
    anon_one_dim = @variable(model, [i=1:10; iseven(i)])
    test_one_dim(anon_one_dim)
    # Parses as typed_vcat on 0.7.
    @variable(model, named_two_dim[j=1:10, k=3:2:9; isodd(j + k) && k <= 8])
    test_two_dim(named_two_dim)
    # Parses as vect on 0.7.
    anon_two_dim = @variable(model, [j=1:10, k=3:2:9; isodd(j + k) && k <= 8])
    test_two_dim(anon_two_dim)
end

function test_variable_macro_return_type(ModelType, VariableRefType)
    model = ModelType()
    @variable(model, x[1:3, 1:4, 1:2], start=0.0)
    @test typeof(x) == Array{VariableRefType,3}
    @test typeof(JuMP.start_value.(x)) == Array{Float64,3}

    @variable(model, y[1:0], start=0.0)
    @test typeof(y) == Vector{VariableRefType}
    # No type to infer for an empty collection.
    @test typeof(JuMP.start_value.(y)) == Vector{Union{Nothing, Float64}}

    @variable(model, z[1:4], start = 0.0)
    @test typeof(z) == Vector{VariableRefType}
    @test typeof(JuMP.start_value.(z)) == Vector{Float64}
end

function test_variable_start_value_on_empty(ModelType)
    model = ModelType()
    @variable(model, x[1:4,  1:0,1:3], start = 0)  # Array{VariableRef}
    @variable(model, y[1:4,  2:1,1:3], start = 0)  # DenseAxisArray
    @variable(model, z[1:4,Set(),1:3], start = 0)  # SparseAxisArray

    @test JuMP.start_value.(x) == Array{Float64}(undef, 4, 0, 3)
    # TODO: Decide what to do here. I don't know if we still need to test this
    #       given broadcast syntax.
    # @test typeof(JuMP.start_value(y)) <: JuMP.DenseAxisArray{Float64}
    # @test JuMP.size(JuMP.start_value(y)) == (4,0,3)
    # @test typeof(JuMP.start_value(z)) ==
    #   JuMP.DenseAxisArray{Float64,3,Tuple{UnitRange{Int},Set{Any},UnitRange{Int}}}
    # @test length(JuMP.start_value(z)) == 0
end

function test_variable_denseaxisarray_slices(ModelType, VariableRefType)
    # Test slicing DenseAxisArrays (JuMP issue #684).
    model = ModelType()
    @variable(model, x[1:3, 1:4, 1:2], container=DenseAxisArray)
    @variable(model, y[1:3, -1:2, 3:4])
    @variable(model, z[1:3, -1:2:4, 3:4])
    @variable(model, w[1:3, -1:2,[:red, "blue"]])

    #@test x[:] == vec(sliceof(VariableRefType, x, 1:3, 1:4, 1:2))
    @test x isa JuMP.Containers.DenseAxisArray
    @test x[:, :, :].data == sliceof(VariableRefType, x, 1:3, 1:4, 1:2)
    @test x[1, :, :].data == sliceof(VariableRefType, x, 1, 1:4, 1:2)
    @test x[1, :, 2].data == sliceof(VariableRefType, x, 1, 1:4, 2)
    @test_throws KeyError x[1, :, 3]
    #@test x[1:2,:,:].data == sliceof(VariableRefType, x, 1:2, 1:4, 1:2)
    #@test x[1:2,:,2].data == sliceof(VariableRefType, x, 1:2, 1:4, 2)
    #@test x[1:2,:,1:2].data == sliceof(VariableRefType, x, 1:2, 1:4, 1:2)
    @test_throws KeyError x[1:2, :, 1:3]

    #@test y[:] == vec(sliceof(VariableRefType, y, 1:3, -1:2, 3:4))
    @test y[:, :, :].data == sliceof(VariableRefType, y, 1:3, -1:2, 3:4)
    @test y[1, :, :].data == sliceof(VariableRefType, y, 1, -1:2, 3:4)
    @test y[1, :, 4].data == sliceof(VariableRefType, y, 1, -1:2, 4)
    @test_throws KeyError y[1, :, 5]
    # @test y[1:2,:,:] == sliceof(VariableRefType, y, 1:2, -1:2, 3:4)
    # @test y[1:2,:,4] == sliceof(VariableRefType, y, 1:2, -1:2, 4)
    # @test y[1:2,:,3:4] == sliceof(VariableRefType, y, 1:2, -1:2, 3:4)
    # @test_throws BoundsError y[1:2,:,1:3]

    #@test z[:] == vec(sliceof(VariableRefType, z, 1:3, -1:2:4, 3:4))
    @test z[:, 1, :].data == sliceof(VariableRefType, z, 1:3, 1, 3:4)
    @test z[1, 1, :].data == sliceof(VariableRefType, z, 1, 1, 3:4)
    @test_throws KeyError z[:, 5, 3]
    # @test z[1:2,1,:] == sliceof(VariableRefType, z, 1:2, 1, 3:4)
    # @test z[1:2,1,4] == sliceof(VariableRefType, z, 1:2, 1, 4)
    # @test z[1:2,1,3:4] == sliceof(VariableRefType, z, 1:2, 1, 3:4)
    # @test_throws BoundsError z[1:2,1,1:3]

    #@test w[:] == vec(sliceof(VariableRefType, w, 1:3, -1:2, [:red,"blue"]))
    @test w[:, :, :] == w
    @test w[1, :, "blue"].data == sliceof(VariableRefType, w, 1, -1:2, ["blue"])
    @test w[1, :, :red].data == sliceof(VariableRefType, w, 1, -1:2, [:red])
    @test_throws KeyError w[1, :, "green"]
    # @test w[1:2,:,"blue"] == sliceof(VariableRefType, w, 1:2, -1:2, ["blue"])
    # @test_throws ErrorException w[1:2,:,[:red,"blue"]]
end

function test_variable_end_indexing(ModelType)
    model = ModelType()
    @variable(model, x[0:2, 1:4])
    @variable(model, z[0:2])
    @test x[end,1] == x[2, 1]
    @test x[0, end-1] == x[0, 3]
    @test z[end] == z[2]
    # TODO: It is redirected to x[11] as it is the 11th element but linear
    #       indexing is not supported
    @test_throws BoundsError x[end-1]
end

function test_variable_unsigned_index(ModelType)
    # Tests unsigned int can be used to construct index set (JuMP issue #857).
    model = ModelType()
    t = UInt(4)
    @variable(model, x[1:t])
    @test 4 == @inferred num_variables(model)
end

function test_variable_symmetric(ModelType)
    model = ModelType()

    @variable model x[1:2, 1:2] Symmetric
    @test x isa Symmetric
    @test x[1, 2] === x[2, 1]
    @test model[:x] === x

    y = @variable model [1:2, 1:2] Symmetric
    @test y isa Symmetric
    @test y[1, 2] === y[2, 1]
end

function test_variables_constrained_on_creation(ModelType)
    model = ModelType()

    err = ErrorException("In `@variable(model, x[1:2] in SecondOrderCone(), set = PSDCone())`: Cannot specify set twice, it was already set to `\$(Expr(:escape, :(SecondOrderCone())))` so the `set` keyword argument is not allowed.")
    @test_macro_throws err @variable(model, x[1:2] in SecondOrderCone(), set = PSDCone())
    err = ErrorException("In `@variable(model, x[1:2] in SecondOrderCone(), PSD)`: Cannot specify set twice, it was already set to `\$(Expr(:escape, :(SecondOrderCone())))` so the `PSD` argument is not allowed.")
    @test_macro_throws err @variable(model, x[1:2] in SecondOrderCone(), PSD)
    err = ErrorException("In `@variable(model, x[1:2] in SecondOrderCone(), Symmetric)`: Cannot specify `Symmetric` when the set is already specified, the variable is constrained to belong to `\$(Expr(:escape, :(SecondOrderCone())))`.")
    @test_macro_throws err @variable(model, x[1:2] in SecondOrderCone(), Symmetric)
    err = ErrorException("In `@variable(model, x[1:2], set = SecondOrderCone(), set = PSDCone())`: `set` keyword argument was given 2 times.")
    @test_macro_throws err @variable(model, x[1:2], set = SecondOrderCone(), set = PSDCone())

    @variable(model, x[1:2] in SecondOrderCone())
    @test num_constraints(model, typeof(x), MOI.SecondOrderCone) == 1
    @test name(x[1]) ==  "x[1]"
    @test name(x[2]) ==  "x[2]"

    @variable(model, [1:2] in SecondOrderCone())
    @test num_constraints(model, typeof(x), MOI.SecondOrderCone) == 2

    @variable(model, [1:3] in MOI.SecondOrderCone(3))
    @test num_constraints(model, typeof(x), MOI.SecondOrderCone) == 3

    z = @variable(model, z in MOI.Semiinteger(1.0, 2.0))
    @test num_constraints(model, typeof(z), MOI.Semiinteger{Float64}) == 1

    @variable(model, set = MOI.Semiinteger(1.0, 2.0))
    @test num_constraints(model, typeof(z), MOI.Semiinteger{Float64}) == 2

    @variable(model, [1:3, 1:3] in PSDCone())
    @test num_constraints(model, typeof(x), MOI.PositiveSemidefiniteConeTriangle) == 1
end

function test_batch_delete_variables(ModelType)
    model = ModelType()
    @variable(model, x[1:3] >= 1)
    @objective(model, Min, sum([1, 2, 3] .* x))
    @test all(is_valid.(model, x))
    delete(model, x[[1, 3]])
    @test all((!is_valid).(model, x[[1, 3]]))
    @test is_valid(model, x[2])
    second_model = ModelType()
    @test_throws Exception JuMP.delete(second_model, x[2])
    @test_throws Exception JuMP.delete(second_model, x[[1, 3]])
end

function variables_test(ModelType::Type{<:JuMP.AbstractModel},
                        VariableRefType::Type{<:JuMP.AbstractVariableRef})
    @testset "Variable name" begin
        test_variable_name(ModelType)
    end

    @testset "Constructors" begin
        test_variable_no_bound(ModelType, VariableRefType)
        test_variable_lower_bound_rhs(ModelType)
        test_variable_lower_bound_lhs(ModelType)
        test_variable_upper_bound_rhs(ModelType)
        test_variable_upper_bound_lhs(ModelType)
        test_variable_interval(ModelType)
        test_variable_fix(ModelType)
        test_variable_custom_index_sets(ModelType)
        test_variable_anonymous(ModelType)
    end

    @testset "isvalid and delete variable" begin
        test_variable_is_valid_delete(ModelType)
    end

    @testset "get and set bounds" begin
        test_variable_bounds_set_get(ModelType)
    end

    @testset "get and set start" begin
        test_variable_starts_set_get(ModelType)
    end

    @testset "get and set integer/binary" begin
        test_variable_integrality_set_get(ModelType)
    end

    @testset "repeated elements in index set (issue #199)" begin
        test_variable_repeated_elements(ModelType)
    end

    @testset "Base.OneTo as index set (#933)" begin
        test_variable_oneto_index_set(ModelType, VariableRefType)
    end

    @testset "base_name= in @variable" begin
        test_variable_base_name_in_macro(ModelType)
    end

    @testset "condition in indexing" begin
        test_variable_condition_in_indexing(ModelType)
    end

    @testset "@variable returning Array{VariableRef}" begin
        test_variable_macro_return_type(ModelType, VariableRefType)
    end

    @testset "start_value on empty things" begin
        test_variable_start_value_on_empty(ModelType)
    end

    @testset "Slices of DenseAxisArray (#684)" begin
        test_variable_denseaxisarray_slices(ModelType, VariableRefType)
    end

    @testset "end for indexing a DenseAxisArray" begin
        test_variable_end_indexing(ModelType)
    end

    @testset "Unsigned dimension lengths (#857)" begin
        test_variable_unsigned_index(ModelType)
    end

    @testset "Symmetric variable" begin
        test_variable_symmetric(ModelType)
    end

    @testset "Variables constrained on creation" begin
        test_variables_constrained_on_creation(ModelType)
    end

    @testset "Batch deletion of variables" begin
        test_batch_delete_variables(ModelType)
    end
end

@testset "Variables for JuMP.Model" begin
    variables_test(Model, VariableRef)
    @testset "all_variables" begin
        model = Model()
        @variable(model, x)
        @variable(model, y)
        @test [x, y] == @inferred JuMP.all_variables(model)
    end
    @testset "@variables" begin
        model = Model()
        @variables model begin
            0 ≤ x[i=1:2] ≤ i
            y ≥ 2, Int, (start = 0.7)
            z ≤ 3, (start = 10)
            q, (Bin, start = 0.5)
        end

        @test "x[1]" == @inferred JuMP.name(x[1])
        @test 0 == @inferred JuMP.lower_bound(x[1])
        @test 1 == @inferred JuMP.upper_bound(x[1])
        @test !JuMP.is_binary(x[1])
        @test !JuMP.is_integer(x[1])
        @test JuMP.start_value(x[1]) === nothing

        @test "x[2]" == @inferred JuMP.name(x[2])
        @test 0 == @inferred JuMP.lower_bound(x[2])
        @test 2 == @inferred JuMP.upper_bound(x[2])
        @test !JuMP.is_binary(x[2])
        @test !JuMP.is_integer(x[2])
        @test JuMP.start_value(x[2]) === nothing

        @test "y" == @inferred JuMP.name(y)
        @test 2 == @inferred JuMP.lower_bound(y)
        @test !JuMP.has_upper_bound(y)
        @test !JuMP.is_binary(y)
        @test JuMP.is_integer(y)
        @test JuMP.start_value(y) === 0.7

        @test "z" == @inferred JuMP.name(z)
        @test !JuMP.has_lower_bound(z)
        @test 3 == @inferred JuMP.upper_bound(z)
        @test !JuMP.is_binary(z)
        @test !JuMP.is_integer(z)
        @test JuMP.start_value(z) === 10.0

        @test "q" == @inferred JuMP.name(q)
        @test !JuMP.has_lower_bound(q)
        @test !JuMP.has_upper_bound(q)
        @test JuMP.is_binary(q)
        @test !JuMP.is_integer(q)
        @test JuMP.start_value(q) === 0.5
    end
end

@testset "Variables for JuMPExtension.MyModel" begin
    variables_test(JuMPExtension.MyModel, JuMPExtension.MyVariableRef)
end

@testset "Dual from Variable" begin
    model = Model()
    @variable(model, x == 0)
    exception = ErrorException(
        "To query the dual variables associated with a variable bound, first " *
        "obtain a constraint reference using one of `UpperBoundRef`, `LowerBoundRef`, " *
        "or `FixRef`, and then call `dual` on the returned constraint reference.\nFor " *
        "example, if `x <= 1`, instead of `dual(x)`, call `dual(UpperBoundRef(x))`.")
    @test_throws exception JuMP.dual(x)
end

@testset "value on containers" begin
    model = Model()
    @variable(model, x[1:2])
    exception = ErrorException(
        "`JuMP.value` is not defined for collections of JuMP types. Use " *
        "Julia's broadcast syntax instead: `JuMP.value.(x)`.")
    @test_throws exception JuMP.value(x)
end

function mock_var_for_RC(
    obj_sense::MOI.OptimizationSense,
    #obj_value::Float64,
    var_obj_coeff::Float64,
    #var_value,
    var_bound_type::Symbol,
    var_bounds_dual = nothing,
    has_duals::Bool = var_bounds_dual !== nothing
)
    mockoptimizer = MOIU.MockOptimizer(
        MOIU.Model{Float64}(), eval_objective_value = false
    )
    m = JuMP.direct_model(mockoptimizer)
    if var_bound_type === :lower
        @variable(m, x >= 0)
        if has_duals
            @assert isa(var_bounds_dual, Float64)
            has_duals && MOI.set(
                mockoptimizer, MOI.ConstraintDual(),
                JuMP.optimizer_index(JuMP.LowerBoundRef(x)), var_bounds_dual
            )
        end
    elseif var_bound_type === :upper
        @variable(m, x <= 10)
        if has_duals
            @assert isa(var_bounds_dual, Float64)
            has_duals && MOI.set(
                mockoptimizer, MOI.ConstraintDual(),
                JuMP.optimizer_index(JuMP.UpperBoundRef(x)), var_bounds_dual
            )
        end
    elseif var_bound_type === :fixed
        @variable(m, x == 10)
        if has_duals
            @assert isa(var_bounds_dual, Float64)
            MOI.set(
                mockoptimizer, MOI.ConstraintDual(),
                JuMP.optimizer_index(JuMP.FixRef(x)), var_bounds_dual
            )
        end
    elseif var_bound_type === :both
        @variable(m, 0 <= x <= 10)
        if has_duals
            @assert length(var_bounds_dual) == 2
            @assert eltype(var_bounds_dual) == Float64
            lb_dual, ub_dual = var_bounds_dual
            MOI.set(
                mockoptimizer, MOI.ConstraintDual(),
                JuMP.optimizer_index(JuMP.LowerBoundRef(x)), lb_dual
            )
            MOI.set(
                mockoptimizer, MOI.ConstraintDual(),
                JuMP.optimizer_index(JuMP.UpperBoundRef(x)), ub_dual
            )
        end
    elseif var_bound_type === :none
        @variable(m, x)
        @assert var_bounds_dual === nothing
    else
        error("unrecognized bound type")
    end

    @objective(m, obj_sense, var_obj_coeff * x)

    if has_duals
        MOI.set(mockoptimizer, MOI.TerminationStatus(), MOI.OPTIMAL)
        MOI.set(mockoptimizer, MOI.ResultCount(), 1)
        MOI.set(mockoptimizer, MOI.PrimalStatus(), MOI.FEASIBLE_POINT)
        MOI.set(mockoptimizer, MOI.DualStatus(), MOI.FEASIBLE_POINT)
    end

    return x
end

@testset "reduced_cost" begin
    Min = MOI.MIN_SENSE
    Max = MOI.MAX_SENSE
    # The method should always fail if duals are not available.
    x = mock_var_for_RC(Min, 1.0, :none)
    @test_throws ErrorException reduced_cost(x)
    x = mock_var_for_RC(Min, 1.0, :fixed)
    @test_throws ErrorException reduced_cost(x)
    x = mock_var_for_RC(Min, 1.0, :lower)
    @test_throws ErrorException reduced_cost(x)
    x = mock_var_for_RC(Min, 1.0, :upper)
    @test_throws ErrorException reduced_cost(x)
    x = mock_var_for_RC(Min, 1.0, :both)
    @test_throws ErrorException reduced_cost(x)
    # My reimplementation of the tests suggested by @odow.
    # Note that the floating point values are compared by equality because
    # there is no risk of the solver messing this up (mocks are being used).
    # First the fixed variable tests.
    x = mock_var_for_RC(Min, 1.0, :none, nothing, true) # free var
    @test reduced_cost(x) == 0.0
    x = mock_var_for_RC(Min, 1.0, :fixed, 1.0) # min x, x == 10
    @test reduced_cost(x) == 1.0
    x = mock_var_for_RC(Max, 1.0, :fixed, -1.0) # max x, x == 10
    @test reduced_cost(x) == 1.0
    x = mock_var_for_RC(Min, -1.0, :fixed, -1.0) # min -x, x == 10
    @test reduced_cost(x) == -1.0
    x = mock_var_for_RC(Max, -1.0, :fixed, 1.0) # max -x, x == 10
    @test reduced_cost(x) == -1.0
    # Then the double bounded variables.
    #x = mock_var_for_RC(Min, 1.0, :both, (0.0, 1.0)) # min x, 0 <= x <= 10
    #@test reduced_cost(x) == 1.0
    #x = mock_var_for_RC(Max, 1.0, :both, (-1.0, 0.0)) # max x, 0 <= x <= 10
    #@test reduced_cost(x) == 1.0
    #x = mock_var_for_RC(Min, -1.0, :both, (-1.0, 0.0)) # min -x, 0 <= x <= 10
    #@test reduced_cost(x) == -1.0
    #x = mock_var_for_RC(Max, -1.0, :both, (0.0, 1.0)) # max -x, 0 <= x <= 10
    #@test reduced_cost(x) == -1.0
    # Test for a single upper bound and a single lower bound.
    x = mock_var_for_RC(Min, 1.0, :lower, 1.0) # min x, 0 <= x
    @test reduced_cost(x) == 1.0
    x = mock_var_for_RC(Max, 1.0, :upper, 1.0) # max x, x <= 10
    @test reduced_cost(x) == 1.0
end

@testset "value(::Number)" begin
    @test value(1) === 1
    @test value(1.0) === 1.0
    @test value(JuMP._MA.Zero()) === 0.0
end
