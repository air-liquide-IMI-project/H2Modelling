using CSV, DataFrames, Impute, Dates

function load_profiles(filename;
    years = [2015, 2016, 2017], 
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

function load_by_periods(filename, period_length = 7;
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
    wind_by_periods = []
    solar_by_periods = []
    time_by_periods = []
    # Split the data into periods
    for i in 1:period_length:length(data.utc_timestamp)
        subData = data[i:min(i+period_length-1, end), :]
        push!(wind_by_periods, subData[!, wind_profile])
        push!(solar_by_periods, subData[!, solar_profile])
        push!(time_by_periods, subData[!, "utc_timestamp"])
        # If some data are missing,
    end
    return time_by_periods, wind_by_periods, solar_by_periods
end