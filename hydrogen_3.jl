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
using PlotlyJS
using CSV
using DataFrames

db = SQLite.DB(raw"DE_data_2.sqlite")


week_index_database = DBInterface.execute(db, "SELECT DE_week_index FROM DE_data_2")
year_index_database = DBInterface.execute(db, "SELECT DE_year FROM DE_data_2")
DE_price_database = DBInterface.execute(db, "SELECT DE_price FROM DE_data_2")
DE_solar_profile_database = DBInterface.execute(db, "SELECT DE_solar_profile FROM DE_data_2")
DE_wind_profile_database = DBInterface.execute(db, "SELECT DE_wind_profile FROM DE_data_2")

# strq_price = DBInterface.execute(db, "SELECT DE_price_day_ahead FROM Mix_date_generation_price")

week_index = Vector{Any}()
year_index = Vector{Any}()
DE_price = Vector{Any}()
DE_solar_profile = Vector{Any}()
DE_wind_profile = Vector{Any}()
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


Index_first_week = 37
Number_weeks = 5 #we count here also the first week, so one initial week + 4 random weeks
Chosen_Year = 2016.0

Different_years = unique(year_index)

Year_to_pick = [year for year in Different_years if year!=2014.0]
Year_picked = Year_to_pick[rand(1:length(Year_to_pick), Number_weeks-1)]

week_to_pick = [i for i in Index_first_week+1 : Index_first_week + Number_weeks-1]
Index_vector = Vector{Any}()

push!(Index_vector, [j for j in 1:length(DE_price) if week_index[j] == Index_first_week && year_index[j] == Chosen_Year])
Year_picked
for i in 1: Number_weeks-1
    push!(Index_vector, [j for j in 1:length(DE_price) if week_index[j]== week_to_pick[i] && year_index[j]==Year_picked[i]])
end

Index_vector
Length_Demand = length(Index_vector[4])

Best_cost = Vector{Float64}()
Final_hyd_stock_vector = Vector{Float64}()
Best_cost_per_group = Vector{Float64}()
Best_cost_plot_trimester = Vector{Any}()

number_day = 7

Demand = [1000 for i in 1:(24*number_day)]
Length_Demand = length(Demand)

PPA = [1000/efficiency_elec for i in 1:Length_Demand]

# Cost_market = DE_price[1:Length_D]
Cost_market = [50000 for i in 1:Length_Demand]

# Cost_PPA = 20  #we can work with a fixed price for this part

Best_cost

# Here are the parameters of our problem, we will probably have to modify them during the project
CostPPA = 20
capex_elec = 1200000 * 0.0004 #(euros/MW)
capex_gas_tank = 407
capex_battery =  250000 * 0.0002 #actually there are two different cases to deal with
Cap_max_elec = 1000 #(MW)
Cap_max_bat_flow = 100
Cap_max_bat_stock = 400
Cap_max_tank_stock = 500
efficiency_elec = 0.05 # (Mwh /kg H2)
efficiency_bat = 0.9
dissipation_bat = 0.01 # here we should modify this value by looking at plausible values
Cost_production_change = 10  #we will probably have to change this value

Ener_stored_bat_initial = 0
Hydrogen_stored_tank_initial = 0

# plot_array_energy = Any[]
# plot_array_hydrogen_storage = Any[]
# index_hyd_stock_level = Any[]
# Hydrogen_stored_tank_opt = Any[]


# hyd_stock_level_test = [floor(Int, rand(Truncated(Normal(200, Variance_2), hyd_stock_min, hyd_stock_max))) for i in 1:Nb_month]


#Here we define a matrix whose lines correpond to the groups of weeks and whose columns correspond to the weeks, we store the minimum constraind storage at the end
#of each week.

# Define the dimensions of the matrix
Nb_weeks = 6  # Replace with your desired number of weeks
Nb_groups = 100  # Replace with your desired number of groups

#here to initiate our matrix, and for all the test we want toensure that we always begin our first weeks with a storage of hydrogen equal to zero
hydrogen_storage_matrix = rand(200:Cap_max_tank_stock, Nb_groups, Nb_weeks) 
# hydrogen_storage_matrix[:, 1] .= 0  #we need to be careful in the indexation

hydrogen_storage_matrix
final_hyd_stock = 0
final_bat_stock = 0

