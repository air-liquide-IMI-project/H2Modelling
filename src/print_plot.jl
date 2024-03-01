using Plots

gr()

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
    elec_out = output["elecGrid"]
    curtailment_out = output["curtail"]
    consPPA_out = output["elecPPA"];
    # Capacities
    println("Battery capacity: $battery_capa MWh, Tank capacity: $tank_capa kg, Electrolyser capacity: $(electro_capa / EELEC) kg/h")
    println("Wind capacity: $wind_capa MW, Solar capacity: $solar_capa MW \n")
    # Energy Mix 
    mix_in_capacity = wind_capa / (wind_capa + solar_capa)
    mix_in_generation = wind_capa * sum(wind_profile) / (wind_capa * sum(wind_profile) + solar_capa * sum(solar_profile))
    println("Wind proportion in capacity: $mix_in_capacity \nWind proportion in generation: $mix_in_generation \n")
    # Total energy needed to run the electrolyser
    total_elec_needed = 8760 * DEMAND * EELEC
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
    output::Dict,
    prod = missing,
    cons = missing,
    level_bat = missing,
    level_tank = missing
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
    # Plot the production & tank charge over time
    if ismissing(prod)
        prod = plot(size=(1200, 500), legend=:topleft, xlabel="Time (h)", ylabel="Production (Kg)",
            title="Hydrogen, Demand : $D kg/h, Electrolyser: $(electro_capa / EELEC) kg/h")
    end
    plot!(prod, prod_out, label="Production")
    # Plot the consumptions, curtailment and battery charge
    if ismissing(cons)
        cons = plot(size=(1200, 500), legend=:topleft, xlabel="Time (h)", ylabel="Electricity consumption (Mwh)",
            title="Consumption, Solar capacity: $(trunc(solar_capa)) MW, Wind capacity: $(trunc(wind_capa)) MW")
    end
    plot!(cons, elec_out, label="Grid consumption")
    plot!(cons, consPPA_out, label="PPA consumption")
    plot!(cons, -curtailment_out, label="Curtailment")
    # Plot the charge levels
    if ismissing(level_bat)
        level_bat = plot(size=(1200, 500), legend=:topleft, xlabel="Time (h)", ylabel="Battery charge (Mwh)",
        title="Battery charge level, Battery capacity : $battery_capa MWh")
    end
    plot!(level_bat, charge_out, label="Battery charge")
    # Plot the tank charge level
    if ismissing(level_tank)
        level_tank = plot(size=(1200, 500), legend=:topleft, xlabel="Time (h)", ylabel="Tank charge (Kg)",
        title="Tank charge level, Tank capacity : $tank_capa Kg")
    end
    plot!(level_tank, stock_out, label="Tank charge")

    return prod, cons, level_bat, level_tank
end;