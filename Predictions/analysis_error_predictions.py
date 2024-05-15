import numpy as np
import matplotlib.pyplot as plt

def max_abs_error(pred, real):
    return np.max(np.abs(pred-real), axis=1)

def max_sum_error(pred, real):
    return np.abs(np.sum(pred-real, axis=1))

def max_rel_error(pred, real):
    return np.max(np.abs(pred-real), axis=1)/np.max(real, axis=1)

def max_neg_error(pred, real):
    return np.sum(np.maximum(pred-real, 0), axis=1)

def max_cumulated_error(pred, real):
    T = pred.shape[1]
    all_cumulated_errors = []
    for t_start in range(T-1):
        for t_end in range(t_start+1, T):
            all_cumulated_errors.append(np.sum(pred[:, t_start:t_end]-real[:, t_start:t_end], axis=1))
    all_cumulated_errors = np.array(all_cumulated_errors)
    return np.max(np.abs(all_cumulated_errors), axis=0)

with open("delta_costs.txt", "r") as file:
    delta_costs = np.loadtxt(file, dtype=float)

with open("ener_Market_opt_values.txt", "r") as file:
    ener_Market_opt_values = np.loadtxt(file, dtype=float)

print(ener_Market_opt_values.shape)


with open('solar_predictions_for_error_estimation.txt', 'r') as f:
    # Read the first array
    y_predicted = np.loadtxt(f, dtype=float)
    
    # Read the second array
    y_test = y_predicted[len(y_predicted)//2:, :]
    y_predicted = y_predicted[:len(y_predicted)//2, :]

from scipy.stats import linregress

prediction_error = max_neg_error(y_predicted, y_test)


#valid_indices = np.isfinite(prediction_error) & np.isfinite(delta_costs)
#prediction_error = prediction_error[valid_indices]
#delta_costs = delta_costs[valid_indices]
#slope, intercept, r_value, p_value, std_err = linregress(prediction_error, delta_costs)

# mean_ener_Market_opt_values = np.mean(ener_Market_opt_values, axis=1)
# mean_y_predicted = np.mean(y_predicted, axis=1)
# valid_indices = np.isfinite(mean_ener_Market_opt_values) & np.isfinite(mean_y_predicted)
# mean_ener_Market_opt_values = mean_ener_Market_opt_values[valid_indices]
# mean_y_predicted = mean_y_predicted[valid_indices]
# slope, intercept, r_value, p_value, std_err = linregress(mean_y_predicted, mean_ener_Market_opt_values)

mean_ener_Market_opt_values = np.mean(ener_Market_opt_values, axis=1)
valid_indices = np.isfinite(prediction_error) & np.isfinite(delta_costs) & np.isfinite()
prediction_error = prediction_error[valid_indices]
delta_costs = delta_costs[valid_indices]
slope, intercept, r_value, p_value, std_err = linregress(prediction_error, delta_costs)





plt.figure(figsize=(12, 6))
plt.scatter(mean_y_predicted, mean_ener_Market_opt_values)
plt.title('Policy of energy purchase against solar profile predictions')
plt.xlabel('Mean solar profile prediction')
plt.ylabel('Mean policy of energy purchase on market')
plt.legend()
plt.grid(True)
plt.show()

# Print the results
print("Slope:", slope)
print("Intercept:", intercept)
print("R-squared:", r_value ** 2)
print("p-value:", p_value)
print("Standard error:", std_err)

# No relative error because during night very low values !
# If I can stock everything, I am directly sensitive to cumulated error on long term
# If I can't stock anything, I am directly sensitive to cumulated neg error - capped positive error to market purchase -> having a policy where I buy a lot makes me only sensitive to cumulated error, which means almost nothing on long term -> perhaps I should overbuy a little bit
# If I can sell everything, it works as if I can stock everything
# As a result, if I add a little battery that I don't take into account in my optimization process, that can stock the surplus due to prediction error and compensate when negative prediction error occurs (see max cumulated error), I am not sensitive to error anymore
    
