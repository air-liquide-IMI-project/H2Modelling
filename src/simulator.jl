include("./solver.jl")


function simulator(
    T :: Int;
    wind_by_week,
    solar_by_week,
    states :: Array{Float64},
    policy :: Array{Int},
    demand,
    wind_capa,
    solar_capa,
    battery_capa,
    tank_capa,
    electro_capa,
    initial_charge = 0.,
    initial_stock = states[1],
    verbose = false
)
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
            println("Current stock: ", current_stock)
            println("Current target: ", states[action])
        end
        output = solve(
            wind_profile = wind_by_week[t],
            solar_profile = solar_by_week[t],
            demand = demand,
            wind_capa = wind_capa,
            solar_capa = solar_capa,
            battery_capa = battery_capa,
            tank_capa = tank_capa,
            electro_capa = electro_capa,
            initial_charge = current_charge,
            initial_stock = current_stock,
            final_charge = -1.,
            final_stock = states[action],
            gurobi_env = gurobi_env,
            verbose = verbose
        )
        # Update the state
        current_stock = output["stock"][end]
        current_charge = output["charge"][end]
        index_current_stock = action
        # Update the costs
        running_cost += output["operating_cost"]
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