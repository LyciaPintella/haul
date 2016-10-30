
#include "HaulLibrary.iss"
variable(script) int EndScript = 0
/* Helps us determine who to warp to */
variable(script) index:fleetmember GangMember
variable(script) int GangMemberCount
variable(script) int Turn = 1
variable(script) bool Loiter
variable(script) bool FallingBehind


/* origin is base camp, destination is mining spot */
function main(string Origin, string Destination, bool ReturnToOrigin=FALSE)
{

LogFile:Set["${Script.CurrentDirectory}/logs/${Time.Month}-${Time.Day}-${Time.Year}.log"]
variable int i = 0
variable int j = 0
variable int Pilots = 0
variable int DynamicDelay
variable bool No3D
variable bool HadOre
DynamicDelay:Set[2500]
Verbose:Set[1]
Loiter:Set[FALSE]
No3D:Set[FALSE]
FallingBehind:Set[FALSE]
ui -load haul

	;call ToggleCargo

	if ${Me.SolarSystemID} != ${EVE.Bookmark[${Origin}].SolarSystemID}
	{
		call AutoPilotTo ${Origin}
		wait 30
	}
			
/* Primary loop, runs constantly unless critical error */
	do
	{

/* pick up ore from origin */
		if ${Me.InStation}
		{
			EVE:CloseAllMessageBoxes
			wait 5
			
			if ${EVE.Is3DDisplayOn} && ${No3D}
   			EVE:Toggle3DDisplay
			
			;call ToggleCargo

			call LoadOreToFreighter
			HadOre:Set[${Return}]
			
			wait 20
			
			call LogEcho "In station? ${Me.InStation}! Undocking"
			call Undock
			wait 100
			
			if ${Me.Ship.CargoCapacity} > 40000
			{
				call WaitForSpeedLessThan 0.20
			}
		}
    
   	 	if ${EVE.Is3DDisplayOn} && ${No3D}
   		EVE:Toggle3DDisplay
   			
		call AutoPilotTo ${Destination}
		wait 30

		/* drop off ore in destination */

		if ${Me.InStation}
		{
			EVE:CloseAllMessageBoxes
			wait 5
			
			
			call TransferEverythingToHangar

		}
	
		if ${HadOre} || ${ReturnToOrigin}
		{

			call LogEcho "In station? ${Me.InStation}! Undocking"
			call Undock
			wait 25
			
			if ${Me.Ship.CargoCapacity} > 40000
			{
				call WaitForSpeedLessThan 0.20
			}
			
			call AutoPilotTo ${Origin}
			wait 30			
		}
		
		if ${EVE.Is3DDisplayOn} && ${No3D}
		EVE:Toggle3DDisplay

	}
	while ${HadOre}
}

function atexit()
{
UIElement -kill "TheHauler"
}



