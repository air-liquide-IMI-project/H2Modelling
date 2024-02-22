using Pkg

# Pkg.add("Plots")
# Pkg.add("Distributions")
# Pkg.add("JuMP")
# Pkg.add("HiGHS")
# Pkg.add("PlotlyJS")
# Pkg.add("SQLite")
# Pkg.add("CSV")

using SQLite
using Distributions
using JuMP
using HiGHS
using Plots
using Random
using PlotlyJS
using CSV

db = SQLite.DB(raw"Mix_date_generation_price.sqlite")
db


strq = DBInterface.execute(db, "SELECT DE_solar_generation_actual FROM Mix_date_generation_price")
strq_price = DBInterface.execute(db, "SELECT DE_price_day_ahead FROM Mix_date_generation_price")

FRF = Int[] 
DE_price  = Float64[]

strq
g=0
for row in strq
    push!(FRF, Int(row[1])) # Assuming the value is in the first column
end

for row in strq_price
    push!(DE_price, row[1]) # Assuming the value is in the first column
end
g
DE_price

FRF

Best_cost = Vector{Float64}()
Best_cost_plot_trimester = Vector{Any}()

number_day = 28
# D = [1000 for i in 1:24]
# Variance = 400
# Demand_min = 0
# Demand_max = 3000

# D = [floor(Int, rand(Truncated(Normal(1000, Variance), Demand_min, Demand_max))) for i in 1:(24*number_day)]
D = [1000 for i in 1:(24*number_day)]
Length_D = length(D)
PPA = FRF[1:Length_D]


# Cost_market = [20.79, 17.41, 16.24, 11.9, 9.77, 15.88, 24.88, 29.7, 35.01, 33.95, 29.9, 29.03]
# Cost_market = vcat(Cost_market,[27.07, 26.43, 27.53, 29.05, 31.42, 39.92, 41.3, 41.51, 39.75, 30.13, 30.36, 32.4])
# for i in 1:(number_day-1)
#     PPA = vcat(PPA,[50 for i in 1:18],[40, 30, 20, 10, 0, 50])
#     Cost_Market_1 = [20.79, 17.41, 16.24, 11.9, 9.77, 15.88, 24.88, 29.7, 35.01, 33.95, 29.9, 29.03]
#     Cost_market = vcat(Cost_market, Cost_Market_1,[27.07, 26.43, 27.53, 29.05, 31.42, 39.92, 41.3, 41.51, 39.75, 30.13, 30.36, 32.4])
# end

Cost_market = DE_price[1:Length_D]

Length_hyd_stock_level = 4
Variance_2 = 100
hyd_stock_min = 0
hyd_stock_max = 500




number_hour = 24*number_day
function random_generate_index(number_hour)   # this function allows to create our six lists of random indexes
    list_index = randperm(number_hour)[1:Length_hyd_stock_level]
    return list_index
end



# PPA = vcat([50 for i in 1:18],[40, 30, 20, 10, 0, 50])
# Cost_market = [20.79, 17.41, 16.24, 11.9, 9.77, 15.88, 24.88, 29.7, 35.01, 33.95, 29.9, 29.03]
# Cost_market = vcat(Cost_market,[27.07, 26.43, 27.53, 29.05, 31.42, 39.92, 41.3, 41.51, 39.75, 30.13, 30.36, 32.4])
CostPPA = 20
capex_elec = 1200000 * 0.0004 #(euros/MW)
capex_gas_tank = 407
capex_battery =  250000 * 0.0002 #actually there are two different cases to deal with
Cap_max_elec = 1000 #(MW)
Cap_max_bat_flux = 100
Cap_max_bat_stock = 400
Cap_max_tank_stock = 500
efficiency_elec = 0.05 # (Mwh /kg H2)
efficiency_bat = 0.9

Ener_stored_bat_initial = 0
Hydrogen_stored_tank_initial = 0

plot_array_energy = Any[]
plot_array_hydrogen_storage = Any[]
index_hyd_stock_level = Any[]
Hydrogen_stored_tank_opt = Any[]

Length_D = length(D)
Nb_month = 40

hyd_stock_level_test = [floor(Int, rand(Truncated(Normal(200, Variance_2), hyd_stock_min, hyd_stock_max))) for i in 1:Nb_month]

