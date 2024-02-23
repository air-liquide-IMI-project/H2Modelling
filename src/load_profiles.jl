using CSV
using DataFrames
using Dates

function load_profiles(filename, years = [2015, 2016, 2017], time = "utc_timestamp", wind_profile = "DE_wind_profile", solar_profile = "DE_solar_profile")
    # Load the file
    data = CSV.read(filename, DataFrame)
    # Time column
    data.utc_timestamp = chop.(data.utc_timestamp, tail=1)
    data.utc_timestamp = DateTime.(data.utc_timestamp)
    # Remove the columns that are not needed
    profile_names = [time, wind_profile, solar_profile]
    data = select(data, Cols(in(profile_names)))
    # Only keep the year that are needed
    windProfiles = Dict()
    solarProfiles = Dict()
    timeIndexes = Dict()
    # for year in years
    #     subData = subset(data, Dates.year.(data.utc_timestamp) .== year)
    #     windProfiles[year] = subData[!, wind_profile]
    #     solarProfiles[year] = subData[!, solar_profile]
    #     timeIndexes[year] = subData[!, utc_timestamp]
    # end

    # return timeIndexes, windProfiles, solarProfiles
    return data
end