for group in 1:Nb_groups
    for week in 1:Nb_weeks+1  #we do not constrained the final stock of the last week
        println(group, "th groups  ", week, "th week")
        if week != Nb_weeks +1
            hyd_stock_level = hydrogen_storage_matrix[group, week]
        end

        model = Model(HiGHS.Optimizer) # this part allows to generate our solution
        set_attribute(model, "time_limit", 360.0) # we may need to have a longer time to run, but here this is not needed

        @variable(model, 0<= Ener_PPA[1:Length_Demand], Int)
        @variable(model, 0<= Ener_Market[1:Length_Demand], Int)
        @variable(model, Ener_Bat_flow[1:Length_Demand], Int)   #here we consider that the sign of the flow is positive if we stored energy in the battery and vice versa.
        @variable(model, 0<= Ener_used_by_elec[1:Length_Demand], Int)
        @variable(model, 0<= Ener_stored_bat[1:Length_Demand+1], Int)
        @variable(model, Stored_Hyd_flow[1:Length_Demand], Int) #here we do the same thing: negative flow means we use stored hydrogen to fill the demand
        @variable(model, 0<= Hydrogen_stored_tank[1:Length_Demand+1], Int)
        @variable(model, change_production[1:Length_Demand], Bin)  # here we need to be careful with the different indexes


        if week ==1
            @constraint(model, Ener_stored_bat[1] == Ener_stored_bat_initial)  #we always begin the first week with an empty stock
            @constraint(model, Hydrogen_stored_tank[1] == Hydrogen_stored_tank_initial)
        else
            @constraint(model, Ener_stored_bat[1] == final_bat_stock)  #Actually we have to used what we produced before.
            @constraint(model, Hydrogen_stored_tank[1] == final_hyd_stock)
        end

        for i in 1:Length_Demand
            @constraint(model, -Hydrogen_stored_tank[i] <= Stored_Hyd_flow[i])  # we cannot use more stored hydrogen that we actually have
            @constraint(model, Demand[i] + Stored_Hyd_flow[i] == Ener_used_by_elec[i]/efficiency_elec) #we should have an equality here, but the cost of energy must prevent it
            @constraint(model, Hydrogen_stored_tank[i+1] == Stored_Hyd_flow[i] + Hydrogen_stored_tank[i] )
            @constraint(model, Hydrogen_stored_tank[i] <= Cap_max_tank_stock) #we may have to change the indexes
            @constraint(model, Ener_PPA[i] <= PPA[i])
            @constraint(model, -Ener_stored_bat[i] <= Ener_Bat_flow[i])  #we cannot used mored stored energy that we actually have
            @constraint(model, Ener_Bat_flow[i] <= Cap_max_bat_flow)
            @constraint(model, - Cap_max_bat_flow <= Ener_Bat_flow[i]) #It is the absolute value of the flow that cannot be greater than this capacity
            @constraint(model, Ener_used_by_elec[i] <= Cap_max_elec)
            @constraint(model, Ener_used_by_elec[i] + Ener_Bat_flow[i]/efficiency_bat == Ener_PPA[i] + Ener_Market[i] ) #we should also have an equality here
            @constraint(model, Ener_stored_bat[i+1] == Ener_stored_bat[i]*(1-dissipation_bat) + Ener_Bat_flow[i]/efficiency_bat)  #here we consider the same efficiency for the storage and the destockage
            @constraint(model, Ener_stored_bat[i] <= Cap_max_bat_stock)
        end

        @constraint(model, Hydrogen_stored_tank[Length_Demand + 1] <= Cap_max_tank_stock)  #we consider that the final constrained hydrogen level alreday respcet this contraint
        @constraint(model, Ener_stored_bat[Length_Demand + 1] <= Cap_max_bat_stock)

        if week != Nb_weeks + 1
            @constraint(model, hyd_stock_level <= Hydrogen_stored_tank[Length_Demand + 1])  #here is the part when we constrained the initial stock of hydrogen of the following week
        end

        function Cost(Ener_PPA, Ener_Market, Ener_used_by_elec, Ener_stored_bat, Hydrogen_stored_tank)
            Cost_energy =  [CostPPA*Ener_PPA[i] + Cost_market[i]*Ener_Market[i] + capex_elec*Ener_used_by_elec[i] for i in 1:Length_Demand]
            #Cost_storage = [capex_battery*Ener_stored_bat[i] + capex_gas_tank*Hydrogen_stored_tank[i] for i in 1:Length_Demand + 1] # here we consider that we pay for the initial sotck of the following week
            # objective_function = sum(Cost_energy[i] + Cost_storage[i + 1]  for i in 1:Length_Demand)                                    #but not for the initial storage of the very first hour of the week
            objective_function = sum(Cost_energy[i] for i in 1:Length_Demand)   #here we consider we do not have any OPEX, so the CAPEX are not taken into ccount
            return objective_function
        end

        @objective(model, Min, Cost(Ener_PPA, Ener_Market, Ener_used_by_elec, Ener_stored_bat, Hydrogen_stored_tank))
        optimize!(model)

        push!(Best_cost,objective_value(model))

        final_hyd_stock = JuMP.value.(Hydrogen_stored_tank)[Length_Demand + 1]
        push!(Final_hyd_stock_vector, final_hyd_stock)
        final_bat_stock = JuMP.value.(Ener_stored_bat)[Length_Demand + 1]
    end
    total_cost = 0
    for week in 1:(Nb_weeks + 1)
        total_cost += Best_cost[(Nb_weeks+1)*(group-1) + week]
    end
    push!(Best_cost_per_group, total_cost)
end
# x = [Nb_test*i for i in 1:trunc(Int,Length_Demand/Nb_test)]
x = [i for i in 1:Nb_groups*Nb_weeks]

Best_cost_per_group
hydrogen_storage_matrix
Final_hyd_stock_vector

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




