include("./solver.jl")
include("./constants.jl")


"""
    Solver for the dynamic programming problem over T time steps (weeks)
    The solver is based on backward induction
    Each week, we compute the best action beginning from each possible state
    The transition cost is given by the LP solver over a week
    We compute the expected cost of each policy using possible wind and solar profile over the coming week

    parameters:
    - T : number of time steps
    - wind_train : training wind profiles, to generate possible wind profiles over the coming week
    - solar_train : training solar profiles, to generate possible solar profiles over the coming week
    - wind_week_gen : wind_week_gen(t, wind_train) should return a list of possible wind profiles for week t, assumed to be equiprobable
    - solar_week_gen : same for solar profiles
    - n_weeks : number of weeks used to compute the expected cost
    - states : possible states of the system
    - initial_charge : initial charge of the battery
    - verbose : print debug information

    returns:
    - V : matrix of size (N, T+1) where V[x, t] is the expected cost of the best policy starting from state x at time t
    - policy : matrix of size (N, T) where policy[x, t] is the best action to take at time t if the state is x
"""
function dynamic_solver(
    T :: Int;
    wind_train :: Array{Array{Float64, 1}},
    solar_train :: Array{Array{Float64, 1}},
    wind_week_gen :: Function,
    solar_week_gen :: Function,
    n_ev_compute :: Int,
    states :: Array{Float64},
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
    # prod_level[x, t] is the production level at the beginning of week t if the stock is x
    # This is to take into account the production change penality cost when changing time period
    prod_level = zeros(Float64, N, T)
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
                possible_wind = wind_week_gen(t, wind_train, n_ev_compute)
                possible_solar = solar_week_gen(t, solar_train, n_ev_compute)
                # Compute the expected cost of the policy
                expect_cost = 0.
                # Also compute the "expected" battery charge and production level
                expect_bat = 0.
                expect_prod = 0.
                for i in 1:n_ev_compute
                    wind = possible_wind[i]
                    solar = possible_solar[i]
                    # Compute the transition cost
                    output = solve(
                        wind_profile = wind,
                        solar_profile = solar,
                        gurobi_env = gurobi_env,
                    )
                    operating_cost = output["operating_cost"]
                    
                    # Add the production change penality cost at every beginning of week (not computed by the milp solver)
                    if t < T
                        operating_cost += PRICE_PENALITY * abs(prod_level[a, t+1] - output["prod"][end])
                    end
                    expect_cost += (1/n_ev_compute) * (operating_cost + V[a, t+1])
                    expect_bat += (1/n_ev_compute) * output["charge"][1]
                    expect_prod += (1/n_ev_compute) * output["prod"][1]
                end
                # Update the best action
                if expect_cost < best_cost
                    best_cost = expect_cost
                    policy[x, t] = a
                    V[x, t] = best_cost
                    battery_charge[x, t] = expect_bat
                    prod_level[x, t] = expect_prod
                end 

            end
        end
    end

    return V, policy
end