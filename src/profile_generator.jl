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
    returns a list k of possible wind profiles for week t, assumed to be equiprobable
"""
function basic_wind_generator(
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
    returns a list k of possible solar profiles for week t, assumed to be equiprobable
"""
function basic_solar_generator(
    t :: Int,
    solar_train :: Array{Array{Float64, 1}},
    k :: Int = 1,
    around :: Int = 3
)
    possible_indexes = basic_possible_indexes(t, length(solar_train))
    chosen_indexes = sample(possible_indexes, k, replace = false)
    return solar_train[chosen_indexes]

end