using Flux
using Knet
using BSON

using CSV
using DataFrames
using Statistics
using ScikitLearn: fit_transform
using ScikitLearn: fit_transform!

# Charger les données
column_name = "DE_solar_generation_actual"
whole_data = DataFrame(CSV.File("time_series_60min_singleindex.csv", dateformat="yyyy-mm-dd HH:MM:SS"))
solar_generation = dropmissing(whole_data[column_name])

# Remplacer les valeurs infinies par des NaN et supprimer les lignes contenant des NaN
solar_generation = dropmissing(replace(solar_generation, [missing, Inf, -Inf] => NaN))

# Réorganiser les données en un tableau 2D
solar_generation = Matrix(reshape(solar_generation[column_name], :, 1))

# Normaliser les données
scaler = fit_transform(MinMaxScaler(), solar_generation)
solar_generation_scaled = fit_transform!(scaler, solar_generation)

# Préparer les données pour l'apprentissage supervisé
function prepare_data(data, time_steps, output_steps)
    X, y = [], []
    for i in 1:(size(data, 1) - time_steps - output_steps)
        push!(X, data[i:(i + time_steps - 1), 1])
        push!(y, data[(i + time_steps):(i + time_steps + output_steps - 1), 1])
    end
    return hcat(X...)', hcat(y...)'  # Transposer les matrices pour obtenir des colonnes pour chaque échantillon
end

time_steps = 6 * 24  # Nombre d'heures à utiliser pour prédire l'heure suivante
output_steps = 7 * 24  # Nombre d'heures à prédire
X, y = prepare_data(solar_generation_scaled, time_steps, output_steps)

X = reshape(X, (size(X, 1), size(X, 2), 1))


# Define the function to load the Keras model
function load_keras_model(model_file::AbstractString)
    # Load the Keras model from the HDF5 file
    loaded_model = Knet.load(model_file)

    # Convert the Keras model to a Flux model
    flux_model = Chain(loaded_model)

    return flux_model
end

# Define the path to the Keras model file
model_file = "solar_generation_nn_better_model.h5"

# Load the Keras model using the defined function
model = load_keras_model(model_file)

# Faire des prédictions sur les données de test
prediction_start_index = 500
test_predictions = model(X[prediction_start_index:prediction_start_index,:])  # Assurez-vous de modifier l'indexation si nécessaire

# Inverser la transformation pour obtenir les vraies valeurs
test_predictions = inverse_transform!(scaler, test_predictions)
println(test_predictions)