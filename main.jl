# -*- coding: utf-8 -*-
# ---
# jupyter:
#   jupytext:
#     text_representation:
#       extension: .jl
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.15.2
#   kernelspec:
#     display_name: Julia 1.10.1
#     language: julia
#     name: julia-1.10
# ---

# ## Zeroth Step
# ### Importing Libraries and Loading Data

# +
GC.gc() # Clear up the memory when doing a "run all" in the notebook

using Plots
gr()

include("src/load_profiles.jl")
include("src/solver.jl");
# -

filename = "profiles.csv"
time_profiles, wind_profiles, solar_profiles = Dict(), Dict(), Dict()
time_profiles, wind_profiles, solar_profiles = load_profiles(filename);

# ### We first define the global parameters of the problem, to have consistent results across solving methods

# Default values
DEMAND = 1000. # Kg of H2
# Battery parameters
EBAT = 0.9 # per month discharge
FBAT = 100. # MW
COST_BAT = 250000 * 0.0002 # € / MWh
# Electrolyzer parameters
EELEC = 0.050 # Mwh / Kg
COST_ELEC =  1200000 * 0.0004 # € / MW
CAPA_ELEC_UPPER = 1000 # MW
# Tank parameters
COST_TANK = 407. # € / Kg
# Grid parameters
PRICE_GRID = 1000. # € / MWh
PRICE_CURTAILING = 1000. # € / MWh;
PRICE_PENALITY = 10 # € / times changed
# Renewable pricing, from https://atb.nrel.gov/electricity/2022/index
# For now : 20 year lifespan, no discount rate + O&M cost per year
COST_WIND = 1352 * 1000 / 20 + 43 * 1000 # € / MW
COST_SOLAR = 1233 * 1000 / 20 + 23 * 1000 # € / MW
# Upper bound on the battery capacity
CAPA_BAT_UPPER = 24 * DEMAND * EELEC # MW
#Year chosen for the simulation
YEAR = 2015;

# +
function print_solution_propreties(
    output::Dict{String, Any}
)
    # Extract the solution values
    battery_capa = trunc(Int64, output["battery_capa"])
    tank_capa = trunc(Int64, output["tank_capa"])
    electro_capa = trunc(Int64, output["electro_capa"])
    wind_capa = trunc(Int64, output["wind_capa"])
    solar_capa = trunc(Int64, output["solar_capa"])
    storage_cost = output["storage_cost"]
    operating_cost = output["operating_cost"]
    electrolyser_cost = output["electrolyser_cost"]
    electricity_cost = output["electricity_plant_cost"]
    prod_out = output["prod"]
    charge_out = output["charge"]
    stock_out = output["stock"]
    elec_out = output["elecGrid"]
    curtailment_out = output["curtail"]
    consPPA_out = output["elecPPA"];
    # Capacities
    println("Battery capacity: $battery_capa, Tank capacity: $tank_capa kg, Electrolyser capacity: $(electro_capa / EELEC) kg/h")
    println("Wind capacity: $wind_capa MW, Solar capacity: $solar_capa MW \n")
    # Energy Mix 
    mix_in_capacity = wind_capa / (wind_capa + solar_capa)
    mix_in_generation = wind_capa * sum(wind_profile) / (wind_capa * sum(wind_profile) + solar_capa * sum(solar_profile))
    println("Wind proportion in capacity: $mix_in_capacity \nWind proportion in generation: $mix_in_generation \n")
    # Costs
    println("Storage cost: $storage_cost, operating cost: $operating_cost")
    println("Electrolyser cost : $electrolyser_cost, electricity plant cost: $electricity_cost")
    println("Total cost: $(storage_cost + operating_cost + electrolyser_cost + electricity_cost)")

end;
# -

function plot_solution(
    output::Dict
)
    # Extract the solution values
    battery_capa = trunc(Int64, output["battery_capa"])
    tank_capa = trunc(Int64, output["tank_capa"])
    electro_capa = trunc(Int64, output["electro_capa"])
    wind_capa = trunc(Int64, output["wind_capa"])
    solar_capa = trunc(Int64, output["solar_capa"])
    storage_cost = output["storage_cost"]
    operating_cost = output["operating_cost"]
    electrolyser_cost = output["electrolyser_cost"]
    electricity_cost = output["electricity_plant_cost"]
    prod_out = output["prod"]
    charge_out = output["charge"]
    stock_out = output["stock"]
    elec_out = output["elecGrid"]
    curtailment_out = output["curtail"]
    consPPA_out = output["elecPPA"];
    # Plot the production & tank charge over time
    prod = plot(size=(1200, 500), legend=:topleft, xlabel="Time (h)", ylabel="Production (Kg)",
    title="Hydrogen, Demand : $D kg/h, Electrolyser: $(electro_capa / EELEC) kg/h")
    plot!(prod, prod_out, label="Production")
    # Plot the consumptions, curtailment and battery charge
    cons = plot(size=(1200, 500), legend=:topleft, xlabel="Time (h)", ylabel="Electricity consumption (Mwh)",
    title="Consumption, Solar capacity: $(trunc(solar_capa)) MW, Wind capacity: $(trunc(wind_capa)) MW")
    plot!(cons, elec_out, label="Grid consumption")
    plot!(cons, consPPA_out, label="PPA consumption")
    plot!(cons, -curtailment_out, label="Curtailment")
    # Plot the charge levels
    level_bat = plot(size=(1200, 500), legend=:topleft, xlabel="Time (h)", ylabel="Battery charge (Mwh)",
     title="Battery charge level, Battery capacity : $battery_capa MWh")
    plot!(level_bat, charge_out, label="Battery charge")
    level_tank = plot(size=(1200, 500), legend=:topleft, xlabel="Time (h)", ylabel="Tank charge (Kg)",
     title="Tank charge level, Tank capacity : $tank_capa Kg")
    plot!(level_tank, stock_out, label="Tank charge")

    return prod, cons, level_bat, level_tank
