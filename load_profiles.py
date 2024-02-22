import pandas as pd
import numpy as np


def load_profiles(filename, profile_names = []):

    # Load the data
    data = pd.read_csv(filename)
    print(data.head())
    columns = data.columns
    #filter the columns
    

    # Create a dictionary to store the profiles
    profiles = {}

    # Extract the profiles
    for profile_name in profile_names:
        profiles[profile_name] = np.array(data[profile_name])

    return profiles


if __name__ == "__main__":
    profiles = load_profiles("profiles.csv")
    print(profiles)