using JuMP, Gurobi, HiGHS
include("default_values.jl")


"""
## Arguments
- wind_profile : Wind profile (% of the capacity)
- solar_profile : Solar profile (% of the capacity)
- wind_capa : Capacity of the wind farm (MW), if missing, is considered a variable to optimize
- solar_capa : Capacity of the solar farm (MW), if missing, is considered a variable to optimize
- battery_capa : Capacity of the battery (MWh), if missing, is considered a variable to optimize
- tank_capa : Capacity of the tank (Kg), if missing, is considered a variable to optimize
- elec_capa : Capacity of the electrolyzer (MW), if missing, is considered a variable to optimize
- demand : Demand of hydrogen (Kg)
- price_grid : Price of the grid (€ / MWh)
- price_curtailing : Price of the curtailed energy (€ / MWh)
- price_penality: Penality for changing the production (€ / times the production changes)
- price_prod_change : Price for changing the production, per Kg of change (€ / Kg of change)
- ebat : Efficiency of the battery, discharge per month
- fbat : Maximum flow of the battery (MW)
- eelec : Efficiency of the electrolyzer (MWh / Kg)
- cost_elec : Cost of the electrolyzer (€ / MW)
- cost_bat : Cost of the battery (€ / MWh)
- cost_tank : Cost of the tank (€ / Kg)
- cost_wind : Cost of installing a wind turbine (€ / MW)
- cost_solar : Cost of installing a solar panel (€ / MW)
- initCharge : Initial charge of the battery (MWh)
- initStock : Initial stock of the tank (Kg)
- finalStock : Final stock of the tank (Kg), if None, the final stock is not constrained
- finalCharge : Final charge of the battery (MWh), if None, the final charge is not constrained
## Returns a dictionnary with following keys
- wind_capa : Capacity of the wind farm (MW)
- solar_capa : Capacity of the solar farm (MW)
- battery_capa : Capacity of the battery (MWh)
- tank_capa : Capacity of the tank (Kg)
- electro_capa : Capacity of the electrolyzer (MW)
- charge : Battery charge (MWh)
- prod : Production of hydrogen (Kg)
- stock : Stock of hydrogen in the tank (Kg)
- elecGrid : Electricity consumption from the grid (MWh)
- consPPA : Consumption of PPA energy (MWh)
- flowBat : Flow of energy to / from the battery ( > 0 if charging, < 0 if discharging) (MWh)
- flowH2 : Flow of hydrogen to / from the tank ( > 0 if charging, < 0 if discharging) (Kg)
- operating_cost : Operating cost (€)
- storage_cost : Construction cost of the storage (€)
- electrolyser_cost : Construction cost of the electrolyzer (€)
- electricity_plant_cost : Construction cost of the electricity production (€)
"""
function solve(
    windProfile :: Array{Float64, 1},
    solarProfile :: Array{Float64, 1},
    demand :: Float64,
    windCapa = missing,
    solarCapa = missing,
    batteryCapa  = missing,
    tankCapa = missing,
    electroCapa = missing,
    price_grid = PRICE_GRID,
    price_curtailing = PRICE_CURTAILING,
    price_penality = PRICE_PENALITY, # Penality for changing the production
    price_prod_change = PRICE_PROD_CHANGE, # Price for changing the production, per Kg of change.
    capa_bat_upper = CELEC, # Upper bound for the electrolyzer capacity
    capa_elec_upper = CAPA_BAT_UPPER, # Upper bound for the battery capacity
    ebat = EBAT,
    fbat = FBAT,
    eelec = EELEC,
    cost_elec = COST_ELEC,
    cost_bat = COST_BAT,
    cost_tank = COST_TANK,
    cost_wind = PRICE_WIND,
    cost_solar = PRICE_SOLAR,
    initCharge =  0.,
    initStock = 0.,
    finalCharge = missing,
    finalStock = missing
)
    # Number of time steps
    T = length(windProfile)
    if length(solarProfile) != T
        throw(ArgumentError("The length of the solar profile should be equal to the length of the wind profile"))
    end

    # Only use one way to penalize production change
    if price_penality > 0 && price_prod_change > 0
        throw(ArgumentError("Only one way to penalize production change should be used"))
    end

    # Create the model
    model = Model(Gurobi.Optimizer)
    println("Adding variables ... ")
    # Electricity production capacities
    if ismissing(windCapa)
        windCapa = @variable(model, lower_bound = 0.)
    end
    if ismissing(solarCapa)
        solarCapa = @variable(model, lower_bound = 0.)
    end
    # Storage variables
    if ismissing(batteryCapa)
        batteryCapa = @variable(model, lower_bound = 0., upper_bound = capa_bat_upper)
    end
    if ismissing(tankCapa)
        tankCapa = @variable(model, lower_bound = 0.)
    end
    # Electrolyser capacity
    if ismissing(electroCapa)
        electroCapa = @variable(model, lower_bound = 0., upper_bound = capa_elec_upper)
    end
    # Main variables
    charge = @variable(model, [1:T+1], lower_bound = 0.)
    stock = @variable(model, [1:T+1], lower_bound = 0.)
    prod = @variable(model, [1:T], lower_bound = 0.)
    # Electricity consumption
    elecPPA = @variable(model, [1:T], lower_bound = 0.)
    elecGrid = @variable(model, [1:T], lower_bound = 0.)
    curtailing = @variable(model, [1:T], lower_bound = 0.)
    # Flow of elecricity / hydrogen
    flowBat = @variable(model, [1:T])
    flowH2 = @variable(model, [1:T])
    # Production changing penality
    if price_penality > 0
        prodHasChanged = @variable(model, [2:T], Bin)
    end

    if price_prod_change > 0
        prodChange_cost = @variable(model, [2:T])
    end
    # Costs pseudo-variables
    operating_cost = @variable(model)
    storage_cost = @variable(model)
    electrolyser_cost = @variable(model)
    electricity_plant_cost = @variable(model)

    println("Adding constraints ... ")
    # Initial charge & stock
    @constraint(model, charge[1] == initCharge)
    @constraint(model, stock[1] == initStock)
    # Final charge & stock
    if !ismissing(finalCharge)
        @constraint(model, charge[T+1] == finalCharge)
    end
    if !ismissing(finalStock)
        @constraint(model, stock[T+1] == finalStock)
    end
    # Get the per hour discharge of the batteryn from the per month parameter
    perHourDischarge = ebat ^ (1 / (30 * 24))
    # PPA contract
    @constraint(model, [t ∈ 1:T], elecPPA[t] == windProfile[t] * windCapa + solarProfile[t] * solarCapa)
    # Demand satisfaction
    @constraint(model, [t ∈ 1:T], prod[t] == flowH2[t] + demand)
    # Electricity consumption
    @constraint(model, [t ∈ 1:T], elecGrid[t] + elecPPA[t] - curtailing[t] == prod[t] * EELEC + flowBat[t])
    # Battery charge
    @constraint(model, [t ∈ 1:T], charge[t+1] == perHourDischarge * charge[t] + flowBat[t])
    # Tank stock
    @constraint(model, [t ∈ 1:T], stock[t+1] == 1 * stock[t] + flowH2[t])
    # Flow of electricity / hydrogen
    @constraint(model, [t ∈ 1:T], -fbat <= flowBat[t] <= fbat)
    # # Can't fill in less than 10 hours
    # @constraint(model, [t ∈ 1:T], flowBat[t] <= batteryCapa / 10)
    # @constraint(model, [t ∈ 1:T], - flowBat[t] <= batteryCapa / 10)
    # @constraint(model, [t ∈ 1:T], flowH2[t] <= tankCapa / 10)
    # @constraint(model, [t ∈ 1:T], - flowH2[t] <= tankCapa / 10)
    # Electrolyzer consumption
    @constraint(model, [t ∈ 1:T], prod[t] * eelec <= electroCapa)
    # Maximum charge & stock
    @constraint(model, [t ∈ 1:T+1], charge[t] <= batteryCapa)
    @constraint(model, [t ∈ 1:T+1], stock[t] <= tankCapa)
    # Boolean variable for production change
    if price_penality > 0
        @constraint(model, [t ∈ 2:T], prod[t] - prod[t-1] <= 2 * capa_elec_upper * prodHasChanged[t] / eelec)
        @constraint(model, [t ∈ 2:T], prod[t-1] - prod[t] <= 2 * capa_elec_upper * prodHasChanged[t] / eelec)
    end
    # Production change cost if applicable
    if price_prod_change > 0
        @constraint(model, [t ∈ 2:T], price_prod_change * (prod[t] - prod[t-1]) <= prodChange_cost[t])
        @constraint(model, [t ∈ 2:T], price_prod_change * (prod[t-1] - prod[t]) <= prodChange_cost[t])
    end
    # Operating cost
    if price_penality > 0
        @constraint(model, operating_cost == 
        sum(elecGrid) * price_grid
        + sum(curtailing) * price_curtailing 
        + sum(prodHasChanged) * price_penality
        )
    elseif price_prod_change > 0
        @constraint(model, operating_cost == 
        sum(elecGrid) * price_grid
        + sum(curtailing) * price_curtailing
        + sum(prodChange_cost)
        )
    else
        @constraint(model, operating_cost == 
        sum(elecGrid) * price_grid
        + sum(curtailing) * price_curtailing
        )
    end
    # Storage cost
    @constraint(model, storage_cost == cost_bat * batteryCapa + cost_tank * tankCapa)
    # Electrolyser cost
    @constraint(model, electrolyser_cost == cost_elec * electroCapa)
    # Electricity production cost
    @constraint(model, electricity_plant_cost == windCapa * cost_wind + solarCapa * cost_solar)
    # Objective
    @objective(model, Min, operating_cost + storage_cost + electrolyser_cost + electricity_plant_cost)

    println("Optimizing ...")
    optimize!(model)

    return Dict(
        "wind_capa" => value.(windCapa),
        "solar_capa" => value.(solarCapa),
        "battery_capa" => value.(batteryCapa),
        "tank_capa" => value.(tankCapa),
        "electro_capa" => value.(electroCapa),
        "charge" => value.(charge),
        "prod" => value.(prod),
        "stock" => value.(stock),
        "elecGrid" => value.(elecGrid),
        "curtail" => value.(curtailing),
        "elecPPA" => value.(elecPPA),
        "flowBat" => value.(flowBat),
        "flowH2" => value.(flowH2),
        "operating_cost" => value(operating_cost),
        "storage_cost" => value(storage_cost),
        "electrolyser_cost" => value(electrolyser_cost),
        "electricity_plant_cost" => value(electricity_plant_cost)
    )
end