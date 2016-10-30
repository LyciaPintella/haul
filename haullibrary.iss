
#include "defines.iss"

variable(script) int AllModulesCount
variable(script) int TractorBeamCount
variable(script) int AfterburnerCount
variable(script) int SensorBoosterCount
variable(script) int RepperCount
variable(script) int SalvagerCount
variable(script) int MindlinkCount
variable(script) int StandardCloakCount
variable(script) int CovertCloakCount
variable(script) index:module AllModules
variable(script) index:module StandardCloaks
variable(script) index:module CovertCloaks
variable(script) index:module TractorBeams
variable(script) bool AvailableTractor
variable(script) iterator ThisTractorBeam
variable(script) index:module Reppers
variable(script) index:module DamageControl
variable(script) index:module Salvagers
variable(script) index:module Afterburners
variable(script) index:module Mindlinks
variable(script) index:module SensorBoosters

variable(script) index:item ItemsInCargoHold
variable(script) index:item ItemsInStationHangar
variable(script) index:item ItemsInFleetHangar
variable(script) index:item ItemsInOreHold


variable(script) index:item HangarCargo
variable(script) index:int64 CargoToTransfer
variable(script) int MaxTractorRange
variable(script) int MaxTargets
variable(script) int MaxTargetRange
variable(script) int TargetCount
variable(script) index:entity Targets
variable(script) index:entity AllEntities
variable(script) int EntityCargoCount
variable(script) index:item EntityCargo
variable(script) collection:int64 ProcessedEntities
variable(script) string LogFile
variable(script) int Verbose

variable(script) collection:int64 CargoholdLoot


/* Salvage variables */
variable(script) bool LibraryInitialized
variable(script) string EVELootingFileName
variable(script) bool CheckLootItemDB
variable(script) settingsetref LootItemsDB
variable(script) filepath EVELootingFilePath
variable(script) bool ContinueOn
variable(script) int MaxSalvageRange


variable(script) bool Salvaging

