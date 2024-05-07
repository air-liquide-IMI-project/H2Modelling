using StatsBase

"""
Generate a possible of length period_length from days of the training set
If class is not -1, only pick periods of the given class (i.e of a similar level of available energy)
"""
function generate_period_from_day(
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

