using CSV, DataFrames

function load_nn_predictions(
    filename :: String = "data/wind_preds.csv",
) :: Vector{Vector{Float64}}
    # First load the solar predictions
    # Load the file
    data = CSV.read(filename, DataFrame)
    # Extract the predictions
    solar_train = Matrix(data[:, 2:end])
    # Transform negatives to 0
    solar_train[solar_train .< 0] .= 0

    vector = []

    for i in 1:size(solar_train, 1)
        push!(vector, solar_train[i, :])
    end

    # Then load the wind predictio
    return vector
end

load_nn_predictions()


