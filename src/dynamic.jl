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
    - train_classes : classes of the training profiles (level of available energy in each period)
    - classes_probas : probabilities of each class
    - profiles_generator : function to generate possible wind and solar profiles over the coming week
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
    period_length :: Int,
    wind_train :: Array{Array{Float64, 1}},
    solar_train :: Array{Array{Float64, 1}},
    classes_train :: Array{Int},
    classes_probas :: Array{Float64},
    profiles_generator_solar :: Function,
    profiles_generator_wind :: Function,
    n_ev_compute :: Int = 1,
    states :: Array{Float64},
    initial_charge = 0.,
    discount_factor = 1.,
    verbose = false,
)
    #gurobi_env = Gurobi.Env()
    println("Using $(Threads.nthreads()) threads")
    # Initialisation
    N = length(states)
    number_of_classes = length(classes_probas)
    # V[x, c, t] is the expected cost of the best policy starting from state x at time t if the upcoming week is of class c
    V = zeros(Float64, N, number_of_classes, T+1)
    policy = zeros(Int, N, number_of_classes, T)
    # battery_charge[x, t] is the charge of the battery at the beginning of week t if the stock is x
    battery_charge = -ones(Float64, N, number_of_classes, T+1)
    # prod_level[x, t] is the production level at the beginning of week t if the stock is x
    # This is to take into account the production change penality cost when changing time period
    prod_level = zeros(Float64, N, number_of_classes, T)
    # Main loop, backward 
    for t in T:-1:1
        if verbose
            println("Period ", t)
        end
        # Initial charge of the battery, only constrain the first week
        if t == 1
            init_charge = initial_charge
        else
            init_charge = -1.
        end
        # Loop over the possible states at the beginning week t
        # Use parallel for loop to speed up the computation
        Threads.@threads for x in 1:N
            # Loop over the classes 
            # One class represent the "level" of energy available in the system over the incoming week
            # If we do prediction specific to the week, we only explore the class corresponding to the week
            for class in 1:number_of_classes
                best_cost = Inf
                # Enumerate the possible actions
                # Here an action is the choice of the final stock at the end of the week
                # Only iterate through the reachable states
                # This is because in the span of one day, we can't fully empty the tank for instance
                # Or we can't fully fill the tank
                reachable_states = []
                for a in 1:N
                    is_reachable = abs(states[a] - states[x]) <= DEMAND * period_length # Can we empty the tank sufficiently ?
                    is_reachable &= abs(states[a] - states[x]) <= ELECTRO_CAPA / EELEC * period_length # Can we fill the tank sufficiently ?
                    if is_reachable
                        push!(reachable_states, a)
                    end
                end
                for a in reachable_states
                    # Get the possible wind and solar profiles for the coming week
                    # We generate n_ev_compute possible profiles
                    possible_wind = profiles_generator_wind(t, wind_train, classes_train,  n_ev_compute, period_length, class)
                    possible_solar = profiles_generator_solar(t, solar_train, classes_train, n_ev_compute, period_length, class)
                    # Keep in memory the costs and corresponding charge and production level for each action
                    cost_per_profile = zeros(Float64, n_ev_compute)
                    bat_level_per_profile = zeros(Float64, n_ev_compute)
                    prod_level_per_profile = zeros(Float64, n_ev_compute)
                    # Compute the expected final charge level (using the probas of each class)
                    final_charge = sum(battery_charge[a, :, t+1] .* classes_probas)
                    # Compute the expected cost over the coming week
                    # for each possible wind and solar profile of the relevant class
                    for i in 1:n_ev_compute
                        wind = possible_wind[i]
                        solar = possible_solar[i]
                        # Compute the transition cost
                        output = solve(
                            wind_profile = wind,
                            solar_profile = solar,
                            initial_charge = init_charge,
                            final_charge = final_charge,
                            initial_stock = states[x],
                            final_stock = states[a],
                        )
                        operating_cost = output["operating_cost"]
                        # Add the production change penality cost at every beginning of week (not computed by the milp solver)
                        if t < T
                            final_prod = sum(prod_level[a, :, t+1] .* classes_probas)
                            operating_cost += PRICE_PENALITY * abs(final_prod - output["prod"][end])
                        end
                        cost_per_profile[i] = operating_cost
                        bat_level_per_profile[i] = output["charge"][1]
                        prod_level_per_profile[i] = output["prod"][1]
                    end
                    # Compute the cost of taking this action
                    # Since we don't know the production level class of the next week, we take the mean
                    next_week_cost = sum([prob * V[a, c, t+1] for (c, prob) in enumerate(classes_probas)])
                    cost_action = mean(cost_per_profile) + discount_factor * next_week_cost
                    expect_bat = mean(bat_level_per_profile)
                    expect_prod = mean(prod_level_per_profile)
                    # Update the best cost and policy
                    if cost_action < best_cost
                        best_cost = cost_action
                        policy[x, class, t] = a
                        V[x, class, t] = best_cost
                        battery_charge[x, class, t] = expect_bat
                        prod_level[x, class, t] = expect_prod
                    end 

                end
            end
        end
    end

    return V, policy
end