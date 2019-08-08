using ParserCombinator
using EponymTuples

"""
A line in one vtree file format
"""
abstract type VtreeFormatLine end

struct VtreeCommentLine{T<:AbstractString} <: VtreeFormatLine
    comment::T
end

struct VtreeHeaderLine <: VtreeFormatLine
    node_count::UInt32
end

struct VtreeInnerLine <: VtreeFormatLine
    node_id::UInt32
    left_id::UInt32
    right_id::UInt32
end

struct VtreeLeafLine <: VtreeFormatLine
    node_id::UInt32
    variable::Var
end

function build_vtree_matchers()
    spc::Matcher = Drop(Space())

    vtree_comment::Matcher = Seq!(E"c", Drop(Space()[0:1]), Pattern(r".*"), Eos()) > VtreeCommentLine{String}
    vtree_header::Matcher = Seq!(E"vtree", spc, PUInt32(), Eos()) > VtreeHeaderLine
    vtree_inner::Matcher = Seq!(E"I", spc, PUInt32(), spc, PUInt32(), spc, PUInt32(), Eos()) > VtreeInnerLine
    vtree_leaf::Matcher = Seq!(E"L", spc, PUInt32(), spc, PUInt32(), Eos()) > VtreeLeafLine

    @eponymtuple(vtree_comment, vtree_header, vtree_inner, vtree_leaf)
end

# function parse_one_obj(s::String, p::Matcher)
#     objs = parse_one(s,p)
#     @assert length(objs) == 1 "$objs is not a single object"
#     objs[1]
# end

const vtree_matchers = build_vtree_matchers()

function parse_vtree_comment_line_fast(ln::String)
    VtreeCommentLine(lstrip(chop(ln, head = 1, tail = 0)))
end

function parse_inner_vtree_fast(ln::String)
    tokens = split(ln)
    node_id = parse(UInt32, tokens[2])
    left_id = parse(UInt32, tokens[3])
    right_id = parse(UInt32, tokens[4])
    VtreeInnerLine(node_id, left_id, right_id)
end

function parse_leaf_vtree_fast(ln::String)
    tokens = split(ln)
    node_id = parse(UInt32, tokens[2])
    var_id  = parse(UInt32, tokens[3])
    VtreeLeafLine(node_id, var_id)
end

function parse_vtree_file(file::String)::Vector{VtreeFormatLine}
    q = Vector{VtreeFormatLine}()
    open(file) do file
        for ln in eachline(file)
            if ln[1] == 'c'
                push!(q, parse_vtree_comment_line_fast(ln))
            elseif ln[1] == 'L'
                push!(q, parse_leaf_vtree_fast(ln))
            elseif ln[1] == 'I'
                push!(q, parse_inner_vtree_fast(ln))
            else
                push!(q, parse_one_obj(ln, vtree_matchers.vtree_header))
            end
        end
    end
    q
end


function compile_vtree_format_lines(lines::Vector{VtreeFormatLine})::Vector{VtreeNode}

    # map from index to VtreeNode for input
    node_cache = Dict{UInt32, VtreeNode}()

    index2node(index::UInt32)::VtreeNode =
        get!(node_cache, index) do
            throw("Invalid Vtree file format, meet children before parent $index")
        end

    index2node(index::UInt32, variable::Var)::VtreeNode =
        get!(node_cache, index) do
            VtreeLeafNode(variable)
        end

    index2node(index::UInt32, left::UInt32, right::UInt32)::VtreeNode =
        get!(node_cache, index) do
            left_node = index2node(left)
            right_node = index2node(right)
            VtreeInnerNode(
                        left_node,
                        right_node,
                        union(Variables(left_node),Variables(right_node)))
        end

    lin = Vector{VtreeNode}()

    # ccompile VtreeFormatLine to VtreeNode
    compile(::Union{VtreeHeaderLine, VtreeCommentLine}) = () # do nothing
    function compile(ln::VtreeLeafLine)
        n = index2node(ln.node_id, ln.variable)
        push!(lin, n)
    end
    function compile(ln::VtreeInnerLine)
        n = index2node(ln.node_id, ln.left_id, ln.right_id)
        push!(lin, n)
    end

    for ln in lines
        compile(ln)
    end
    lin
end

function load_vtree(file::String)::Vector{VtreeNode}
    return compile_vtree_format_lines(parse_vtree_file(file))
end