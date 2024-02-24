import pandas as pd
import numpy as np


def load_profiles(filename, profile_names = []):
    # Load the data
    data = pd.read_csv(filename)
    # Format the time column and set it as the index
    timeColumn = "utc_timestamp"
    time = pd.to_datetime(data[timeColumn], format='%Y-%m-%dT%H:%M:%SZ', utc=True)
    data.set_index(time, inplace=True)
    # Drop the columns that are not needed
    for column in data.columns:
        if column not in profile_names:
            data = data.drop(column, axis=1)
    # Remove the NA values
    data = data.interpolate(method='time')
    # Return the data
    return data

if __name__ == "__main__":
    profiles = load_profiles("profiles.csv", ["DE_wind_profile", "DE_solar_profile"])
    print(profiles.head())