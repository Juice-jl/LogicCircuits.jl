export Vtree, balanced_vtree, random_vtree, top_down_vtree, bottom_up_vtree, depth

#############
# Vtree
#############

"Root of the vtree node hiearchy"
abstract type Vtree <: Tree end

#############
# Constructors
#############

"Construct a balanced vtree with variables ranging from `first` to `last` (inclusive)"
function balanced_vtree(::Type{VN}, first::Var, last::Var)::VN where {VN <: Vtree}
    @assert last >= first "Must have $last >= $first"
    if last == first
        return VN(first)
    else
        return VN(balanced_vtree(VN, first, Var(first+(last-first+1)÷2-1)), 
        balanced_vtree(VN, Var(first+(last-first+1)÷2), last))
    end
end

using Random: randperm

function random_vtree(::Type{VN}, num_variables; vtree_mode::String="balanced")::VN where {VN <: Vtree}
    @assert vtree_mode in ["linear", "balanced", "rand"]
    leaves = VN.(Var.(randperm(num_variables)))
    vtree = [Vector{VN}(); leaves]
    right = popfirst!(vtree)
    while !isempty(vtree)
        left = popfirst!(vtree)
        v = VN(left, right)
        if vtree_mode == "linear"
            pushfirst!(vtree, v)
        elseif vtree_mode == "balanced"
            push!(vtree, v)
        elseif vtree_mode == "rand"
            pushrand!(vtree, v)
        end
        right = popfirst!(vtree)
    end
    right
end

"""
Construct Vtree top town, using method specified by split_method.
"""
function top_down_root(::Type{VN}, vars::Vector{Var}, split_method::Function)::VN  where {VN <: Vtree}
    @assert !isempty(vars) "Cannot construct a vtree with zero variables"
    if length(vars) == 1
        VN(vars[1])
    else
        (X, Y) = split_method(vars)
        prime = top_down_root(VN, X, split_method)
        sub = top_down_root(VN, Y, split_method)
        VN(prime, sub)
    end
end

"""
Construct Vtree bottom up, using method specified by combine_method!.
"""
function bottom_up_vtree(::Type{VN}, vars::Vector{Var}, combine_method!::Function)::VN where {VN <: Vtree}
    vars = copy(vars)
    ln = Vector{VN}()
    node_cache = Dict{Var, VN}() # map from variable to *highest* level node

    "1. construct leaf node"
    for var in vars
        n = VN(var)
        node_cache[var] = n
        push!(ln, n)
    end

    "2. construct inner node"
    while length(vars) > 1
        matches = combine_method!(vars) # vars are mutable
        for (left, right) in matches
            n = VN(node_cache[left], node_cache[right])
            node_cache[left] = node_cache[right] = n
            push!(ln, n)
        end
    end

    "3. clean up"
    ln[end]
end

#############
# Methods
#############

"""
Compute the path length from vtree node `n` to leaf node which contains `var`
"""
depth(n::Vtree, var::Var)::Int = depth(NodeType(n), n, var)

function depth(::Inner, n::Vtree, var::Var)::Int
    @assert var in variables(n)
    if var in variables(n.left)
        return 1 + depth(n.left, var)
    else
        return 1 + depth(n.right, var)
    end
end

function depth(::Leaf, n::Vtree, var::Var)::Int
    @assert var ∈ variables(n)
    return 0
end