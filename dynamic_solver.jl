# -*- coding: utf-8 -*-
# ---
# jupyter:
#   jupytext:
#     text_representation:
#       extension: .jl
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.15.2
#   kernelspec:
#     display_name: Julia 1.10.1
#     language: julia
#     name: julia-1.10
# ---

# +
using Plots

include("src/loader.jl")
include("src/solver.jl")

filename = "profiles.csv"
# -

time_by_week, wind_by_week, solar_by_week = load_by_periods(filename, 7 * 24);

# Default values
DEMAND = 1000. # Kg of H2
# Grid parameters
PRICE_GRID = 1000. # € / MWh
PRICE_CURTAILING = 750. # € / MWh;
PRICE_PROD_CHANGE = 1 # € / kg of change in production level
# CHOSEN CAPACITIES
ELECTRO_CAPA = 1720 * EELEC # MW
TANK_CAPA = 46878 # Kg
BATTERY_CAPA = 600 # MWh

# # Dynamic Programming, simple approach
# - We denote by $x^s_t$ the state of the system at time $t$, where $x^s_t$ is the current stock in the tank.
# - To remove complexity, we use a discrete state space, where $x^s_t$ take values by e.g. 1/10th of the tank capacity.
# - The action at time $t$ is the choice of stock level we want to reach at time $t+1$
# - The cost function is given by solving the MILP problem over the period $[t,t+1]$ (e.g usually a week)
# - The dynamic programming equation is given by:
# $$ V_T(x^s_T) = 0 $$
# $$ V_t(x^s_t) = \min_{x^s_{t+1}} \left\{ C(x^s_t,x^s_{t+1}) + V_{t+1}(x^s_{t+1}) \right\} $$
# where $C(x^s_t,x^s_{t+1})$ is the cost of reaching $x^s_{t+1}$ from $x^s_t$ over the period $[t,t+1]$ (given by the MILP solver)

# +
N_State = 10 # State in 10th of the total capacity
T = 7 * 24 * 52 # 52 weeks
# States of the hydrogen tank
states = [i * TANK_CAPA / N_State for i in 0:N_State]
# V matix
V = zeros(N_State + 1, T)

# Solve the problem
for t ∈ T-1:-1:1
    for xₜ ∈ 1:N_State
        min = Inf
        for xₜ₊₁ ∈ 1:N_State
            output = solve(
