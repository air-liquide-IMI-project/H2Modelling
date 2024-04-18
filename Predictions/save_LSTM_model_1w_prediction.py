import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from sklearn.preprocessing import MinMaxScaler
from tensorflow.keras.models import Sequential, load_model
from tensorflow.keras.layers import LSTM, Dense, Dropout
from tensorflow.keras.callbacks import EarlyStopping
from tensorflow.keras.optimizers import Adam

# Charger les données
column_name = 'DE_solar_generation_actual'
whole_data = pd.read_csv('time_series_60min_singleindex.csv', parse_dates=['utc_timestamp'], index_col='utc_timestamp')
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
output_steps = 7*24  # Nombre d'heures à prédire
X, y = prepare_data(solar_generation_scaled, time_steps, output_steps)

# Diviser les données en ensembles d'entraînement et de test
train_size = int(len(X) * 0.8)
X_train, X_test = X[:train_size], X[train_size:]
y_train, y_test = y[:train_size], y[train_size:]

# Remodeler les données pour les rendre compatibles avec l'entrée du LSTM
X_train = X_train.reshape((X_train.shape[0], X_train.shape[1], 1))
X_test = X_test.reshape((X_test.shape[0], X_test.shape[1], 1))

units1=80
units2=50
units3=80

# Créer le modèle LSTM
model = Sequential()
model.add(LSTM(units=units1, return_sequences=True, input_shape=(time_steps, 1)))
model.add(Dropout(0.2))

model.add(LSTM(units=units2, return_sequences=True))
model.add(Dropout(0.2))

model.add(LSTM(units=units3))
model.add(Dropout(0.2))

# Output layer
model.add(Dense(units=output_steps, activation='linear'))

optimizer = Adam(learning_rate=0.001)
model.compile(optimizer=optimizer, loss='mean_squared_error')

# Entraîner le modèle
early_stopping = EarlyStopping(patience=5, restore_best_weights=True)
history = model.fit(X_train, y_train, epochs=2, batch_size=32, validation_split=0.1, callbacks=[early_stopping], verbose=1)

# Sauvegarder le modèle
model.save('solar_generation_lstm_model.h5')

# Évaluer le modèle chargé
train_loss = model.evaluate(X_train, y_train, verbose=0)
test_loss = model.evaluate(X_test, y_test, verbose=0)
print(f'Train Loss: {train_loss:.6f}')
print(f'Test Loss: {test_loss:.6f}')

# Faire des prédictions avec le modèle chargé
test_predictions = model.predict(X_test[0:1])

# Inverser la transformation pour obtenir les vraies valeurs
test_predictions = scaler.inverse_transform(test_predictions)
y_test_ = scaler.inverse_transform(y_test[0:1].reshape(-1, 1))

# Tracer les résultats
plt.figure(figsize=(12, 6))
plt.plot(y_test_.flatten(), label='True Values')
plt.plot(test_predictions.flatten(), label='Predictions')
plt.title('Solar Generation Forecast - Test Data')
plt.xlabel('Time (hours)')
plt.ylabel('Solar Generation')
plt.legend()
plt.grid(True)
plt.show()