function:bool CheckForLoot()
{
	variable int i = 1
	variable int k = 1
	variable int j = 1
	variable int n = 2 ;always one can ahead of i
	variable int SecondaryTractorTarget = 0
	variable bool Immobile
	variable index:entity Cans
	variable int CanCount
	Immobile:Set[TRUE]
	AvailableTractor:Set[TRUE]
	variable int t = 1

	/* We're going to start fresh on the tractor list each time */
	TractorBeams:GetIterator[ThisTractorBeam]
	call LogNewLine
	if ${Verbose} > 1
	call LogEcho "CheckForLoot called. Initial ${ThisTractorBeam.Value.ToItem.Name} Active? ${ThisTractorBeam.Value.IsActive}  Deactivating? ${ThisTractorBeam.Value.IsDeactivating}."
	
	Cans:Clear
	Targets:Clear
	
	MaxTargets:Set[${MyShip.MaxLockedTargets}]
	MaxTargetRange:Set[${MyShip.MaxTargetRange}]
	
	EVE:QueryEntities[Cans, "GroupID = GROUPID_CAN && (HaveLootRights = 1)"]
	
	CanCount:Set[${Cans.Used}]
	
	if ${Verbose} > 1
		  call LogEcho "${CanCount} cans found "


	if ${CanCount} > 0
	{
		if ${Verbose} > 2
	  		call LogEcho "- Looting: ${CanCount} cargo containers found, processing..."
  		 	
	 	while ((${i} <= ${CanCount}) && (${MyShip.UsedCargoCapacity}<${Math.Calc[${MyShip.CargoCapacity}*.90]}))
	 	{
			/* Make sure we own this can */
			/* cut out  || !${Cans.Get[${i}].Owner.ToFleetMember(exists)} */
			if ${Verbose} > 2
			{
				call LogEcho "Is owner of i ${i} in my group? ${Cans.Get[${i}].Owner.ToFleetMember(exists)}"
				call LogEcho "Do I have loot rights on i ${i}? ${Entity[${Cans.Get[${i}].ID}].HaveLootRights}"
			}
			
			
			/* If we've already processed this can, then we want to ignore it. */
			if (${ProcessedEntities.Element[${Cans.Get[${i}].ID}](exists)})
			{
				if ${Verbose} > 2
				call LogEcho "Can ${i} has already been processed."
				i:Inc
				n:Inc
				continue
			}
	 	
				ProcessedEntities:Set[${Cans.Get[${i}].ID},1]  
				
			/* Target */
			if (${Cans.Get[${i}].Distance} > ${MaxTargetRange})
			{
				call LogNewLine
				call LogEcho "--- Can too far away to target :: Approaching..."
				Cans.Get[${i}]:Approach
				if (${AfterburnerCount} > 0)
				{
			   	
			   		if (${Afterburners.Get[1].IsDeactivating})
			   		{
			      			do
			      			{
			      				wait 5
			      			}
			    		  	while ${Afterburners.Get[1].IsDeactivating}
			   		}			
				   
				    if (!${Afterburners.Get[1].IsActive})
				    {
				    	Afterburners.Get[1]:Click
				    }	   	
				}			
				
				do
				{
					call Check_Reppers
					if ${Verbose} > 2
					call LogEcho "Line _LINE_: Is this a locked target? ${Cans.Get[${i}].IsLockedTarget}"
					if !${Cans.Get[${i}].IsLockedTarget}
					{
						Cans.Get[${i}]:LockTarget
						do
						{
							if ${Verbose} > 2
							call LogEcho "Line _LINE_: It was not locked, doing so now (wait loop)."
							wait WAIT_TARGETING
						}
						while ${Me.TargetingCount} > 0
					
						wait WAIT_TARGETING

						if ${Verbose} > 2
						call LogEcho "Line _LINE_: Setting active target to ${i} ${Cans.Get[${i}].ID}."
						
						Cans.Get[${i}]:MakeActiveTarget
						wait WAIT_TARGET_SWITCH
					}						
				}
				while (${Cans.Get[${i}].Distance} > ${MaxTargetRange})
			}
			else
			{
			/* If in targeting range, still approach */
				if !${Immobile}
				{
					if ${Verbose} > 2
					call LogEcho "Line _LINE_: In targeting range, still approaching."
					Cans.Get[${i}]:Approach
				}
				else
					if (${Afterburners.Get[1].IsActive})
				    {
				    	Afterburners.Get[1]:Click
				    }
			}
		
			/* this block makes sure we're not trying to target an already-targeted can */
			TargetCount:Set[${Me:GetTargets[Targets]}]
			k:Set[1]
		
			if ${TargetCount} > 0
			{
				if ${Targets.Get[${k}].ID} != ${Cans.Get[${i}].ID}
				{
					Cans.Get[${i}]:LockTarget
				}		
		
				wait 2
			}
			else
			{
				Cans.Get[${i}]:LockTarget
			}
		
			call LogNewLine
			;do
			;{
				;call Check_Reppers
					
					if ${Verbose} > 2
					call LogEcho "Line _LINE_: Is can ${i} ${Cans.Get[${i}].ID} a locked target? ${Cans.Get[${i}].IsLockedTarget}"
					
					if !${Cans.Get[${i}].IsLockedTarget}
					{
						Cans.Get[${i}]:LockTarget
						;do
						;{
							;if ${Verbose} > 1
							;call LogEcho "Line _LINE_: Can ${i} ${Cans.Get[${i}].ID} was not locked, doing so now (wait loop)."
							;wait WAIT_TARGETING
						;}
						;while ${Me.TargetingCount} > 0
					
						;wait WAIT_TARGETING
					}
					else
					{
						if ${Verbose} > 2
						call LogEcho "Line _LINE_: Cans.Get[${i}].IsLockedTarget was TRUE."
					}	
			 	
				;wait WAIT_TARGETING
			;}
			;while ${Me.TargetingCount} > 0
			
			/* 
			if ${Verbose} > 1
			call LogEcho "Line _LINE_: Setting active target to ${i} ${Cans.Get[${i}].ID}."
			Cans.Get[${i}]:MakeActiveTarget
			wait WAIT_TARGET_SWITCH
			*/

			
			/* Tractor...or else approach and wait for can to be in distance */
			if ${Cans.Get[${i}].Distance} > 1300
			{
				call LogNewLine
			  if ${Verbose} > 2
			 	 call LogEcho "Line _LINE_: Can too far away to loot -- Tractoring..."
				
				if ${Cans.Get[${i}].Distance} > ${MaxTractorRange}
				{
					call LogNewLine
					
					if ${Verbose} > 2
				  	call LogEcho "Line _LINE_:  Can too far away to tractor -- Approaching..."
					
					Cans.Get[${i}]:Approach
					if (${AfterburnerCount} > 0)
					{
				    if (${Cans.Get[${i}].Distance} > 10000)
				    {
					   	if (${Afterburners.Get[1].IsDeactivating})
					   	{
					      do
					      {
					      	wait 5
					      }
					      while ${Afterburners.Get[1].IsDeactivating}
					   	}
					   	if (!${Afterburners.Get[1].IsActive})
						   	Afterburners.Get[1]:Click
						 	wait 5
					 	}
				 	}
					do
					{
						call LogNewLine
						call Check_Reppers
						if ${Verbose} > 2
						call LogEcho "Line _LINE_: Is primary can i (${i}) a locked target? ${Cans.Get[${i}].IsLockedTarget}"
						if !${Cans.Get[${i}].IsLockedTarget}
						{
							if ${Verbose} > 2
							call LogEcho "Line _LINE_: It was not locked, doing so now."
							Cans.Get[${i}]:LockTarget
							do
							{
								wait WAIT_TARGETING
							}
							while ${Me.TargetingCount} > 0
					
							wait WAIT_TARGETING
							if ${Verbose} > 2
							call LogEcho "Line _LINE_: From the 'out of lock range' section: Making can i (${i}) our active target."
							Cans.Get[${i}]:MakeActiveTarget
							wait WAIT_TARGET_SWITCH
						}
						else
						{
							if ${Verbose} > 1
							call LogEcho "Line _LINE_: Cans.Get[${i}].IsLockedTarget was TRUE."
						}							
						wait 5
					}
					while (${Cans.Get[${i}].Distance} > ${MaxTractorRange})
					wait 2
					
					if ${Verbose} > 2
					call LogEcho "Line _LINE_: Can is now within tractor range. Stopping ship."

					EVE:Execute[CmdStopShip]
					if (${Afterburners.Get[1].IsActive})
				    {
				    	Afterburners.Get[1]:Click
				    }
				}
				
				call LogNewLine
				if ${Verbose} > 2
				call LogEcho "Line _LINE_: End of max tractor range if statement."
				/* Bugfix, if we are using tractor from the last cycle go to next tractor */
				call SelectInactiveTractor
				
				/* Check for possible double tractor */
				if ${Entity[${Cans.Get[${n}].ID}].HaveLootRights} && (${Cans.Get[${n}].Distance} < ${MaxTractorRange}) \
				&& (${n} <= ${CanCount}) && ${Cans.Get[${n}].Owner.ToFleetMember(exists)} && (${TractorBeamCount} > 1)
				{
					if !${Immobile}
					{
						Cans.Get[${n}]:Approach
					}

					Cans.Get[${n}]:LockTarget

					do
					{
						call Check_Reppers
										
						wait WAIT_TARGETING
					}
					while ${Me.TargetingCount} > 0
					
					wait WAIT_TARGETING

					call LogNewLine
					if ${Verbose} > 2
					call LogEcho "Line _LINE_: Checking to see if tractoring can ${n} ${Cans.Get[${n}].ID}."
					call IsTractoringWreckID ${Cans.Get[${n}].ID}
					if !${Return}
					{
						if ${AvailableTractor}
						{
							call LogEcho "Line _LINE_: Setting secondary can n (${n}) as active target."
							Cans.Get[${n}]:MakeActiveTarget
							wait WAIT_TARGET_SWITCH
						
							call LogEcho "Line _LINE_: Activating secondary ${ThisTractorBeam.Value.ToItem.Name} on secondary can ${n}." 
							ThisTractorBeam.Value:Click
							wait WAIT_TRACTOR_STATUS
							call SelectInactiveTractor
						}
					
					}
					else
					{
						if ${Verbose} > 1
						call LogEcho "Line _LINE_: No available tractor for secondary can ${n}"
					}
					
					
					call LogNewLine
					if ${Verbose} > 2
					call LogEcho "Line _LINE_: Checking to see if tractoring can ${i} ${Cans.Get[${i}].ID}."
					call IsTractoringWreckID ${Cans.Get[${i}].ID}
					if !${Return}
					{
						if ${AvailableTractor}
						{

							while ${Me.TargetingCount} > 0
							{
								call Check_Reppers
								wait WAIT_TARGETING
							}
		
							if ${Verbose} > 2
							call LogEcho "Line _LINE_: Making primary can ${i} the active target."
							
							Cans.Get[${i}]:MakeActiveTarget
							wait WAIT_TARGET_SWITCH

							if ${Verbose} > 2
							call LogEcho "Line _LINE_: Activating primary ${ThisTractorBeam.Value.ToItem.Name} on primary can ${i} ${Cans.Get[${i}].ID}." 
							
							ThisTractorBeam.Value:Click
							wait WAIT_TRACTOR_STATUS
							call SelectInactiveTractor
						}
					}
					

					if ${Cans.Get[${i}].Distance} > 5000
					{
						if (${AfterburnerCount} > 0)
						{
							if !${Immobile}
								Cans.Get[${i}]:Approach
								
						   if (${Cans.Get[${i}].Distance} > 10000) && !${Immobile}
						   {
							   if (${Afterburners.Get[1].IsDeactivating})
							   {
								  do
								  {
									wait 5
								  }
								  while ${Afterburners.Get[1].IsDeactivating}
							   }
							   if (!${Afterburners.Get[1].IsActive})
								   Afterburners.Get[1]:Click
								 wait 2
							}
						}							
					}
					wait 5
				}
				wait 2
			
				 
					/* This is the wait loop for the primary can to get close.
					If a failure causes there to be no tractor on the can
					this portion of the script will get stuck, so we need
					to ensure that we cover this case. */
					
				do 
				{
					call Check_Reppers
					if ${Verbose} > 1
						call LogEcho "Line _LINE_: Can Distance is ${Cans.Get[${i}].Distance}"
   					
   					if ${Verbose} > 1
   						call LogEcho "Line _LINE_: Checking to see if tractoring can ${i} ${Cans.Get[${i}].ID}."

			        call IsTractoringWreckID ${Cans.Get[${i}].ID}
			        if !${Return}
			        {
			        	if ${AvailableTractor}
			            {

			            	while ${Me.TargetingCount} > 0
							{
								call Check_Reppers
								wait WAIT_TARGETING
							}

			            	if ${Verbose} > 1
			            	call LogEcho "Line _LINE_: Making primary can ${i} ${Cans.Get[${i}].ID} the active target."
			            	
			            	Cans.Get[${i}]:MakeActiveTarget
			            	wait WAIT_TARGET_SWITCH

			            	if ${Verbose} > 1
			            	call LogEcho "Line _LINE_: Activating primary ${ThisTractorBeam.Value.ToItem.Name} on primary can ${i} ${Cans.Get[${i}].ID}." 
			            	
			            	ThisTractorBeam.Value:Click
							wait WAIT_TRACTOR_STATUS
			            	call SelectInactiveTractor
			            }
			            else
			            {
			            	/* If we are not tractoring it, turn off a tractor. */
							ThisTractorBeam.Value:Click
							wait WAIT_TRACTOR_STATUS
			            	call SelectInactiveTractor
			            }
			        }
					wait GENERIC_WAIT
				}
				while ${Cans.Get[${i}].Distance} > 2000
			}
			else
			 /* if we were within 2000m of primary can to start with. */
			{
				call LogNewLine
				if ${Verbose} > 1
					call LogEcho "Line _LINE_: We started out within 2000m of can ${i} ${Cans.Get[${i}].ID}."
				
				call SelectInactiveTractor

				call IsTractoringWreckID ${Cans.Get[${i}].ID}
				if !${Return}
				{
					Cans.Get[${i}]:LockTarget
				}
				
				/* Check for possible double tractor */
				if ${Entity[${Cans.Get[${n}].ID}].HaveLootRights} && (${Cans.Get[${n}].Distance} < ${MaxTractorRange}) \
				&& (${n} <= ${CanCount}) && ${Cans.Get[${n}].Owner.ToFleetMember(exists)} && (${TractorBeamCount} > 1)
				{
					if !${Immobile}
					{
						Cans.Get[${n}]:Approach
					}

					Cans.Get[${n}]:LockTarget
					
					
					call LogNewLine
					if ${Verbose} > 1
					call LogEcho "Line _LINE_: Checking to see if tractoring can ${n} ${Cans.Get[${n}].ID}."
					call IsTractoringWreckID ${Cans.Get[${n}].ID}
					if !${Return}
					{
						call LogEcho "Line _LINE_: Not tractoring. Available tractor?: ${AvailableTractor}."
						if ${AvailableTractor}
						{
							if ${Verbose} > 1
								call LogEcho "Line _LINE_: Me.TargetingCount value: ${Me.TargetingCount}."
							
							while ${Me.TargetingCount} > 0
							{
								call Check_Reppers
								wait WAIT_TARGETING
							}

							wait WAIT_TARGETING
							
							call LogEcho "Line _LINE_: Setting secondary can n (${n}) as active target."
							Cans.Get[${n}]:MakeActiveTarget
							wait WAIT_TARGET_SWITCH
						
							call LogEcho "Line _LINE_: Activating secondary ${ThisTractorBeam.Value.ToItem.Name} on secondary can ${n}." 
							ThisTractorBeam.Value:Click
							wait WAIT_TRACTOR_STATUS
							call SelectInactiveTractor
						}
					
					}
					else
					{
						if ${Verbose} > 1
						call LogEcho "Line _LINE_: No available tractor for secondary can ${n}"
					}
				}
				
				call LogNewLine

				if ${Verbose} > 1
				call LogEcho "Line _LINE_: We started out inside our loot range, call to see if tractoring can (${i}) ${Cans.Get[${i}].ID}."
				
				call IsTractoringWreckID ${Cans.Get[${i}].ID}
				if !${Return}
				{
					call LogEcho "Line _LINE_: Do we have a tractor? ${AvailableTractor}"
					if ${AvailableTractor}
					{
						while ${Me.TargetingCount} > 0
						{
							call Check_Reppers
							wait WAIT_TARGETING
						}

						if ${Verbose} > 1
						call LogEcho "Line _LINE_: We started out inside our loot range, making i (${i}) ${Cans.Get[${i}].ID} active target."
						Cans.Get[${i}]:MakeActiveTarget
						wait WAIT_TARGET_SWITCH
						if ${Verbose} > 1
						{
							call LogEcho "Line _LINE_: Available tractor? ${AvailableTractor}."
							call LogEcho "Line _LINE_: Activating primary ${ThisTractorBeam.Value.ToItem.Name} on primary can ${i} ${Cans.Get[${i}].ID}." 
						}
						
						ThisTractorBeam.Value:Click
						wait WAIT_TRACTOR_STATUS
						call SelectInactiveTractor
					}
				}
			}
			
					
			if ${Verbose} > 1
			call LogEcho "Line _LINE_: Can ${i} ${Cans.Get[${i}].ID} is now within range. Looting."
			if (${AfterburnerCount} > 0)
			{
			   if (${Afterburners.Get[1].IsActive})
				Afterburners.Get[1]:Click
				wait 2
			}				
		
			/* Loot! */
	  		
	  		call StopTractoringID ${Cans.Get[${i}].ID}
			call LootEntity ${Cans.Get[${i}]}

			
			if ${Cans.Get[${i}](exists)}
			{
				Cans.Get[${i}]:CloseCargo
				
				wait 6
				TargetCount:Set[${Me:GetTargets[Targets]}]
				k:Set[1]
				if ${TargetCount} > 0
				{
				 	do
				 	{
				 		if ${Targets.Get[${k}].ID} == ${Cans.Get[${i}].ID}
				 		{
				 		   Cans.Get[${i}]:UnlockTarget
				 		   break
				 		}
				 		wait 2
				 	}
				 	while ${k:Inc} <= ${TargetCount}
				}
				else
					{
						Cans.Get[${i}]:UnlockTarget
					}
			}

			;wait WAIT_TRACTOR_DEACTIVATE
			i:Inc	
			n:Inc
			j:Set[1]
		}
		/* End main CheckForLoot while loop */
		
	}
	else
	{
		return FALSE
	}
	/* end very long if cancount > 0 */	 	
}

function StopTractoringID(int64 EntityID)
{
	variable iterator ModuleIter

	TractorBeams:GetIterator[ModuleIter]
	if ${ModuleIter:First(exists)}
	do
	{
		if ${ModuleIter.Value.LastTarget(exists)} && \
			${ModuleIter.Value.LastTarget.ID.Equal[${EntityID}]} && \
			${ModuleIter.Value.IsActive}
		{
			ModuleIter.Value:Click
		}
	}
	while ${ModuleIter:Next(exists)}
}

