include("./solver.jl")


function dynamic_solver(
    T :: Int;
    wind_by_week :: Array{Array{Float64, 1}},
    solar_by_week :: Array{Array{Float64, 1}},
    states :: Array{Float64},
    demand,
    wind_capa,
    solar_capa,
    battery_capa,
    tank_capa,
    electro_capa,
    initial_charge = 0.,
    verbose = false,
)
    gurobi_env = Gurobi.Env()
    # Initialisation
    N = length(states)
    V = zeros(Float64, N, T+1)
    policy = zeros(Int, N, T)
    # battery_charge[x, t] is the charge of the battery at the beginning of week t if the stock is x
    battery_charge = -ones(Float64, N, T+1)
    # Main loop, backward induction
    for t in T:-1:1
        if verbose
            println("Week ", t)
        end
        # Initial charge of the battery, only constrain the first week
        if t == 1
            init_charge = initial_charge
        else
            init_charge = -1.
        end
        # Loop over the possible states at the beginning week t
        for x in 1:N
            best_cost = Inf
            # Enumerate the possible actions
            # Here an action is the choice of the final stock at the end of the week
            for a in 1:N
                output = solve(
                    wind_profile = wind_by_week[t],
                    solar_profile = solar_by_week[t],
                    demand = demand,
                    wind_capa = wind_capa,
                    solar_capa = solar_capa,
                    battery_capa = battery_capa,
                    tank_capa = tank_capa,
                    electro_capa = electro_capa,
                    initial_charge = init_charge,
                    initial_stock = states[x],
                    final_charge = battery_charge[a, t+1],
                    final_stock = states[a],
                    gurobi_env = gurobi_env,
                )
                # Update the cost
                cost = output["operating_cost"]
                if cost < best_cost
                    best_cost = cost
                    V[x, t] = cost + V[a, t+1]
                    policy[x, t] = a
                    battery_charge[x, t] = output["charge"][1]
                end
            end
        end
    end

    return V, policy
end