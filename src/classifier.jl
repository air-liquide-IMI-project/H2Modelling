include("./constants.jl")

"""
Compute the classes using the given list of profiles, based on total energy produced
Returns the threshold values for each class, and the associated probabilities (counting the number of profiles in each class)
"""
function compute_classes(
    wind_by_periods :: Vector{Vector{Float64}},
    solar_by_periods :: Vector{Vector{Float64}},
    k::Int
    )
    # Compute the total energy produced for each period
    n = length(wind_by_periods)
    total_energy = [
        sum(wind_by_periods[i]) * WIND_CAPA + sum(solar_by_periods[i]) * SOLAR_CAPA
        for i in 1:n
    ]
    # Divide the data into k classes uniformly spaced between the min and max values
    min_energy = minimum(total_energy)
    max_energy = maximum(total_energy)
    thresholds = range(min_energy, max_energy, length=k+1)
    # Exclude the first and last thresholds (because they are the min and max values)
    true_thresholds = [ thresholds[i] for i in 2:k ]
    # Count the number of profiles in each class
    counts = zeros(Int, k)
    for i in 1:n
        class = 1
        while class < k && total_energy[i] > true_thresholds[class] 
            class += 1
        end
        counts[class] += 1
    end
    # Compute the probabilities
    probs = counts ./ n
    println("Thresholds : ", vec(true_thresholds))
    println("Minimum energy : ", min_energy, " Maximum energy : ", max_energy)
    return true_thresholds, probs
end

"""
Classify the profiles into classes based on the total energy produced,
using the given thresholds (computed by compute_classes)
Returns the class index for each profile
"""
function classify_profiles(wind_by_periods, solar_by_periods, thresholds)
    n = length(wind_by_periods)
    k = length(thresholds) + 1
    if n != length(solar_by_periods)
        throw(ArgumentError("The number of wind and solar profiles must be the same"))
    end
    # Compute the total energy produced for each period
    total_energy = [
        sum(wind_by_periods[i]) * WIND_CAPA + sum(solar_by_periods[i]) * SOLAR_CAPA
        for i in 1:n
    ]
    # Classify the profiles
    classes = zeros(Int, n)
    for i in 1:n
        # Compute the class index = the first threshold strictly below the total energy produced
        class = 1
        while class < k && total_energy[i] > thresholds[class]
            class += 1
        end
        classes[i] = class
    end
    return classes
end
    