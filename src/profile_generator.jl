using StatsBase

"""
Generate a possible of length period_length from full periods of the training set
If class is not -1, only pick periods of the given class (i.e of a similar level of available energy)
"""
function generate_period_from_full_period(
    t :: Int, # Index of the day relative to the year
    periods_train :: Array{Array{Float64, 1}},
    classes_train :: Array{Int},
    k :: Int = 1,
    period_length :: Int = 24,
    class :: Int = -1, # Global class of the periods to generate, if -1, choose randomly
)
    # Check that the period length is a multiple of 24
    train_period_length = length(periods_train[1])
    if period_length % train_period_length != 0
        throw(ArgumentError("period_length should be a multiple of the length of the training set periods"))
    end

    # First pick the possible days to pick from in the training set
    # Iterate over the full training set, only adding periods of the right class
    i = 1
    possible_indexes = []
    while i <= length(periods_train)
        if classes_train[i] == class || class == -1
            push!(possible_indexes, i)
        end
        i += 1
    end

    # Generate the profiles
    if length(possible_indexes) == 0
        throw(ArgumentError("No period of the given class, class = $class"))
    end
    # Pick the indexes of the days to pick
    picked_indexes = sample(possible_indexes, k, replace=true)
    generated_profiles = [periods_train[i] for i in picked_indexes]

    return generated_profiles
end


"""
Generate full periods from sub-periods extracted from the training set
To adhere to the class, we pick the sub-periods from periods of the required class
"""

function generate_period_from_sub_period(
    t :: Int, # Index of the day relative to the year
    periods_train :: Array{Array{Float64, 1}},
    classes_train :: Array{Int},
    k :: Int = 1,
    period_length :: Int = 24* 7,
    class :: Int = -1, # Global class of the periods to generate, if -1, choose randomly
    sub_period_length :: Int = 24,
)
    # Check that the period length is a multiple of the sub-period length
    if period_length % sub_period_length != 0
        throw(ArgumentError("period_length should be a multiple of the sub_period_length, period_length = $period_length, sub_period_length = $sub_period_length"))
    end

    # First pick the possible days to pick from in the training set
    # Iterate over the full training set, only adding periods of the right class
    i = 1
    possible_indexes = []
    while i <= length(periods_train)
        if classes_train[i] == class || class == -1
            push!(possible_indexes, i)
        end
        i += 1
    end

    # For every period we need to generate, pick the sub-periods
    sub_periods_per_period = Int(period_length / sub_period_length)
    generated_profiles = Vector{Vector{Float64}}()
    for i in 1:k
        # Pick the indexes of the days to pick
        picked_indexes = sample(possible_indexes, sub_periods_per_period, replace=true)
        # Generate a profile for the period
        profile = []
        for (j, index) in enumerate(picked_indexes)
            profile = vcat(profile, periods_train[index][1 + (j - 1) * sub_period_length : j * sub_period_length])
        end
        push!(generated_profiles, profile)
    end

    return generated_profiles

end

function get_same_week(
    t :: Int, # Index of the day relative to the year
    periods_train :: Array{Array{Float64, 1}},
    classes_train :: Array{Int},
    k :: Int = 1,
    period_length :: Int = 24* 7,
    class :: Int = -1, # Global class of the periods to generate, if -1, choose randomly
    sub_period_length :: Int = 24,
)
    return [periods_train[t]]

end


