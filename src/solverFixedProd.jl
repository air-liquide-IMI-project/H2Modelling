using JuMP, Gurobi, HiGHS
include("default_values.jl")


"""
## Arguments
- wind_capa : Capacity of the wind farm (MW)
- wind_profile : Wind profile (% of the capacity)
- solar_capa : Capacity of the solar farm (MW)
- solar_profile : Solar profile (% of the capacity)
- demand : Demand of hydrogen (Kg)
- price_grid : Price of the grid (€ / MWh)
- price_curtailing : Price of the curtailed energy (€ / MWh)
- prodChangePenality : Penality for changing the production (€ / times the production changes)
- initCharge : Initial charge of the battery (MWh)
- initStock : Initial stock of the tank (Kg)
- finalStock : Final stock of the tank (Kg), if None, the final stock is not constrained
- finalCharge : Final charge of the battery (MWh), if None, the final charge is not constrained
## Returns a dictionnary with following keys
- battery_capa : Capacity of the battery (MWh)
- tank_capa : Capacity of the tank (Kg)
- charge : Battery charge (MWh)
- prod : Production of hydrogen (Kg)
- stock : Stock of hydrogen in the tank (Kg)
- elecGrid : Electricity consumption from the grid (MWh)
- consPPA : Consumption of PPA energy (MWh)
- flowBat : Flow of energy to / from the battery ( > 0 if charging, < 0 if discharging) (MWh)
- flowH2 : Flow of hydrogen to / from the tank ( > 0 if charging, < 0 if discharging) (Kg)
- operating_cost : Operating cost (€)
- storage_cost : Construction cost (€) # In this version, could be computed before optimization
"""
function solveFixedProd(
    windCapa :: Float64,
    solarCapa :: Float64,
    windProfile :: Array{Float64, 1},
    solarProfile :: Array{Float64, 1},
    demand :: Float64,
    price_grid = PRICE_GRID,
    price_curtailing = PRICE_CURTAILING,
    price_penality = 0.,
    initCharge =  0.,
    initStock = 0.,
    finalCharge = missing,
    finalStock = missing,
)
    # Number of time steps
    T = length(windProfile)
    if length(solarProfile) != T
        throw(ArgumentError("The length of the solar profile should be equal to the length of the wind profile"))
    end

    # Create the model
    model = Model(HiGHS.Optimizer)
    # Storage variables
    batteryCapa = @variable(model, lower_bound = 0.)
    tankCapa = @variable(model, lower_bound = 0.)
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
    prodHasChanged = @variable(model, [2:T], Bin)
    # Costs pseudo-variables
    operating_cost = @variable(model)
    storage_cost = @variable(model)

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
    perHourDischarge = EBAT ^ (1 / (30 * 24))
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
    @constraint(model, [t ∈ 1:T], -FBAT <= flowBat[t] <= FBAT)
    # Electrolyzer consumption
    @constraint(model, [t ∈ 1:T], prod[t] * EELEC <= CELEC)
    # Maximum charge & stock
    @constraint(model, [t ∈ 1:T+1], charge[t] <= batteryCapa)
    @constraint(model, [t ∈ 1:T+1], stock[t] <= tankCapa)
    # Boolean variable for production change
    @constraint(model, [t ∈ 2:T], prod[t] - prod[t-1] <= 2 * CELEC * prodHasChanged[t] / EELEC)
    @constraint(model, [t ∈ 2:T], prod[t-1] - prod[t] <= 2 * CELEC * prodHasChanged[t] / EELEC)
    # Operating cost
    @constraint(model, operating_cost == 
    sum(elecGrid) * price_grid
     + sum(curtailing) * price_curtailing 
     + sum(prodHasChanged) * price_penality
    )
    # Storage cost
    @constraint(model, storage_cost == COST_BAT * batteryCapa + COST_TANK * tankCapa)
    # Objective
    @objective(model, Min, operating_cost + storage_cost)
    optimize!(model)

    return Dict(
        "battery_capa" => value.(batteryCapa),
        "tank_capa" => value.(tankCapa),
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
    )
end