/* Find an inactive or deactivating tractor beam */
function:bool SelectInactiveTractor()
{

variable int i = 0

	if ${Verbose} > 1
	call LogEcho "Line _LINE_: SelectInactiveTractor called. Initial ${ThisTractorBeam.Value.ToItem.Name} Active? ${ThisTractorBeam.Value.IsActive}  Deactivating? ${ThisTractorBeam.Value.IsDeactivating}."

  while ${ThisTractorBeam.Value.IsActive} && !${ThisTractorBeam.Value.IsDeactivating}
  {
  	if ${Verbose} > 1
    call LogEcho "Line _LINE_: ${ThisTractorBeam.Value.ToItem.Name} is busy from last cycle." 

    if ${ThisTractorBeam:Next(exists)}
    {
    	if ${Verbose} > 1
    	{
    		call LogEcho "Line _LINE_: Incrementing tractors. ${ThisTractorBeam.Value.ToItem.Name} is now tractor." 
     		call LogEcho "Line _LINE_: Incremented tractor status. Active: ${ThisTractorBeam.Value.IsActive} Deactivating?: ${ThisTractorBeam.Value.IsDeactivating}."
    	}
    }
    else
    {
      ThisTractorBeam:First

      if ${Verbose} > 1
      {
		call LogEcho "Line _LINE_: Resetting tractors. ${ThisTractorBeam.Value.ToItem.Name} is now tractor."
      	call LogEcho "Line _LINE_: Reset tractor status. Active: ${ThisTractorBeam.Value.IsActive} Deactivating?: ${ThisTractorBeam.Value.IsDeactivating}."
      }
      
    } 

    /* If we have examined every tractor beam, end the loop */
    if ${i:Inc} > ${TractorBeamCount}
    {
    	if ${Verbose} > 1
    	call LogEcho "Line _LINE_: We found no available tractor beam to use."

    	AvailableTractor:Set[FALSE]
    	;wait WAIT_TRACTOR_STATUS
    	return FALSE
    }
  }
  	if ${Verbose} > 1
	call LogEcho "Line _LINE_: We found an available tractor."
	AvailableTractor:Set[TRUE]

	if ${ThisTractorBeam.Value.IsDeactivating}
	{
		if ${Verbose} > 1
			call LogEcho "Line _LINE_: Waiting for tractor beam to deactivate."
		while ${ThisTractorBeam.Value.IsDeactivating}
		{
			wait WAIT_TRACTOR_STATUS
		}
		wait WAIT_TRACTOR_STATUS
    }
return TRUE
}


function:bool IsTractoringWreckID(int64 EntityID)
{

	variable iterator ModuleIter
	TractorBeams:GetIterator[ModuleIter]

	wait GENERIC_WAIT
	
	if ${Verbose} > 2
	call LogEcho "Line _LINE_: IsTractoringWreckID: Called, checking ${EntityID}."
	
	if ${ModuleIter:First(exists)}
	{
		do
		{
			if ${ModuleIter.Value.LastTarget(exists)} && \
				${ModuleIter.Value.LastTarget.ID.Equal[${EntityID}]} && \
				${ModuleIter.Value.IsActive}
			{
				if ${Verbose} > 2
				call LogEcho "Line _LINE_: IsTractoringWreckID? Yes."
				return TRUE
			}
		}
		while ${ModuleIter:Next(exists)}
	}
	
	if ${Verbose} > 2
	call LogEcho "Line _LINE_: IsTractoringWreckID? No."
	return FALSE
}

function LoadAllEntities()
{
	AllEntities:Clear
	EVE:QueryEntities[AllEntities]
	
	if ${Verbose} > 3
		call LogEcho "Loaded ${AllEntities.Used} entities."
}

function CanCloak()
{
	variable int i = 1
	
	call LoadAllEntities
	
	do
	{
		if ${Verbose} > 3
			call LogEcho "Distance to entity ${i} ${AllEntities.Get[${i}].Name} is ${AllEntities.Get[${i}].Distance}. ID is ${AllEntities.Get[${i}].ID}, Group is ${AllEntities.Get[${i}].GroupID}, my ID is ${MyShip.ID}"
	
		if ${AllEntities.Get[${i}].Distance} < 2001 && ${AllEntities.Get[${i}].ID} != ${MyShip.ID}
			return FALSE
		
		if ${Me.InStation}
		break
					
	}
	while ${i:Inc} < ${AllEntities.Used}
	
	return TRUE
}

function NearGate()
{
	variable int i = 1
	
	call LoadAllEntities
	
	do
	{
		if ${Verbose} > 3
		{	
			call LogEcho "Distance to ${AllEntities.Get[${i}].Name} is ${AllEntities.Get[${i}].Distance}. Group is ${AllEntities.Get[${i}].GroupID}"
		}
		elseif ${AllEntities.Get[${i}].GroupID} == GROUP_STARGATE
		{
			if ${Verbose} > 3
			call LogEcho "Stargate to ${AllEntities.Get[${i}].Name} detected."
		}

		/* If we are near a gate, return that gate's index so we can access it via AllEntities */
		if ${AllEntities.Get[${i}].Distance} < 2501 && ${AllEntities.Get[${i}].GroupID} == GROUP_STARGATE
		{
			if ${Verbose} > 3
				call LogEcho "Distance to nearest stargate ${AllEntities.Get[${i}].Name} is ${AllEntities.Get[${i}].Distance}."
			return ${i}
		}
		
		if ${Me.InStation}
		break
					
	}
	while ${i:Inc} < ${AllEntities.Used}
	
	if ${Verbose} > 3
		call LogEcho "We are not near a gate currently." 
	
		
	return FALSE
}

function WarpBlackList()
{
	
	call LogEcho "WarpBlacklist called. For ${GangMember.Get[${Turn}].Name} ${GangMember.Get[${Turn}].CharID}"
	if ${GangMember.Get[${Turn}].CharID} == ${Me.CharID}
	{
		if ${Verbose} > 0
		call LogEcho "Stop trying to haul for yourself, ${Me.Name}. ^_^"
		return TRUE
	}
	
	return FALSE
}

function:bool CanBlackList(int i)
{

	if ${Verbose} > 2
	call LogEcho "ID ${Entity[${i}].Owner.CharID} Name ${Entity[${i}].Owner.Name} owns this can"
	if ${Entity[${i}].Owner.CorporationID} != ${Me.CorporationID}
	{
		if ${Verbose} > 2
		call LogEcho "Owner of can is not in same corp as I am, I'm gonna die."
		return TRUE
	}
	return FALSE
}

function:bool CheckOwnership(int64 i)
{
	if ${Verbose} > 2
	{
		call LogEcho "Owner CharID ${Entity[${i}].OwnerID}"
		call LogEcho "Is owner of i ${i} in my group? ${Me.Fleet.IsMember[${Entity[${i}].OwnerID}]}"
		call LogEcho "Is owner of i ${i} in my group? ${Entity[${i}].Owner.ToFleetMember(exists)}"
		call LogEcho "Do I have loot rights on i ${i}? ${Entity[${i}].HaveLootRights}"
	}


/* (${Entity[${i}].Owner.CorporationID} == ${Me.CorporationID}) */

	if ${Entity[${i}].Owner.ToFleetMember(exists)} && ${Entity[${i}].HaveLootRights}
	{
		if ${Verbose} > 1
		call LogEcho "We have loot rights."
		return TRUE
	}
	
	if ${Verbose} > 1
	call LogEcho "He doesn't like you to haul for him"
	return FALSE
}


function GetModulesInformation()
{
	variable int k = 1
	TractorBeams:Clear
	Salvagers:Clear
	Afterburners:Clear
	Reppers:Clear
	DamageControl:Clear
	SensorBoosters:Clear
	Mindlinks:Clear
	CovertCloaks:Clear
	StandardCloaks:Clear
	variable int GroupID

	
	
	
	/* module data not available inside station, undocking */
	if ${Me.InStation}
	{
		call Undock
	}
	
	/*  Determine the modules at our disposal */
	if ${Verbose} > 0
	call LogEcho "- Acquiring Information about your ship's modules..."
	MyShip:GetModules[AllModules]
	AllModulesCount:Set[${AllModules.Used}]
	if (${AllModulesCount} <= 0)
	{
		call LogEcho "ERROR -- Your ship does not appear to have any modules"
		return
	}
	
	do
	{
		GroupID:Set[${AllModules.Get[${k}].ToItem.GroupID}]
		if ${Verbose} > 2
			call LogEcho "checking ${AllModules.Get[${k}].ToItem.Name}  groupid ${AllModules.Get[${k}].ToItem.GroupID}"
		if ${GroupID} == GROUP_SENSORBOOSTER
		{
			if ${Verbose} > 2
			call LogEcho "Adding ${AllModules.Get[${k}].ToItem.Name} to 'SensorBoosters'"
			SensorBoosters:Insert[${AllModules.Get[${k}]}]
		}
			
			
		if (${AllModules.Get[${k}].MaxTractorVelocity} > 0)
		{
			if ${Verbose} > 2
				call LogEcho "Adding ${AllModules.Get[${k}].ToItem.Name} to 'TractorBeams'"
			
			TractorBeams:Insert[${AllModules.Get[${k}]}]
			
			if ${MaxTractorRange} <= 0
			{
				MaxTractorRange:Set[${AllModules.Get[${k}].OptimalRange}]
				if ${Verbose} > 2
					call LogEcho "MaxTractorRange set to: ${MaxTractorRange}"
			}
		}
		elseif (${AllModules.Get[${k}].MaxVelocityBonus} > 0)
		{
			if ${Verbose} > 2
			call LogEcho "Adding ${AllModules.Get[${k}].ToItem.Name} to 'Afterburners'"
		  Afterburners:Insert[${AllModules.Get[${k}]}] 	  
		}
		elseif (${AllModules.Get[${k}].AccessDifficultyBonus} > 0)
		{
			if ${Verbose} > 2
				call LogEcho "Adding ${AllModules.Get[${k}].ToItem.Name} to 'Salvagers'"
		 
			Salvagers:Insert[${AllModules.Get[${k}]}]
				
			if ${MaxSalvageRange} <= 0
			{
					MaxSalvageRange:Set[${AllModules.Get[${k}].OptimalRange}]
			}   	  
		}	
		elseif (${GroupID} == GROUPID_ARMOR_REPAIRERS)
		{
			if ${Verbose} > 2
				call LogEcho "Adding ${AllModules.Get[${k}].ToItem.Name} to 'Reppers'"
	   
			Reppers:Insert[${AllModules.Get[${k}]}]
		}
		elseif (${GroupID} == GROUPID_DAMAGE_CONTROL)
		{
			if ${Verbose} > 2
				call LogEcho "Adding ${AllModules.Get[${k}].ToItem.Name} to 'Damage Control'"
			
			DamageControl:Insert[${AllModules.Get[${k}]}]
		}
		elseif (${GroupID} == GROUPID_SHIELD_BOOSTER)
		{
			if ${Verbose} > 2
				call LogEcho "Adding ${AllModules.Get[${k}].ToItem.Name} to 'Reppers'"
			Reppers:Insert[${AllModules.Get[${k}]}]
		}
		elseif (${GroupID} == GROUPID_INDUSTRIAL_MINDLINK)
		{
			if ${Verbose} > 2
				call LogEcho "Adding ${AllModules.Get[${k}].ToItem.Name} to 'Mindlinks'"
			Mindlinks:Insert[${AllModules.Get[${k}]}]
		}
		elseif (${GroupID} == GROUPID_CLOAKING_DEVICE)
		{
				if ${AllModules.Get[${k}].MaxVelocityPenalty} == 0
				{
					CovertCloaks:Insert[${AllModules.Get[${k}]}]
				}
				else
					{
						StandardCloaks:Insert[${AllModules.Get[${k}]}]
					}
		}
		else
		{
		call LogEcho "Unknown module ${AllModules.Get[${k}].ToItem.Name} ${GroupID}
		}
	}
	while ${k:Inc} <= ${AllModulesCount}
	
	TractorBeamCount:Set[${TractorBeams.Used}]
	MindlinkCount:Set[${Mindlinks.Used}]
	SalvagerCount:Set[${Salvagers.Used}]
	AfterburnerCount:Set[${Afterburners.Used}]
	RepperCount:Set[${Reppers.Used}]
	DamageControlCount:Set[${DamageControl.Used}]
	SensorBoosterCount:Set[${SensorBoosters.Used}]
	StandardCloakCount:Set[${StandardCloaks.Used}]
	CovertCloakCount:Set[${CovertCloaks.Used}]
  
	 call LogEcho "Your ship has ${TractorBeamCount} Tractor Beams, ${MindlinkCount} mindlink, ${SalvagerCount} Salvage Modules"
	 call LogEcho "${RepperCount} reppers, ${SensorBoosterCount} sensor boosters, ${StandardCloakCount} Standard Cloaks, ${CovertCloakCount} Covert Cloaks,  and ${AfterburnerCount} Afterburner."
}

