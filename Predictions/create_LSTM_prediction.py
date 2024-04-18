import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from sklearn.preprocessing import MinMaxScaler
from tensorflow.keras.models import Sequential, load_model
from tensorflow.keras.layers import LSTM, Dense
from tensorflow.keras.callbacks import EarlyStopping

# Charger les données
column_name = 'DE_solar_generation_actual'
whole_data = pd.read_csv('time_series_60min_singleindex.csv', parse_dates=['utc_timestamp'], index_col='utc_timestamp')
wind_generation = whole_data[column_name].interpolate(method='linear')

# Remove infinite values
wind_generation = wind_generation.replace([np.inf, -np.inf], np.nan).dropna()

wind_generation = wind_generation.values.reshape(-1, 1)

# Normaliser les données
scaler = MinMaxScaler()
wind_generation_scaled = scaler.fit_transform(wind_generation)

# Préparer les données pour l'apprentissage supervisé
def prepare_data(data, time_steps):  # Methode heure par heure
    X, y = [], []
    for i in range(len(data) - time_steps):
        X.append(data[i:(i + time_steps), 0])
        y.append(data[i + time_steps, 0])
    return np.array(X), np.array(y)

# Actualiser les données lorsque des prédictions sont faites
def actualize_data(X, y, time, value):
    for i in range(min(time_steps, len(X)-time-1)):
        X[time+1+i][time_steps-1-i] = value
    y[time]=value

time_steps = 2*24  # Nombre d'heures à utiliser pour prédire l'heure suivante
X, y = prepare_data(wind_generation_scaled, time_steps)

# Diviser les données en ensembles d'entraînement et de test
train_size = int(len(X) * 0.8)
periode_de_prevision = 7*24
X_test = X[train_size:train_size+periode_de_prevision]
y_test = y[train_size:train_size+periode_de_prevision]
y_predicted = np.zeros(periode_de_prevision)

# Remodeler les données pour les rendre compatibles avec l'entrée du LSTM
X_test = X_test.reshape((X_test.shape[0], X_test.shape[1], 1))
print(X_test.shape)

# Charger le modèle
loaded_model = load_model('wind_generation_lstm_model.h5')


# Faire des prédictions avec le modèle chargé
for t in range(periode_de_prevision):
    test_prediction = (loaded_model.predict(X_test[t:t+1]))[0, 0]
    actualize_data(X_test, y_predicted, t, test_prediction)

# Inverser la transformation pour obtenir les vraies valeurs
y_predicted = scaler.inverse_transform([y_predicted])
y_test = scaler.inverse_transform([y_test])

# Tracer les résultats

plt.figure(figsize=(12, 6))
plt.plot(y_test.flatten(), label='True Values')
plt.plot(y_predicted.flatten(), label='Predictions')
plt.title('Solar Generation Forecast - Test Data')
plt.xlabel('Time')
plt.ylabel('Solar Generation')
plt.legend()
plt.grid(True)
plt.show()