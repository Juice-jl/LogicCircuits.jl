using Test
using LogicCircuits

include("../helper/little_circuits.jl")

@testset "SDD as LogicCircuit parser" begin

  circuit = zoo_sdd("random.sdd") 

  @test circuit isa PlainLogicCircuit

  @test num_nodes(circuit) == 1676
  @test isdecomposable(circuit)
  @test !issmooth(circuit)
  @test any(isfalse, linearize(circuit))
  @test any(istrue, linearize(circuit))
  @test num_variables(circuit) == 30

  # not sure what this is testing for
  @test issomething(canonical_literals(circuit))
  @test issomething(canonical_constants(circuit))

end

@testset "SDD write and save" begin

  sdd = readme_sdd()

  mktempdir() do tmp
    
    # write as a unstructured logic circuit
    sdd_path = "$tmp/example.sdd"
    write(sdd_path, sdd)

    # read as a unstructured logic circuit
    sdd2 = read(sdd_path, LogicCircuit, SddFormat())
    
    @test sdd2 isa PlainLogicCircuit

    @test num_nodes(sdd) == num_nodes(sdd2)
    @test prob_equiv(sdd, sdd2, 10)

    # write with vtree
    vtree_path = "$tmp/example.vtree"
    paths = (sdd_path, vtree_path)
    write(paths, sdd)

    # read as a structured logic circuit
    formats = (SddFormat(), VtreeFormat())
    sdd3 = read(paths, StructLogicCircuit, formats) 
    
    @test sdd3 isa PlainStructLogicCircuit

    @test num_nodes(sdd) == num_nodes(sdd3)
    @test prob_equiv(sdd, sdd3, 10)

    @test Vtree(mgr(sdd)) == vtree(sdd3)

    # read as an SDD
    sdd4 = read(paths, Sdd, formats) 
    
    @test sdd4 isa Sdd

    @test num_nodes(sdd) == num_nodes(sdd4)
    @test prob_equiv(sdd, sdd4, 10)

    @test Vtree(mgr(sdd)) == Vtree(mgr(sdd4))

    # write/read compressed
    paths = ("$sdd_path.gz", vtree_path)
    write(paths, sdd)
    sdd4 = read(paths, StructLogicCircuit) 
    
    @test sdd4 isa PlainStructLogicCircuit
    @test num_nodes(sdd) == num_nodes(sdd4)
    @test prob_equiv(sdd, sdd4, 10)
    @test Vtree(mgr(sdd)) == vtree(sdd4)
    
  end

  mktempdir() do tmp
    mgr = SddMgr(7, :balanced)
    v = Dict([(i => compile(mgr, Lit(i))) for i=1:7])
    c = (v[1] | !v[2] | v[3]) &
        (v[2] | !v[7] | v[6]) &
        (v[3] | !v[4] | v[5]) &
        (v[1] | !v[4] | v[6])
    @test num_edges(c) == 147

    @test_nowarn write("$tmp/temp.sdd", c)
    l = read("$tmp/temp.sdd", LogicCircuit)
    @test num_edges(l) == 147
    @test num_variables(l) == 7

  end

end