function BoostSensors()
{
	variable int i == 1
	i:Set[1]
						
	if ${Verbose} > 2				
		call LogEcho "${SensorBoosterCount} sensor boosters found, activating."
					
	if (${SensorBoosterCount} > 0)
	{
		do
		{
			if ${Verbose} > 2
				call LogEcho "Booster ${i},${SensorBoosters.Get[${i}].ToItem.Name} active?  ${SensorBoosters.Get[${i}].IsActive}"
			
	   	   	if (!${SensorBoosters.Get[${i}].IsActive})
			{
				SensorBoosters.Get[${i}]:Click
				wait WAIT_MODULE
			}
		}
		while ${i:Inc} <= ${SensorBoosterCount}
	}


}

function DecrementTurn()
{
	if ${Verbose} > 2
		call LogEcho "Decrementing turn from ${Turn}"
		
	if ${Turn}==1
	{
		Turn:Set[${GangMemberCount}]
	}
	else
	Turn:Dec
	
	if ${Verbose} > 2
	call LogEcho "Turn is now ${Turn}"

}

function CheckForLeftovers()
{
	variable int CansLeft
	variable index:entity CanCheck
	EVE:QueryEntities[CanCheck, "GroupID = GROUPID_CAN && (HaveLootRights = 1 || IsOwnedByCorpMember = 1)"]
	CansLeft:Set[${CanCheck.Used}]

	if ${CansLeft} > 2
	{
		call DecrementTurn
	}

}

function LootCargoContainer(entity CargoContainer)
{	

}

function StackAllCargoInAllHolds()
{
	call OpenShipCargo
	
	wait 5
	EVEWindow[Inventory].ChildWindow[ShipFleetHangar]:MakeActive
	wait 5
	EVEWindow[Inventory]:StackAll
	wait 20
	EVEWindow[Inventory].ChildWindow[ShipOreHold]:MakeActive
	wait 5
	EVEWindow[Inventory]:StackAll
	wait 20
	EVEWindow[Inventory].ChildWindow[ShipCargo]:MakeActive
	wait 5
	EVEWindow[Inventory]:StackAll
}

function LootEntity(entity CargoContainer)
{	

	variable iterator ThisCargo
	variable iterator CargoIterator
	variable float64 TotalCargoVolume = 0
	
	;; Open Entity for looting
	CargoContainer:Open
	wait WAIT_OPENCONTAINER
	;EVEWindow[Inventory]:StackAll
	wait WAIT_OPENCARGO
	call OpenShipCargo
	wait WAIT_OPENCARGO

	
	/* Populate "EntityCargo" (index:item) */
	CargoContainer:GetCargo[EntityCargo]
	EntityCargo:GetIterator[ThisCargo]

	/* Populate 'CargoToTransfer' based upon whether it's set to ignore or not in theLoot Items Database */
	
	CargoToTransfer:Clear
	if ${ThisCargo:First(exists)}
	{
		do
		{
			variable string Name
			Name:Set[${ThisCargo.Value.Name}]			
			
			CheckLootItemDB:Set[${LootItemsDB.FindSetting["${Name}",FALSE]}]
			LavishSettings[Loot Items Database]:Export[${EVELootingFileName}]
			
			; If the entry in the xml is FALSE, then we want to loot it.
			if (!${CheckLootItemDB})
			{
				if (!${LootContraband})
				{
					if (${ThisCargo.Value.IsContraband})
					{
						echo "EVESalvage->LootCargoContainer::  Ignoring ${Name} (CONTRABAND)"
						continue
					}
				}
				
				/* BEGIN FLEET HANGAR BLOCK */

				if ${Verbose} > 2
				{
					call LogEcho "Fleet Hangar Capacity ${EVEWindow[Inventory].ChildWindow[ShipFleetHangar].Capacity}"
					call LogEcho "Fleet Hangar UsedCapacity ${EVEWindow[Inventory].ChildWindow[ShipFleetHangar].UsedCapacity}"
					call LogEcho "Fleet Hangar AvailableCapacity ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[ShipFleetHangar].Capacity} - ${EVEWindow[Inventory].ChildWindow[ShipFleetHangar].UsedCapacity})]}"
					call LogEcho "Number to Transfer ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[ShipFleetHangar].Capacity} - ${EVEWindow[Inventory].ChildWindow[ShipFleetHangar].UsedCapacity}) / ${ThisCargo.Value.Volume} - 2]}"
					call LogEcho "ThisCargo.Value.Quantity ${ThisCargo.Value.Quantity}"
					call LogEcho "ThisCargo.Value.Volume ${ThisCargo.Value.Volume}"
				}
			
				if (${Math.Calc[${ThisCargo.Value.Quantity} * ${ThisCargo.Value.Volume}]}) < (${Math.Calc[(${EVEWindow[Inventory].ChildWindow[ShipFleetHangar].Capacity} - ${EVEWindow[Inventory].ChildWindow[ShipFleetHangar].UsedCapacity})]})
				{
					if ${Verbose} > 2
						call LogEcho "LootEntity: Moving ${ThisCargo.Value.Quantity} ${ThisCargo.Value.Name} ${Math.Calc[${ThisCargo.Value.Quantity} * ${ThisCargo.Value.Volume}]} to Fleet Hangar"
						
					ThisCargo.Value:MoveTo[MyShip,FleetHangar]
					wait WAIT_CARGO_UPDATE
					
					if ${ThisCargo:Next(exists)}
					{
						if ${Verbose} > 2
							call LogEcho "Loot Entity: Fleet Hangar section has detected that the next cargo entry exists."
						continue
					}
					else
					{
						if ${Verbose} > 2
							call LogEcho "Loot Entity: Fleet Hangar section has detected that the next cargo entry does not exist."
						break
					}
			
				}
				else
				{
					
					;if (${Math.Calc[${EVEWindow[Inventory].ChildWindow[ShipFleetHangar].UsedCapacity}<${EVEWindow[Inventory].ChildWindow[ShipFleetHangar].Capacity}*.98]})
					if ${Math.Calc[(${Math.Calc[(${Math.Calc[(${EVEWindow[Inventory].ChildWindow[ShipFleetHangar].Capacity} - ${EVEWindow[Inventory].ChildWindow[ShipFleetHangar].UsedCapacity})]})]}) / ${ThisCargo.Value.Volume} - 2]} > 1
					{
						ThisCargo.Value:MoveTo[MyShip, FleetHangar,  ${Math.Calc[(${Math.Calc[(${Math.Calc[(${EVEWindow[Inventory].ChildWindow[ShipFleetHangar].Capacity} - ${EVEWindow[Inventory].ChildWindow[ShipFleetHangar].UsedCapacity})]})]}) / ${ThisCargo.Value.Volume} - 2]}]
						
						if ${Verbose} > 2
						call LogEcho "LootEntity: Fleet Hangar too full, looting a partial amount."
						wait WAIT_CARGO_UPDATE
					}
					else
					{
					if ${Verbose} > 2
						call LogEcho "LootEntity: Fleet Hangar is completely full, skipping it."
					}
				}
				/* END FLEET HANGAR BLOCK */					

				
				/* BEGIN ORE HOLD BLOCK */
				if ${Verbose} > 2
					call LogEcho "LootEntity: Beginning Ore Hold Checks. Loot category is ${ThisCargo.Value.CategoryID}"
					
				if ${ThisCargo.Value.CategoryID} == CATEGORYID_ORE
				{
				
					if ${Verbose} > 2
					{
						call LogEcho "Ore Hold Capacity ${EVEWindow[Inventory].ChildWindow[ShipOreHold].Capacity}"
						call LogEcho "Ore Hold UsedCapacity ${EVEWindow[Inventory].ChildWindow[ShipOreHold].UsedCapacity}"
						call LogEcho "Ore Hold AvailableCapacity ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[ShipOreHold].Capacity} - ${EVEWindow[Inventory].ChildWindow[ShipOreHold].UsedCapacity})]}"
						call LogEcho "Number to Transfer ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[ShipOreHold].Capacity} - ${EVEWindow[Inventory].ChildWindow[ShipOreHold].UsedCapacity}) / ${ThisCargo.Value.Volume} - 2]}"
						call LogEcho "ThisCargo.Value.Quantity ${ThisCargo.Value.Quantity}"
						call LogEcho "ThisCargo.Value.Volume ${ThisCargo.Value.Volume}"
					}
					
					
					;if (${Math.Calc[${ThisCargo.Value.Quantity} * ${ThisCargo.Value.Volume}]}) < (${Math.Calc[(${EVEWindow[Inventory].ChildWindow[ShipOreHold].Capacity} - ${EVEWindow[Inventory].ChildWindow[ShipOreHold].UsedCapacity})]})
					if (${Math.Calc[${ThisCargo.Value.Quantity} * ${ThisCargo.Value.Volume}]}) < (${Math.Calc[(${EVEWindow[Inventory].ChildWindow[ShipOreHold].Capacity} - ${EVEWindow[Inventory].ChildWindow[ShipOreHold].UsedCapacity})]})
					{
						if ${Verbose} > 2
							call LogEcho "LootEntity: Moving ${ThisCargo.Value.Quantity} ${ThisCargo.Value.Name} ${Math.Calc[${ThisCargo.Value.Quantity} * ${ThisCargo.Value.Volume}]} to Ore Hold"
							
						ThisCargo.Value:MoveTo[MyShip,OreHold]
						wait 5
						
						if ${ThisCargo:Next(exists)}
						{
							if ${Verbose} > 2
								call LogEcho "Loot Entity: Ore hold section has detected that the next cargo entry exists."
							continue
						}
						else
						{
							if ${Verbose} > 2
								call LogEcho "Loot Entity: Ore hold section has detected that the next cargo entry does not exist."
							break
						}						
						
						
					}
					else
					{
						if ${Math.Calc[(${Math.Calc[(${Math.Calc[(${EVEWindow[Inventory].ChildWindow[ShipOreHold].Capacity} - ${EVEWindow[Inventory].ChildWindow[ShipOreHold].UsedCapacity})]})]}) / ${ThisCargo.Value.Volume} - 2]} > 1
						{
							ThisCargo.Value:MoveTo[MyShip, OreHold,  ${Math.Calc[(${Math.Calc[(${Math.Calc[(${EVEWindow[Inventory].ChildWindow[ShipOreHold].Capacity} - ${EVEWindow[Inventory].ChildWindow[ShipOreHold].UsedCapacity})]})]}) / ${ThisCargo.Value.Volume} - 2]}]
							
							if ${Verbose} > 2
							call LogEcho "LootEntity: Ore hold too full, looting a partial amount."
							
							wait WAIT_CARGO_UPDATE
						}
						else
						{
							if ${Verbose} > 2
								call LogEcho "LootEntity: Ore Hold was completely full, skipping it."
						}
					}
				}
				/* END ORE HOLD BLOCK */			
				
				
				
				/* BEGIN STANDARD HOLD BLOCK */
				
				if ${Verbose} > 2
				{
					call LogEcho "Ship Hold Capacity ${EVEWindow[Inventory].ChildWindow[ShipCargo].Capacity}"
					call LogEcho "Ship Hold UsedCapacity ${EVEWindow[Inventory].ChildWindow[ShipCargo].UsedCapacity}"
					call LogEcho "Ship Hold AvailableCapacity ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[ShipCargo].Capacity} - ${EVEWindow[Inventory].ChildWindow[ShipCargo].UsedCapacity})]}"
					call LogEcho "Number to Transfer ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[ShipCargo].Capacity} - ${EVEWindow[Inventory].ChildWindow[ShipCargo].UsedCapacity}) / ${ThisCargo.Value.Volume} - 2]}"
					call LogEcho "ThisCargo.Value.Quantity ${ThisCargo.Value.Quantity}"
					call LogEcho "ThisCargo.Value.Volume ${ThisCargo.Value.Volume}"
				}					
				
				if (${Math.Calc[${ThisCargo.Value.Quantity} * ${ThisCargo.Value.Volume}]}) < (${Math.Calc[(${EVEWindow[Inventory].ChildWindow[ShipCargo].Capacity} - ${EVEWindow[Inventory].ChildWindow[ShipCargo].UsedCapacity})]})
				{
					if ${Verbose} > 2
						call LogEcho "LootEntity: Moving ${ThisCargo.Value.Quantity} ${ThisCargo.Value.Name} ${Math.Calc[${ThisCargo.Value.Quantity} * ${ThisCargo.Value.Volume}]} to Main Cargo Hold."
						
					ThisCargo.Value:MoveTo[MyShip,CargoHold]
					wait WAIT_CARGO_UPDATE
					
					if ${ThisCargo:Next(exists)}
					{
						if ${Verbose} > 2
							call LogEcho "Loot Entity: Standard cargo hold section has detected that the next cargo entry exists."
						continue
					}
					else
					{
						if ${Verbose} > 2
							call LogEcho "Loot Entity: Standard cargo hold section has detected that the next cargo entry does not exist."
						break
					}						
							
				}
				else
				{ /* not enough space for a full stack, do a partial */
					
					if ${Verbose} > 2
					{
						call LogEcho "2 Capacity ${MyShip.CargoCapacity}"
						call LogEcho "2 UsedCapacity ${MyShip.UsedCargoCapacity}"
						call LogEcho "2 AvailableCapacity ${Math.Calc[(${MyShip.CargoCapacity} - ${MyShip.UsedCargoCapacity})]}"
						call LogEcho "2 Number to Transfer ${Math.Calc[(${MyShip.CargoCapacity} - ${MyShip.UsedCargoCapacity}) / ${ThisCargo.Value.Volume} - 2]}"
					}
					
					if ${Verbose} > 2
						call LogEcho "LootEntity:  Main Cargo Hold too full, looting a partial amount."
						
					if ${EVE.Bookmark[AlignHaul](exists)}
					{
						if ${Verbose} > 2
							call LogEcho "Aligning to AlignHaul"
							
						EVE.Bookmark[AlignHaul]:AlignTo
						call PulseAfterburner
					}
						
					ThisCargo.Value:MoveTo[MyShip, CargoHold,  ${Math.Calc[(${Math.Calc[(${Math.Calc[(${EVEWindow[Inventory].ChildWindow[ShipCargo].Capacity} - ${EVEWindow[Inventory].ChildWindow[ShipCargo].UsedCapacity})]})]}) / ${ThisCargo.Value.Volume} - 2]}]
					

					break
				}
				/* END STANDARD HOLD BLOCK */
				
				if ${Verbose} > 2
				{
					call LogEcho "LootEntity has completed a cycle, checking all of the available storage areas on your ship."
				}
			}
			else
			{
				call LogEcho "Ignoring ${ThisCargo.Value.Name}"	
			
				if ${ThisCargo:Next(exists)}
				{
					if ${Verbose} > 2
						call LogEcho "Loot Entity: After ignoring loot, script has detected that the next cargo entry exists."
					continue
					
				}
				else
				{
					if ${Verbose} > 2
						call LogEcho "Loot Entity: After ignoring loot, script has detected that the next cargo entry does not exist."
					break
					
				}
			}
		}
		while ${EndScript} == 0
		/* Special loop, we will only break the loop from within. */
	}
	return
		
}