end;

# # First Step :
# ## Solve the problem given the production and storage capacities

# We use the default values for now
BAT_SIZE = 400. # MWh
TANK_SIZE = 500. # Kg
ELEC_CAPA = 1000. # MW
time_index = wind_profiles[YEAR]
wind_profile = wind_profiles[YEAR]
solar_profile = solar_profiles[YEAR]
# We decide on a mix of wind and solar
# For example, 25% of the energy comes from solar and 75% from wind
wind_share = 0.75
Total_energy_needed = D * length(wind_profile) * EELEC * 1.05 # in MWh, with a 5% safety margin
wind_capa = Total_energy_needed * wind_share / sum(wind_profile)
solar_capa = Total_energy_needed * (1 - wind_share) / sum(solar_profile);

output1 = solve(
    wind_profile, solar_profile, # WIND_PROFILE, SOLAR_PROFILE
    DEMAND, # DEMAND
    wind_capa, solar_capa, # WIND_CAPA, SOLAR_CAPA, if set to missing, the solver will optimize it
    BAT_SIZE, TANK_SIZE, ELEC_CAPA, # BAT_SIZE, TANK_SIZE, ELEC_CAPA, if set to missing, the solver will optimize it
    PRICE_GRID, PRICE_CURTAILING, PRICE_PENALITY, # PRICE_GRID, PRICE_CURTAILING, PRICE_PENALITY
    CAPA_BAT_UPPER, CAPA_ELEC_UPPER, # CAPA_BAT_UPPER, CAPA_ELEC_UPPER
    EBAT, FBAT, EELEC, # EBAT, FBAT, EELEC
    COST_ELEC, COST_BAT, COST_TANK, # COST_ELEC, COST_BAT, COST_TANK
    COST_WIND, COST_SOLAR, # COST_WIND, COST_SOLAR
    0., # No initial charge
    0., # No initial stock
    missing, # No final charge constraint
    missing, # No final stock constraint
);

print_solution_propreties(output1)

prod1, cons1, bat1, tank1 = plot_solution(output1);

prod1

cons1

bat1

tank1

# # Second Step :
# ## Solve the problem given the production capacities only

# We use the default values for now
D = 1000.
time_index = wind_profiles[YEAR]
wind_profile = wind_profiles[YEAR]
solar_profile = solar_profiles[YEAR]
# We decide on a mix of wind and solar
# For example, 25% of the energy comes from solar and 75% from wind
wind_share = 0.75
Total_energy_needed = D * length(wind_profile) * EELEC * 1.05 # in MWh, with a 5% safety margin
wind_capa = Total_energy_needed * wind_share / sum(wind_profile)
solar_capa = Total_energy_needed * (1 - wind_share) / sum(solar_profile);

output2 = solve(
    wind_profile, solar_profile, # WIND_PROFILE, SOLAR_PROFILE
    DEMAND, # DEMAND
    wind_capa, solar_capa, # WIND_CAPA, SOLAR_CAPA, if set to missing, the solver will optimize it
    missing, missing, missing, # BAT_SIZE, TANK_SIZE, ELEC_CAPA, if set to missing, the solver will optimize it
    PRICE_GRID, PRICE_CURTAILING, PRICE_PENALITY, # PRICE_GRID, PRICE_CURTAILING, PRICE_PENALITY
    CAPA_BAT_UPPER, CAPA_ELEC_UPPER, # CAPA_BAT_UPPER, CAPA_ELEC_UPPER
    EBAT, FBAT, EELEC, # EBAT, FBAT, EELEC
    COST_ELEC, COST_BAT, COST_TANK, # COST_ELEC, COST_BAT, COST_TANK
    COST_WIND, COST_SOLAR, # COST_WIND, COST_SOLAR
    0., # No initial charge
    0., # No initial stock
    missing, # No final charge constraint
    missing, # No final stock constraint
);

print_solution_propreties(output2)

prod2, cons2, bat2, tank2 = plot_solution(output2);

prod2

cons2

bat2

tank2

# # Third Step : 
# ## Solve the problem given the demand only.

D = 1000.
time_index = wind_profiles[YEAR]
wind_profile = wind_profiles[YEAR]
solar_profile = solar_profiles[YEAR];

output3 = solve(
    wind_profile, solar_profile, # WIND_PROFILE, SOLAR_PROFILE
    DEMAND, # DEMAND
    missing, missing, # WIND_CAPA, SOLAR_CAPA, if set to missing, the solver will optimize the capacities
    missing, missing, missing, # BAT_SIZE, TANK_SIZE, ELEC_CAPA, if set to missing, the solver will optimize the capacities
    PRICE_GRID, PRICE_CURTAILING, PRICE_PENALITY, # PRICE_GRID, PRICE_CURTAILING, PRICE_PENALITY
    CAPA_BAT_UPPER, CAPA_ELEC_UPPER, # CAPA_BAT_UPPER, CAPA_ELEC_UPPER
    EBAT, FBAT, EELEC, # EBAT, FBAT, EELEC
    COST_ELEC, COST_BAT, COST_TANK, # COST_ELEC, COST_BAT, COST_TANK
    COST_WIND, COST_SOLAR, # COST_WIND, COST_SOLAR
    0., # No initial charge
    0., # No initial stock
    missing, # No final charge constraint
    missing, # No final stock constraint
);

print_solution_propreties(output3)

prod3, cons3, bat3, tank3 = plot_solution(output3);

prod3

cons3

bat3

tank3
