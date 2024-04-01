using Pkg

# Pkg.add("Plots")
# Pkg.add("Distributions")
# Pkg.add("JuMP")
# Pkg.add("HiGHS")
# Pkg.add("PlotlyJS")
# Pkg.add("SQLite")
# Pkg.add("CSV")
# Pkg.add("DataFrames")

using SQLite
using Distributions
using JuMP
using HiGHS
using Plots
using Random
# using PlotlyJS
using CSV
using DataFrames


f =rand()
exp(-300/10e6)

function metropolis_criterion(delta, T)
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

stock_list_test = [145,900,1000,23,620]



# stock_list_test = neighborhood(stock_list_test, 1000,5)


db = SQLite.DB(raw"DE_data.sqlite")


week_index_database = DBInterface.execute(db, "SELECT DE_week_index FROM DE_data")
year_index_database = DBInterface.execute(db, "SELECT DE_year FROM DE_data")
DE_price_database = DBInterface.execute(db, "SELECT DE_price FROM DE_data")
DE_semi_negative_price_database = DBInterface.execute(db, "SELECT DE_semi_negativeness_price_median FROM DE_data")
DE_solar_profile_database = DBInterface.execute(db, "SELECT DE_solar_profile FROM DE_data")
DE_wind_profile_database = DBInterface.execute(db, "SELECT DE_wind_profile FROM DE_data")


# strq_price = DBInterface.execute(db, "SELECT DE_price_day_ahead FROM Mix_date_generation_price")

week_index = Vector{Any}()
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
Initial_temperature_vector = Vector{Float64}()




argmin_index_vector = Vector{Float64}()
minimum_heuristic_cost_vector = Vector{Float64}()
optimal_chosen_stock_vector = Vector{Any}()


First_size_group = [10 for i in 1:20] # this will be part of the policy chosen to explore


# DE_price  = Float64[]


for row in week_index_database
    push!(week_index, row[1]) # Assuming the value is in the first column
end
for row in year_index_database
    push!(year_index, row[1]) # Assuming the value is in the first column
end
for row in DE_price_database
    push!(DE_price, row[1]) # Assuming the value is in the first column
end
for row in DE_semi_negative_price_database
    push!(DE_semi_negative_price, row[1]) # Assuming the value is in the first column
end
for row in DE_solar_profile_database
    push!(DE_solar_profile, row[1]) # Assuming the value is in the first column
end
for row in DE_wind_profile_database
    push!(DE_wind_profile, row[1]) # Assuming the value is in the first column
end




week_index = [parse(Int, week_index[i]) for i in 1: length(week_index)]
DE_price = [parse(Float16, DE_price[i]) for i in 1: length(DE_price)]
DE_solar_profile = [parse(Float16, DE_solar_profile[i]) for i in 1: length(DE_solar_profile)]
DE_wind_profile = [parse(Float16, DE_wind_profile[i]) for i in 1: length(DE_wind_profile)]
DE_semi_negative_price = [parse(Float16, DE_semi_negative_price[i]) for i in 1: length(DE_semi_negative_price)]


Index_first_week = 37
Number_weeks = 5 #we count here also the first week, so one initial week + 4 random weeks
Chosen_Year = 2016.0

Different_years = unique(year_index)

Year_to_pick = [year for year in Different_years if year!=2014.0]
Year_picked = Year_to_pick[rand(1:length(Year_to_pick), Number_weeks-1)]

week_to_pick = [i for i in Index_first_week+1 : Index_first_week + Number_weeks-1]


push!(Index_vector, [j for j in 1:length(DE_price) if week_index[j] == Index_first_week && year_index[j] == Chosen_Year])
Year_picked
for i in 1: Number_weeks-1
    push!(Index_vector, [j for j in 1:length(DE_price) if week_index[j]== week_to_pick[i] && year_index[j]==Year_picked[i]])
end

Index_vector




for i in 1:Number_weeks
    push!(Price_vector, DE_price[Index_vector[i]])
    push!(Solar_profile_vector, DE_solar_profile[Index_vector[i]])
    push!(Wind_profile_vector, DE_wind_profile[Index_vector[i]])
end



Hconca = Index_vector[1]

for i in 2: Number_weeks
    Hconca = vcat(Hconca, Index_vector[i])
end

Hconca

# Price_vector = DE_price[Hconca]
Solar_profile_vector = DE_solar_profile[Hconca]
Wind_profile_vector = DE_wind_profile[Hconca]
Unreal_Price = DE_semi_negative_price[Hconca]

