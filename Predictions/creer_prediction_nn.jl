using Flux
using Knet
using BSON

using CSV
using DataFrames
using Statistics
using HDF5

mutable struct MinMaxScaler
    feature_range::Tuple{Float64, Float64}
    min_values::Vector{Float64}
    max_values::Vector{Float64}
end

function MinMaxScaler(feature_range::Tuple{Float64, Float64}=(0.0, 1.0))
    return MinMaxScaler(feature_range, Float64[], Float64[])
end

function fit!(scaler::MinMaxScaler, data::Vector{T}) where T
    scaler.min_values = [minimum(data)]
    scaler.max_values = [maximum(data)]
end

function fit!(scaler::MinMaxScaler, data::Matrix{T}) where T
    scaler.min_values = minimum(data, dims=1)
    scaler.max_values = maximum(data, dims=1)
end

function transform!(scaler::MinMaxScaler, data::Matrix{T}) where T
    min_vals = scaler.min_values
    max_vals = scaler.max_values
    feature_range = scaler.feature_range
    scaled_data = similar(data, T, size(data))
    for i in axes(data, 2)
        min_val = min_vals[i]
        max_val = max_vals[i]
        scaled_data[:, i] .= (data[:, i] .- min_val) ./ (max_val - min_val) * (feature_range[2] - feature_range[1]) .+ feature_range[1]
    end
    return scaled_data
end

function transform!(scaler::MinMaxScaler, data::Vector{T}) where T
    min_val = scaler.min_values[1]
    max_val = scaler.max_values[1]
    feature_range = scaler.feature_range
    scaled_data = similar(data, T, length(data))
    scaled_data .= (data .- min_val) ./ (max_val - min_val) * (feature_range[2] - feature_range[1]) .+ feature_range[1]
    return scaled_data
end

function inverse_transform!(scaler::MinMaxScaler, data::Matrix{T}) where T
    min_vals = scaler.min_values
    max_vals = scaler.max_values
    feature_range = scaler.feature_range
    inverse_scaled_data = similar(data, T, size(data))
    for i in axes(data, 2)
        min_val = min_vals[i]
        max_val = max_vals[i]
        inverse_scaled_data[:, i] .= (data[:, i] .- feature_range[1]) ./ (feature_range[2] - feature_range[1]) .* (max_val - min_val) .+ min_val
    end
    return inverse_scaled_data
end

# Charger les données
column_name = "DE_solar_generation_actual"
whole_data = DataFrame(CSV.File("time_series_60min_singleindex.csv", dateformat="yyyy-mm-dd HH:MM:SS"))

whole_data[!, column_name] = coalesce.(whole_data[!, column_name], NaN)
# Remplacer les valeurs infinies par des NaN et supprimer les lignes contenant des NaN
solar_generation = dropmissing(whole_data, [column_name])

# Réorganiser les données en un tableau 2D
# solar_generation = Matrix(reshape(solar_generation[!, column_name], :, 1))
solar_generation = whole_data[!, column_name]

# Normaliser les données
scaler = MinMaxScaler()
fit!(scaler, solar_generation)
solar_generation_scaled = transform!(scaler, solar_generation)

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

function load_keras_model(model_file::AbstractString)
    # Load the Keras model from the HDF5 file
    weights_dict = h5open(model_file) do file
        Dict(k => try read(file[k])[:] catch; read(file[k]) end for k in keys(file))
    end
    # Extract layer names from the nested dictionaries
    layer_names = []
    for (layer_name, layer_weights) in weights_dict["model_weights"]
        if isa(layer_weights, Dict)
            push!(layer_names, layer_name)
        end
    end

    println("Layer names found in the model_weights dictionary:")
    println(layer_names)
    # Define the Flux model architecture
    model = Chain(
        Dense(6*24, 6*24, Flux.relu),
        Flux.flatten,
        Dense(6*24, 7*24, Flux.relu),
        Dense(7*24, 7*24, Flux.relu),
        Dense(7*24, 7*24)
    )
    println("Layer names in Flux model:")
    Flux.summary(model)
    # Load the weights into the model
    Flux.loadparams!(model, weights_dict["model_weights"])
    

    return model
end
function get_layer_by_name(model::Chain, name::String)
    for layer in Flux.params(model)
        if get_name(layer) == name
            return layer
        end
    end
    println("Layer $name not found in model")
end

function get_name(layer)
    if hasproperty(layer, :name)
        return getfield(layer, :name)
    else
        return ""
    end
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