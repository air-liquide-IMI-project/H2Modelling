# Default values
DEMAND = 1000. # Kg of H2
# Electrolyzer parameters
EELEC = 0.050 # MWh / Kg
COST_ELEC =  1200000 * 0.0004 # € / MW
CAPA_ELEC_UPPER = 1000 # MW
# Battery parameters
EBAT = 0.9 # per month discharge
FBAT = 100. # MW
COST_BAT = 250000 * 0.0002 # € / MWh
CAPA_BAT_UPPER = 12 * DEMAND * EELEC # MW, 12 hours of production
# Tank parameters
COST_TANK = 407. # € / Kg
# Grid parameters
PRICE_GRID = 1000. # € / MWh
PRICE_CURTAILING = 500. # € / MWh;
PRICE_PENALITY = 10 # € / kg of change in production level
# Renewable pricing, from https://atb.nrel.gov/electricity/2022/index
# For now : 20 year lifespan, no discount rate + O&M cost per year
COST_WIND = 1352 * 1000 / 20 + 43 * 1000 # € / MW
COST_SOLAR = 1233 * 1000 / 20 + 23 * 1000 # € / MW
#Year chosen for the simulation
YEAR = 2014;
# CHOSEN CAPACITIES
ELECTRO_CAPA = 1720 * EELEC # MW
TANK_CAPA = 50978 # Kg
BATTERY_CAPA = 300; # MWh
WIND_CAPA = 132 # MW
SOLAR_CAPA = 196; # MW
