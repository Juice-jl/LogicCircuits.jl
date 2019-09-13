if endswith(@__FILE__, PROGRAM_FILE)
   # this file is run as a script
   include("../../../src/Juice/Juice.jl")
end

using Test
using .Juice
import .Juice.IO: 
   parse_comment_line, parse_lc_header_line, parse_lc_literal_line, parse_psdd_literal_line, parse_lc_decision_line, parse_bias_line, parse_lc_file, 
   CircuitFormatLine, BiasLine, DecisionLine, WeightedLiteralLine, CircuitHeaderLine, CircuitCommentLine, LCElement, CircuitFormatLines

@testset "Logistic circuit file parser tests" begin
   @test parse_comment_line("c blah blablah") isa CircuitCommentLine
   @test parse_comment_line("c") isa CircuitCommentLine
   @test parse_comment_line("c    blah blablah") isa CircuitCommentLine
   @test parse_lc_header_line("Logisitic Circuit") isa CircuitHeaderLine
   @test parse_lc_header_line("Logistic Circuit") isa CircuitHeaderLine
   @test parse_lc_literal_line("T 0 0 1 0.11139313932426485 0.5341755009918099 0.4104354811044485 0.2088029562981886 0.38317256253159404 0.21456111303752262 0.33798418436324884 0.7382343563376387 0.5769125897294547 0.13071237914862724") isa WeightedLiteralLine
   @test parse_lc_literal_line("F 1069 490 491 0.6277380017061743 -0.45260459349249044 0.34609986139917703 0.6004763090354547 0.2394524067773312 0.22081649811500942 -0.26666977618500204 0.14544044474614298 0.30372580539872435 0.2192352511676825") isa WeightedLiteralLine
   @test parse_lc_decision_line("D 1799 985 4 (472 474 0.27742886347699697 -0.0894114793745983 0.5298165134268861 0.5827938730880822 0.14116799704274996 0.3970938168763751 0.17798346381236296 0.08917988964843772 -0.05605305315306568 0.1702693902831316) (472 475 0.3833466224435187 0.8445851879217264 -0.3572571803165608 0.1793868357569113 -0.2373580813674068 0.670248227361854 -0.11119443329855791 0.13163431621813051 0.5421030929813475 0.25786192990838014) (473 474 1.0369907390437323 0.44729016983853126 -0.07892427803381961 0.38996680892303803 0.5285038536250287 0.3944289684978373 0.2762655604492141 0.556958084538147 0.2711846681681724 0.39922629776124985) (473 475 0.032883234975809694 -0.02256663542306192 0.6555725013615572 0.5140023339657676 0.11841852634121926 0.14907399101146324 -0.22404529652178906 -0.11976212824115842 -0.15206954052616856 0.0022385109727181413)") isa DecisionLine{LCElement}
   @test parse_lc_decision_line("D 10652 1001 2 (508 511 0.0008337025235152718 -6.048729079142479e-05 0.0012900540050118133 0.006382987897195768 0.00013330176570593142 -0.0034902489721742023 0.003162325487226574 -0.009619185307110537 0.043311151137203116 -0.007194862955461081) (509 511 0.023396488696149225 -0.000729066431265012 6.551173017401332e-06 0.05715185398005281 -0.008310854435718613 -0.003834142193742804 -0.005833871820252338 -0.05352747769146413 0.010573950714222884 0.03262423061844396)") isa DecisionLine{LCElement}
   @test parse_bias_line("B -0.6090213458520287 0.10061233805363132 -0.44510731039287776 -0.4536824618763301 -0.738392695523771 -0.5610245232140584 -0.4586543592164493 -0.07962059343551083 -0.2582953135054242 -0.03257926010007175") isa BiasLine
   @test parse_lc_file("test/circuits/mnist-large.circuit") isa CircuitFormatLines
end


@testset "Load a small PSDD and test methods" begin
   file = "test/circuits/little_4var.psdd"
   prob_circuit = load_prob_circuit(file);
   @test prob_circuit isa ProbCircuit△

   # Testing number of nodes and parameters
   @test  9 == num_parameters(prob_circuit)
   @test 20 == size(prob_circuit)[1]
   
   # Testing Read Parameters
   EPS = 1e-7
   @test abs(prob_circuit[13].log_thetas[1] - (-1.6094379124341003)) < EPS
   @test abs(prob_circuit[13].log_thetas[2] - (-1.2039728043259361)) < EPS
   @test abs(prob_circuit[13].log_thetas[3] - (-0.916290731874155)) < EPS
   @test abs(prob_circuit[13].log_thetas[4] - (-2.3025850929940455)) < EPS

   @test abs(prob_circuit[18].log_thetas[1] - (-2.3025850929940455)) < EPS
   @test abs(prob_circuit[18].log_thetas[2] - (-2.3025850929940455)) < EPS
   @test abs(prob_circuit[18].log_thetas[3] - (-2.3025850929940455)) < EPS
   @test abs(prob_circuit[18].log_thetas[4] - (-0.35667494393873245)) < EPS

   @test abs(prob_circuit[20].log_thetas[1] - (0.0)) < EPS
end

psdd_files = ["test/circuits/little_4var.psdd", "test/circuits/msnbc-yitao-a.psdd", "test/circuits/msnbc-yitao-b.psdd", "test/circuits/msnbc-yitao-c.psdd", "test/circuits/msnbc-yitao-d.psdd", "test/circuits/msnbc-yitao-e.psdd", "test/circuits/mnist-antonio.psdd"]

@testset "Test parameter integrity of loaded PSDDs" begin
   for psdd_file in psdd_files
      @test check_parameter_integrity(load_prob_circuit(psdd_file))
   end
end

@testset "Test parameter integrity of loaded structured PSDDs" begin
   circuit, vtree = load_struct_prob_circuit(
      "test/circuits/little_4var.psdd", "test/circuits/little_4var.vtree")
   @test check_parameter_integrity(circuit)
   @test vtree isa Vtree△
   # no other combinations of vtree and psdd are in this repo?
   # @test check_parameter_integrity(load_struct_prob_circuit(
   #          "test/circuits/mnist-antonio.psdd", "test/circuits/balanced.vtree"))
end

@testset "Test structured logical circuit loading" begin
   circuit, vtree = load_struct_smooth_logical_circuit("./test/circuits/mnist-large.circuit", "./test/circuits/balanced.vtree")
   @test circuit isa StructLogicalCircuit△
   @test vtree isa Vtree△
   @test is_decomposable(circuit)
end

@testset "Load an MNIST logistic circuit as a logical circuit" begin

   file = "./test/circuits/mnist-large.circuit";
   lc = load_smooth_logical_circuit(file);
   
   @test lc isa LogicalCircuit△

end