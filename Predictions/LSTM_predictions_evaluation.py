import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from sklearn.preprocessing import MinMaxScaler
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense
from tensorflow.keras.callbacks import EarlyStopping

# Charger les données
column_name = 'DE_wind_generation_actual'
whole_data = pd.read_csv('time_series_60min_singleindex.csv', parse_dates=['utc_timestamp'], index_col='utc_timestamp')
wind_generation = whole_data[column_name].interpolate(method='linear')

# Remove infinite values
wind_generation = wind_generation.replace([np.inf, -np.inf], np.nan).dropna()

wind_generation = wind_generation.values.reshape(-1, 1)

# Normaliser les données
scaler = MinMaxScaler()
wind_generation_scaled = scaler.fit_transform(wind_generation)


# Préparer les données pour l'apprentissage supervisé
def prepare_data(data, time_steps):
    X, y = [], []
    for i in range(len(data) - time_steps):
        X.append(data[i:(i + time_steps), 0])
        y.append(data[i + time_steps, 0])
    return np.array(X), np.array(y)

time_steps = 24  # Nombre d'heures à utiliser pour prédire l'heure suivante
X, y = prepare_data(wind_generation_scaled, time_steps)

# Diviser les données en ensembles d'entraînement et de test
train_size = int(len(X) * 0.8)
X_train, X_test = X[:train_size], X[train_size:]
y_train, y_test = y[:train_size], y[train_size:]

# Remodeler les données pour les rendre compatibles avec l'entrée du LSTM
X_train = X_train.reshape((X_train.shape[0], X_train.shape[1], 1))
X_test = X_test.reshape((X_test.shape[0], X_test.shape[1], 1))

# Créer le modèle LSTM
model = Sequential()
model.add(LSTM(units=50, return_sequences=True, input_shape=(time_steps, 1)))
model.add(LSTM(units=50))
model.add(Dense(units=1))
model.compile(optimizer='adam', loss='mean_squared_error')

# Entraîner le modèle
early_stopping = EarlyStopping(patience=5, restore_best_weights=True)
history = model.fit(X_train, y_train, epochs=3, batch_size=32, validation_split=0.1, callbacks=[early_stopping], verbose=1)

# Évaluer le modèle
train_loss = model.evaluate(X_train, y_train, verbose=0)
test_loss = model.evaluate(X_test, y_test, verbose=0)
print(f'Train Loss: {train_loss:.6f}')
print(f'Test Loss: {test_loss:.6f}')

# Faire des prédictions
# train_predictions = model.predict(X_train)
test_predictions = model.predict(X_test)
# print("Test Predictions:", test_predictions)

# Inverser la transformation pour obtenir les vraies valeurs
# train_predictions = scaler.inverse_transform(train_predictions)
# y_train = scaler.inverse_transform([y_train])
test_predictions = scaler.inverse_transform(test_predictions)
y_test = scaler.inverse_transform([y_test])

# Tracer les résultats
duree_trace = 7*24

plt.figure(figsize=(12, 6))
plt.plot(y_test.flatten()[:duree_trace], label='True Values')
plt.plot(test_predictions.flatten()[:duree_trace], label='Predictions')
plt.title('Wind Generation Forecast - Test Data')
plt.xlabel('Time')
plt.ylabel('Wind Generation')
plt.legend()
plt.grid(True)
plt.show()
