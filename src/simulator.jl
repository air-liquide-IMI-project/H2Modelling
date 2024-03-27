include("./solver.jl")
include("./constants.jl")


"""
Simulates the system over the validation period, using the given policy.
Computes the true cost of the policy over the validation period

## parameters:
- solar_val : solar profiles over the validation period
- wind_val : wind profiles over the validation period
- states : possible states of the system
- policy : policy[x, t] is the index of the action to take at time t if the state index is x
- initial_charge : initial charge of the battery
- initial_stock : initial stock of the tank
- verbose : print debug information

## returns: a dictionary with the following keys:
- cost : total cost of the policy
- prod : production level over the validation period
- charge : charge level of the battery over the validation period
- stock : stock level of the tank over the validation period
- elec_ppa : electricity bought from the PPA over the validation period
- elec_grid : electricity bought from the grid over the validation period
- curtailing : electricity curtailed over the validation period
"""
function simulator(
    ;
    solar_val,
    wind_val,
    states :: Array{Float64},
    policy :: Array{Int},
    initial_charge = 0.,
    initial_stock = states[1],
    verbose = false
)
    T = length(wind_val)
    gurobi_env = Gurobi.Env()
    # Initialisation
    running_cost = 0.
    prod, charge, stock = [], [], []
    elec_ppa, elec_grid, curtailing = [], [], []
    current_stock = initial_stock
    current_charge = initial_charge
    index_current_stock = findfirst(states .== current_stock)
    # Main loop 
    for t in 1:T
        # Get the action
        action = policy[index_current_stock, t]
        if verbose
            println("Week ", t)
        end
        output = solve(
            wind_profile = wind_val[t],
            solar_profile = solar_val[t],
            initial_charge = current_charge,
            initial_stock = current_stock,
            final_charge = -1.,
            final_stock = states[action],
            gurobi_env = gurobi_env,
            verbose = false
        )
        # Update the state
        current_stock = output["stock"][end]
        current_charge = output["charge"][end]
        index_current_stock = action
        # Update the costs
        running_cost += output["operating_cost"]
        # Add the production change penality cost at every beginning of week (not computed by the milp solver)
        if t > 1
            running_cost += PRICE_PENALITY * abs(prod[end] - output["prod"][1])
        end
        # Update the outputs
        append!(prod, output["prod"])
        append!(charge, output["charge"][Not(end)])
        append!(stock, output["stock"][Not(end)])
        append!(elec_ppa, output["elec_ppa"])
        append!(elec_grid, output["elec_grid"])
        append!(curtailing, output["curtailing"])
    end

    return Dict(
        "cost" => running_cost,
        "prod" => prod,
        "charge" => charge,
        "stock" => stock,
        "elec_ppa" => elec_ppa,
        "elec_grid" => elec_grid,
        "curtailing" => curtailing
    )
end


"""
Computes the true optimal cost of the system over the validation period,
using the linear solver on the aggregated profiles.

## parameters:
- solar_val : solar profiles over the validation period
- wind_val : wind profiles over the validation period
- states : possible states of the system
- initial_charge : initial charge of the battery
- initial_stock : initial stock of the tank
- verbose : print debug information

## Returns a dictionnary with following keys
- charge : Battery charge (MWh)
- prod : Production of hydrogen (Kg)
- stock : Stock of hydrogen in the tank (Kg)
- elec_grid : Electricity consumption from the grid (MWh)
- elec_ppa : Consumption of PPA energy (MWh)
- curtailing : Electricity curtailed (MWh)
- flow_bat : Flow of energy to / from the battery ( > 0 if charging, < 0 if discharging) (MWh)
- flow_H2 : Flow of hydrogen to / from the tank ( > 0 if charging, < 0 if discharging) (Kg)
- operating_cost : Operating cost (€)

"""
function optimal(
    ;
    solar_val,
    wind_val,
    initial_charge = 0.,
    initial_stock = states[1],
    verbose = false
)
    T = length(wind_val)
    overall_wind = Vector{Float64}()
    overall_solar = Vector{Float64}()
    for t in 1:T
        append!(overall_wind, wind_val[t])
        append!(overall_solar, solar_val[t])
    end

    output = solve(
        wind_profile = overall_wind,
        solar_profile = overall_solar,
        initial_charge = initial_charge,
        initial_stock = initial_stock,
        verbose = verbose
    )

    return Dict(
        "charge" => output["charge"],
        "prod" => output["prod"],
        "stock" => output["stock"],
        "elec_grid" => output["elec_grid"],
        "elec_ppa" => output["elec_ppa"],
        "curtailing" => output["curtailing"],
        "flow_bat" => output["flow_bat"],
        "flow_H2" => output["flow_H2"],
        "operating_cost" => output["operating_cost"]
    )
end