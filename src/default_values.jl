# Default values
D = 1000 # Kg of H2
# Battery parameters
EBAT = 0.9
CBAT = 400 # MWh
FBAT = 100 # MW
COST_BAT = 250000 * 0.0002 # € / MWh
CAPA_BAT_UPPER = 40000 # MWh, 10 GWh
# Electrolyzer parameters
EELEC = 0.050 # Mwh / Kg
CELEC = 1000 # MW
COST_ELEC =  1200000 * 0.0004 # € / MW
# Tank parameters
CTANK = 500 # Kg
COST_TANK = 407 # € / Kg
# Grid parameters
PRICE_GRID = 1000 # € / MWh
PRICE_CURTAILING = 1000 # € / MWh
PRICE_PENALITY = 0 # € / Times changed
# Renewable pricing, from https://atb.nrel.gov/electricity/2022/index
PRICE_WIND = 1352 * 1000 # € / MW
PRICE_SOLAR = 1233 * 1000 # € / MW
