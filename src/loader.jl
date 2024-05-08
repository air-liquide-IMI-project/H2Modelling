using CSV, DataFrames, Impute, Dates


"""
    Load the profiles from the file as a dictionary of year-long profiles

    parameters:
    - filename : path to the file
    - years : years to load
    - verbose : print debug information
    - wind_profile : name of the wind profile column
    - solar_profile : name of the solar profile column

    returns: a tuple with the following elements:
    - timeIndexes : dictionary of the time indexes for each year
    - windProfiles : dictionary of the wind profiles for each year
    - solarProfiles : dictionary of the solar profiles for each year
"""
function load_profiles(filename;
    years = [2015, 2016, 2017, 2018, 2019], 
    verbose = false, 
    wind_profile = "DE_wind_profile", 
    solar_profile = "DE_solar_profile"
)
    # Load the file
    data = CSV.read(filename, DataFrame)
    # Time column
    data.utc_timestamp = chop.(data.utc_timestamp, tail=1)
    data.utc_timestamp = DateTime.(data.utc_timestamp)
    # Remove the columns that are not needed
    profile_names = ["utc_timestamp", wind_profile, solar_profile]
    select!(data, Cols(in(profile_names)))
    # Interpolate the missing values
    Impute.interp!(data)
    # Only keep the year that are needed
    windProfiles = Dict()
    solarProfiles = Dict()
    timeIndexes = Dict()
    for year in years
        if verbose
            println("Loading the profiles for the year $year")
        end
        subData = filter(row -> year == Dates.year(row.utc_timestamp), data)
        disallowmissing!(subData)
        windProfiles[year] = subData[!, wind_profile]
        solarProfiles[year] = subData[!, solar_profile]
        timeIndexes[year] = subData[!, "utc_timestamp"]
        # If some data are missing,
        if any(ismissing, windProfiles[year]) || any(ismissing, solarProfiles[year])
            println("Some data are missing for the year $year")
        end
    end

    return timeIndexes, windProfiles, solarProfiles
end


"""
Load the profiles from the file as a list of profiles by periods, periods have a default length of 7 days

## usage:
```julia
time_by_periods, wind_by_periods, solar_by_periods = load_by_periods("data.csv", period_length=7) \n
week_profile = wind_by_periods[t] # Get the wind profile for the week t
```

## parameters:
- filename : path to the file
- period_length : length of the periods, in days
- years : years to load
- wind_profile : name of the wind profile column
- solar_profile : name of the solar profile column

## returns: a tuple with the following elements:
- time_by_periods : list of the time indexes for each period
- wind_by_periods : list of the wind profiles for each period
- solar_by_periods : list of the solar profiles for each period
"""
function load_by_periods(filename, period_length = 7*24;
    years = [2014, 2015, 2016, 2017, 2018],
    wind_profile = "DE_wind_profile",
    solar_profile = "DE_solar_profile"
)
    # Load the file
    data = CSV.read(filename, DataFrame)
    # Time column
    data.utc_timestamp = chop.(data.utc_timestamp, tail=1)
    data.utc_timestamp = DateTime.(data.utc_timestamp)
    # Remove the columns that are not needed
    profile_names = ["utc_timestamp", wind_profile, solar_profile]
    select!(data, Cols(in(profile_names)))
    # Interpolate the missing values
    Impute.interp!(data)
    # Only keep the year we want
    data = filter(row -> Dates.year(row.utc_timestamp) in years, data)
    disallowmissing!(data)
    wind_by_periods = Vector{Vector{Float64}}()
    solar_by_periods = Vector{Vector{Float64}}()
    time_by_periods = Vector{Vector{DateTime}}()
    # Split the data into periods
    for i in 1:period_length:length(data.utc_timestamp)
        subData = data[i:min(i+period_length-1, end), :]
        push!(wind_by_periods, subData[!, wind_profile])
        push!(solar_by_periods, subData[!, solar_profile])
        push!(time_by_periods, subData[!, "utc_timestamp"])
        # If some data are missing,
    end
    # Remove the last period if it is not complete
    if length(wind_by_periods[end]) != period_length
        pop!(wind_by_periods)
        pop!(solar_by_periods)
        pop!(time_by_periods)
    end
    return time_by_periods, wind_by_periods, solar_by_periods
end


"""
Split the data into training and validation sets

## parameters:
- time_by_periods : list of the time indexes for each period
- wind_by_periods : list of the wind profiles for each period
- solar_by_periods : list of the solar profiles for each period
- years_train : years to include in the training set
- years_val : years to include in the validation set

## returns: a tuple with the following elements:
- time_train : list of the time indexes for each period in the training set
- wind_train : list of the wind profiles for each period in the training set
- solar_train : list of the solar profiles for each period in the training set
- time_val : list of the time indexes for each period in the validation set
- wind_val : list of the wind profiles for each period in the validation set
- solar_val : list of the solar profiles for each period in the validation set
"""
function train_val_split(time_by_periods, wind_by_periods, solar_by_periods;
    years_train = [2014, 2015, 2016, 2017],
    years_val = [2018],
)
    wind_train = Vector{Vector{Float64}}()
    solar_train = Vector{Vector{Float64}}()
    time_train = Vector{Vector{DateTime}}()
    wind_val = Vector{Vector{Float64}}()
    solar_val = Vector{Vector{Float64}}()
    time_val = Vector{Vector{DateTime}}()
    for i in eachindex(time_by_periods)
        year = Dates.year(time_by_periods[i][1])
        if year in years_train
            push!(wind_train, wind_by_periods[i])
            push!(solar_train, solar_by_periods[i])
            push!(time_train, time_by_periods[i])
        elseif year in years_val
            push!(wind_val, wind_by_periods[i])
            push!(solar_val, solar_by_periods[i])
            push!(time_val, time_by_periods[i])
        end
    end
    return time_train, wind_train, solar_train, time_val, wind_val, solar_val
end