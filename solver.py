from pulp import *
from default_values import *


def solve_fixed_prod_storage_capa(
    wind_capa,
    wind_profile,
    solar_capa,
    solar_profile,
    battery_capa,
    tank_capa,
    demand,
    ebat=EBAT,
    fbat=FBAT,
    eelec=EELEC,
    celec=CELEC,
    initCharge=0,
    initStock=0,
    finalStock=None,
    finalCharge=None,
    price_grid = PRICE_GRID,
):
    """
    Parameters ::
    - wind_capa : Capacity of the wind farm (MW)
    - wind_profile : Wind profile (% of the capacity)
    - solar_capa : Capacity of the solar farm (MW)
    - solar_profile : Solar profile (% of the capacity)
    - battery_capa : Capacity of the battery (MWh)
    - tank_capa : Capacity of the tank (Kg)
    - demand : Demand of hydrogen (Kg)
    - ebat : Efficiency of the battery, in charge loss per month
    - fbat : Maximum flow of energy to / from the battery (MW)
    - eelec : Electricity consumption for 1 Kg of hydrogen (MWh / Kg)
    - celec : Maximum electricity consumption of the electrolyzer (MW)
    - initCharge : Initial charge of the battery (MWh)
    - initStock : Initial stock of the tank (Kg)
    - finalStock : Final stock of the tank (Kg), if None, the final stock is not constrained
    - finalCharge : Final charge of the battery (MWh), if None, the final charge is not constrained \n
    - price_grid : Price of the grid (€ / MWh), high to avoid using the grid / curtailing
    Returns a dictionnary with following keys ::
    - charge : Battery charge (MWh)
    - prod : Production of hydrogen (Kg)
    - stock : Stock of hydrogen in the tank (Kg)
    - elecGrid : Electricity consumption from the grid (MWh)
    - consPPA : Consumption of PPA energy (MWh)
    - flowBat : Flow of energy to / from the battery ( > 0 if charging, < 0 if discharging) (MWh)
    - flowH2 : Flow of hydrogen to / from the tank ( > 0 if charging, < 0 if discharging) (Kg)
    """
    # Create the model
    problem = LpProblem("Production_Problem", LpMinimize)
    T = len(wind_profile)
    if T != len(solar_profile):
        raise ValueError("The wind and solar profiles must have the same length")
    indices = range(T)
    indicesExt = range(T + 1)  # Add the first hour of the period (Final state)
    # Variables
    charge = LpVariable.dicts("charge", indicesExt, 0, None)  # Battery charge (MWh)
    prod = LpVariable.dicts("prod", indices, 0, None)  # Production of hydrogen (Kg)
    stock = LpVariable.dicts(
        "stock", indicesExt, 0, None
    )  # Stock of hydrogen in the tank (Kg)
    elecGrid = LpVariable.dicts(
        "elec", indices, 0, None
    )  # Electricity consumption  from the grid (MWh)
    curtail = LpVariable.dicts(
        "curtail", indices, 0, None
    )  # Curtailing (MWh)
    consPPA = LpVariable.dicts(
        "consPPA", indices, 0, None
    )  # Consumption of PPA energy (MWh)
    flowBat = LpVariable.dicts(
        "flowBat", indices, 0, None
    )  # Flow of energy to / from the battery ( > 0 if charging, < 0 if discharging) (MWh)
    flowH2 = LpVariable.dicts(
        "flowH2", indices, 0, None
    )  # Flow of hydrogen to / from the tank ( > 0 if charging, < 0 if discharging) (Kg)
    # Convert the per month discharge loss to per hour
    ebatPerHour = ebat ** (1 / (30 * 24))
    # Initial state
    problem += charge[0] == initCharge
    problem += stock[0] == initStock

    for t in range(T):
        # PPA constraints, we need to respect the PPA contract
        problem += consPPA[t] == wind_profile[t] * wind_capa + solar_profile[t] * solar_capa
        # Demand satisfaction
        problem += prod[t] == demand + flowH2[t]
        # Electricity consumption
        problem += consPPA[t] + elecGrid[t] - curtail[t] == eelec * prod[t] + flowBat[t]
        # Battery constraints
        problem += ebatPerHour * charge[t] + flowBat[t] == charge[t + 1]
        # Tank constraints
        problem += stock[t] + flowH2[t] == stock[t + 1]
        # Flow constraints
        problem += flowBat[t] <= fbat
        problem += -flowBat[t] <= fbat
        # Electrolyzer constraints
        problem += prod[t] * eelec <= celec

    # We also need to respect those constraints for the final state
    for t in range(T + 1):
        # Capacity constraints for battery and tank
        problem += charge[t] <= battery_capa
        problem += stock[t] <= tank_capa

    # Final state constraints
    if finalStock is not None:
        problem += stock[T] == finalStock

    if finalCharge is not None:
        problem += charge[T] == finalCharge

    # Objective function
    problem += sum(elecGrid[t] * price_grid + curtail[t] * price_grid for t in indices)

    # Solve the problem
    problem.solve(GUROBI_CMD())

    # Return the results

    charge_out = [charge[t].varValue for t in indicesExt]
    prod_out = [prod[t].varValue for t in indices]
    stock_out = [stock[t].varValue for t in indicesExt]
    elecGrid_out = [elecGrid[t].varValue for t in indices]
    curtail_out = [curtail[t].varValue for t in indices]
    consPPA_out = [consPPA[t].varValue for t in indices]
    flowBat_out = [flowBat[t].varValue for t in indices]
    flowH2_out = [flowH2[t].varValue for t in indices]

    return {
        "charge": charge_out,
        "prod": prod_out,
        "stock": stock_out,
        "elecGrid": elecGrid_out,
        "curtail": curtail_out,
        "consPPA": consPPA_out,
        "flowBat": flowBat_out,
        "flowH2": flowH2_out,
    }