function TransferItemToShipCargoHold()
{
/* return values indicate whether we had enough space to cover everything */

	if (${Math.Calc[${CargoToTransfer.Get[1].Quantity} * ${CargoToTransfer.Get[1].Volume}]}) < 
	{
		if ${Verbose} > 2
			call LogEcho "LootEntity: Moving ${CargoToTransfer.Get[1].Quantity} ${CargoToTransfer.Get[1].Name} ${Math.Calc[${CargoToTransfer.Get[1].Quantity} * ${CargoToTransfer.Get[1].Volume}]} to MyShip"
			
			EVE:MoveItemsTo[CargoToTransfer,MyShip,CargoHold]
		wait WAIT_CARGO_UPDATE
		
		return TRUE
		
	}
	else
	{
		
		if ${EVE.Bookmark[AlignHaul](exists)}
		{	
			EVE.Bookmark[AlignHaul]:AlignTo
		}
		
			if ${Verbose} > 2
			{
				call LogEcho "2 Capacity ${EVEWindow[Inventory].ChildWindow[ShipCargo].Capacity}"
				call LogEcho "2 UsedCapacity ${EVEWindow[Inventory].ChildWindow[ShipCargo].UsedCapacity}"
				call LogEcho "2 AvailableCapacity ${EVEWindow[Inventory].ChildWindow[ShipCargo].Capacity} - ${EVEWindow[Inventory].ChildWindow[ShipCargo].UsedCapacity})]}"
				call LogEcho "2 Number to Transfer ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[ShipCargo].Capacity} - ${EVEWindow[Inventory].ChildWindow[ShipCargo].UsedCapacity}) / ${CargoToTransfer.Get[1].Volume} - 2]}"
			}
			
		CargoToTransfer.Get[1]:MoveTo[MyShip, CargoHold,  ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[ShipCargo].Capacity} - ${EVEWindow[Inventory].ChildWindow[ShipCargo].UsedCapacity}) / ${CargoToTransfer.Get[1].Volume} - 2]}]
		
		return FALSE
	}
}


function AutoPilotTo(string Destination)
{
variable int i
variable bool DestinationFound
i:Set[1]
DestinationFound:Set[FALSE]

	if ${Me.InStation}
	{
		call LogEcho "Undocking."
		call Undock
		wait GENERIC_WAIT
		
		if ${Verbose} > 2
			call LogEcho "AutoPilotTo: Cargo Capacity is ${MyShip.CargoCapacity}"
			
		if ${MyShip.CargoCapacity} > 60000
		{
			call WaitForSpeedLessThan 0.20
		}
	}

    call GetModulesInformation
	
	do
	{
		if !${EVE.Bookmark[${Destination}](exists)}
		{ 
			if ${Verbose} > 1
			call LogEcho "Bookmark not found, looking for system."
			call AutoToSystem ${Destination}
			DestinationFound:Set[${Return}]
			
		}
		else
		{
			if ${Verbose} > 1
			call LogEcho "Autopiloting to bookmark."
			call AutoToBookmark ${Destination}
			DestinationFound:Set[${Return}]
		}
		wait GENERIC_WAIT
	}
	while !${DestinationFound} && (${i:Inc}<10)
}

function:bool AutoToSystem(string Destination)
{
variable int Counter
Counter:Set[1]
	if (!${Universe[${Destination}](exists)})
	{
		do
		{
			call LogEcho "${Destination} not visible."
			wait 20
		}
		while (!${Universe[${Destination}](exists)} && ${Counter:Inc}<10)
		if ${Counter} > 9
		return FALSE   
	}	  
 
 	while (${Universe[${Destination}].ID} != ${Me.SolarSystemID})
 	{
	  	call LogEcho "Setting autopilot destination: ${Universe[${Destination}]}"
	  	if ${Verbose} > 2
		call LogEcho "My solar system id is ${Me.SolarSystemID} , destination ID is ${Universe[${Destination}].ID}"
		
		Universe[${Destination}]:SetDestination
		wait GENERIC_WAIT

		if ${Verbose} > 1
		call LogEcho "Activating autopilot and waiting until arrival..."
		call ActivateAutopilot ${Destination}
	}
	return TRUE
	

}

function:bool AutoToBookmark(string Destination)
{
variable int Counter
Counter:Set[1]

	if ${Verbose} > 1
	call LogEcho "Autopiloting to bookmark"	
	
	if (!${EVE.Bookmark[${Destination}](exists)})
  	{
  		do
  		{
			call LogEcho "${Destination} not visible."

			if ${Verbose} > 1
			call LogEcho "${EVE.Bookmark[${Destination}]} is lookup result."
			wait 20
  		}
  		while (!${EVE.Bookmark[${Destination}](exists)} && ${Counter:Inc}<10)

		if ${Counter} > 9
		return FALSE	   
  	}

		if ${Verbose} > 1
	  	call LogEcho "- Setting autopilot destination: ${EVE.Bookmark[${Destination}]}"
		
		EVE.Bookmark[${Destination}]:SetDestination
		wait GENERIC_WAIT

		if ${Verbose} > 1
		call LogEcho "- Activating autopilot and waiting until arrival..."
		call ActivateAutopilot ${Destination}

	/* no longer used, but showing how it had been used before.
		call WarpToBookmark ${Destination}
	*/
return TRUE
}

