using CSV, DataFrames

# Read the transition matrix from the CSV file
transition_matrix = CSV.read("transition_matrix.csv", DataFrame)

# Convert DataFrame to matrix
transition_matrix = convert(Matrix, transition_matrix)

# Function to simulate Markov chain
function simulate_markov_chain(transition_matrix, start_index, num_steps)
    num_states = size(transition_matrix, 1)
    current_state = start_index
    chain_history = [current_state]
    
    for _ in 1:num_steps
        # Select next state based on transition probabilities
        probabilities = transition_matrix[current_state, :]
        next_state = rand(1:num_states, weights=probabilities)
        
        push!(chain_history, next_state)
        current_state = next_state
    end
    
    return chain_history
end

# Choose a starting index
start_index = 1

# Run simulation for 7*24 time steps
num_steps = 7 * 24
simulation_result = simulate_markov_chain(transition_matrix, start_index, num_steps)

# Display simulation result
println("Simulation result:")
println(simulation_result)