#####################
# General logic
#####################

"""
Variables are represented as 32-bit unsigned integers
"""
const Var = UInt32 # variable ids

"""
Literals are represented as 32-bit signed integers.
Positive literals are positive integers identical to their variable. Negative literals are their negations. Integer 0 should not be used to represent literals.
"""
const Lit = Int32 # variable with a positive or negative sign

"Convert a variable to the corresponding positive literal"
@inline var2lit(v::Var)::Lit = convert(Var,v)

"Convert a literal its variable, removing the sign of the literal"
@inline lit2var(l::Lit)::Var = convert(Lit,abs(l))

#####################
# General circuits
#####################

"Root of the circuit node hierarchy"
abstract type ΔNode end

"Any circuit represented as a bottom-up linear order of nodes"
const Δ = AbstractVector{<:ΔNode}

"A circuit node that has an origin of type O"
abstract type DecoratorΔNode{O<:ΔNode} <: ΔNode end

"Any circuit that has an origin represented as a bottom-up linear order of nodes"
const DecoratorΔ{O} = AbstractVector{<:DecoratorΔNode{O}}

#####################
# General traits
#####################

"""
A trait hierarchy denoting types of nodes
`GateType` defines an orthogonal type hierarchy of node types, not circuit types, so we can dispatch on node type regardless of circuit type.
See @ref{https://docs.julialang.org/en/v1/manual/methods/#Trait-based-dispatch-1}
"""
abstract type GateType end

abstract type LeafGate <: GateType end
abstract type InnerGate <: GateType end

"A trait denoting literal leaf nodes of any type"
struct LiteralLeaf <: LeafGate end

"A trait denoting constant leaf nodes of any type"
struct ConstantLeaf <: LeafGate end

"A trait denoting conjuction nodes of any type"
struct ⋀ <: InnerGate end

"A trait denoting disjunction nodes of any type"
struct ⋁ <: InnerGate end

# map gate type traits to graph node traits
import ..Utils.NodeType # make available for extension
@inline NodeType(::Type{CN}) where {CN<:ΔNode} = NodeType(GateType(CN))
@inline NodeType(::Type{<:LeafGate}) = Leaf()
@inline NodeType(::Type{<:InnerGate}) = Inner()

#####################
# methods
#####################

# When you suspect there is a bug but execution halts, it may be because of 
# pretty printing a huge recursive circuit structure. 
# To safeguard against that case, we set a default show:
Base.show(io::IO, c::ΔNode) = print(io, "$(typeof(c))($(hash(c))))")

# following methods should be defined for all types of circuits

"Get the logical literal in a given literal leaf node"
@inline literal(n::ΔNode)::Lit = literal(GateType(n), n)
@inline literal(::LiteralLeaf, n::ΔNode)::Lit = error("Each `LiteralLeaf` should implement a `literal` method")

"Get the logical constant in a given constant leaf node"
@inline constant(n::ΔNode)::Bool = literal(GateType(n), n)
@inline constant(::ConstantLeaf, n::ΔNode)::Bool = error("Each `ConstantLeaf` should implement a `constant` method")

"Get the children of a given inner node"
@inline children(n::ΔNode)::Vector{<:ΔNode} = children(GateType(n), n)
@inline children(::InnerGate, n::ΔNode)::Vector{<:ΔNode} = error("Each inner node should implement a `children` method")

# next bunch of methods are derived from literal, constant, children, and the traits

"Get the logical variable in a given literal leaf node"
@inline variable(n::ΔNode)::Var = variable(GateType(n), n)
@inline variable(::LiteralLeaf, n::ΔNode)::Var = lit2var(literal(n))

"Get the sign of the literal leaf node"
@inline positive(n::ΔNode)::Bool = positive(GateType(n), n)
@inline positive(::LiteralLeaf, n::ΔNode)::Bool = literal(n) >= 0 
@inline negative(n::ΔNode)::Bool = !positive(n)

"Does the node have children?"
@inline has_children(n::ΔNode)::Bool = has_children(GateType(n), n)
@inline has_children(::InnerGate, n::ΔNode)::Bool = !isempty(children(n))
@inline has_children(::LeafGate, n::ΔNode)::Bool = false

"Get the number of children of a given inner node"
@inline num_children(n::ΔNode)::Int = num_children(GateType(n), n)
@inline num_children(::InnerGate, n::ΔNode)::Int = length(children(n))
@inline num_children(::LeafGate, n::ΔNode)::Int = 0

