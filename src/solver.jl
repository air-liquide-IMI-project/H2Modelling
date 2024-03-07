using JuMP, Gurobi, HiGHS
include("constants.jl")


"""
Solve the MILP problem for the hydrogen production and storage.
## Positional arguments
- windProfile : Array of the wind profile (% of the total capacity)
- solarProfile : Array of the solar profile (% of the total capacity), same length as windProfile
- demand : Demand of hydrogen (Kg)
## Keyword arguments
- wind_capa
- solar_capa
- battery_capa
- tank_capa
- electro_capa
- price_grid : Price of the electricity from the grid (€ / MWh)
- price_curtailing : Price of the curtailed electricity (€ / MWh)
- price_penality : Price for changing the production, per Kg of change.
- capa_bat_upper : Upper bound for the battery capacity
- capa_elec_upper : Upper bound for the electrolyzer capacity
- ebat : Efficiency of the battery (Discharge rate per month)
- fbat : Maximum flow of energy to / from the battery (MW)
- eelec : Efficiency of the electrolyzer (Mwh / Kg)
- cost_elec : Cost of the electrolyzer (€ / MW)
- cost_bat : Cost of the battery (€ / MWh)
- cost_tank : Cost of the tank (€ / Kg)
- cost_wind : Cost of installing a wind turbine (€ / MW)
- cost_solar : Cost of installing a solar panel (€ / MW)
- initial_charge : Initial charge of the battery (MWh), defaults to 0
- initial_stock : Initial stock of hydrogen (Kg), defaults to 0
- final_charge : Final charge of the battery (MWh), defaults to not constrainded
- final_stock : Final stock of hydrogen (Kg), defaults to not constrained
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
    demand :: Float64;
    wind_capa :: Float64 = -1.,
    solar_capa :: Float64 = -1.,
    battery_capa :: Float64 = -1.,
    tank_capa :: Float64 = -1.,
    electro_capa ::Float64 = -1.,
    price_grid :: Float64 = PRICE_GRID,
    price_curtailing :: Float64 = PRICE_CURTAILING,
    price_penality :: Float64 = price_penality, # Price for changing the production, per Kg of change.
    capa_bat_upper :: Float64 = CELEC, # Upper bound for the electrolyzer capacity
    capa_elec_upper :: Float64 = CAPA_BAT_UPPER, # Upper bound for the battery capacity
    ebat :: Float64 = EBAT,
    fbat  :: Float64 = FBAT,
    eelec  :: Float64 = EELEC,
    cost_elec :: Float64 = COST_ELEC,
    cost_bat :: Float64 = COST_BAT,
    cost_tank :: Float64 = COST_TANK,
    cost_wind :: Float64 = PRICE_WIND,
    cost_solar :: Float64 = PRICE_SOLAR,
    initial_charge :: Float64 =  0.,
    initial_stock :: Float64 = 0.,
    final_charge :: Float64 = missing,
    final_stock :: Float64 = missing,
    verbose :: Bool = false,
)
    # Number of time steps
    T = length(windProfile)
    if length(solarProfile) != T
        throw(ArgumentError("The length of the solar profile should be equal to the length of the wind profile"))
    end
    # Create the model
    model = Model(Gurobi.Optimizer)

    if !verbose
        set_silent(model)
    end
    if verbose
        println("Adding variables ...")
    end
    # Potential variables
    if wind_capa < 0
        wind_capa = @variable(model, lower_bound = 0.)
    end
    if solar_capa < 0
        solar_capa = @variable(model, lower_bound = 0.)
    end
    if battery_capa < 0
        battery_capa = @variable(model, lower_bound = 0., upper_bound = capa_bat_upper)
    end
    if tank_capa < 0
        tank_capa = @variable(model, lower_bound = 0.)
    end
    if electro_capa < 0
        electro_capa = @variable(model, lower_bound = 0., upper_bound = capa_elec_upper)
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
    # Costs pseudo-variables
    # Production changing penality
    prodChange_cost = @variable(model, [2:T])
    operating_cost = @variable(model)
    storage_cost = @variable(model)
    electrolyser_cost = @variable(model)
    electricity_plant_cost = @variable(model)

    if verbose
        println("Adding constraints ...")
    end
    # Initial charge & stock
    @constraint(model, charge[1] == initial_charge)
    @constraint(model, stock[1] == initial_stock)
    # Final charge & stock
    if !ismissing(final_charge)
        @constraint(model, charge[T+1] == final_charge)
    end
    if !ismissing(final_stock)
        @constraint(model, stock[T+1] == final_stock)
    end
    # Get the per hour discharge of the batteryn from the per month parameter
    perHourDischarge = ebat ^ (1 / (30 * 24))
    # PPA contract
    @constraint(model, [t ∈ 1:T], elecPPA[t] == windProfile[t] * wind_capa + solarProfile[t] * solar_capa)
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
    # Electrolyzer consumption
    @constraint(model, [t ∈ 1:T], prod[t] * eelec <= electro_capa)
    # Maximum charge & stock
    @constraint(model, [t ∈ 1:T+1], charge[t] <= battery_capa)
    @constraint(model, [t ∈ 1:T+1], stock[t] <= tank_capa)
    # Production change cost if applicable
    @constraint(model, [t ∈ 2:T], price_penality * (prod[t] - prod[t-1]) <= prodChange_cost[t])
    @constraint(model, [t ∈ 2:T], price_penality * (prod[t-1] - prod[t]) <= prodChange_cost[t])
    # Operating cost
    @constraint(model, operating_cost == sum(elecGrid) * price_grid + sum(curtailing) * price_curtailing + sum(prodChange_cost))
    # Storage cost
    @constraint(model, storage_cost == cost_bat * battery_capa + cost_tank * tank_capa)
    # Electrolyser cost
    @constraint(model, electrolyser_cost == cost_elec * electro_capa)
    # Electricity production cost
    @constraint(model, electricity_plant_cost == wind_capa * cost_wind + solar_capa * cost_solar)
    # Objective
    @objective(model, Min, operating_cost + storage_cost + electrolyser_cost + electricity_plant_cost)

    if verbose
        println("Solving the model ...")
    end
    optimize!(model)

    return Dict(
        "wind_capa" => value.(wind_capa),
        "solar_capa" => value.(solar_capa),
        "battery_capa" => value.(battery_capa),
        "tank_capa" => value.(tank_capa),
        "electro_capa" => value.(electro_capa),
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