using StatsBase


"""
    returns a list of possible indexes for the wind profiles
    Here we use the -3, +3 weeks around the week t for each year of the training set
"""
function basic_possible_indexes(
    t :: Int,
    n_train :: Int,
    around :: Int = 3
)
    t_in_year = mod(t, 52)
    # Generate a list of possible indexes for the wind profiles
    # Here we use the -3, +3 weeks around the week t for each year of the training set
    possible_indexes :: Array{Int, 1} = []
    year = 0
    while year*52 < n_train
        for j in -around:around
            index = (year)*52 + t_in_year + j
            if index > 0 && index <= n_train
                push!(possible_indexes, index)
            end
        end
        year += 1
    end
    return possible_indexes
end
"""
    returns a list k of possible profiles for week t, assumed to be equiprobable
    The returned profiles are whole weeks from the training set
"""
function generate_from_weeks(
    t :: Int,
    wind_train :: Array{Array{Float64, 1}},
    k :: Int = 1,
    around :: Int = 3
)
    possible_indexes = basic_possible_indexes(t, length(wind_train), around)
    chosen_indexes = sample(possible_indexes, k, replace = false)

    return wind_train[chosen_indexes]

end

"""
    returns a list k of possible load profiles for week t, assumed to be equiprobable.
    To generate the profiles, we build a new profile by recomposing days from the training set
    We have to be careful, because the training set is already divided into weeks.
"""
function generate_from_days(
    t :: Int, # week index
    wind_train :: Array{Array{Float64, 1}},
    k :: Int = 1,
    around :: Int = 3
)
    n_train = length(wind_train)
    # First choose from which weeks we can take the data
    week_index = basic_possible_indexes(t, n_train, around)
    generated_wind = Array{Array{Float64, 1}}(undef, k)
    for i in 1:k
        # For each week, we choos 7 days at random from the training set
        for j in 1:7
            if j == 1
                generated_wind[i] = []
            end
            chosen_week = sample(week_index, 1)[1]
            chosen_day = rand(1:7)
            # Get the beginning of the day in the hourly data
            index_begin = (chosen_day-1)*24 + 1
            index_end = chosen_day*24
            day = wind_train[chosen_week][index_begin:index_end]
            generated_wind[i] = vcat(generated_wind[i], day)
        end
    end
    
    return generated_wind
end


