using JuMP, Gurobi
include("constants.jl")


"""
Solve the MILP problem for the hydrogen production and storage.
## Keyword arguments
- wind_profile : Array of the wind profile (% of the total capacity)
- solar_profile : Array of the solar profile (% of the total capacity), same length as wind_profile
- demand : Demand of hydrogen (Kg)
## Optional keyword arguments, if not provided, the default values are used (see constants.jl)
- demand : Demand of hydrogen (Kg)
- gurobi_env : Gurobi environment, defaults to Gurobi.Env()
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
- elec_grid : Electricity consumption from the grid (MWh)
- elec_ppa : Consumption of PPA energy (MWh)
- curtailing : Electricity curtailed (MWh)
- flow_bat : Flow of energy to / from the battery ( > 0 if charging, < 0 if discharging) (MWh)
- flow_H2 : Flow of hydrogen to / from the tank ( > 0 if charging, < 0 if discharging) (Kg)
- operating_cost : Operating cost (€)
- storage_cost : Construction cost of the storage (€)
- electrolyser_cost : Construction cost of the electrolyzer (€)
- electricity_plant_cost : Construction cost of the electricity production (€)
"""
function solve(
    ;
    wind_profile::Array{Float64,1},
    solar_profile::Array{Float64,1},
    demand::Union{Float64,Int}=DEMAND,
    wind_capa=WIND_CAPA,
    solar_capa=SOLAR_CAPA,
    battery_capa=BATTERY_CAPA,
    tank_capa=TANK_CAPA,
    electro_capa=-1.0,
    price_grid=PRICE_GRID,
    price_curtailing=PRICE_CURTAILING,
    price_penality=PRICE_PENALITY, # Price for changing the production, per Kg of change.
    capa_bat_upper=CAPA_ELEC_UPPER, # Upper bound for the electrolyzer capacity
    capa_elec_upper=CAPA_BAT_UPPER, # Upper bound for the battery capacity
    ebat=EBAT,
    fbat=FBAT,
    eelec=EELEC,
    cost_elec=COST_ELEC,
    cost_bat=COST_BAT,
    cost_tank=COST_TANK,
    cost_wind=COST_WIND,
    cost_solar=COST_SOLAR,
    initial_charge=-1.0,
    initial_stock=-1.0,
    final_charge=-1.0,
    final_stock=-1.0,
    verbose::Bool=false,
)
    # Number of time steps
    T = length(wind_profile)
    if length(solar_profile) != T
        throw(ArgumentError("The length of the solar profile should be equal to the length of the wind profile"))
    end
    # Create the gurobi environment
    gurobi_env = Gurobi.Env(
        output_flag = 0
    )
    # Create the model
    model = Model(() -> Gurobi.Optimizer(gurobi_env))
    set_silent(model)

    if verbose
        println("Adding variables ...")
    end
    # Potential variables
    if wind_capa < 0
        wind_capa = @variable(model, lower_bound = 0.0)
    end
    if solar_capa < 0
        solar_capa = @variable(model, lower_bound = 0.0)
    end
    if battery_capa < 0
        battery_capa = @variable(model, lower_bound = 0.0, upper_bound = capa_bat_upper)
    end
    if tank_capa < 0
        tank_capa = @variable(model, lower_bound = 0.0)
    end
    if electro_capa < 0
        electro_capa = @variable(model, lower_bound = 0.0, upper_bound = capa_elec_upper)
    end
    # Main variables
    charge = @variable(model, [1:T+1], lower_bound = 0.0)
    stock = @variable(model, [1:T+1], lower_bound = 0.0)
    prod = @variable(model, [1:T], lower_bound = 0.0)
    # Electricity consumption
    elecPPA = @variable(model, [1:T], lower_bound = 0.0)
    elecGrid = @variable(model, [1:T], lower_bound = 0.0)
    curtailing = @variable(model, [1:T], lower_bound = 0.0)
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
    if initial_charge >= 0
        @constraint(model, charge[1] == initial_charge)
    end
    if initial_stock >= 0
        @constraint(model, stock[1] == initial_stock)
    end
    # Final charge & stock
    if final_charge >= 0
        if verbose
            println("Constraining the final charge to ", final_charge)
        end
        @constraint(model, charge[T+1] == final_charge)
    end
    if final_stock >= 0
        if verbose
            println("Constraining the final stock to ", final_stock)
        end
        @constraint(model, stock[T+1] == final_stock)
    end
    # Get the per hour discharge of the batteryn from the per month parameter
    perHourDischarge = ebat^(1 / (30 * 24))
    # PPA contract
    @constraint(model, [t ∈ 1:T], elecPPA[t] == wind_profile[t] * wind_capa + solar_profile[t] * solar_capa)
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

    # Check the status of the model
    if termination_status(model) != MOI.OPTIMAL
        println("The model was not solved to optimality")
        println("Initial charge: ", initial_charge)
        println("Initial stock: ", initial_stock)
        println("Final charge: ", final_charge)
        println("Final stock: ", final_stock)
    end

    return Dict(
        "wind_capa" => value.(wind_capa),
        "solar_capa" => value.(solar_capa),
        "battery_capa" => value.(battery_capa),
        "tank_capa" => value.(tank_capa),
        "electro_capa" => value.(electro_capa),
        "charge" => value.(charge),
        "prod" => value.(prod),
        "stock" => value.(stock),
        "elec_grid" => value.(elecGrid),
        "curtailing" => value.(curtailing),
        "elec_ppa" => value.(elecPPA),
        "flow_bat" => value.(flowBat),
        "flow_H2" => value.(flowH2),
        "operating_cost" => value(operating_cost),
        "storage_cost" => value(storage_cost),
        "electrolyser_cost" => value(electrolyser_cost),
        "electricity_plant_cost" => value(electricity_plant_cost)
    )
end