"Is the circuit syntactically equal to true?"
@inline is_true(n::ΔNode)::Bool = is_true(GateType(n), n)
@inline is_true(::GateType, n::ΔNode)::Bool = false
@inline is_true(::ConstantLeaf, n::ΔNode)::Bool = (constant(n) == true)

"Is the circuit syntactically equal to false?"
@inline is_false(n::ΔNode)::Bool = is_false(GateType(n), n)
@inline is_false(::GateType, n::ΔNode)::Bool = false
@inline is_false(::ConstantLeaf, n::ΔNode)::Bool = (constant(n) == false)


"Get the list of conjunction nodes in a given circuit"
⋀_nodes(c::Δ) = filter(n -> GateType(n) isa ⋀, c)

"Get the list of disjunction nodes in a given circuit"
⋁_nodes(c::Δ) = filter(n -> GateType(n) isa ⋁, c)

"Number of nodes in the circuit"
num_nodes(c::Δ) = length(c)

"Number of edges in the circuit"
num_edges(c::Δ) = sum(n -> length(children(n)), inodes(c))

"Number of edges in the circuit"
num_variables(c::Δ) = length(variable_scope(c))

"Give count of types and fan-ins of inner nodes in the circuit"
function inode_stats(c::Δ)
    groups = groupby(e -> (typeof(e),num_children(e)), inodes(c))
    map_values(v -> length(v), groups, Int)
end

"Give count of types of leaf nodes in the circuit"
function leaf_stats(c::Δ)
    groups = groupby(e -> typeof(e), leafnodes(c))
    map_values(v -> length(v), groups, Int)
end

"Give count of types and fan-ins of all nodes in the circuit"
node_stats(c::Δ) = merge(leaf_stats(c), inode_stats(c))

"""
Compute the number of nodes in of a tree-unfolding of the DAG circuit. 
"""
function tree_num_nodes(circuit::Δ)::BigInt
    size = Dict{ΔNode,BigInt}()
    for node in circuit
        if has_children(node)
            size[node] = one(BigInt) + sum(c -> size[c], children(node))
        else
            size[node] = one(BigInt)
        end
    end
    size[circuit[end]]
end

"Get the variable scope of the entire circuit"
function variable_scope(circuit::Δ)::BitSet
    variable_scopes(circuit)[circuit[end]]
end

"Get the variable scope of each node in the circuit"
function variable_scopes(circuit::Δ)::Dict{ΔNode,BitSet}
    scope = Dict{ΔNode,BitSet}()
    scope_set(n::ΔNode) = scope_set(GateType(n),n)
    scope_set(::ConstantLeaf, ::ΔNode) = BitSet()
    scope_set(::LiteralLeaf, n::ΔNode) = BitSet(variable(n))
    scope_set(::InnerGate, n::ΔNode) = 
        mapreduce(c -> scope[c], union, children(n))
    for node in circuit
        scope[node] = scope_set(node)
    end
    scope
end

"Is the circuit smooth?"
function is_smooth(circuit::Δ)::Bool
    scope = variable_scopes(circuit)
    is_smooth_node(n::ΔNode) = is_smooth_node(GateType(n),n)
    is_smooth_node(::GateType, ::ΔNode) = true
    is_smooth_node(::⋁, n::ΔNode) =
        all(c -> scope[c] == scope[n], children(n))
    all(n -> is_smooth_node(n), circuit)
end

"Is the circuit decomposable?"
function is_decomposable(circuit::Δ)::Bool
    scope = variable_scopes(circuit)
    is_decomposable_node(n::ΔNode) = is_decomposable_node(GateType(n),n)
    is_decomposable_node(::GateType, ::ΔNode) = true
    is_decomposable_node(::⋀, n::ΔNode) =
        disjoint(map(c -> scope[c], children(n))...)
    all(n -> is_decomposable_node(n), circuit)
end

"Make the circuit smooth"
function smooth(circuit::Δ)
    scope = variable_scopes(circuit)
    smoothed = Dict{ΔNode,ΔNode}()
    smooth_node(n::ΔNode) = smooth_node(GateType(n),n)
    smooth_node(::LeafGate, n::ΔNode) = n
    function smooth_node(::⋀, n::ΔNode)
        smoothed_children = map(c -> smoothed[c], children(n))
        conjoin_like(n, smoothed_children...)
    end
    function smooth_node(::⋁, n::ΔNode) 
        parent_scope = scope[n]
        smoothed_children = map(children(n)) do c
            missing_scope = setdiff(parent_scope, scope[c])
            smooth(smoothed[c], missing_scope)
        end
        disjoin_like(n, smoothed_children...)
    end
    for node in circuit
        smoothed[node] = smooth_node(node)
    end
    root(smoothed[circuit[end]])
