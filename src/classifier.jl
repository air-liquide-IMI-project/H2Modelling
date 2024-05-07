include("./constants.jl")

"""
no classification, return the same class for all profiles
"""
function dummy_one_class(
    wind_by_periods_train :: Vector{Vector{Float64}},
    solar_by_periods_train :: Vector{Vector{Float64}},
    wind_by_periods_val :: Vector{Vector{Float64}},
    solar_by_periods_val :: Vector{Vector{Float64}},
    k::Int
    )
    n = length(wind_by_periods_train)
    classes_train = ones(Int, n)
    n_val = length(wind_by_periods_val)
    classes_val = ones(Int, n_val)
    return ones(Float64, 1), classes_train, classes_val
end

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


"""
Classify the profiles such that the number of profiles in each class is the same, based on the total energy produced
Returns the classes for each profile and the corresponding probas
"""
function classify_uniform_distribution(
    wind_by_periods_train :: Vector{Vector{Float64}},
    solar_by_periods_train :: Vector{Vector{Float64}},
    wind_by_periods_val :: Vector{Vector{Float64}},
    solar_by_periods_val :: Vector{Vector{Float64}},
    k::Int
    )
    n = length(wind_by_periods_train)
    total_energy = [
        sum(wind_by_periods_train[i]) * WIND_CAPA + sum(solar_by_periods_train[i]) * SOLAR_CAPA
        for i in 1:n
    ]
    # Sort the profiles by total energy produced
    sorted_indices = sortperm(total_energy)
    # Get the corresponding thresholds
    thresholds_indexes = floor.(Int, vec(range(1, n, length=k+1)))
    print(thresholds_indexes)
    thresholds = total_energy[sorted_indices[thresholds_indexes[2:k]]]
    
    # Assign the classes
    # Divide the data into k classes uniformly spaced between the min and max values
    classes_train = zeros(Int, n)
    counts = zeros(Int, k)
    for i in 1:n
        class = 1
        while class < k && total_energy[i] > thresholds[class] 
            class += 1
        end
        counts[class] += 1
        classes_train[sorted_indices[i]] = class
    end

    # Compute the probabilities
    probs = counts ./ n

    ## Second step, classify the validation profiles
    n_val = length(wind_by_periods_val)
    total_energy_val = [
        sum(wind_by_periods_val[i]) * WIND_CAPA + sum(solar_by_periods_val[i]) * SOLAR_CAPA
        for i in 1:n_val
    ]
    # Count the number of profiles in each class, and compute the validation classes
    classes_val = zeros(Int, n_val)
    for i in 1:n_val
        class = 1
        while class < k && total_energy_val[i] > thresholds[class] 
            class += 1
        end
        classes_val[i] = class
    end

    return probs, classes_train, classes_val
end

using Clustering, LinearAlgebra

"""
Classify the available energy profiles using a k-means algorithm
"""
function classify_kmeans(
    wind_by_periods_train :: Vector{Vector{Float64}},
    solar_by_periods_train :: Vector{Vector{Float64}},
    wind_by_periods_val :: Vector{Vector{Float64}},
    solar_by_periods_val :: Vector{Vector{Float64}},
    k::Int
    )
    n = length(wind_by_periods_train)
    # Compute the energy available at each time period_length
    energy_available_train = [
        wind_by_periods_train[i] * WIND_CAPA + solar_by_periods_train[i] * SOLAR_CAPA
        for i in 1:n
    ]
    # Put the data in the shape expected by the k-means algorithm
    data = hcat(energy_available_train...)
    println("Shape of the data", size(data))

    # Run the k-means algorithm
    results = kmeans(data, k)

    # Compute the classes
    classes_train = assignments(results)
    classes_train_count = counts(results)
    
    # Compute the probabilities
    probas = classes_train_count / n

    ## Compute the classes on the validation data
    # i.e. make a prediction
    # First, put the centers in a matrix, each column is  a center
    cluster_centers = results.centers
    
    # Then, for each data point in the validation set, compute the closest center
    n_val = length(wind_by_periods_val)
    energy_available_val = [
        wind_by_periods_val[i] * WIND_CAPA + solar_by_periods_val[i] * SOLAR_CAPA
        for i in 1:n_val
    ]
    classes_val = zeros(Int, n_val)

    # We need to treat the last profile separately, because it might not be of full length
    for i in 1:n_val-1
        # Compute the distances from this profile to the centers
        distances = [norm(energy_available_val[i] - cluster_centers[:, j]) for j in 1:k]
        best_class = argmin(distances)
        classes_val[i] = best_class
    end

    # Compute the last distance by padding with the mean of the last profile 
    missing_length = size(data, 1) - length(energy_available_val[end])
    mean_last_profile = mean(energy_available_val[end])
    last_profile_paddes = append!(energy_available_val[end], ones(missing_length) * mean_last_profile)
    distances = [norm(last_profile_paddes - cluster_centers[:, j]) for j in 1:k]
    best_class = argmin(distances)
    classes_val[end] = best_class

    return probas, classes_train, classes_val
end
    