for test in 1:Nb_month

    if (test%4 == 0)
        D = [floor(Int, rand(Truncated(Normal(1000, Variance), Demand_min, Demand_max))) for i in 1:(24*number_day)]
    end
    # hyd_stock_level = [floor(Int, rand(Truncated(Normal(200, Variance_2), hyd_stock_min, hyd_stock_max))) for i in 1:Length_hyd_stock_level]
    # index_hyd_stock_level = sort(random_generate_index(number_hour))

    hyd_stock_level = [hyd_stock_level_test[test] for i in 1:Length_hyd_stock_level]
    index_hyd_stock_level = [i*7*24 for i in 1:Length_hyd_stock_level]

    model = Model(HiGHS.Optimizer) # this part allows to generate our initial solution
    set_attribute(model, "time_limit", 360.0) # we may need to have a longer time to run

    @variable(model,0<= Ener_PPA[1:Length_D], Int)
    @variable(model,0<= Ener_Market[1:Length_D], Int)
    @variable(model, 0<=Ener_Bat_flux[1:Length_D], Int)
    @variable(model, 0<= Ener_used_by_elec[1:Length_D], Int)
    @variable(model, 0<= Ener_stored_bat[1:Length_D+1], Int)
    @variable(model, 0<= Hydrogen_stored_tank[1:Length_D+1], Int)

    @constraint(model, Ener_stored_bat[1] == Ener_stored_bat_initial)
    @constraint(model, Hydrogen_stored_tank[1] == Hydrogen_stored_tank_initial)

    for i in 1:Length_D
        @constraint(model, D[i] <= Ener_used_by_elec[i]/efficiency_elec+ Hydrogen_stored_tank[i])
        @constraint(model, Hydrogen_stored_tank[i+1] == Ener_used_by_elec[i]/efficiency_elec - D[i])
        @constraint(model, Hydrogen_stored_tank[i+1] <= Cap_max_tank_stock)
        @constraint(model, Ener_PPA[i] <= PPA[i])
        @constraint(model, Ener_Bat_flux[i] <= Ener_stored_bat[i])
        @constraint(model, Ener_Bat_flux[i] <= Cap_max_bat_flux)
        @constraint(model, Ener_used_by_elec[i] <= Cap_max_elec)
        @constraint(model, Ener_used_by_elec[i] <= Ener_PPA[i] + Ener_Market[i] + Ener_Bat_flux[i]/efficiency_bat)
        @constraint(model, Ener_stored_bat[i+1] == Ener_PPA[i]+ Ener_Market[i] + Ener_Bat_flux[i]/efficiency_bat- Ener_used_by_elec[i])
        @constraint(model, Ener_stored_bat[i+1] <= Cap_max_bat_stock)
    end

    for i in 1:Length_hyd_stock_level
        @constraint(model, hyd_stock_level[i] <= Hydrogen_stored_tank[index_hyd_stock_level[i]])
    end

    function Cost(Ener_PPA, Ener_Market, Ener_used_by_elec, Ener_stored_bat, Hydrogen_stored_tank)
        Cost_energy =  [CostPPA*Ener_PPA[i] + Cost_market[i]*Ener_Market[i] + capex_elec*Ener_used_by_elec[i] for i in 1:Length_D]
        Cost_storage = [capex_battery*Ener_stored_bat[i] + capex_gas_tank*Hydrogen_stored_tank[i] for i in 1:Length_D]
        objective_function = sum(Cost_energy[i] + Cost_storage[i]  for i in 1:Length_D)
        return objective_function
    end

    @objective(model, Min, Cost(Ener_PPA, Ener_Market, Ener_used_by_elec, Ener_stored_bat, Hydrogen_stored_tank))
    optimize!(model)

    push!(Best_cost,objective_value(model))

    Ener_used_by_elec_opt = JuMP.value.(Ener_used_by_elec)
    Ener_PPA_opt = JuMP.value.(Ener_PPA)
    Ener_Market_opt = JuMP.value.(Ener_Market)
    Ener_stored_bat_opt= JuMP.value.(Ener_stored_bat)
    Hydrogen_stored_tank_opt = JuMP.value.(Hydrogen_stored_tank)


    x = [24*i for i in 1:trunc(Int,Length_D/24)]
    y1 = [Ener_PPA_opt[24*i] for i in 1:trunc(Int,Length_D/24)]
    y2 = [Ener_Market_opt[24*i] for i in 1:trunc(Int,Length_D/24)]
    y3 = [Ener_stored_bat_opt[24*i] for i in 1:trunc(Int,Length_D/24)]

    h1 = [Hydrogen_stored_tank_opt[i] for i in 1:Length_D]


    plot(x, y1, label="Energy from PPA", xlabel="Hours", ylabel="Value in MW")
    plot!(x, y2, label="Energy from market")
    plot_test_energy = plot!(x, y3, label="Energy from battery", xlabel="Hours")
    push!(plot_array_energy, plot_test_energy )

    plot(index_hyd_stock_level, h1[index_hyd_stock_level], label="Hydrogen_stored_tank", xlabel="Hours", ylabel="Value in kg")
    plot_hyd_storage = plot!(index_hyd_stock_level, hyd_stock_level, label ="Hyd_sotck_level_constraint")
    push!(plot_array_hydrogen_storage, plot_hyd_storage)
