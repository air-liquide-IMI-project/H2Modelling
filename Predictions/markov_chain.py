import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

# Load CSV file into a DataFrame
column_name = 'DE_wind_generation_actual'
full_data = pd.read_csv('data/profiles.csv', parse_dates=['utc_timestamp'], index_col='utc_timestamp')
# Only train using non 2018 data
whole_data = full_data.loc[full_data.index.year != 2018]
val_data = full_data.loc[full_data.index.year == 2018]

max_value = whole_data['DE_wind_profile'].max()

print("Maximum value:", max_value)
# Discretize values into bins
bins = np.arange(0, 1, 1/199)  # Create bins from 0 to 4000 with step 25

# Apply discretization
whole_data['binned'] = pd.cut(whole_data['DE_wind_profile'], bins=bins)

# Count transitions
transition_matrix = pd.crosstab(whole_data['binned'], whole_data['binned'].shift(-1), normalize='index')
print(transition_matrix.head())

# Fill NaN values with 0 (if there are no transitions)
transition_matrix = transition_matrix.fillna(0)

# Convert to numpy array
transition_matrix = transition_matrix.to_numpy()

# Save the matrix to a CSV file
np.savetxt('Predictions/transition_matrix.csv', transition_matrix, delimiter=',')

# Define the number of time steps
num_steps = 7 * 24

# Define the start state index (replace start_state_index with your actual start state index)
start_state_index = 50

# Simulate the process
def simulate_markov_chain(transition_matrix, start_state_index, num_steps):
    current_state_index = start_state_index
    simulation = [current_state_index]
    for _ in range(num_steps):
        next_state_index = np.random.choice(range(len(transition_matrix)), p=transition_matrix[current_state_index])
        simulation.append(next_state_index)
        current_state_index = next_state_index

    return simulation


if __name__ == '__main__':
    # Compute predictions using the last hour of every preceding week in 2017
    first_hour = val_data.iloc[0]['DE_wind_profile']
    # Find the index in the bins
    first_hour_index = np.digitize(first_hour, bins)
    print("First hour:", first_hour, "Index:", first_hour_index)
    predictions = []
    # Predict 52 weeks of 2018
    for i in range(52):
        # Predict the next hour
        week_pred = simulate_markov_chain(transition_matrix, first_hour_index, 168)
        # Save the prediction
        predictions.append(bins[week_pred][:])
        # Update the first hour
        first_hour = val_data.iloc[i * 168]['DE_wind_profile']
        first_hour_index = np.digitize(first_hour, bins)
    
    # Save the predictions to a CSV file
    predictions = np.array(predictions)
    print(predictions.shape)
    np.savetxt('data/wind_preds.csv', predictions, delimiter=',')