function CloakFor(int Seconds)
{


}

function ActivateAutopilot(string Destination)
{
variable int TimesNearGate = 0
variable int GateCheckSolarSystemID = 0
variable int LastGateThatWasClose = 0
variable int NearGateReturnValue = 0

;not used yet
variable int NearGateEntityID = 0

if ${Verbose} > 0
call LogEcho "ActivateAutoPilot Called"

	if ${Me.InStation}
		return


		
		if !${Me.AutoPilotOn} && ${Me.AutoPilotOn(exists)}
		{
			do
			{
				wait 5
				if !${Me.AutoPilotOn}
					EVE:Execute[CmdToggleAutopilot]
					
				if ${Me.InStation}
					break
			}
			while !${Me.AutoPilotOn} && ${Me.AutoPilotOn(exists)}
		}
	

	if ${MyShip.MaxVelocity} > 0
	{
		if ${Verbose} > 2
			call LogEcho "Afterburner check - cloaked ${Me.ToEntity.IsCloaked} speed percent ${Math.Calc[${Me.ToEntity.Velocity}/${MyShip.MaxVelocity}]}"
					
		if !${Me.ToEntity.IsCloaked} && (${Math.Calc[${Me.ToEntity.Velocity}/${MyShip.MaxVelocity}]} < 0.4) && ${EVE.Bookmark[${Destination}].SolarSystemID} != ${Me.SolarSystemID}
		{
			if ${Verbose} > 2
				call LogEcho "Check succeeded, pulsing burner!"
			
			call WaitForWarp
			call PulseAfterburner
		}
	}

	do
	{
	;bookmark - work out this section later.
		if !${Me.ToEntity.IsCloaked}
		{
			if ${CovertCloakCount} > 0
			{
				if ${Verbose} > 2
					call LogEcho "I am not cloaked, checking for Covert Ops Cloak and activating."
						
				call CanCloak
				if ${Return}
				{
					;call EngageCovertCloak
					wait 1
				}
			}
		}
		
		/* Check to ensure we are not sitting cloaked betweek 2001 and 2500 near the outbound gate */
		
		call NearGate
		
		if !${Return}
		{
			if ${Verbose} > 3
				call LogEcho "NearGate returned False."
		}
		else
		{
			NearGateReturnValue:Set[${Return}]
			TimesNearGate:Inc
			
			if ${Verbose} > 2
				call LogEcho "We are near the stargate to ${AllEntities.Get[${NearGateReturnValue}].Name}. ID is ${AllEntities.Get[${NearGateReturnValue}].ID} TimesNearGate is ${TimesNearGate}"
				
			/* If this is the first time we are near a gate, record which system we are in */
			if ${TimesNearGate} == 1
			{
				GateCheckSolarSystemID:Set[${Me.SolarSystemID}]
			}
			wait 10
			
			if ${LastGateThatWasClose} == 0
			{
				LastGateThatWasClose:Set[${AllEntities.Get[${NearGateReturnValue}].ID}]
				
				if ${Verbose} > 2
					call LogEcho "No previous close gate detected, storing ${AllEntities.Get[${NearGateReturnValue}].ID} in variable: ${LastGateThatWasClose}"
			}
			elseif ${LastGateThatWasClose} != ${AllEntities.Get[${NearGateReturnValue}].ID}
			{
				TimesNearGate:Set[0]
				LastGateThatWasClose:Set[${AllEntities.Get[${NearGateReturnValue}].ID}]
				
				if ${Verbose} > 2
					call LogEcho "This is a new close gate, storing ${AllEntities.Get[${NearGateReturnValue}].ID} in variable: ${LastGateThatWasClose}"
			}
			
			
		}
		
		if ${TimesNearGate} > 60 && ${Me.ToEntity.IsCloaked} && ${Me.AutoPilotOn}
		{
			if ${Verbose} > 2
				call LogEcho "TimesNearGate has hit 61, checking to see if we need to approach gate."
		
			if ${Me.SolarSystemID} == ${GateCheckSolarSystemID}
			{
				if ${Verbose} > 2
					call LogEcho "We have been near the stargate to ${AllEntities.Get[${NearGateReturnValue}].Name} for ${TimesNearGate} seconds. Approaching it."
				
				AllEntities.Get[${NearGateReturnValue}]:Approach
			}
			
			TimesNearGate:Set[0]
		}
		

		
		waitframe
		if ${Verbose} > 3
			call LogEcho "Autopilot On? ${Me.AutoPilotOn} Exists? ${Me.AutoPilotOn(exists)}"
				
		if !${Me.AutoPilotOn} && ${Me.AutoPilotOn(exists)}
		{
			break
		}
			
		if ${Me.InStation}
			break
			
	}
	while ${EndScript} == 0

		call LogEcho "Autopilot appears to have finished, waiting for cloak or station."
		call WaitForCloak

}

function:bool WaitForWarp()
{
variable int i
i:Set[1]

	while (${Me.ToEntity.Mode} != 3) && (${i:Inc} < 35) && !${Me.InStation}
	{
		if ${Verbose} > 2
			call LogEcho "Wait for warp."
			wait 10
	}

	if ${Me.ToEntity.Mode} == 3
	return TRUE
	else
	return FALSE
	
}

function WaitForNoScramble()
{
	while ${Me.ToEntity.IsWarpScrambled}
	{
		call LogEcho "I am Scrambled."
		wait 10
	}
}

function WaitWhileWarping()
{
	while (${Me.ToEntity.Mode} == 3) && !${Me.InStation}
	{
		wait 10
		if ${Verbose} > 2
		call LogEcho "Wait while warping"
		call Check_Reppers
	}
	wait 10
}

function WaitForSpeedLessThan(float Velocity)
{
	if ${Verbose} > 2
		call LogEcho "${Math.Calc[${Me.ToEntity.Velocity}/${MyShip.MaxVelocity}]} is velocity ${Velocity} is goal"

	while ${Math.Calc[${Me.ToEntity.Velocity}/${MyShip.MaxVelocity}]} > ${Velocity}
	{
		wait GENERIC_WAIT
		if ${Verbose} > 2
			call LogEcho "${Math.Calc[${Me.ToEntity.Velocity}/${MyShip.MaxVelocity}]} is velocity ${Velocity} is goal"
	}
}

function WaitForSpeedGreaterThan(float Velocity)
{
	while ${Math.Calc[${Me.ToEntity.Velocity}/${MyShip.MaxVelocity}]} < ${Velocity}
	{
	wait GENERIC_WAIT
	call LogEcho "${Math.Calc[${Me.ToEntity.Velocity}/${MyShip.MaxVelocity}]} is velocity ${Velocity} is goal"
	}
}

function EngageCovertCloak()
{

	if (${CovertCloakCount} > 0)
	{
		if ${Verbose} > 2
			call LogEcho "EngageCovertCloak called. ${CovertCloakCount} Covert Cloaks fitted."

		if !${CovertCloaks.Get[1].IsActive}
		{
			CovertCloaks.Get[1]:Click
		}
	}	
}

function PulseAfterburner()
{
/* Activates the afterburner and turns it off immediately, it helps with getting into warp faster on the orca */

	if ${Verbose} > 2
	call LogEcho "PulseAfterburner called. ${AfterburnerCount} afterburners."

	if (${AfterburnerCount} > 0)
	{

		if ${Afterburners.Get[1].IsActive} && !${Afterburners.Get[1].IsDeactivating}
		{
			Afterburners.Get[1]:Click
		}
		
		if ${Afterburners.Get[1].IsDeactivating}
		{
			do
			{
				wait WAIT_MODULE
			}
			while ${Afterburners.Get[1].IsDeactivating}
			wait 20
		}
		
		if ${Verbose} > 2
		call LogEcho "Current speed is ${Math.Calc[${Me.ToEntity.Velocity}/${MyShip.MaxVelocity}]}%"
		if !${Afterburners.Get[1].IsActive} && (${Math.Calc[${Me.ToEntity.Velocity}/${MyShip.MaxVelocity}]} < 0.4) && ${MyShip.CargoCapacity} > 60000 && !${Afterburners.Get[1].IsDeactivating}
		{
			Afterburners.Get[1]:Click
			wait 90
			Afterburners.Get[1]:Click
		}

		
	}	
}



function WaitForCloak()
{
variable int i
i:Set[1]
		
	if ${Me.InStation}
	{
		return
	}
	
	do
	{
		if ${Verbose} > 2
		call LogEcho "Waiting for cloak."
		wait 10
	}
	while (!${Me.ToEntity.IsCloaked} || ${Me.AutoPilotOn}) && ${i:Inc} < 45
	;after final jump, wait while I am either not cloaked or if autopilot is on, but no more than 45 seconds.
}


function WarpToBookmark(string Bookmark)
{

	if !${EVE.Bookmark[${Bookmark}].ToEntity(exists)} || (${EVE.Bookmark[${Bookmark}].ToEntity.Distance} > 155000
	{
		call LogEcho "Warping to bookmark ${Bookmark}"

		if ${Verbose} > 2
		EVE.Bookmark[${Bookmark}]:WarpTo

		call WaitForWarp
		call PulseAfterburner
		call WaitWhileWarping
	}
}

/* Dock with designated station bookmark entry */
function DockWith(string Destination)
{
	/* A timekeeper */
	variable int Counter

  		if (!${EVE.Bookmark[${Destination}](exists)})
	  	{
	  		do
	  		{
				if ${Verbose} > 1
				{
					call LogEcho "${Destination} not visible."
					call LogEcho "${EVE.Bookmark[${Destination}]} is lookup result."
				}
	  			wait 20
	  		}
	  		while (!${EVE.Bookmark[${Destination}](exists)})	   
	  	}
			if ${Verbose} > 2
				call LogEcho "- Warping to ${EVE.Bookmark[${Destination}].ToEntity.Name}"
			
			call WarpToBookmark ${Destination}
			
			call LogEcho "- Docking with ${EVE.Bookmark[${Destination}].ToEntity.Name}"
			
			if ${EVE.Bookmark[${Destination}].ToEntity(exists)}
			{
				if (${EVE.Bookmark[${Destination}].ToEntity.CategoryID} == 3)
				{
					EVE.Bookmark[${Destination}].ToEntity:Approach
					do
					{
						wait 20
						EVE.Bookmark[${Destination}].ToEntity:Approach
					}
					while (${EVE.Bookmark[${Destination}].ToEntity.Distance} > 300)
					
					wait 20
					EVE.Bookmark[${Destination}].ToEntity:Dock
					
					Counter:Set[0]	
					do
					{
					   wait 20
					   Counter:Inc[20]
					   if (${Counter} > 200)
					   {
					   	call LogEcho " - Docking attempt failed ... trying again."

				      	if ${Verbose} > 2
					   	call LogEcho "- Warping to ${EVE.Bookmark[${Destination}].ToEntity.Name}"

						call WarpToBookmark ${Destination}]
						call PulseAfterburner
						call WaitForWarp
						call WaitWhileWarping
					      
					   	EVE.Bookmark[${Destination}].ToEntity:Approach
					   	wait 20
					    EVE.Bookmark[${Destination}].ToEntity:Dock
					  	wait 20
					    Counter:Set[0]
					   }
					}
					while (!${Me.InStation})					
				}
			}
			wait 30
}



