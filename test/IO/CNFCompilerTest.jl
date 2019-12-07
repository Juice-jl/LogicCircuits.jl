using Test
using .Juice
import .Juice.IO:
   load_cnf, load_dnf


@testset "CNF file parser tests" begin

   cnfs = [ ("easy","C17_mince",32),
            ("easy","majority_mince",32),
            ("easy","b1_mince",8),
            ("easy","cm152a_mince",2048),
            ("iscas89","s208.1.scan",262144)]
      
   for (suite, name, count) in cnfs

      cnf = load_cnf("test/cnfs/$suite/$name.cnf")
      vtree = load_vtree("test/cnfs/$suite/$name.min.vtree");

      mgr = SddMgr(TrimSddMgr, vtree)
      # cnfΔ = @time compile_cnf(mgr, cnf)
      cnfΔ = node2dag(compile_cnf(mgr, cnf), TrimSdd)

      # println("Final number of edges: ", num_edges(cnfΔ))
      # println("Final SDD size: ", sdd_size(cnfΔ))
      # println("Final SDD node count: ", sdd_num_nodes(cnfΔ))
      # println("Final SDD model count: ", model_count(cnfΔ))

      @test model_count(cnfΔ) == count

      validate(cnfΔ)

   end

end