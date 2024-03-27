using StatsBase
"""
    returns a list k of possible wind profiles for week t, assumed to be equiprobable
"""
function basic_wind_generator(
    t :: Int,
    wind_train :: Array{Array{Float64, 1}},
    k :: Int = 1
)
    if t > 52 || t < 1
        throw(ArgumentError("The week index should be between 1 and 52"))
    end
    n_train = length(wind_train)
    if n_train == 0
        throw(ArgumentError("The training wind profiles should not be empty"))
    end
    # Generate a list of possible indexes for the wind profiles
    # Here we use the -3, +3 weeks around the week t for each year of the training set
    possible_indexes :: Array{Int, 1} = []
    n_years = div(n_train, 52)    
    for i in 1:n_years
        for j in -3:3
            index = (i-1)*52 + t + j
            if index > 0 && index <= n_train
                push!(possible_indexes, index)
            end
        end
    end
    # Select the profiles
    chosen_indexes = sample(possible_indexes, k, replace = false)

    return wind_train[chosen_indexes]

end

"""
    returns a list k of possible solar profiles for week t, assumed to be equiprobable
"""
function basic_solar_generator(
    t :: Int,
    solar_train :: Array{Array{Float64, 1}},
    k :: Int = 1
)
    if t > 52 || t < 1
        throw(ArgumentError("The week index should be between 1 and 52"))
    end
    n_train = length(solar_train)
    if n_train == 0
        throw(ArgumentError("The training solar profiles should not be empty"))
    end
    # Generate a list of possible indexes for the solar profiles
    # Here we use the -3, +3 weeks around the week t for each year of the training set
    possible_indexes :: Array{Int, 1} = []
    n_years = div(n_train, 52)
    for i in 1:n_years
        for j in -3:3
            index = (i-1)*52 + t + j
            if index > 0 && index <= n_train
                push!(possible_indexes, index)
            end
        end
    end
    # Select the profiles
    chosen_indexes = sample(possible_indexes, k, replace = false)

    return solar_train[chosen_indexes]

end