end

# x = [Nb_test*i for i in 1:trunc(Int,Length_D/Nb_test)]
x = [i for i in 1:Nb_month]

plot(x, hyd_stock_level_test, label ="hydrogen_sotck_level_test", ylabel = "H2 level in Kg", color=:red)

Best_cost_plot = plot!(twinx(), x, Best_cost, label ="Best_cost", xlabel = "month", ylabel = "cost in euro")


savefig(Best_cost_plot, "plots/best_cost_plot.png")



for (i, p) in enumerate(plot_array_energy)
    savefig(p, "plots/plot_energy$i.png")  # Save each plot as a separate PNG file
end


for (i, p) in enumerate(plot_array_hydrogen_storage)
    savefig(p, "plots/plot_hydrogen_storage$i.png")  # Save each plot as a separate PNG file
end

G = Vector{Any}()

JU = [5,6,3,4,5,7,8]
JU[2:5]


# Best_cost = Vector{Float64}()
Best_cost_plot_tot = Vector{Any}()
x = [i for i in 1:Nb_month]
for i in 1:10
    plot(x[1 + (i-1)*4: 4*i], hyd_stock_level_test[1 + (i-1)*4: 4*i], label ="hydrogen_sotck_level_test", ylabel = "H2 level in Kg", color=:red, legend=false, yguidefontcolor=:red, size=(2000, 2000))
    Best_cost_plot_trimester = plot!(twinx(), x[1 + (i-1)*4: 4*i], Best_cost[1 + (i-1)*4: 4*i], label ="Best_cost", xlabel = "month", ylabel = "cost in euro", legend=false, yguidefontcolor=:blue, size=(2000, 2000))
    push!(Best_cost_plot_tot,Best_cost_plot_trimester)
end




H = [
    Best_cost_plot_tot[1] Best_cost_plot_tot[2] 
    Best_cost_plot_tot[3] Best_cost_plot_tot[4] 
    Best_cost_plot_tot[5] Best_cost_plot_tot[6] 
    Best_cost_plot_tot[7] Best_cost_plot_tot[8]
    Best_cost_plot_tot[9] Plot_energy_vector[1] 
]

Plot_energy_vector = Vector{Any}()
for i in 1:40
    push!(Plot_energy_vector,plot_array_energy[i] )
end
Best_cost_plot_tot[1]
Plot_energy_vector[ 4]

P = [
    Plot_energy_vector[1 +(1-1)*4] Plot_energy_vector[2 +(1-1)*4] 
    Plot_energy_vector[3 +(1-1)*4] Plot_energy_vector[4 +(1-1)*4] 
]

for i in 1:10
    Ploty = [
    Plot_energy_vector[1+(i-1)*4] Plot_energy_vector[2+(i-1)*4]
    Plot_energy_vector[3+(i-1)*4] Plot_energy_vector[4+(i-1)*4] 
]
    Plot_energy = plot(Ploty...)
    savefig(Plot_energy,"plots/plot_energy_trimester$i.png")
end

H = plot(H...)
savefig(H,"plots/h.png")