end

"""
Forget variables from the circuit. 
Warning: this may or may not destroy the determinism property.
"""
function forget(is_forgotten::Function, circuit::Δ)
    forgotten = Dict{ΔNode,ΔNode}()
    forget_node(n::ΔNode) = forget_node(GateType(n),n)
    forget_node(::ConstantLeaf, n::ΔNode) = n
    forget_node(::LiteralLeaf, n::ΔNode) =
        is_forgotten(variable(n)) ? true_like(n) : n
    function forget_node(::⋀, n::ΔNode)
        forgotten_children = map(c -> forgotten[c], children(n))
        conjoin_like(n, forgotten_children...)
    end
    function forget_node(::⋁, n::ΔNode) 
        forgotten_children = map(c -> forgotten[c], children(n))
        disjoin_like(n, forgotten_children...)
    end
    for node in circuit
        forgotten[node] = forget_node(node)
    end
    root(forgotten[circuit[end]])
end

"Construct a true node in the hierarchy of node n"
true_like(n) = conjoin_like(n)

"Construct a false node in the hierarchy of node n"
false_like(n) = disjoin_like(n)

"Remove all constant leafs from the circuit"
function propagate_constants(circuit::Δ)
    proped = Dict{ΔNode,ΔNode}()
    propagate(n::ΔNode) = propagate(GateType(n),n)
    propagate(::LeafGate, n::ΔNode) = n
    function propagate(::⋀, n::ΔNode) 
        proped_children = map(c -> proped[c], children(n))
        if any(c -> is_false(c), proped_children)
            false_like(n) 
        else
            proped_children = filter(c -> !is_true(c), proped_children)
            conjoin_like(n, proped_children...)
        end
    end
    function propagate(::⋁, n::ΔNode) 
        proped_children = map(c -> proped[c], children(n))
        if any(c -> is_true(c), proped_children)
            true_like(n) 
        else
            proped_children = filter(c -> !is_false(c), proped_children)
            disjoin_like(n, proped_children...)
        end
    end
    for node in circuit
        proped[node] = propagate(node)
    end
    root(proped[circuit[end]])
end

"Rebuild a circuit's linear bottom-up order from a new root node"
function root(root::ΔNode)::Δ
    seen = Set{ΔNode}()
    circuit = Vector{ΔNode}()
    see(n::ΔNode) = see(GateType(n),n)
    function see(::LeafGate, n::ΔNode)
        if n ∉ seen
            push!(seen,n)
            push!(circuit,n)
        end
    end
    function see(::InnerGate, n::ΔNode)
        if n ∉ seen
            for child in children(n)
                see(child)
            end
            push!(seen,n)
            push!(circuit,n)
        end
    end
    see(root)
    lower_element_type(circuit) # specialize the circuit node type
end

"Get the origin of the given decorator circuit node"
@inline (origin(n::DecoratorΔNode{O})::O) where {O<:ΔNode} = n.origin
"Get the origin of the given decorator circuit"
@inline origin(circuit::DecoratorΔ) = lower_element_type(map(n -> n.origin, circuit))

"Get the first origin of the given decorator circuit node of the given type"
@inline (origin(n::DecoratorΔNode{<:O}, ::Type{O})::O) where {O<:ΔNode} = origin(n)
"Get the first origin of the given decorator circuit of the given type"
@inline (origin(n::DecoratorΔNode, ::Type{T})::T) where {T<:ΔNode} = origin(origin(n),T)
@inline origin(circuit::DecoratorΔ, ::Type{T}) where T = lower_element_type(map(n -> origin(n,T), circuit))

"Get the origin of the origin of the given decorator circuit node"
@inline (grand_origin(n::DecoratorΔNode{<:DecoratorΔNode{O}})::O) where {O} = n.origin.origin
"Get the origin of the origin the given decorator circuit"
@inline grand_origin(circuit::DecoratorΔ) = origin(origin(circuit))

"Get the type of circuit node contained in this circuit"
circuitnodetype(circuit::Δ)::Type{<:ΔNode} = eltype(circuit)
