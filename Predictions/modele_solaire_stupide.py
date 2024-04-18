import math
import pandas as pd
import numpy as np
import scipy.stats as stats
import matplotlib.pyplot as plt
from sklearn.preprocessing import MinMaxScaler

# The data that we want to analyse
column_name = 'DE_solar_generation_actual'

# Load the data
whole_data = pd.read_csv('time_series_60min_singleindex.csv', parse_dates=['utc_timestamp'], index_col='utc_timestamp')
solar_generation = whole_data[column_name].interpolate(method='linear')

# Remove infinite values
solar_generation = solar_generation.replace([np.inf, -np.inf], np.nan).dropna()
jour = 10

moyenne_annuelle = (27000-5000)/2

def production_solaire(jour, heure_debut_trace, duree_trace):
    heures_trace = [(heure_debut_trace+i)%24 for i in range(duree_trace)]
    return [(moyenne_annuelle + moyenne_annuelle*math.sin(math.pi*jour/365))*max(math.sin(math.pi*(heure-3)/14), 0) for heure in heures_trace]

debut_trace = (4*365+10)*24-11
duree_trace = 24
heure_debut_trace = solar_generation.index[debut_trace].hour
vraies_valeurs = solar_generation[debut_trace:debut_trace+duree_trace]
valeurs_predictions = production_solaire(jour, heure_debut_trace, duree_trace)

# Tracé des tirages successifs
plt.figure(figsize=(10, 6))
plt.plot(list(range(duree_trace)), vraies_valeurs)
plt.plot(list(range(duree_trace)), valeurs_predictions)
plt.title('Tirages successifs de la distribution de Weibull')
plt.xlabel('Index')
plt.ylabel('Valeurs de la distribution de Weibull')
plt.legend()
plt.grid(True)
plt.show()


'''
# Exemple d'utilisation
periode_echantillonage = 100
temps = list(range(periode_echantillonage))


transformee_fourier = np.fft.fft(solar_generation)
nb_coef = 50000
serie_reconstruite = np.real(np.fft.ifft(transformee_fourier[:nb_coef]))

plt.figure(figsize=(10, 6))
plt.plot(temps, solar_generation[:periode_echantillonage], label='Série originelle')
plt.plot(temps, serie_reconstruite[:periode_echantillonage], label='Série reconstruite')
plt.xlabel('Temps (h)')
plt.ylabel('Valeurs')
plt.title('Transformée de Fourier')
plt.legend()
plt.grid(True)
plt.show()
'''

def production_solaire_moyenne_variable(debut_trace, duree_trace):
    jour_debut_trace = (debut_trace%(int(365.25*24)))//24
    dist_premier_janvier = min(jour_debut_trace, 365-jour_debut_trace)
    duree_journee = ((dist_premier_janvier)/182.5)*14+(np.abs(jour_debut_trace-182.5)/182.5)*8
    heure_decalage = ((dist_premier_janvier)/182.5)*3+(np.abs(jour_debut_trace-182.5)/182.5)*7
    heure_debut_trace = solar_generation.index[debut_trace].hour
    moyenne_derniers_jours = np.array([np.max(solar_generation[debut_trace-(i+1)*24:debut_trace-i*24]) for i in range(6)])
    moyenne_mobile = np.mean(moyenne_derniers_jours)
    heures_trace = [(heure_debut_trace+i)%24 for i in range(duree_trace)]
    return [moyenne_mobile*max(math.sin(math.pi*(heure-heure_decalage)/duree_journee), 0) if ((heure-heure_decalage)/duree_journee <= 1 and 0 <= (heure-heure_decalage)/duree_journee) else 0. for heure in heures_trace]

vraies_valeurs = solar_generation[debut_trace:debut_trace+duree_trace]
valeurs_predictions = production_solaire_moyenne_variable(debut_trace, duree_trace)

# Tracé des tirages successifs
plt.figure(figsize=(10, 6))
plt.plot(list(range(duree_trace)), vraies_valeurs, label="Série originelle")
plt.plot(list(range(duree_trace)), valeurs_predictions, label="Modèle simple")
plt.title('Comparaison série temporelle et modèle simple')
plt.xlabel('Index')
plt.ylabel('Valeurs de la série')
plt.legend()
plt.grid(True)
plt.show()


solar_generation_scaled = solar_generation.values.reshape(-1, 1)
scaler = MinMaxScaler()
solar_generation_scaled = scaler.fit_transform(solar_generation_scaled)
train_test_separation = int(0.8*len(solar_generation))
mse_array = []
duree_trace = 7*24
for start in range(train_test_separation, len(solar_generation)-duree_trace, 7*24):
    debut_trace = start
    vraies_valeurs = solar_generation_scaled[debut_trace:debut_trace+duree_trace]
    valeurs_predictions = np.array(production_solaire_moyenne_variable(debut_trace, duree_trace)).reshape(-1, 1)
    valeurs_predictions = scaler.transform(valeurs_predictions)
    mse = np.mean((vraies_valeurs - valeurs_predictions)**2)
    mse_array.append(mse)
mse_array = np.array(mse_array)
print(np.mean(mse_array))

# MSE : 0.008568138154270027