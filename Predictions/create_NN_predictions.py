import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from sklearn.preprocessing import MinMaxScaler
from tensorflow.keras.models import Sequential, load_model
from tensorflow.keras.layers import Dense, Flatten
from tensorflow.keras.callbacks import EarlyStopping
from tensorflow.keras.optimizers import Adam

# Charger les données
column_name = 'DE_solar_generation_actual'
whole_data = pd.read_csv('data/profiles.csv', parse_dates=['utc_timestamp'], index_col='utc_timestamp')
# Only keep the data from year 2014 to 2018
whole_data = whole_data.loc['2014-01-01 00:00:00':'2019-01-01 00:00:00']
solar_generation = whole_data[column_name].interpolate(method='linear')

# Remove infinite values
solar_generation = solar_generation.replace([np.inf, -np.inf], np.nan).dropna()

solar_generation = solar_generation.values.reshape(-1, 1)

# Normaliser les données
scaler = MinMaxScaler()
solar_generation_scaled = scaler.fit_transform(solar_generation)

# Préparer les données pour l'apprentissage supervisé
def prepare_data(data, time_steps, output_steps):
    X, y = [], []
    for i in range(len(data) - time_steps - output_steps):
        X.append(data[i:(i + time_steps), 0])
        y.append(data[(i + time_steps):(i + time_steps + output_steps), 0])
    return np.array(X), np.array(y)

time_steps = 6*24  # Nombre d'heures à utiliser pour prédire l'heure suivante
output_steps = 7*24 + 1 # Nombre d'heures à prédire
X, y = prepare_data(solar_generation_scaled, time_steps, output_steps)

# Diviser les données en ensembles d'entraînement et de test
# Find the first index of the year 2018
first_index_2018 = whole_data.index.get_loc('2018-01-01 00:00:00')
train_size = first_index_2018
print("Train size:", train_size)
print("Test size:", len(X) - train_size)
X_train, X_test = X[:train_size], X[train_size:]
y_train, y_test = y[:train_size], y[train_size:]

# Remodeler les données pour les rendre compatibles avec l'entrée du LSTM
X_train = X_train.reshape((X_train.shape[0], X_train.shape[1], 1))
X_test = X_test.reshape((X_test.shape[0], X_test.shape[1], 1))

loaded_model = load_model('Predictions/solar_generation_nn_better_model.h5')

# Faire des prédictions avec le modèle chargé
y_predicted = (loaded_model.predict(X_test))

# Inverser la transformation pour obtenir les vraies valeurs
print(y_predicted.shape)
y_predicted = scaler.inverse_transform(y_predicted)
y_test = scaler.inverse_transform(y_test)

# Only keep the lines with index % 168 == 0
line = 0
y_predicted_output = []
y_test_output = []
while line < len(y_predicted):
    y_predicted_output.append(y_predicted[line])
    y_test_output.append(y_test[line])
    line += 168

with open("data/solar_preds.csv", 'w') as f:
    np.savetxt(f, y_predicted_output, fmt='%f', delimiter=',')
    #np.savetxt(f, y_test_output, fmt='%f')