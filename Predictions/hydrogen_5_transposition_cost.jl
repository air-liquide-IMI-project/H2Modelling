using Pkg

# Pkg.add("Plots")
# Pkg.add("Distributions")
# Pkg.add("JuMP")
# Pkg.add("HiGHS")
# Pkg.add("PlotlyJS")
# Pkg.add("SQLite")
# Pkg.add("CSV")
# Pkg.add("DataFrames")
# Pkg.add("Distances")

using SQLite
using Distributions
using HiGHS
using Random
# using PlotlyJS
using CSV
using DataFrames
using Distances
using JuMP
Random.seed!(3)

using DelimitedFiles

# Read the arrays from the file
predictions = readdlm("solar_predictions_for_error_estimation.txt")
# Extract the arrays
y_predicted = predictions[1:div(size(predictions, 1),2), :]
y_test = predictions[div(size(predictions, 1),2)+1:size(predictions, 1), :]

function metropolis_criterion(delta, T, seed)
    Random.seed!(seed)
    if delta < 0
        return true
    else
        U = rand()
        if U < exp(-delta/T)
            return true
        else
            return false
        end
    end
end

function neighborhood(stock_list, variance,k)
    rng = MersenneTwister(k)
    new_list =[floor(Int,rand(rng,Truncated(Normal(stock, variance), 0, Cap_max_tank_stock))) for stock in stock_list]
    return new_list
end

function neighborhood_direction_selection(stock_list, variance,k) #with this function we do not always update all the directions at the same time
    rng = MersenneTwister(k)                                       
    random_integer = rand(rng,1:length(stock_list)) #actually the number of updated directions is here random
    index_list = randperm(rng, length(stock_list))[1:random_integer]
    new_list =[floor(Int,rand(rng,Truncated(Normal(stock, variance), 0, Cap_max_tank_stock))) for stock in stock_list[index_list]]
    stock_list_copy = [stock_list[i] for i in 1:length(stock_list)] #need to be very careful with the deep copy, since it could copy the path and not only the value
    stock_list_copy[index_list] = new_list                          #so when it is modified, it modifies the initial list
    return stock_list_copy
end



db = SQLite.DB(raw"DE_data.sqlite")


week_index_database = DBInterface.execute(db, "SELECT DE_week_index FROM DE_data")
year_index_database = DBInterface.execute(db, "SELECT DE_year FROM DE_data")
DE_price_database = DBInterface.execute(db, "SELECT DE_price FROM DE_data")
DE_semi_negative_price_database = DBInterface.execute(db, "SELECT DE_semi_negativeness_price_median FROM DE_data")
DE_solar_profile_database = DBInterface.execute(db, "SELECT DE_solar_profile FROM DE_data")
DE_wind_profile_database = DBInterface.execute(db, "SELECT DE_wind_profile FROM DE_data")


# strq_price = DBInterface.execute(db, "SELECT DE_price_day_ahead FROM Mix_date_generation_price")
year_index = Vector{Any}()

DE_price = Vector{Any}()
DE_semi_negative_price = Vector{Any}()
DE_solar_profile = Vector{Any}()
DE_wind_profile = Vector{Any}()

Index_vector = Vector{Any}()
Price_vector = Vector{Any}()
Solar_profile_vector = Vector{Any}()
Wind_profile_vector = Vector{Any}()

Number_neighbourhood_search_vector = Vector{Any}()
temperature_vector = Vector{Any}()
Decrease_temperature_coefficient_vector = Vector{Any}()
variance_stock_vector = Vector{Any}()
Initial_solution_vector = Vector{Any}()
Initial_temperature_vector = Vector{Float16}()

argmin_index_vector = Vector{Float16}()
minimum_heuristic_cost_vector = Vector{Float16}()
optimal_chosen_stock_vector = Vector{Any}()

Best_cost_total  = Vector{Float16}()
tested_Best_cost = Vector{Float16}()
tested_stock = Vector{Any}()
chosen_stock = Vector{Any}()






for row in year_index_database
    push!(year_index, row[1]) 
end
for row in DE_price_database
    push!(DE_price, row[1])
end
for row in DE_semi_negative_price_database
    push!(DE_semi_negative_price, row[1]) 
