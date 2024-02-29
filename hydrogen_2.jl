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

# db = SQLite.DB(raw"Mix_date_generation_price.sqlite")


# strq = DBInterface.execute(db, "SELECT DE_solar_generation_actual FROM Mix_date_generation_price")
# strq_price = DBInterface.execute(db, "SELECT DE_price_day_ahead FROM Mix_date_generation_price")

# FRF = Int[] 
# DE_price  = Float64[]

# strq
# g=0
# for row in strq
#     push!(FRF, Int(row[1])) # Assuming the value is in the first column
# end

# for row in strq_price
#     push!(DE_price, row[1]) # Assuming the value is in the first column
# end
# g
# DE_price

# FRF

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
            Cost_storage = [capex_battery*Ener_stored_bat[i] + capex_gas_tank*Hydrogen_stored_tank[i] for i in 1:Length_Demand + 1] # here we consider that we pay for the initial sotck of the following week
            objective_function = sum(Cost_energy[i] + Cost_storage[i + 1]  for i in 1:Length_Demand)                                    #but not for the initial storage of the very first hour of the week
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

# plot(x, hyd_stock_level_test, label ="hydrogen_sotck_level_test", ylabel = "H2 level in Kg", color=:red)

# Best_cost_plot = plot!(twinx(), x, Best_cost, label ="Best_cost", xlabel = "month", ylabel = "cost in euro")


# savefig(Best_cost_plot, "plots/best_cost_plot.png")



# for (i, p) in enumerate(plot_array_energy)
#     savefig(p, "plots/plot_energy$i.png")  # Save each plot as a separate PNG file
# end


# for (i, p) in enumerate(plot_array_hydrogen_storage)
#     savefig(p, "plots/plot_hydrogen_storage$i.png")  # Save each plot as a separate PNG file
# end

# G = Vector{Any}()

# JU = [5,6,3,4,5,7,8]
# JU[2:5]


# # Best_cost = Vector{Float64}()
# Best_cost_plot_tot = Vector{Any}()
# x = [i for i in 1:Nb_month]
# for i in 1:10
#     plot(x[1 + (i-1)*4: 4*i], hyd_stock_level_test[1 + (i-1)*4: 4*i], label ="hydrogen_sotck_level_test", ylabel = "H2 level in Kg", color=:red, legend=false, yguidefontcolor=:red, size=(2000, 2000))
#     Best_cost_plot_trimester = plot!(twinx(), x[1 + (i-1)*4: 4*i], Best_cost[1 + (i-1)*4: 4*i], label ="Best_cost", xlabel = "month", ylabel = "cost in euro", legend=false, yguidefontcolor=:blue, size=(2000, 2000))
#     push!(Best_cost_plot_tot,Best_cost_plot_trimester)
# end




# H = [
#     Best_cost_plot_tot[1] Best_cost_plot_tot[2] 
#     Best_cost_plot_tot[3] Best_cost_plot_tot[4] 
#     Best_cost_plot_tot[5] Best_cost_plot_tot[6] 
#     Best_cost_plot_tot[7] Best_cost_plot_tot[8]
#     Best_cost_plot_tot[9] Plot_energy_vector[1] 
# ]

# Plot_energy_vector = Vector{Any}()
# for i in 1:40
#     push!(Plot_energy_vector,plot_array_energy[i] )
# end
# Best_cost_plot_tot[1]
# Plot_energy_vector[ 4]

# P = [
#     Plot_energy_vector[1 +(1-1)*4] Plot_energy_vector[2 +(1-1)*4] 
#     Plot_energy_vector[3 +(1-1)*4] Plot_energy_vector[4 +(1-1)*4] 
# ]

# for i in 1:10
#     Ploty = [
#     Plot_energy_vector[1+(i-1)*4] Plot_energy_vector[2+(i-1)*4]
#     Plot_energy_vector[3+(i-1)*4] Plot_energy_vector[4+(i-1)*4] 
# ]
#     Plot_energy = plot(Ploty...)
#     savefig(Plot_energy,"plots/plot_energy_trimester$i.png")
# end

# H = plot(H...)
# savefig(H,"plots/h.png")