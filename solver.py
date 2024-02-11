from pulp import *
 
# Default values
D = 1000 # Kg of H2
PPA = [50] * 18 + [40, 30, 20, 10, 0, 50] # Mwh
PPPA = 20 # € / MWh
PT = [20.79, 17.41, 16.24, 11.9, 9.77, 15.88, 24.88, 29.7, 35.01, 33.95, 29.9, 29.03] # € / MWh
PT += [27.07, 26.43, 27.53, 29.05, 31.42, 39.92, 41.3, 41.51, 39.75, 30.13, 30.36, 32.4]

EBAT = 0.9
CBAT = 400 # MWh
FBAT = 100 # MW

EELEC = 0.050 # Mwh / Kg
CELEC = 1000 # MW

CTANK = 500 # Kg

def solve(demand = D, ppa = PPA, pppa = PPPA, pt = PT, ebat = EBAT, cbat = CBAT, fbat = FBAT, eelec = EELEC, celec = CELEC, ctank = CTANK):
    """
    Parameters ::
    - demand : Demand of hydrogen (Kg), constant
    - ppa : Array of PPA energy that must be consummed(MWh)
    - pppa : Price of PPA energy (€ / MWh)
    - pt : Price of energy from the grid (€ / MWh)
    - ebat : Efficiency of the battery, in charge loss per month
    - cbat : Capacity of the battery (MWh)
    - fbat : Maximum flow of energy to / from the battery (MW)
    - eelec : Electricity consumption for 1 Kg of hydrogen (MWh / Kg)
    - celec : Maximum electricity consumption of the electrolyzer (MW)
    - ctank : Capacity of the tank (Kg) \n
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
    problem = LpProblem("Production Problem", LpMaximize)
    T = len(PPA) # Number of hours
    indices = range(T) 
    indicesExt = range(T+1) # Add the first hour of the next day (Final state)
    # Variables
    charge = LpVariable.dicts("charge", indicesExt, 0, None) # Battery charge (MWh)
    prod = LpVariable.dicts("prod", indices, 0, None) # Production of hydrogen (Kg)
    stock = LpVariable.dicts("stock", indicesExt, 0, None) # Stock of hydrogen in the tank (Kg)
    elecGrid = LpVariable.dicts("elec", indices, 0, None) # Electricity consumption from the grid (MWh)
    consPPA = LpVariable.dicts("consPPA", indices, 0, None) # Consumption of PPA energy (MWh)
    flowBat = LpVariable.dicts("flowBat", indices, 0, None) # Flow of energy to / from the battery ( > 0 if charging, < 0 if discharging) (MWh)
    flowH2 = LpVariable.dicts("flowH2", indices, 0, None) # Flow of hydrogen to / from the tank ( > 0 if charging, < 0 if discharging) (Kg)
    # Convert the per month discharge loss to per hour
    ebatPerHour = ebat**(1/(30*24))
    #Initial state
    problem += charge[0] == 0
    problem += stock[0] == 0

    for t in range(T):
        # PPA constraints, we need to respect the PPA contract
        problem += consPPA[t] == ppa[t] 
        # Electricity consumption
        problem += consPPA[t] + elecGrid[t] == eelec * prod[t] + flowBat[t]
        # Battery constraints
        problem += ebatPerHour * charge[t] + flowBat[t] == charge[t+1]
        # Demand satisfaction
        problem += prod[t] == demand + flowH2[t]
        # Tank constraints
        problem += stock[t] + flowH2[t] == stock[t+1]
        # Flow constraints
        problem += flowBat[t] <= fbat
        problem += -flowBat[t] <= fbat
        # Electrolyzer constraints
        problem += prod[t] * eelec <= celec

    # We also need to respect those constraints for the final state
    for t in range(T+1):
        # Capacity constraints for battery and tank
        problem += charge[t] <= cbat
        problem += stock[t] <= ctank

    # Objective function
    problem += sum([pppa * consPPA[t] + pt[t] * elecGrid[t] for t in indices])

    # Solve the problem
    problem.solve()

    # Return the results

    charge_out = [charge[t].varValue for t in indicesExt]
    prod_out = [prod[t].varValue for t in indices]
    stock_out = [stock[t].varValue for t in indicesExt]
    elecGrid_out = [elecGrid[t].varValue for t in indices]
    consPPA_out = [consPPA[t].varValue for t in indices]
    flowBat_out = [flowBat[t].varValue for t in indices]
    flowH2_out = [flowH2[t].varValue for t in indices]

    return {
        "charge" : charge_out,
        "prod" : prod_out,
        "stock" : stock_out,
        "elecGrid" : elecGrid_out,
        "consPPA" : consPPA_out,
        "flowBat" : flowBat_out,
        "flowH2" : flowH2_out
    }

