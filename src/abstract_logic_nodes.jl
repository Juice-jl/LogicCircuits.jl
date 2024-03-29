export LogicCircuit, GateType, InnerGate, LeafGate, 
    LiteralGate, ConstantGate, isinnergate, isleafgate, ⋁Gate, ⋀Gate,
    isliteralgate, isconstantgate, is⋁gate, is⋀gate, literal_nodes,
    literal, constant, conjoin, disjoin, op, neutral,
    variable, ispositive, isnegative, istrue, isfalse,
    conjoin, disjoin, copy, compile, pos_literals, neg_literals, literals,
    fully_factorized_circuit, 
    ⋁_nodes, ⋀_nodes, or_nodes, and_nodes, 
    canonical_literals, canonical_constants, tree_formula_string,
    isflat, iscnf, isdnf, has_vars_contiguous

@reexport using DirectedAcyclicGraphs

import ..Utils: variables #extend

#####################
# Abstract infrastructure for logic circuit nodes
#####################

"Root of the logic circuit node hierarchy"
abstract type LogicCircuit <: DAG end

"""
A trait hierarchy denoting types of nodes
`GateType` defines an orthogonal type hierarchy of node types, not circuit types, so we can dispatch on node type regardless of circuit type.
See @ref{https://docs.julialang.org/en/v1/manual/methods/#Trait-based-dispatch-1}
"""
abstract type GateType end

"A logical gate that is a leaf node"
abstract type LeafGate <: GateType end

"A logical gate that is an inner node"
abstract type InnerGate <: GateType end

"A trait denoting literal leaf nodes of any type"
struct LiteralGate <: LeafGate end

"A trait denoting constant leaf nodes of any type"
struct ConstantGate <: LeafGate end

"A trait denoting conjuction nodes of any type"
struct ⋀Gate <: InnerGate end

"A trait denoting disjunction nodes of any type"
struct ⋁Gate <: InnerGate end

"Get the gate type trait of the given `LogicCircuit`"
@inline GateType(instance::LogicCircuit) = GateType(typeof(instance))

# map gate type traits to graph node traits
import DirectedAcyclicGraphs.NodeType # make available for extension
@inline NodeType(::Type{N}) where {N<:LogicCircuit} = NodeType(GateType(N))
@inline NodeType(::LeafGate) = Leaf()
@inline NodeType(::InnerGate) = Inner()

#####################
# node functions that need to be implemented for each type of circuit
#####################

import DirectedAcyclicGraphs.children # make available for extension by concrete types

"Get the logical literal in a given literal leaf node"
@inline literal(n::LogicCircuit)::Lit = n.literal # override when needed

"Conjoin nodes into a single circuit"
function conjoin end

"Disjoin nodes into a single circuit"
function disjoin end

"Create new circuit nodes in the given context."
function compile end

#####################
# derived node functions
#####################

"Is the node an inner gate?"
@inline isinnergate(n) = GateType(n) isa InnerGate
"Is the node a leaf gate?"
@inline isleafgate(n) = GateType(n) isa LeafGate
"Is the node an And gate?"
@inline is⋀gate(n) = GateType(n) isa ⋀Gate
"Is the node an Or gate?"
@inline is⋁gate(n) = GateType(n) isa ⋁Gate
"Is the node a literal gate?"
@inline isliteralgate(n) = GateType(n) isa LiteralGate
"Is the node a constant gate?"
@inline isconstantgate(n) = GateType(n) isa ConstantGate

"Get the logical constant in a given constant leaf node"
@inline constant(n::LogicCircuit) = constant(GateType(n), n)
@inline constant(::ConstantGate, n::LogicCircuit) = n.constant::Bool

"Get the logical variable in a given literal leaf node"
@inline variable(n::LogicCircuit) = variable(GateType(n), n)
@inline variable(::LiteralGate, n::LogicCircuit)::Var = lit2var(literal(n))::Var

"Get the sign of the literal leaf node"
@inline ispositive(n::LogicCircuit) = ispositive(GateType(n), n)
@inline ispositive(::LiteralGate, n::LogicCircuit)::Bool = literal(n) >= 0 

@inline isnegative(n::LogicCircuit)::Bool = !ispositive(n)

"Is the circuit syntactically equal to true?"
@inline istrue(n::LogicCircuit)::Bool = istrue(GateType(n), n)
@inline istrue(::GateType, n::LogicCircuit)::Bool = false
@inline istrue(::ConstantGate, n::LogicCircuit)::Bool = (constant(n) == true)

"Is the circuit syntactically equal to false?"
@inline isfalse(n::LogicCircuit)::Bool = isfalse(GateType(n), n)
@inline isfalse(::GateType, n::LogicCircuit)::Bool = false
@inline isfalse(::ConstantGate, n::LogicCircuit)::Bool = (constant(n) == false)

#####################
# methods to easily construct circuits
#####################

@inline conjoin(xs::LogicCircuit...) = conjoin(collect(xs))
@inline disjoin(xs::LogicCircuit...) = disjoin(collect(xs))

