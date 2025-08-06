return {
	{
		name = "System",
		startunit = "kernel",
	},
	{
		name = "Hacker",
		startunit = "hole",
	},
	{
		name = "Network",
		startunit = "carrier",
	},

	--[[ AFAICT these were listed just to have
	     a faction to HQ mapping, but not to be
	     pickable in multiplayer lobbies.

	     Also note that `sidedata.tdf` is still used
	     to provide buildoptions to FBI unit defs.

	{
		name = "Touhou",
		startunit = "thbase",
	},
	{
		name = "Old Hacker",
		startunit = "holeold",
	},
	{
		name = "Rock Paper Scissors",
		startunit = "hand",
	}, ]]
}