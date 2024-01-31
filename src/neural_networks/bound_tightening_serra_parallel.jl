using JuMP
using Gurobi
using GLPK

const GUROBI_ENV = Ref{Gurobi.Env}()

function __init__()
    const GUROBI_ENV[] = Gurobi.Env()
end

function copy_model(input_model, solver_params)
    model = copy(input_model)
    set_solver_params!(model, solver_params)
    return model
end

function set_solver_params!(model, params)
    set_optimizer(model, () -> Gurobi.Optimizer(GUROBI_ENV[]))
    # set_optimizer(model, () -> GLPK.Optimizer())
    params.silent && set_silent(model)
    params.threads != 0 && set_attribute(model, "Threads", params.threads)
    params.relax && relax_integrality(model)
    params.time_limit != 0 && set_attribute(model, "TimeLimit", params.time_limit)
    # params.time_limit != 0 && set_attribute(model, "tm_lim", params.time_limit)
end

function calculate_bounds(model::JuMP.Model, layer, neuron, W, b, neurons)

    @objective(model, Max, b[layer][neuron] + sum(W[layer][neuron, i] * model[:x][layer-1, i] for i in neurons(layer-1)))
    optimize!(model)
    
    upper_bound = if termination_status(model) == OPTIMAL
        max(objective_value(model), 0.0)
    else
        max(objective_bound(model), 0.0)
    end

    set_objective_sense(model, MIN_SENSE)
    optimize!(model)
 
    lower_bound = if termination_status(model) == OPTIMAL
        max(-objective_value(model), 0.0)
    else
        max(-objective_bound(model), 0.0)
    end

    println("Neuron: $neuron")

    return upper_bound, lower_bound
end