Length_Demand = length(Hconca)





Demand = [1000 for i in 1:Length_Demand]


Best_cost

# Here are the parameters of our problem, we will probably have to modify them during the project
CostPPA = 0  # Here we consider that the energy from PPA is free
Cap_max_elec = 2143 #(kg/h)
Cap_max_bat_flow = 100 #(MW)
Cap_max_bat_stock = 300 # (MW)
Cap_max_tank_stock = 51603/2 #(kg)
efficiency_elec = 0.05 # (Mwh /kg H2)
efficiency_bat = 0.9
dissipation_bat = 0.005 # here we should modify this value by looking at plausible values
Cost_production_change = 10  #we will probably have to change this value
Solar_capacity = 194 # (MW)
Wind_capacity = 143 #(MW)

Ener_stored_bat_initial = 0
Hydrogen_stored_tank_initial = 0


Index_first_week_first_hour = Index_vector[1][1]

Real_index_vector = [i for i in Index_first_week_first_hour: (Index_first_week_first_hour + 168*Number_weeks -1)]

Real_price_vector = DE_price[Real_index_vector]
Real_solar_profile = DE_solar_profile[Real_index_vector]
Real_wind_profile = DE_wind_profile[Real_index_vector]


Real_PPA = [Solar_capacity*Real_solar_profile[i] + Wind_capacity*Real_wind_profile[i] for i in 1: Length_Demand]

Real_optimal_cost = 0 # to compare to the cases with random weeks

model = Model(HiGHS.Optimizer) # this part allows to generate our solution
set_attribute(model, "time_limit", 360.0) # we may need to have a longer time to run, but here this is not needed

@variable(model, 0<= Ener_PPA[1:Length_Demand])
@variable(model, 0<= Ener_Market[1:Length_Demand])
@variable(model, Ener_Bat_flow[1:Length_Demand])   #here we consider that the sign of the flow is positive if we stored energy in the battery and vice versa.
@variable(model, 0<= Ener_used_by_elec[1:Length_Demand])
@variable(model, 0<= Ener_stored_bat[1:Length_Demand+1])
@variable(model, Stored_Hyd_flow[1:Length_Demand]) #here we do the same thing: negative flow means we use stored hydrogen to fill the demand
@variable(model, 0<= Hydrogen_stored_tank[1:Length_Demand+1])
# @variable(model, change_production[1:Length_Demand], Bin)  # here we need to be careful with the different indexes


#Initial constraints
@constraint(model, Ener_stored_bat[1] == Ener_stored_bat_initial)  #we always begin the first week with an empty stock by default
@constraint(model, Hydrogen_stored_tank[1] == Hydrogen_stored_tank_initial)


for i in 1:Length_Demand
    @constraint(model, -Hydrogen_stored_tank[i] <= Stored_Hyd_flow[i])  # we cannot use more stored hydrogen that we actually have
    @constraint(model, Demand[i] + Stored_Hyd_flow[i] == Ener_used_by_elec[i]/efficiency_elec) #we should have an equality here, but the cost of energy must prevent it
    @constraint(model, Hydrogen_stored_tank[i+1] == Stored_Hyd_flow[i] + Hydrogen_stored_tank[i] ) #here is the bilan of hydrogen stored in the tank
    @constraint(model, Hydrogen_stored_tank[i] <= Cap_max_tank_stock)
    @constraint(model, Ener_PPA[i] <= Real_PPA[i])
    @constraint(model, -Ener_stored_bat[i] <= Ener_Bat_flow[i]/efficiency_bat)  #we cannot used mored stored energy that we actually have
    @constraint(model, Ener_Bat_flow[i] <= Cap_max_bat_flow)
    @constraint(model, - Cap_max_bat_flow <= Ener_Bat_flow[i]) #It is the absolute value of the flow that cannot be greater than this capacity
    @constraint(model, Ener_used_by_elec[i]/efficiency_elec <= Cap_max_elec) #here we need to be careful to the unit of the Cap_max_elec
    @constraint(model, Ener_used_by_elec[i] + Ener_Bat_flow[i] == Ener_PPA[i] + Ener_Market[i] ) #we do no mutliply here the flow of the battery by its efficiency
    @constraint(model, Ener_stored_bat[i+1] == Ener_stored_bat[i]*(1-dissipation_bat) + Ener_Bat_flow[i]*efficiency_bat)  #here we consider the same efficiency for the storage and the destockage
    @constraint(model, Ener_stored_bat[i] <= Cap_max_bat_stock)
