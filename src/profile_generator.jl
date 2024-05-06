using StatsBase

"""
Generate a possible of length period_length from days of the training set
"""
function generate_period_from_day(
    t :: Int, # Index of the day relative to the year
    wind_train :: Array{Array{Float64, 1}},
    k :: Int = 1,
    period_length :: Int = 24,
    around :: Int = 10
)
    # Check that the period length is a multiple of 24
    if period_length % 24 != 0
        throw(ArgumentError("period_length should be a multiple of 24"))
    end

    # First pick the possible days to pick from in the training set
    length_one_year = floor(365 * 24 / period_length) # Number of periods in a year
    length_one_year_train = floor(365 * 24 / length(wind_train[1])) # Number of periods in a year of the training set
    year = 0
    possible_indexes = []
    while year * length_one_year_train < length(wind_train)
        if around == 0
            push!(possible_indexes, Int(year * length_one_year_train + t))
        else
            for j in -around:around
                index = Int(year * length_one_year_train + t + j)
                if index > 0 && index <= length(wind_train)
                    push!(possible_indexes, index)
                end
            end
        end
        year += 1
    end

    # Choose the days and concatenate them if need be
    generated_profiles = Array{Array{Float64, 1}}(undef, k)
    # Generate k possible periods
    # For each period, we concatenate days at random from the training set
    days_per_period = floor(Int, period_length / 24)
    for i in 1:k
        generated_profiles[i] = []
        for j in 1:days_per_period
            chosen_day = sample(possible_indexes, 1)[1]
            generated_profiles[i] = vcat(generated_profiles[i], wind_train[chosen_day])
        end
    end

    return generated_profiles
end

