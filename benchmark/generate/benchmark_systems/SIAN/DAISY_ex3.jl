#! format: off
#! source: https://github.com/alexeyovchinnikov/SIAN-Julia

import AbstractAlgebra

function DAISY_ex3(; np=AbstractAlgebra, internal_ordering=:degrevlex, k=np.QQ)
    R, (x₁_8,x₁_7,x₂_7,u₀_7,x₁_6,x₂_6,x₃_6,u₀_6,x₁_5,x₂_5,x₃_5,u₀_5,x₁_4,x₂_4,x₃_4,u₀_4,x₁_3,x₂_3,x₃_3,u₀_3,x₁_2,x₂_2,x₃_2,u₀_2,x₁_1,x₂_1,x₃_1,u₀_1,x₁_0,x₂_0,x₃_0,u₀_0,z_aux,p₁_0,p₃_0,p₄_0,p₆_0,p₇_0) = np.polynomial_ring(k, [:x₁_8,:x₁_7,:x₂_7,:u₀_7,:x₁_6,:x₂_6,:x₃_6,:u₀_6,:x₁_5,:x₂_5,:x₃_5,:u₀_5,:x₁_4,:x₂_4,:x₃_4,:u₀_4,:x₁_3,:x₂_3,:x₃_3,:u₀_3,:x₁_2,:x₂_2,:x₃_2,:u₀_2,:x₁_1,:x₂_1,:x₃_1,:u₀_1,:x₁_0,:x₂_0,:x₃_0,:u₀_0,:z_aux,:p₁_0,:p₃_0,:p₄_0,:p₆_0,:p₇_0], internal_ordering=internal_ordering)
    sys = [
    		-x₁_0 + 4922968439,
		x₁_0*p₁_0 + x₁_1 - x₂_0 - u₀_0,
		-u₀_0 + 1728248484,
		u₀_1 - 1,
		-x₁_1 - 1715388886812602808572,
		x₁_1*p₁_0 + x₁_2 - x₂_1 - u₀_1,
		-x₁_0*p₃_0 + x₂_0*p₄_0 + x₂_1 - x₃_0,
		-x₁_2 + 597720474858688962556832358969386,
		x₁_2*p₁_0 + x₁_3 - x₂_2 - u₀_2,
		u₀_2,
		-x₁_1*p₃_0 + x₂_1*p₄_0 + x₂_2 - x₃_1,
		-x₁_0*p₆_0 + x₃_0*p₇_0 + x₃_1,
		-x₁_3 - 208273336043856564835537414513414028990711128,
		x₁_3*p₁_0 + x₁_4 - x₂_3 - u₀_3,
		-x₁_2*p₃_0 + x₂_2*p₄_0 + x₂_3 - x₃_2,
		u₀_3,
		-x₁_1*p₆_0 + x₃_1*p₇_0 + x₃_2,
		-x₁_4 + 72572020420229915484200473092774106881944179424254612746,
		x₁_4*p₁_0 + x₁_5 - x₂_4 - u₀_4,
		-x₁_3*p₃_0 + x₂_3*p₄_0 + x₂_4 - x₃_3,
		u₀_4,
		-x₁_2*p₆_0 + x₃_2*p₇_0 + x₃_3,
		-x₁_5 - 25287433561709915109129299559752894795252876827044034887155874576724,
		x₁_5*p₁_0 + x₁_6 - x₂_5 - u₀_5,
		u₀_5,
		-x₁_4*p₃_0 + x₂_4*p₄_0 + x₂_5 - x₃_4,
		-x₁_3*p₆_0 + x₃_3*p₇_0 + x₃_4,
		-x₁_6 + 8811306236696612795474102260850994204426633545009906588607742786168236593967460,
		x₁_6*p₁_0 + x₁_7 - x₂_6 - u₀_6,
		-x₁_5*p₃_0 + x₂_5*p₄_0 + x₂_6 - x₃_5,
		u₀_6,
		-x₁_4*p₆_0 + x₃_4*p₇_0 + x₃_5,
		-x₁_7 - 3070264817796243304911204604710947273955980594989338120122959237477396089600702502647451526,
		x₁_7*p₁_0 + x₁_8 - x₂_7 - u₀_7,
		u₀_7,
		-x₁_6*p₃_0 + x₂_6*p₄_0 + x₂_7 - x₃_6,
		-x₁_5*p₆_0 + x₃_5*p₇_0 + x₃_6,
		-x₁_8 + 1069821635768385755726586406696878559977334347079597227079566684863387417645341738911252554640878030802,
		-u₀_1 + 1,
		-u₀_2,
		-u₀_3,
		-u₀_4,
		-u₀_5,
		-u₀_6,
		-u₀_7,
		z_aux - 1
    ]
end
