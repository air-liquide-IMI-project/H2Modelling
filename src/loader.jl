using CSV
using DataFrames
using Dates
using Impute

function load_profiles(filename, years = [2015, 2016, 2017], verbose = false, wind_profile = "DE_wind_profile", solar_profile = "DE_solar_profile")
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