end

@constraint(model, Hydrogen_stored_tank[Length_Demand + 1] <= Cap_max_tank_stock)  #we consider that the final constrained hydrogen level already respects this constraint
@constraint(model, Ener_stored_bat[Length_Demand + 1] <= Cap_max_bat_stock)


function Cost(Ener_Market)
    Cost_energy =  [ Real_price_vector[i]*Ener_Market[i] for i in 1:Length_Demand] #here we took away the capex for the electrolyser and we condider that the energy from PPA is free
    #Cost_storage = [capex_battery*Ener_stored_bat[i] + capex_gas_tank*Hydrogen_stored_tank[i] for i in 1:Length_Demand + 1] # here we consider that we pay for the initial sotck of the following week
    # objective_function = sum(Cost_energy[i] + Cost_storage[i + 1]  for i in 1:Length_Demand)                                    #but not for the initial storage of the very first hour of the week
    objective_function = sum(Cost_energy[i] for i in 1:Length_Demand)   #here we consider we do not have any OPEX, so the CAPEX are not taken into ccount
    return objective_function
end

@objective(model, Min, Cost(Ener_Market))
optimize!(model)

Real_optimal_cost = objective_value(model) #Here we store the optimal value where we had access to the true data 

Ener_used_by_elec_opt = JuMP.value.(Ener_used_by_elec)
Ener_PPA_opt = JuMP.value.(Ener_PPA)
Ener_Market_opt = JuMP.value.(Ener_Market)
Ener_stored_bat_opt= JuMP.value.(Ener_stored_bat)
Hydrogen_stored_tank_opt = JuMP.value.(Hydrogen_stored_tank)

x = [i for i in 1:Length_Demand ]

plot(x, Ener_Market_opt, label="Energy from PPA", xlabel="Hours", ylabel="Value in MW")


Unreal_PPA = [Solar_capacity*Solar_profile_vector[i] + Wind_capacity*Wind_profile_vector[i] for i in 1: Length_Demand]
#Here we use our final-week stock constraints

Number_groups = 400

Max_constrained_hyd_storage = Cap_max_tank_stock

hydrogen_storage_matrix = rand(0:Max_constrained_hyd_storage, Number_groups, Number_weeks-1) 


# negative_unreal_price = [Unreal_Price[i] for i in 1:Length_Demand if Unreal_Price[i] < 0]

# negative_price = [Real_price_vector[i] for i in 1:Length_Demand if Real_price_vector[i] < 0]

hydrogen_storage_matrix[1, :] =[0 for i in 1:(Number_weeks-1)] # this acutally means that we do not constraint the final level of hydrogen for the first group, just to see


going_criteria = true

Initial_solution_list = [0, Cap_max_tank_stock*0.3, Cap_max_tank_stock*0.5, Cap_max_tank_stock*0.8]

hyd_stock_level = [0 for i in 1:(Number_weeks-1)]



patch_number = 20

Number_neighbourhood_search_list = [1, 5, 10, 20]

First_size_group = [10 for i in 1:patch_number] # this will be part of the policy chosen to explore



Initial_temperature = 1e4

Temperature = Initial_temperature



Initial_temperature_list = [5e2, 5e3, 5e4, 5e5]

Decrease_temperature_coefficient_list = [0.05, 0.1, 0.2, 0.3] 

Decrease_temperature_coefficient = 0.15


variance_stock_list = [100, 500, 1000, 2000]

T=0
k=0
heuristic_solution= 1e7

total_size = 300

seed = 247



