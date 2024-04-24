import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

# Load CSV file into a DataFrame
column_name = 'DE_wind_generation_actual'
whole_data = pd.read_csv('time_series_60min_singleindex.csv', parse_dates=['utc_timestamp'], index_col='utc_timestamp')

max_value = whole_data['DE_solar_generation_actual'].max()

print("Maximum value:", max_value)
# Discretize values into bins
bins = np.arange(0, 32100, 100)  # Create bins from 0 to 4000 with step 25

# Apply discretization
whole_data['binned'] = pd.cut(whole_data['DE_wind_generation_actual'], bins=bins)

# Count transitions
transition_matrix = pd.crosstab(whole_data['binned'], whole_data['binned'].shift(-1), normalize='index')

# Fill NaN values with 0 (if there are no transitions)
transition_matrix = transition_matrix.fillna(0)

# Convert to numpy array
transition_matrix = transition_matrix.to_numpy()

# Save the matrix to a CSV file
np.savetxt('transition_matrix.csv', transition_matrix, delimiter=',', fmt='%d')

# Define the number of time steps
num_steps = 40

# Define the start state index (replace start_state_index with your actual start state index)
start_state_index = 50

# Simulate the process
current_state_index = start_state_index
simulation = [current_state_index]
for _ in range(num_steps):
    next_state_index = np.random.choice(range(len(transition_matrix)), p=transition_matrix[current_state_index])
    simulation.append(next_state_index)
    current_state_index = next_state_index


plt.figure(figsize=(12, 6))
# plt.plot(y_test.flatten(), label='True Values')
plt.plot(bins[np.array(simulation)], label='Predictions')
plt.title('Wind Generation Forecast')
plt.xlabel('Time')
plt.ylabel('Wind Generation')
plt.legend()
plt.grid(True)
plt.show()
