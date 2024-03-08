using Dates
using Plots

function print_solution_propreties(
    output::Dict{String, Any};
    time :: Vector{DateTime},
    wind :: Vector{Float64},
    solar :: Vector{Float64},
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
    elec_out = output["elecGrid"]
    curtailment_out = output["curtail"]
    consPPA_out = output["elecPPA"];
    # Capacities
    println("Battery capacity: $battery_capa MWh, Tank capacity: $tank_capa kg, Electrolyser capacity: $(electro_capa / EELEC) kg/h")
    println("Wind capacity: $wind_capa MW, Solar capacity: $solar_capa MW \n")
    # Energy Mix 
    mix_in_capacity = wind_capa / (wind_capa + solar_capa)
    mix_in_generation = wind_capa * sum(wind) / (wind_capa * sum(wind) + solar_capa * sum(solar))
    println("Wind proportion in capacity: $mix_in_capacity \nWind proportion in generation: $mix_in_generation \n")
    # Total energy needed to run the electrolyser
    total_elec_needed = DEMAND * EELEC * length(time)
    total_elec_produced = trunc(sum(consPPA_out))
    total_elec_imported = trunc(sum(elec_out))
    total_elec_curtailment = trunc(sum(curtailment_out))
    println("Total electricity needed: $total_elec_needed MWh, Total electricity produced: $total_elec_produced MWh")
    println("Total electricity imported: $total_elec_imported MWh, Total electricity curtailment: $total_elec_curtailment MWh \n")
    println("Produced / Needed ratio : $(total_elec_produced / total_elec_needed) \n")
    # Costs
    println("Storage cost: $storage_cost, operating cost: $operating_cost")
    println("Electrolyser cost : $electrolyser_cost, electricity plant cost: $electricity_cost")
    println("Total cost: $(storage_cost + operating_cost + electrolyser_cost + electricity_cost)")

end;

function plot_solution(
    output::Dict;
    demand :: Float64,
    time :: Vector{DateTime} = [],
)
    # Extract the solution values
    battery_capa = trunc(Int64, output["battery_capa"])
    tank_capa = trunc(Int64, output["tank_capa"])
    electro_capa = trunc(Int64, output["electro_capa"])
    wind_capa = trunc(Int64, output["wind_capa"])
    solar_capa = trunc(Int64, output["solar_capa"])
    prod_out = output["prod"]
    charge_out = output["charge"]
    stock_out = output["stock"]
    elec_out = output["elecGrid"]
    curtailment_out = output["curtail"]
    consPPA_out = output["elecPPA"];

    # if time index is not given, plot along indices
    if isempty(time)
        time = 1:length(prod_out)
        time_ext = 1:(length(prod_out) + 1)
    # if time index is given, plot along it
    else
        last_hour = time[end] + Hour(1)
        time_ext = vcat(time, last_hour)
    end

    # Plot the production & tank charge over time
    prod = plot(size=(1200, 500), legend=:topleft, xlabel="Time (h)", ylabel="Production (Kg)",
        title="Hydrogen, Demand : $demand kg/h, Electrolyser: $(electro_capa / EELEC) kg/h")
    plot!(prod, time, prod_out, label="Production")

    # Plot the consumptions, curtailment and battery charge
    cons = plot(size=(1200, 500), legend=:topleft, xlabel="Time (h)", ylabel="Electricity consumption (Mwh)",
        title="Consumption, Solar capacity: $(trunc(solar_capa)) MW, Wind capacity: $(trunc(wind_capa)) MW")
    plot!(cons, time, elec_out, label="Grid consumption")
    plot!(cons, time, consPPA_out, label="PPA consumption")
    plot!(cons, time, -curtailment_out, label="Curtailment")

    # Plot the charge levels
    level_bat = plot(size=(1200, 500), legend=:topleft, xlabel="Time (h)", ylabel="Battery charge (Mwh)",
        title="Battery charge level, Battery capacity : $battery_capa MWh")
    plot!(level_bat, time_ext, charge_out, label="Battery charge")

    # Plot the tank charge level
    level_tank = plot(size=(1200, 500), legend=:topleft, xlabel="Time (h)", ylabel="Tank charge (Kg)",
        title="Tank charge level, Tank capacity : $tank_capa Kg")
    plot!(level_tank, time_ext, stock_out, label="Tank charge")

    return prod, cons, level_bat, level_tank
end;