for Number_neighbourhood_search in Number_neighbourhood_search_list
    patch_number = floor(Int,total_size/Number_neighbourhood_search)
    for variance_stock in variance_stock_list
        for Initial_solution in Initial_solution_list
            hyd_stock_level_initial = [initial_solution for i in 1:(Number_weeks-1)]
            for Initial_temperature in Initial_temperature_list
                for Decrease_temperature_coefficient in Decrease_temperature_coefficient_list
                    Temperature_list = Vector{Float64}()
                    push!(Temperature_list, Initial_temperature)
                    for i in 2:patch_number
                        Temperature = Temperature_list[i-1]*Decrease_temperature_coefficient
                        push!(Temperature_list,Temperature)
                    end
                    k= 0 
                    heuristic_solution= 1e7

                    push!(Number_neighbourhood_search_vector, Number_neighbourhood_search)
                    push!(variance_stock_vector, variance_stock)
                    push!(Initial_solution_vector, Initial_solution)
                    push!(Initial_temperature_vector, Initial_temperature)
                    push!(Decrease_temperature_coefficient_vector, Decrease_temperature_coefficient)

                    chosen_stock = Vector{Any}()
                    while going_criteria && k < patch_number
                        k+=1
                        T= (k!=1)*T*(1-Decrease_temperature_coefficient) + (k==1)*Initial_temperature
                        for j in 1:First_size_group[k]
                        #we do not constrained the final stock of the last week

                            if k == 1
                                group = j
                            else
                                group = (k-1)*First_size_group[k-1] + j
                            end

                            println("this is the ",group, "th group ")
                            println("k=  ", k, " j = ",j)

                            hyd_stock_level = [hyd_stock_level_initial[i]*(k==1)*(j==1) for i in 1:length(hyd_stock_level_initial)] + [neighborhood(hyd_stock_level, variance_stock, seed)[i]*(j!=1 || k!=1) for i in 1:length(hyd_stock_level)]#this is for the initial solution
                            push!(chosen_stock, hyd_stock_level)

                            model = Model(HiGHS.Optimizer) # this part allows to generate our solution
                            set_attribute(model, "time_limit", 360.0) # we may need to have a longer time to run, but here this is not needed

                            @variable(model, 0<= Ener_PPA[1:Length_Demand])
                            @variable(model, 0<= Ener_Market[1:Length_Demand])
                            @variable(model, Ener_Bat_flow[1:Length_Demand])   #here we consider that the sign of the flow is positive if we stored energy in the battery and vice versa.
                            @variable(model, 0<= Ener_used_by_elec[1:Length_Demand])
                            @variable(model, 0<= Ener_stored_bat[1:Length_Demand+1])
                            @variable(model, Stored_Hyd_flow[1:Length_Demand]) #here we do the same thing: negative flow means we use stored hydrogen to fill the demand
                            @variable(model, 0<= Hydrogen_stored_tank[1:Length_Demand+1])
                            # @variable(model, change_production[1:Length_Demand], Bin)  # here we need to be careful with the different indexes


                            @constraint(model, Ener_stored_bat[1] == Ener_stored_bat_initial)  #we always begin the first week with an empty stock
                            @constraint(model, Hydrogen_stored_tank[1] == Hydrogen_stored_tank_initial)


                            for i in 1:Length_Demand
                                @constraint(model, -Hydrogen_stored_tank[i] <= Stored_Hyd_flow[i])  # we cannot use more stored hydrogen that we actually have
                                @constraint(model, Demand[i] + Stored_Hyd_flow[i] == Ener_used_by_elec[i]/efficiency_elec) #we should have an equality here, but the cost of energy must prevent it
                                @constraint(model, Hydrogen_stored_tank[i+1] == Stored_Hyd_flow[i] + Hydrogen_stored_tank[i] )
                                @constraint(model, Hydrogen_stored_tank[i] <= Cap_max_tank_stock) #we may have to change the indexes
                                @constraint(model, Ener_PPA[i] <= Unreal_PPA[i]) # this is here that we use our unreal weeks
                                @constraint(model, -Ener_stored_bat[i] <= Ener_Bat_flow[i]/efficiency_bat)  #we cannot used mored stored energy that we actually have
                                @constraint(model, Ener_Bat_flow[i] <= Cap_max_bat_flow)
                                @constraint(model, - Cap_max_bat_flow <= Ener_Bat_flow[i]) #It is the absolute value of the flow that cannot be greater than this capacity
                                @constraint(model, Ener_used_by_elec[i] <= Cap_max_elec)
                                @constraint(model, Ener_used_by_elec[i] + Ener_Bat_flow[i]/efficiency_bat == Ener_PPA[i] + Ener_Market[i] ) #we should also have an equality here
                                @constraint(model, Ener_stored_bat[i+1] == Ener_stored_bat[i]*(1-dissipation_bat) + Ener_Bat_flow[i]*efficiency_bat)  #here we consider the same efficiency for the storage and the destockage
                                @constraint(model, Ener_stored_bat[i] <= Cap_max_bat_stock)
                            end

                            @constraint(model, Hydrogen_stored_tank[Length_Demand + 1] <= Cap_max_tank_stock)  #we consider that the final constrained hydrogen level alreday respcet this contraint
                            @constraint(model, Ener_stored_bat[Length_Demand + 1] <= Cap_max_bat_stock)


                            #here we add our final constraint fo the first hour of each new week except the first one, 168 = 7days times 24 hours, so one week

                            for week in 1:(Number_weeks-1) # we do not constraint the last week
                                @constraint(model,hyd_stock_level[week] <= Hydrogen_stored_tank[168*week + 1] )
                            end


                            function Cost(Ener_Market)
                                Cost_energy =  [ Unreal_Price[i]*Ener_Market[i]  for i in 1:Length_Demand]  # this is also here that we use our unreal weeks
                                objective_function = sum(Cost_energy[i] for i in 1:Length_Demand)   #here we consider we do not have any OPEX, so the CAPEX are not taken into acount
                                return objective_function
                            end

                            @objective(model, Min, Cost(Ener_Market))
                            optimize!(model)

                            Ener_used_by_elec_opt_value = JuMP.value.(Ener_used_by_elec)
                            Ener_PPA_opt_value = JuMP.value.(Ener_PPA)
                            Ener_Market_opt_value = JuMP.value.(Ener_Market)
                            Ener_stored_bat_opt_value = JuMP.value.(Ener_stored_bat)
                            Hydrogen_stored_tank_opt_value = JuMP.value.(Hydrogen_stored_tank)
                            


                            #Here is one of the most important parts where we actually transpose our predicted solution into a feasible one
                            Cost_mistake_energy_vector_value = [max(0, (Ener_PPA_opt_value[i] - Real_PPA[i]))*Real_price_vector[i] for i in 1:Length_Demand]
                            Available_surplus_PPA_value = [max(0, Real_PPA[i]-Ener_PPA_opt_value[i]) for i in 1:Length_Demand]

                            Cost_energy_market_value = [max(0, Ener_Market_opt_value[i] - Available_surplus_PPA_value[i])*Real_price_vector[i] for i in 1:Length_Demand]

                            #But no change in the production plan, we just replace as much energy from the grid by renewable enregy as we can

                            Cost_mistake_energy = sum( Cost_mistake_energy_vector_value[i] for i in 1:Length_Demand)
                            Cost_real_price = sum(Cost_energy_market_value[i] for i in 1:Length_Demand) #this part is really important for a coherent transposition
                            
                            total_cost = Cost_real_price + Cost_mistake_energy -Real_optimal_cost # here we compute the difference with the real optimal cost
                            
                            delta = total_cost - heuristic_solution

                            if metropolis_criterion(delta, T)
                                heuristic_solution = total_cost
                            end

                            push!(Best_cost_per_group, heuristic_solution) 

                        end
                    end

                    push!(argmin_index_vector, argmin(Best_cost_per_group))
                    push!(minimum_heuristic_cost, minimum(Best_cost_per_group))
                    push!(optimal_chosen_stock, chosen_stock[argmin_index])
                    
                    Best_cost_per_group = Vector{Float64}()
                    chosen_stock = Vector{Any}()
                end
            end
        end
    end