end
for row in DE_solar_profile_database
    push!(DE_solar_profile, row[1])
end
for row in DE_wind_profile_database
    push!(DE_wind_profile, row[1]) 
end



DE_price = [parse(Float16, DE_price[i]) for i in 1: length(DE_price)]
DE_solar_profile = [parse(Float16, DE_solar_profile[i]) for i in 1: length(DE_solar_profile)]
DE_wind_profile = [parse(Float16, DE_wind_profile[i]) for i in 1: length(DE_wind_profile)]
DE_semi_negative_price = [parse(Float16, DE_semi_negative_price[i]) for i in 1: length(DE_semi_negative_price)]

total_number_weeks = size(y_test, 1)

train_size = length(DE_solar_profile)-total_number_weeks-167

Delta_costs = Vector{Float16}()
Ener_Market_opt_values = Vector{Vector{Float16}}()

for iterator in 1:total_number_weeks
    week_index = train_size+1+(iterator-1)*168


    Number_weeks = 1 #we count here also the first week, so one initial week + 4 random weeks


    push!(Index_vector, [j for j in week_index:week_index+167])
    Index_vector



    Hconca = Index_vector[1]

    # Price_vector = DE_price[Hconca]
    Solar_profile_vector = y_predicted[iterator, :]
    Wind_profile_vector = DE_wind_profile[Hconca, :]
    Unreal_Price = DE_semi_negative_price[Hconca, :]
    Price_vector = DE_price[Hconca, :]

    Length_Demand = length(Hconca)


    Demand = [1000 for i in 1:Length_Demand]



    # Here are the parameters of our problem, we will probably have to modify them during the project
    CostPPA = 0  # Here we consider that the energy from PPA is free
    Cap_max_elec = 1000 # 2143 #(kg/h)
    Cap_max_bat_flow = 100 #(MW)
    Cap_max_bat_stock = 300 # (MW)
    Cap_max_tank_stock = 25000 # 51603 #(kg) #here we need to be careful since for a lot of simultation the level was constrained at half of this capacity
    efficiency_elec = 0.05 # (Mwh /kg H2)
    efficiency_bat = 0.9
    dissipation_bat = 0.005 # here we should modify this value by looking at plausible values
    Cost_production_change = 10  #we will probably have to change this value
    Solar_capacity = 50 # 194 # (MW)
    Wind_capacity = 40 # 143 #(MW)

    Ener_stored_bat_initial = 0
    Hydrogen_stored_tank_initial = 0


    Index_first_week_first_hour = Index_vector[1][1]

    Real_index_vector = [i for i in Index_first_week_first_hour: (Index_first_week_first_hour + 168*Number_weeks -1)]
    Real_index_vector

    Real_price_vector = DE_price[Real_index_vector]
    Real_solar_profile = y_test[iterator, :]
    Real_wind_profile = DE_wind_profile[Real_index_vector]



    Real_PPA = [Solar_capacity*Real_solar_profile[i] + Wind_capacity*Real_wind_profile[i] for i in 1: Length_Demand]
    Unreal_PPA = [Solar_capacity*Solar_profile_vector[i] + Wind_capacity*Wind_profile_vector[i] for i in 1: Length_Demand]
    Unreal_PPA = [max(0, x) for x in Unreal_PPA]
    #Here we compute the relative errors of the predictions

    #Here we do not need to take into account the values of the capacities since we are computing an relative error

    Loss_mistake_prediction_solar = abs.(Real_solar_profile .- Solar_profile_vector)./Real_solar_profile
    Loss_mistake_prediction_wind = abs.(Real_wind_profile .- Wind_profile_vector)./Real_wind_profile
    Loss_mistake_prediction_price = abs.(Real_price_vector .- Unreal_Price)./abs.(Real_price_vector)

    index_NaN_solar = findall(isnan.(Loss_mistake_prediction_solar))
    index_NaN_wind = findall(isnan.(Loss_mistake_prediction_wind))
    index_NaN_price = findall(isnan.(Loss_mistake_prediction_price))

    Loss_mistake_prediction_solar[index_NaN_solar] = abs.(Real_solar_profile .- Solar_profile_vector)[index_NaN_solar]
    Loss_mistake_prediction_wind[index_NaN_wind] = abs.(Real_wind_profile .- Wind_profile_vector)[index_NaN_wind]
    Loss_mistake_prediction_price[index_NaN_price] = abs.(Real_price_vector .- Unreal_Price)[index_NaN_price]

    x = [i for i in 1:length(Loss_mistake_prediction_solar)]

    # plot(x, Loss_mistake_prediction_solar, label="Relative error for solar prediction", xlabel="Hours", ylabel="relative error")
    # plot(x, Loss_mistake_prediction_wind, label="Relative error for wind prediction", xlabel="Hours", ylabel="relative error")
    # plot(x, Loss_mistake_prediction_price, label="Relative error for price prediction", xlabel="Hours", ylabel="relative error")

    # Computation of the total relative erros with ponderation for the part of the renewable energies used in the PPA. Here it is very important to use the capacities

    Predicted_solar_Part = Solar_profile_vector*Solar_capacity./(Solar_profile_vector*Solar_capacity .+ Wind_profile_vector*Wind_capacity)
    Predicted_wind_part = 1 .-Predicted_solar_Part

    Total_loss_per_hour = Predicted_solar_Part .*Loss_mistake_prediction_solar .+ Predicted_wind_part .*Loss_mistake_prediction_wind  .+ Loss_mistake_prediction_price

    # plot(x, Total_loss_per_hour, label="Relative error for all predictions with ponderation", xlabel="Hours", ylabel="relative error")

    Total_loss_score = sum(Total_loss_per_hour[i] for i in 1:length(Total_loss_per_hour))
    Unreal_optimal_cost = 0


    function Cost(Ener_Market)
        Cost_energy =  [Real_price_vector[i]*Ener_Market[i] for i in 1:Length_Demand] #here we took away the capex for the electrolyser and we condider that the energy from PPA is free
        objective_function = sum(Cost_energy[i] for i in 1:Length_Demand)   #here we consider we do not have any OPEX, so the CAPEX are not taken into ccount
        return objective_function
    end

    unreal_model = Model(HiGHS.Optimizer) # this part allows to generate our solution
    set_attribute(unreal_model, "time_limit", 360.0) # we may need to have a longer time to run, but here this is not needed
    set_attribute(unreal_model, "output_flag", false)

    @variable(unreal_model, 0<= Ener_PPA[1:Length_Demand])
    @variable(unreal_model, 0<= Ener_Market[1:Length_Demand])
    @variable(unreal_model, Ener_Bat_flow[1:Length_Demand])   #here we consider that the sign of the flow is positive if we stored energy in the battery and vice versa.
    @variable(unreal_model, 0<= Ener_used_by_elec[1:Length_Demand])
    @variable(unreal_model, 0<= Ener_stored_bat[1:Length_Demand+1])
    @variable(unreal_model, Stored_Hyd_flow[1:Length_Demand]) #here we do the same thing: negative flow means we use stored hydrogen to fill the demand
    @variable(unreal_model, 0<= Hydrogen_stored_tank[1:Length_Demand+1])
    # @variable(model, change_production[1:Length_Demand], Bin)  # here we need to be careful with the different indexes


    #Initial constraints
    @constraint(unreal_model, Ener_stored_bat[1] == Ener_stored_bat_initial)  #we always begin the first week with an empty stock by default
    @constraint(unreal_model, Hydrogen_stored_tank[1] == Hydrogen_stored_tank_initial)


    for i in 1:Length_Demand
        @constraint(unreal_model, -Hydrogen_stored_tank[i] <= Stored_Hyd_flow[i])  # we cannot use more stored hydrogen that we actually have
        @constraint(unreal_model, Demand[i] + Stored_Hyd_flow[i] == Ener_used_by_elec[i]/efficiency_elec) #we should have an equality here, but the cost of energy must prevent it
        @constraint(unreal_model, Hydrogen_stored_tank[i+1] == Stored_Hyd_flow[i] + Hydrogen_stored_tank[i] ) #here is the bilan of hydrogen stored in the tank
        @constraint(unreal_model, Hydrogen_stored_tank[i] <= Cap_max_tank_stock)
        @constraint(unreal_model, Ener_PPA[i] <= Unreal_PPA[i])
        @constraint(unreal_model, -Ener_stored_bat[i] <= Ener_Bat_flow[i]/efficiency_bat)  #we cannot used mored stored energy that we actually have
        @constraint(unreal_model, Ener_Bat_flow[i] <= Cap_max_bat_flow)
        @constraint(unreal_model, - Cap_max_bat_flow <= Ener_Bat_flow[i]) #It is the absolute value of the flow that cannot be greater than this capacity
        @constraint(unreal_model, Ener_used_by_elec[i]/efficiency_elec <= Cap_max_elec) #here we need to be careful to the unit of the Cap_max_elec
        @constraint(unreal_model, Ener_used_by_elec[i] + Ener_Bat_flow[i] == Ener_PPA[i] + Ener_Market[i] ) #we do no mutliply here the flow of the battery by its efficiency
        @constraint(unreal_model, Ener_stored_bat[i+1] == Ener_stored_bat[i]*(1-dissipation_bat) + Ener_Bat_flow[i]*efficiency_bat)  #here we consider the same efficiency for the storage and the destockage
        @constraint(unreal_model, Ener_stored_bat[i] <= Cap_max_bat_stock)
    end

    @constraint(unreal_model, Hydrogen_stored_tank[Length_Demand + 1] <= Cap_max_tank_stock)  #we consider that the final constrained hydrogen level already respects this constraint
    @constraint(unreal_model, Ener_stored_bat[Length_Demand + 1] <= Cap_max_bat_stock)


    function Unreal_Cost(Ener_Market)
        Cost_energy =  [Unreal_Price[i]*Ener_Market[i] for i in 1:Length_Demand] #here we took away the capex for the electrolyser and we condider that the energy from PPA is free
        objective_function = sum(Cost_energy[i] for i in 1:Length_Demand)   #here we consider we do not have any OPEX, so the CAPEX are not taken into ccount
        return objective_function
    end

    @objective(unreal_model, Min, Unreal_Cost(Ener_Market))
    optimize!(unreal_model)

    Unreal_optimal_cost = objective_value(unreal_model)

    Ener_used_by_elec_opt_value = JuMP.value.(Ener_used_by_elec)
    Ener_PPA_opt_value = JuMP.value.(Ener_PPA)
    Ener_Market_opt_value = JuMP.value.(Ener_Market)
    Ener_stored_bat_opt_value = JuMP.value.(Ener_stored_bat)
    Hydrogen_stored_tank_opt_value = JuMP.value.(Hydrogen_stored_tank)
    


    #Here is one of the most important parts where we actually transpose our predicted solution into a feasible one
    Cost_mistake_energy_vector_value = [max(0, (Ener_PPA_opt_value[i] - Real_PPA[i]))*Real_price_vector[i] for i in 1:Length_Demand]
    Available_surplus_PPA_value = [max(0, Real_PPA[i]-Ener_PPA_opt_value[i]) for i in 1:Length_Demand]

    Cost_energy_market_value = [max(0, Ener_Market_opt_value[i] - Available_surplus_PPA_value[i])*Real_price_vector[i] for i in 1:Length_Demand]
    # We don't consider that we can stock the surplus !
    # No dynamic programming !

    #But no change in the production plan, we just replace as much energy from the grid by renewable enregy as we can

    # Cost_mistake_energy = sum( Cost_mistake_energy_vector_value[i] for i in 1:Length_Demand)
    # Cost_real_price = sum(Cost_energy_market_value[i] for i in 1:Length_Demand) #this part is really important for a coherent transposition
    
    # total_cost = Cost_real_price + Cost_mistake_energy #- Real_optimal_cost  we  do not finally compute the difference with the real optimal cost
    
    total_cost = sum([max(0, (Ener_PPA_opt_value[i] + Ener_Market_opt_value[i] - Real_PPA[i]))*Real_price_vector[i] for i in 1:Length_Demand])
    delta = total_cost - Unreal_optimal_cost

    push!(Delta_costs, delta)
    push!(Ener_Market_opt_values, Ener_Market_opt_value)
end

open("delta_costs.txt", "w") do io
    writedlm(io, Delta_costs)
end

open("ener_Market_opt_values.txt", "w") do io
    writedlm(io, Ener_Market_opt_values)
end
