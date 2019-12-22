#####################
# Save lines
#####################

function save_lines(name::String, lines::CircuitFormatLines)
    open(name, "w") do f
        for line in lines
            println(f, line)
        end
    end
end

#####################
# decompile for nodes
#####################

# decompile for sdd circuit
decompile(n::StructLiteralNode, node2id, vtree2id)::UnweightedLiteralLine = 
    UnweightedLiteralLine(node2id[n], vtree2id[n.vtree], literal(n), false)

decompile(n::StructConstantNode, node2id, vtree2id)::AnonymousConstantLine = 
    AnonymousConstantLine(node2id[n], constant(n), false)

decompile(n::Struct⋁Node, node2id, vtree2id)::DecisionLine{SDDElement} = 
    DecisionLine(node2id[n], vtree2id[n.vtree], UInt32(num_children(n)), map(c -> make_element(c, node2id), children(n)))

make_element(n::Struct⋀Node, node2id) = 
    SDDElement(node2id[n.children[1]],  node2id[n.children[2]])

make_element(n::StructLogicalΔNode, node2id) = 
    error("Given circuit is not an SDD, its decision node elements are not conjunctions.")

# TODO: decompile for logical circuit to some file format

#####################
# build maping
#####################

function get_node2id(ln::AbstractVector{X}, T::Type)where X #<: T#::Dict{T, ID}
    node2id = Dict{T, ID}()
    outnodes = filter(n -> !(GateType(n) isa ⋀), ln)
    sizehint!(node2id, length(outnodes))
    index = ID(0) # node id start from 0
    for n in outnodes
        node2id[n] = index
        index += ID(1)
    end
    node2id
end

function get_vtree2id(ln::PlainVtree):: Dict{PlainVtreeNode, ID}
    vtree2id = Dict{PlainVtreeNode, ID}()
    sizehint!(vtree2id, length(ln))
    index = ID(0) # vtree id start from 0

    for n in ln
        vtree2id[n] = index
        index += ID(1)
    end
    vtree2id
end

#####################
# saver for circuits
#####################

function sdd_header()
    """
    c ids of sdd nodes start at 0
    c sdd nodes appear bottom-up, children before parents
    c
    c file syntax:
    c sdd count-of-sdd-nodes
    c F id-of-false-sdd-node
    c T id-of-true-sdd-node
    c L id-of-literal-sdd-node id-of-vtree literal
    c D id-of-decomposition-sdd-node id-of-vtree number-of-elements {id-of-prime id-of-sub}*
    c
    c File generated by Juice.jl
    c"""
end

function save_sdd_file(name::String, circuit::DecoratorΔ, vtree::PlainVtree)
    save_sdd_file(name, origin(circuit, StructLogicalΔNode), vtree)
end

function save_sdd_file(name::String, circuit::StructLogicalΔ, vtree::PlainVtree)
    #TODO no need to pass the vtree, we can infer it from origin?
    @assert endswith(name, ".sdd")
    node2id = get_node2id(circuit, StructLogicalΔNode)
    vtree2id = get_vtree2id(vtree)
    formatlines = Vector{CircuitFormatLine}()
    append!(formatlines, parse_sdd_file(IOBuffer(sdd_header())))
    push!(formatlines, SddHeaderLine(num_nodes(circuit)))
    for n in filter(n -> !(GateType(n) isa ⋀), circuit)
        push!(formatlines, decompile(n, node2id, vtree2id))
    end
    save_lines(name, formatlines)
end

save_circuit(name::String, circuit::StructLogicalΔ, vtree::PlainVtree) = save_sdd_file(name, circuit, vtree)