end
# x = [Nb_test*i for i in 1:trunc(Int,Length_Demand/Nb_test)]
Available_surplus_PPA_per_group
Real_optimal_cost
Best_cost_per_group



x = [i for i in 1:Length_Demand +1]

x_best_cost = [ i for i in 1:length(Best_cost_per_group)]

plot(x, Hydrogen_stored_tank_opt_per_group[4001], label="Energy from PPA", xlabel="Hours", ylabel="Value in MW")

plot(x, Ener_PPA_opt_per_group[2863], label="Energy from PPA", xlabel="Hours", ylabel="Value in MW")

plot(x_best_cost, Best_cost_per_group,label="Best_cost with constrained level of hydrogen", xlabel="groups", ylabel="Value in €")

plot(x_best_cost, cost_per_group,label="Best_cost with constrained level of hydrogen", xlabel="groups", ylabel="Value in €")


plot(x_test, test, label="Energy from PPA", xlabel="Hours", ylabel="Value in MW")


Optimal_cost_hyd_storage = hcat(Best_cost_per_group, hydrogen_storage_matrix)

week_names = String["Optimal_Cost"]

# Generate week names and append them to the array
for i in 1:Nb_weeks
    push!(week_names, "Week_$i")
end

week_names

final_hyd_stock
column_names = ["Optimal_Cost", "Week1", "Week2", "Week3", ""]

df = DataFrame(Optimal_cost_hyd_storage, Symbol.(week_names))

CSV.write("Optimal_cost_hyd_storage.csv", df)