function OpenShipCargo()
{
	if ${Verbose} > 2
	call LogEcho "Called OpenShipCargo"
	
	MyShip:Open
	wait 20
	
	if ${EVEWindow["Inventory"].ChildWindow[ShipFleetHangar].HasCapacity} && ${EVEWindow["Inventory"].ChildWindow[ShipFleetHangar].Capacity} == -1
	{
		call RefreshChildHangars
		return
	}
	
	if ${EVEWindow["Inventory"].ChildWindow[ShipOreHold].HasCapacity} && ${EVEWindow["Inventory"].ChildWindow[ShipOreHold].Capacity} == -1
	{
		call RefreshChildHangars
		return
	}
}

/*  Closes the player's ship cargo hold */
function CloseShipCargo()
{
	if ${Verbose} > 2
		call LogEcho "Called CloseShipCargo"
		
	if ${EVEWindow[Inventory](exists)}
	{
		EVEWindow[Inventory]:Close
				
		while ${EVEWindow[Inventory](exists)}
		{
			wait 0.5
		}
		wait GENERIC_WAIT
	}
}


function ToggleCargo()
{
	if ${Verbose} > 2
		call LogEcho "Called ToggleCargo."
		
	call CloseShipCargo
	wait 10                       
										   
	call OpenShipCargo
	wait 10
		
}

function RefreshChildHangars()
{

	if ${EVEWindow["Inventory"].ChildWindow[ShipFleetHangar].HasCapacity}
	{
		EVEWindow[Inventory].ChildWindow[ShipFleetHangar]:MakeActive
		wait GENERIC_WAIT
	}

	
	if ${Verbose} > 2
	{
		call LogEcho "RefreshChildHangars: Fleet Hangar Capacity ${EVEWindow[Inventory].ChildWindow[ShipFleetHangar].Capacity}"
		call LogEcho "RefreshChildHangars: Fleet Hangar UsedCapacity ${EVEWindow[Inventory].ChildWindow[ShipFleetHangar].UsedCapacity}"
		call LogEcho "RefreshChildHangars: Fleet Hangar AvailableCapacity ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[ShipFleetHangar].Capacity} - ${EVEWindow[Inventory].ChildWindow[ShipFleetHangar].UsedCapacity})]}"
	}

	if ${EVEWindow["Inventory"].ChildWindow[ShipOreHold].HasCapacity}
	{
		EVEWindow[Inventory].ChildWindow[ShipOreHold]:MakeActive
		wait GENERIC_WAIT
	}

	
	if ${Verbose} > 2
	{
		call LogEcho "RefreshChildHangars: Ore Hold Capacity ${EVEWindow[Inventory].ChildWindow[ShipOreHold].Capacity}"
		call LogEcho "RefreshChildHangars: Ore Hold UsedCapacity ${EVEWindow[Inventory].ChildWindow[ShipOreHold].UsedCapacity}"
		call LogEcho "RefreshChildHangars: Ore Hold AvailableCapacity ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[ShipOreHold].Capacity} - ${EVEWindow[Inventory].ChildWindow[ShipOreHold].UsedCapacity})]}"
	}

}

function:bool LoadOreToFreighter()
{

	call OpenShipCargo
	wait WAIT_OPENCARGO
	EVE:Execute[OpenHangarFloor]
	wait WAIT_OPENCARGO
	
	variable iterator ThisCargo
	variable float64 TotalCargoVolume = 0
	variable bool HadOre
	ItemsInStationHangar:Clear
	HadOre:Set[FALSE] /* reword later, it will actually mean "still has ore after loading up" */

	Me:GetHangarItems[ItemsInStationHangar]
	ItemsInStationHangar:GetIterator[ThisCargo]	
	
	
	
	if ${ThisCargo:First(exists)}
	{
		do
		{
			variable string Name
			Name:Set[${ThisCargo.Value.Name}]			

			/* BEGIN LOAD ONLY ORE AND MINERALS */

			if ${ThisCargo.Value.CategoryID} == CATEGORYID_ORE || ${ThisCargo.Value.CategoryID} == CATEGORYID_MINERAL
			{
				HadOre:Set[TRUE]
				if ${Verbose} > 1
				call LogEcho "LoadOreToFreighter: Setting HadOre to TRUE. Result: ${HadOre}."
			
				if ${Verbose} > 2
				{
					call LogEcho "LoadOreToFreighter: Ship Hold Capacity ${EVEWindow[Inventory].ChildWindow[ShipCargo].Capacity}"
					call LogEcho "LoadOreToFreighter: Ship Hold UsedCapacity ${EVEWindow[Inventory].ChildWindow[ShipCargo].UsedCapacity}"
					call LogEcho "LoadOreToFreighter: Ship Hold AvailableCapacity ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[ShipCargo].Capacity} - ${EVEWindow[Inventory].ChildWindow[ShipCargo].UsedCapacity})]}"
					call LogEcho "LoadOreToFreighter: Number to Transfer ${Math.Calc[(${EVEWindow[Inventory].ChildWindow[ShipCargo].Capacity} - ${EVEWindow[Inventory].ChildWindow[ShipCargo].UsedCapacity}) / ${ThisCargo.Value.Volume} - 2]}"
					call LogEcho "LoadOreToFreighter: ThisCargo.Value.Quantity ${ThisCargo.Value.Quantity}"
					call LogEcho "LoadOreToFreighter: ThisCargo.Value.Volume ${ThisCargo.Value.Volume}"
				}					
				
				if (${Math.Calc[${ThisCargo.Value.Quantity} * ${ThisCargo.Value.Volume}]}) < (${Math.Calc[${MyShip.CargoCapacity} - ${MyShip.UsedCargoCapacity}]})
				{
					if ${Verbose} > 2
						call LogEcho "LoadOreToFreighter: Moving ${ThisCargo.Value.Quantity} ${ThisCargo.Value.Name} ${Math.Calc[${ThisCargo.Value.Quantity} * ${ThisCargo.Value.Volume}]} to Main Cargo Hold."
						
					ThisCargo.Value:MoveTo[MyShip,CargoHold]
					wait WAIT_CARGO_UPDATE
					
					if ${ThisCargo:Next(exists)}
					{
						if ${Verbose} > 0
							call LogEcho "Loot Entity: Standard cargo hold section has detected that the next cargo entry exists."
						continue
					}
					else
					{
						if ${Verbose} > 0
							call LogEcho "Loot Entity: Standard cargo hold section has detected that the next cargo entry does not exist."
						break
					}
				}
				else
				{ /* not enough space for a full stack, do a partial */
					
					if ${Verbose} > 2
					{
						call LogEcho "LoadOreToFreighter: Capacity ${MyShip.CargoCapacity}"
						call LogEcho "LoadOreToFreighter: UsedCapacity ${MyShip.UsedCargoCapacity}"
						call LogEcho "LoadOreToFreighter: AvailableCapacity ${Math.Calc[(${MyShip.CargoCapacity} - ${MyShip.UsedCargoCapacity})]}"
						call LogEcho "LoadOreToFreighter: Number to Transfer ${Math.Calc[(${MyShip.CargoCapacity} - ${MyShip.UsedCargoCapacity}) / ${ThisCargo.Value.Volume} - 2]}"
					}
					
					if ${Verbose} > 2
						call LogEcho "LoadOreToFreighter:  Main Cargo Hold too full, looting a partial amount."
						
											
					ThisCargo.Value:MoveTo[MyShip, CargoHold,  ${Math.Calc[(${Math.Calc[${MyShip.CargoCapacity} - ${MyShip.UsedCargoCapacity}]}) / ${ThisCargo.Value.Volume} - 2]}]
					wait wait WAIT_CARGO_UPDATE

					break
				}
				/* END LOAD ONLY ORE AND MINERALS */
			}
			/* End Ore & Mineral Check */
			
			if ${Verbose} > 2
			{
				call LogEcho "LoadOreToFreighter has completed reviewing an item. HadOre is currently set to: ${HadOre}"
			}
		}
		while ${EndScript} == 0
		/* Special loop, we will only break the loop from within. */
	}


/* new check for still having ore left to move later */

	Me:GetHangarItems[ItemsInStationHangar]
	ItemsInStationHangar:GetIterator[ThisCargo]	
	HadOre:Set[FALSE]
		
	if ${ThisCargo:First(exists)}
	{
		do
		{
			if ${ThisCargo.Value.CategoryID} == CATEGORYID_ORE || ${ThisCargo.Value.CategoryID} == CATEGORYID_MINERAL
			{
				HadOre:Set[TRUE]
				if ${Verbose} > 1
					call LogEcho "LoadOreToFreighter finished. Will return HadOre with the value of ${HadOre}"
				return ${HadOre}
			}	

		}
		while ${ThisCargo:Next(exists)}

		HadOre:Set[FALSE]
	}
	
	if ${Verbose} > 1
		call LogEcho "LoadOreToFreighter finished. Will return HadOre with the value of ${HadOre}"
	
	return ${HadOre}
}



