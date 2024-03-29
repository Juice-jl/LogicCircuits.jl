# [Queries](@id man-queries)

## Evaluation
Given a logic circuit ``\Delta`` and an assignment to its variable, we would like to know the output of the circuit. For example, if ``\Delta = X \land Y ``, and we assign ``x``, ``\lnot y``:

```math
X \land Y = \text{true} \land \text{false} = \text{false}
```

```@example eval
using LogicCircuits # hide
lc = zoo_sdd("random.sdd");
X = rand(Bool, num_variables(lc));

lc(X)
```

## Satisfiability

Given a logic circuit ``\Delta``, the goal of SAT is to answer whether there is an assignment to its variables such that the output is `true`. Depending on the structural properties of the logic circuit this problem can be intractable or tractable.

We can use [`sat_prob`](@ref) to compute probability of a random world satisfying the circuit. Note that [`sat_prob`](@ref) assumes that we have a smooth, deterministic, and decomposable circuit.

```@example sat
using LogicCircuits # hide
lc = zoo_sdd("random.sdd");
prob = sat_prob(lc);
Float64(prob)
```

By default, every postive literal ``x_i`` has probability 1/2, we can set probability of literal values to any constant probabilities, for example:

```@example sat
prob = sat_prob(lc; varprob = (i) -> BigInt(1) // BigInt(3));
Float64(prob)
```

## Model Counting

Given a logic circuit ``\Delta``, the goal of model counting is to count how many ways there are to assign values to variables of ``\Delta`` such that the output of the circuit is `true`. Note that [`model_count`](@ref) assumes we have a smooth, deterministic, and decomposable circuit.

```@example mc
using LogicCircuits # hide
lc = smooth(zoo_sdd("random.sdd"));
model_count(lc)
```

Let's see how conjoining affects the model count. Observe that model count of ``\Delta`` should equal to adding model counts of ``\Delta \mid x_2`` and ``\Delta \mid \lnot x_2``.

```@example mc
c2 = conjoin(lc, Lit(2));
c2not = conjoin(lc, Lit(-2));
model_count(c2, num_variables(lc)), model_count(c2not, num_variables(lc))
```

Note that some transformations lead to losing required properties needed for tractable model count. For example, after forgetting variables we lose determinism and hence cannot use [`model_count`](@ref) anymore.

## Equivalence Checking

Given two logic circuits ``\Delta_1`` and ``\Delta_2``, the goal is to check whether these two circuits represent the same formula. There are both determnistic and probabilistic algorithms for this task.

## Misc

Here are few other useful queries. Look inside thier documentation for more details.

- [`variables`](@ref): Get the variable mentioned in the circuit root.
- [`infer_vtree`](@ref) Infer vtree of struct decomposable circuits.
- [`implied_literals`](@ref) Implied Literals.