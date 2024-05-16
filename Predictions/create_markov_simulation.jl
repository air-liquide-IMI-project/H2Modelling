using CSV, DataFrames, StatsBase, Plots

# Read the transition matrix from the CSV file
transition_matrix = CSV.read("Predictions/transition_matrix.csv", DataFrame)

# Convert DataFrame to matrix
transition_matrix = Matrix(transition_matrix)

# Function to simulate Markov chain
function simulate_markov_chain(transition_matrix, start_index, num_steps)
    bins = LinRange(0, 1, 200)
    num_states = size(transition_matrix, 1)
    current_state = start_index
    chain_history = [current_state]
    profile_history = [bins[current_state]]
    
    for _ in 1:num_steps
        # Select next state based on transition probabilities
        probabilities = transition_matrix[current_state, :][1:end-1]
        next_state = sample(1:num_states, Weights(probabilities))
        
        push!(chain_history, next_state)
        current_state = next_state
        push!(profile_history, bins[current_state])
    end
    
    return profile_history
end

# Choose a starting index
start_index = 1

# Run simulation for 7*24 time steps
num_steps = 7 * 24
simulation_result = simulate_markov_chain(transition_matrix, start_index, num_steps)

# Display simulation result
println("Simulation result:")
println(simulation_result)

plot(simulation_result, title="Markov Chain Simulation", xlabel="Time Step", ylabel="State Index", legend=false)