@inline Base.:&(x::LogicCircuit, y::LogicCircuit) = conjoin(x,y)
@inline Base.:&(xs::LogicCircuit...) = conjoin(xs...)
@inline Base.:|(x::LogicCircuit, y::LogicCircuit) = disjoin(x,y)
@inline Base.:|(xs::LogicCircuit...) = disjoin(xs...)

@inline Base.:-(x::LogicCircuit) = begin
    @assert isliteralgate(x) "Negation is only supported for literal gates, not arbitrary circuits."
    compile(x, -literal(x))
end

# Get the function corresponding to the gate type
@inline op(::⋀Gate)::Function = conjoin
@inline op(::⋁Gate)::Function = disjoin

# Get the neural element corresponding to the gate type
@inline neutral(::⋀Gate)::Bool = true
@inline neutral(::⋁Gate)::Bool = false

# Syntactic sugar for compile
(T::Type{<:LogicCircuit})(args...) = compile(T, args...)

compile(n::LogicCircuit, args...) = compile(typeof(n), args...)

"Get a sequence of positive literals"
pos_literals(::Type{T}, num_lits::Int) where {T<:LogicCircuit} = 
    map(l -> compile(T, Lit(l)), 1:num_lits)

"Get a sequence of negative literals"
neg_literals(::Type{T}, num_lits::Int) where {T<:LogicCircuit} = 
    map(l -> compile(T, -Lit(l)), 1:num_lits)

"Get a sequence of positive and negative literals"
literals(::Type{T}, num_lits::Int) where {T<:LogicCircuit} = 
    zip(pos_literals(T,num_lits), neg_literals(T,num_lits))

"Generate a fully factorized circuit over the given range of variables"
function fully_factorized_circuit end

#####################
# circuit inspection
#####################

"Get the list of conjunction nodes in a given circuit"
⋀_nodes(c::LogicCircuit) = filter(is⋀gate, c)

"Get the list of And nodes in a given circuit"
@inline and_nodes(c::LogicCircuit) = ⋀_nodes(c)

"Get the list of disjunction nodes in a given circuit"
⋁_nodes(c::LogicCircuit) = filter(is⋁gate, c)

"Get the list of or nodes in a given circuit"
@inline or_nodes(c::LogicCircuit) = ⋁_nodes(c)

"Get the list of literal nodes in a given circuit"
literal_nodes(c::LogicCircuit) = filter(isliteralgate, c)

"Construct a mapping from literals to their canonical node representation"
function canonical_literals(circuit::LogicCircuit)::Dict{Lit,LogicCircuit}
    lit_dict = Dict{Lit,LogicCircuit}()
    f_lit(n)= begin
        !haskey(lit_dict, literal(n)) || error("Circuit has multiple representations of literal $(literal(n))")
        lit_dict[literal(n)] = n
    end
    foreach(circuit, noop, f_lit, noop, noop)
    lit_dict
end

"Construct a mapping from constants to their canonical node representation"
function canonical_constants(circuit::LogicCircuit)::Tuple{Union{Nothing, LogicCircuit},Union{Nothing, LogicCircuit}}
    true_node::Union{Nothing, LogicCircuit} = nothing
    false_node::Union{Nothing, LogicCircuit} = nothing
    f_con(n)= begin
        if istrue(n)
            isnothing(true_node) || error("Circuit has multiple representations of true")
            true_node = n
        else
            @assert isfalse(n)
            isnothing(false_node) || error("Circuit has multiple representations of false")
            false_node = n
        end
    end
    foreach(circuit, f_con, noop, noop, noop)
    (false_node, true_node)
end

"""
Get the formula of a given circuit as a string, expanding the formula into a tree
"""
function tree_formula_string(n::LogicCircuit)
    if isliteralgate(n)
        "$(literal(n))"
    elseif isconstantgate(n)
        "$(constant(n))"
    elseif is⋀gate(n)
        s = ""
        for (i,c) in enumerate(children(n))
            if i < length(children(n))
                s = string(s, tree_formula_string(c), " ⋀ ")
            else
                s = string(s, tree_formula_string(c))
            end
        end
        s = string("(", s, ")")
        s
    else
        @assert is⋁gate(n)
        s = ""
        for (i,c) in enumerate(children(n))
            if i < length(children(n))
                s = string(s, tree_formula_string(c), " ⋁ ")
            else
                s = string(s, tree_formula_string(c))
            end
        end
        s = string("(", s, ")")
        s
    end
end

"Is the circuit a flat DNF or CNF structure?"
isflat(circuit) = iscnf(circuit) || isdnf(circuit)

"Is the circuit a conjunction of disjunctive clauses?"
iscnf(circuit) =
    is⋀gate(circuit) && all(children(circuit)) do clause
        is⋁gate(clause) && all(isliteralgate, children(clause))
    end

"Is the circuit a disjunction of conjunctive clauses?"
isdnf(circuit) =
    is⋁gate(circuit) && all(children(circuit)) do clause
        is⋀gate(clause) && all(isliteralgate, children(clause))
    end

"Does the circuit have a contiguously indexed set of variables"
has_vars_contiguous(circuit) = begin
    vars = variables(circuit)
    (maximum(vars) == length(vars))
end