function PopulateCargoToTransferFromOrca()
{
	
	variable iterator ThisCargo
	variable iterator AllCargo

	call OpenShipCargo
	wait WAIT_OPENCARGO

	MyShip:GetCargo[ItemsInCargoHold]
	wait 10
	MyShip:GetFleetHangarCargo[ItemsInFleetHangar]
	wait 10
	MyShip:GetOreHoldCargo[ItemsInOreHold]
	wait 10
		
	
	if (${ItemsInCargoHold.Used} == 0) || (${ItemsInOreHold.Used} == 0)
	{
		call LogEcho "PopulateCargoToTransferFromOrca: No cargo found, double checking."
		call ToggleCargo
		
		MyShip:GetCargo[ItemsInCargoHold]
		wait 10
		
;		EVEWindow[Inventory].ChildWindow[ShipFleetHangar]:MakeActive
;		wait 10
		MyShip:GetFleetHangarCargo[ItemsInFleetHangar]
		
;		EVEWindow[Inventory].ChildWindow[ShipOreHold]:MakeActive
;		wait 10
		MyShip:GetOreHoldCargo[ItemsInOreHold]
	}					
	
	if ${Verbose} > 2
	{
		call LogEcho "PopulateCargoToTransferFromOrca: We found ${ItemsInFleetHangar.Used} items in the Fleet Hangar."
		call LogEcho "PopulateCargoToTransferFromOrca: We found ${ItemsInOreHold.Used} items in the Ore Hold."
		call LogEcho "PopulateCargoToTransferFromOrca: We found ${ItemsInCargoHold.Used} items in the Main Cargo Hold."
		call LogEcho "Clearing CargoToTransfer"
	}
		
	CargoToTransfer:Clear

	
	ItemsInCargoHold:GetIterator[ThisCargo]
	
	do
	{
		if ${Verbose} > 2
		{
			call LogEcho "PopulateCargoToTransferFromOrca=>Main Cargo Hold: Adding ${ThisCargo.Value.Name} to list."
		}
		
		if ${ItemsInCargoHold.Used} == 0
		{
			break
		}
		
		if ${Verbose} > 2
		{
			call LogEcho "PopulateCargoToTransferFromOrca=>Main Cargo Hold: Adding ${ThisCargo.Value.Name} to list."
		}
		
		CargoToTransfer:Insert[${ThisCargo.Value.ID}]
		
		if ${Verbose} > 2
			call LogEcho "CargoToTransfer has ${CargoToTransfer.Used} entries."

	}
	while ${ThisCargo:Next(exists)}
			
	ItemsInFleetHangar:GetIterator[ThisCargo]
	
	
	do
	{
		if ${ItemsInFleetHangar.Used} == 0
		{
			break
		}
		
		if ${Verbose} > 2
		{
			call LogEcho "PopulateCargoToTransferFromOrca=>Fleet Hangar: checking ${ThisCargo.Value.Name}."
		}	
		
		if ${ThisCargo.Value.CategoryID} == CATEGORYID_ORE
		{
			if ${Verbose} > 2
				call LogEcho "PopulateCargoToTransferFromOrca=>Fleet Hangar: ${ThisCargo.Value.Name} matches as ore, adding it to the list."
			CargoToTransfer:Insert[${ThisCargo.Value.ID}]

			if ${Verbose} > 2
				call LogEcho "CargoToTransfer has ${CargoToTransfer.Used} entries."
		}	
	}
	while ${ThisCargo:Next(exists)}
	
	ItemsInOreHold:GetIterator[ThisCargo]
	
	do
	{
		if ${Verbose} > 2
		{
			call LogEcho "PopulateCargoToTransferFromOrca::  Checking ${ThisCargo.Value.Name}"
		}	
		
		if ${ItemsInOreHold.Used} == 0
		{
			break
		}
		
		if ${Verbose} > 2
			call LogEcho "PopulateCargoToTransferFromOrca=>Ore Hold: Adding ${ThisCargo.Value.Name} to list."

		CargoToTransfer:Insert[${ThisCargo.Value.ID}]
		
		if ${Verbose} > 2
			call LogEcho "CargoToTransfer has ${CargoToTransfer.Used} entries."
		
	}
	while ${ThisCargo:Next(exists)}
	
	call LogEcho "End of PopulateCargoToTransferFromOrca, we have ${CargoToTransfer.Used} items to transfer."

	return
}

function TransferEverythingToHangar()
{	
	if ${Verbose} > 1
	call LogEcho "TransferEverythingToHangar: Unloading Loot."
	call PopulateCargoToTransferFromOrca
	
	if ${Verbose} > 1
	call LogEcho "TransferEverythingToHangar -- ${CargoToTransfer.Used} items found..."
	
	if (${CargoToTransfer.Used} > 0)
	{
		if ${Verbose} > 2
			call LogEcho "TransferEverythingToHangar: Transferring items to your personal hangar"
	
		EVE:MoveItemsTo[CargoToTransfer, MyStationHangar, Hangar]	
	}
	
	if ${Verbose} > 2
		call LogEcho "Stacking Cargo"

	wait GENERIC_WAIT
	EVEWindow[Inventory].ChildWindow[${Me.StationID},"StationItems"]:MakeActive

	wait WAIT_CARGO_UPDATE
	EVEWindow[Inventory]:StackAll
}

function SetTurns()
{
	if ${Verbose} > 2
		call LogEcho "SetTurns called, current turn is ${Turn}"

	if ${Turn}>=${GangMemberCount}
	{
		if ${Verbose} > 2
			call LogEcho "Looping Turn to 1"
		Turn:Set[1]
	}
	else
	Turn:Inc

	if ${Verbose} > 2
		call LogEcho "Turn is now ${Turn}"
}


function WarpToMiner()
{
variable bool Loop

	do
	{
	call WarpBlackList
		if ${Return}
		{
			call SetTurns
			Loop:Set[TRUE]
		}
		else
		Loop:Set[FALSE]	
	}
	while ${Loop}

		if ${Verbose} > 1
			call LogEcho "Is pilot on overview? ${GangMember.Get[${Turn}].ToEntity(exists)} Distance? ${GangMember.Get[${Turn}].ToEntity.Distance}"
	
		if !${GangMember.Get[${Turn}].ToEntity(exists)} || ${GangMember.Get[${Turn}].ToEntity.Distance} > 160000
		{
			if ${Verbose} > 1
			call LogEcho "Warping to ${GangMember.Get[${Turn}].Name}"

		if ${MyShip.CargoCapacity} > 60000
		{
			GangMember.Get[${Turn}]:WarpTo[30000]
		}
		else
			{
				GangMember.Get[${Turn}]:WarpTo
			}
			wait GENERIC_WAIT

			call WaitForWarp
			call PulseAfterburner
			call WaitWhileWarping
		}


	
}

function LoadGangMembers()
{
	GangMember:Clear
	variable int i = 1
	GangMemberCount:Set[${Me.Fleet.Size}]
	Me.Fleet:GetMembers[GangMember]
	do
	{
		call LogEcho "LoadGangMembers: ${i} ${GangMember.Get[${i}].Name}"
		
		if ${Verbose} > 2
		{
			call LogEcho "LoadGangMembers: ${i} ${GangMember.Get[${i}].CharID}"
			call LogEcho "LoadGangMembers: ${i} ${Me.Fleet.IsMember[${GangMember.Get[${i}].CharID}]}"
		}
	}
	while ${i:Inc} <= ${GangMemberCount}
}

function Undock()
{
variable int Counter

Counter:Set[0]

	EVE:Execute[CmdExitStation]
	do
	{
		wait 10
		Counter:Inc[1]
		
		if ${Counter} > 20
		{
		   Counter:Set[0]
		   EVE:Execute[CmdExitStation]	
		}

	}
	while ${Me.InStation} || !${EVEWindow[Local](exists)} || !${Me.InStation(exists)}
	wait 200
	
	if ${Verbose} > 1
		call LogEcho "Undock: CargoCapactity ${MyShip.CargoCapacity}"

	if ${MyShip.CargoCapacity} > 60000
	{
		EVE:Execute[CmdStopShip]
		waitframe
	}

}


function Stop_Reppers(int GroupToStop)
{
variable int i
variable int GroupID
i:Set[1]

	do
	{
		GroupID:Set[${Reppers.Get[${i}].ToItem.GroupID}]
		if ${Reppers.Get[${i}].IsActive} && (${GroupID} == ${GroupToStop})
		{
			Reppers.Get[${i}]:Click
			wait 10
		}				
	}
	while ${i:Inc} <= ${RepperCount}
}

function Check_DamageControl()
{
	if ${DamageControlCount} > 0
	{
		if !${DamageControl.Get[1].IsActive}
		{
			DamageControl.Get[1]:Click
		}
	}
}

function Check_Reppers()
{
variable int i
variable int GroupID
i:Set[1]

			/* call LogEcho "Armor PCT: ${MyShip.ArmorPct}" */
			if ${MyShip.ArmorPct} == 100
			{
				call Stop_Reppers GROUPID_ARMOR_REPAIRERS
			}
			else
			{
					do
					{
					GroupID:Set[${Reppers.Get[${i}].ToItem.GroupID}]
					
						if ((${MyShip.ArmorPct} < 70) && (${i} <= ${RepperCount}) && (${GroupID} == GROUPID_ARMOR_REPAIRERS))
						{
							if !${Reppers.Get[${i}].IsActive}
							{
								Reppers.Get[${i}]:Click
								wait 10
								continue
							}
						}
									
					if ((${MyShip.ArmorPct} < 80) && (${i} <= ${RepperCount}) && (${GroupID} == GROUPID_ARMOR_REPAIRERS))
						{
							if !${Reppers.Get[${i}].IsActive}
							{
								Reppers.Get[${i}]:Click
								wait 10
							}
						}
					}
					while (${i:Inc} <= ${RepperCount}) 
			}
			
			
			i:Set[1]
			if ${MyShip.ShieldPct} == 100
			{
				call Stop_Reppers GROUPID_SHIELD_BOOSTER
			}
			else
			{
					do
					{
					GroupID:Set[${Reppers.Get[${i}].ToItem.GroupID}]
					
						if ((${MyShip.ShieldPct} < 70) && (${i} <= ${RepperCount}) && (${GroupID} == GROUPID_SHIELD_BOOSTER))
						{
							if !${Reppers.Get[${i}].IsActive}
							{
								Reppers.Get[${i}]:Click
								wait 10
								continue
							}
						}
									
					if ((${MyShip.ShieldPct} < 80) && (${i} <= ${RepperCount}) && (${GroupID} == GROUPID_SHIELD_BOOSTER))
						{
							if !${Reppers.Get[${i}].IsActive}
							{
								Reppers.Get[${i}]:Click
								wait 10
							}
						}
					}
					while (${i:Inc} <= ${RepperCount}) 
			}			

}

function Check_Mindlinks()
{
variable int i
i:Set[1]

if ${MindlinkCount} == 0
{
	if ${Verbose} > 2
	call LogEcho "No mindlinks, exiting Check_Mindlinks."
	return
}

	do
	{
		if !${Mindlinks.Get[${i}].IsActive}
		{
			Mindlinks.Get[${i}]:Click
			wait 1
		}
		
	}
	while (${i:Inc} <= ${MindlinkCount}) 
}


function InitializeLibrary()
{

		EVELootingFilePath:Set["${LavishScript.HomeDirectory}/Scripts/"]
		EVELootingFileName:Set[${EVELootingFilePath}EVEIgnoreLootingItems.xml]

		call LogEcho "**********************"
		call LogEcho "File path set to ${EVELootingFileName}"
		call LogEcho "**********************"
		
		ProcessedEntities:Clear

		LavishSettings:AddSet[Loot Items Database]
		LavishSettings[Loot Items Database]:Clear
		LavishSettings[Loot Items Database]:AddComment["This is your 'ignore' list while looting.  Items set to TRUE will be ignored and therefore NOT looted."]
		LavishSettings[Loot Items Database]:AddSet[${Me.Name}]
		LavishSettings[Loot Items Database]:Import[${EVELootingFileName}]
		
		LootItemsDB:Set[${LavishSettings[Loot Items Database].FindSet[${Me.Name}]}]		
	
	LibraryInitialized:Set[TRUE]
	return
}


function LogNewLine()
{
	echo " "
	redirect -append "${LogFile}" echo " "
}

function LogEcho(string aString)
{
    UIElement[StatusConsole@MainTab@MainTabControl@TheHauler]:Echo["${Time} ${aString}"]
    echo "${aString}"
    redirect -append "${LogFile}" echo "${aString}"
}
