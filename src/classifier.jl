include("./constants.jl")

"""
Compute the classes using the given list of profiles (over the training profiles), based on total energy produced
Returns the classes for each profile and the corresponding probas (by counting the number of profiles in each class in the training set)
"""
function classify_uniform_thresholds(
    wind_by_periods_train :: Vector{Vector{Float64}},
    solar_by_periods_train :: Vector{Vector{Float64}},
    wind_by_periods_val :: Vector{Vector{Float64}},
    solar_by_periods_val :: Vector{Vector{Float64}},
    k::Int
    )
    ## First step, compute the thresholds
    # Compute the total energy produced for each period
    n = length(wind_by_periods_train)
    total_energy = [
        sum(wind_by_periods_train[i]) * WIND_CAPA + sum(solar_by_periods_train[i]) * SOLAR_CAPA
        for i in 1:n
    ]
    # Divide the data into k classes uniformly spaced between the min and max values
    min_energy = minimum(total_energy)
    max_energy = maximum(total_energy)
    thresholds = range(min_energy, max_energy, length=k+1)
    # Exclude the first and last thresholds (because they are the min and max values)
    true_thresholds = [ thresholds[i] for i in 2:k ]
    # Count the number of profiles in each class, and compute the training classes
    counts = zeros(Int, k)
    classes_train = zeros(Int, n)
    for i in 1:n
        class = 1
        while class < k && total_energy[i] > true_thresholds[class] 
            class += 1
        end
        counts[class] += 1
        classes_train[i] = class
    end
    # Compute the probabilities
    probs = counts ./ n
    
    ## Second step, classify the validation profiles
    # Compute the total energy produced for each period

    n_val = length(wind_by_periods_val)
    total_energy_val = [
        sum(wind_by_periods_val[i]) * WIND_CAPA + sum(solar_by_periods_val[i]) * SOLAR_CAPA
        for i in 1:n_val
    ]
    # Count the number of profiles in each class, and compute the validation classes
    classes_val = zeros(Int, n_val)
    for i in 1:n_val
        class = 1
        while class < k && total_energy_val[i] > true_thresholds[class] 
            class += 1
        end
        classes_val[i] = class
    end

    return probs, classes_train, classes_val
end
