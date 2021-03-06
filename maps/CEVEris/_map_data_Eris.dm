#include "overmap-eris.dm"
#include "shuttles-eris.dm"
#include "_CEV_Eris.dmm"
#include "centcomm.dmm"


var/datum/maps_data/maps_data = new

/proc/isStationLevel(var/level)
	return level in maps_data.station_levels

/proc/isNotStationLevel(var/level)
	return !isStationLevel(level)

/proc/isOnStationLevel(var/atom/A)
	var/turf/T = get_turf(A)
	return T && isStationLevel(T.z)

/proc/isPlayerLevel(var/level)
	return level in maps_data.player_levels

/proc/isOnPlayerLevel(var/atom/A)
	var/turf/T = get_turf(A)
	return T && isPlayerLevel(T.z)

/proc/isContactLevel(var/level)
	return level in maps_data.player_levels

/proc/isOnContactLevel(var/atom/A)
	var/turf/T = get_turf(A)
	return T && isContactLevel(T.z)

/proc/isAdminLevel(var/level)
	return level in maps_data.admin_levels

/proc/isNotAdminLevel(var/level)
	return !isAdminLevel(level)

/proc/isOnAdminLevel(var/atom/A)
	var/turf/T = get_turf(A)
	return T && isAdminLevel(T.z)

/proc/get_level_name(var/level)
	return (maps_data.names.len >= level && maps_data.names[level]) || level

/proc/max_default_z_level()
	return maps_data.all_levels.len

/proc/is_on_same_plane_or_station(var/z1, var/z2)
	if(z1 == z2)
		return TRUE
	if(isStationLevel(z1) && isStationLevel(z2))
		return TRUE
	return FALSE

ADMIN_VERB_ADD(/client/proc/test_MD, R_DEBUG, null)
/client/proc/test_MD()
	set name = "Check level data"
	set category = "Debug"

	var/turf/T = get_turf(mob)

	mob << "<b>We are at [T.z] level.</b>"

	mob << "level name is [get_level_name(T.z)]"

	mob << "isStationLevel: [isStationLevel(mob.z)]"
	mob << "isNotStationLevel: [isNotStationLevel(mob.z)]"
	mob << "isOnStationLevel: [isOnStationLevel(mob)]"

	mob << "isPlayerLevel: [isPlayerLevel(mob.z)]"
	mob << "isOnPlayerLevel: [isOnPlayerLevel(mob)]"

	mob << "isAdminLevel: [isAdminLevel(mob.z)]"
	mob << "isNotAdminLevel: [isNotAdminLevel(mob.z)]"
	mob << "isOnAdminLevel: [isOnAdminLevel(mob)]"

	mob << "isAcessableLevel: [maps_data.accessable_levels[num2text(mob.z)]]"

	if(maps_data.asteroid_leves[num2text(T.z)])
		mob << "Asteroid will be generated here"
	else
		mob << "This isn't asteroid level"

/datum/maps_data
	var/list/all_levels        = new
	var/list/station_levels    = new // Z-levels the station exists on
	var/list/admin_levels      = new // Z-levels for admin functionality (Centcom, shuttle transit, etc)
	var/list/player_levels     = new // Z-levels a character can typically reach
	var/list/contact_levels    = new // Z-levels that can be contacted from the station, for eg announcements
	var/list/sealed_levels	   = new // Z-levels that don't allow random transit at edge
	var/list/asteroid_leves    = new
	var/list/accessable_levels = new
	var/list/empty_levels = null     // Empty Z-levels that may be used for various things
	var/list/names = new
	var/security_state = /decl/security_state/default // The default security state system to use.

	var/list/loadout_blacklist	//list of types of loadout items that will not be pickable

	var/default_spawn = "Cryogenic Storage"

	var/allowed_jobs = list(/datum/job/captain, /datum/job/rd, /datum/job/hop, /datum/job/cmo, /datum/job/chief_engineer, /datum/job/ihc,
						/datum/job/gunserg, /datum/job/inspector, /datum/job/medspec, /datum/job/ihoper,
						/datum/job/doctor, /datum/job/chemist, /datum/job/paramedic, /datum/job/psychiatrist,
						/datum/job/technomancer,
						/datum/job/cargo_tech, /datum/job/mining, /datum/job/merchant,
						/datum/job/janitor, /datum/job/chef, /datum/job/bartender, /datum/job/hydro, /datum/job/actor,
						/datum/job/chaplain,
						/datum/job/scientist, /datum/job/roboticist,
						/datum/job/ai, /datum/job/cyborg,
						/datum/job/assistant

						)

	var/overmap_z
	var/overmap_size = 50
	var/overmap_event_areas = 40

	var/emergency_shuttle_docked_message = "The escape pods are now armed. You have approximately %ETD% to board the escape pods."
	var/emergency_shuttle_leaving_dock = "The escape pods have been launched, arriving at rendezvous point in %ETA%."
	var/emergency_shuttle_called_message = "The emergency evacuation procedures are now in effect. Escape pods will be armed in %ETA%"
	var/emergency_shuttle_recall_message = "Emergency evacuation sequence aborted. Return to normal operating conditions."

	var/shuttle_docked_message = "Jump preparation complete. The bluespace drive is now spooling up, secure all stations for departure. Time to jump: approximately %ETD%."
	var/shuttle_leaving_dock = "Jump initiated, exiting bluespace in %ETA%."
	var/shuttle_called_message = "Jump sequence initiated. Transit procedures are now in effect. Jump in %ETA%."
	var/shuttle_recall_message = "Jump sequence aborted, return to normal operating conditions."

	var/list/usable_email_tlds = list("cev_eris.org","eris.scg","eris.net")
	var/path = "eris"

	var/access_modify_region = list(
		ACCESS_REGION_SECURITY = list(access_hos, access_change_ids),
		ACCESS_REGION_MEDBAY = list(access_cmo, access_change_ids),
		ACCESS_REGION_RESEARCH = list(access_rd, access_change_ids),
		ACCESS_REGION_ENGINEERING = list(access_ce, access_change_ids),
		ACCESS_REGION_COMMAND = list(access_change_ids),
		ACCESS_REGION_GENERAL = list(access_change_ids),
		ACCESS_REGION_SUPPLY = list(access_change_ids)
	)

/datum/maps_data/proc/character_save_path(var/slot)
	return "/[path]/character[slot]"

/datum/maps_data/proc/character_load_path(var/savefile/S, var/slot)
	var/original_cd = S.cd
	S.cd = "/"
	. = private_use_legacy_saves(S, slot) ? "/character[slot]" : "/[path]/character[slot]"
	S.cd = original_cd // Attempting to make this call as side-effect free as possible

/datum/maps_data/proc/private_use_legacy_saves(var/savefile/S, var/slot)
	if(!S.dir.Find(path)) // If we cannot find the map path folder, load the legacy save
		return TRUE
	S.cd = "/[path]" // Finally, if we cannot find the character slot in the map path folder, load the legacy save
	return !S.dir.Find("character[slot]")


/datum/maps_data/proc/registrate(var/obj/map_data/MD)
	var/level = MD.z_level
	if(level in all_levels)
		WARNING("[level] is already in all_levels list!")
		qdel(MD)
		return

	MD.loc = null
	if(all_levels.len < level)
		all_levels.len = level
		names.len = level
	all_levels[level] = MD
	names[level] = MD.name

	if(MD.is_station_level)
		station_levels += level

	if(MD.is_admin_level)
		admin_levels += level

	if(MD.is_player_level)
		player_levels += level

	if(MD.is_contact_level)
		contact_levels += level

	if(MD.generate_asteroid)
		asteroid_leves += level

	if(MD.is_accessable_level)
		accessable_levels[num2text(level)] = MD.is_accessable_level

/datum/maps_data/proc/get_empty_zlevel()
	if(empty_levels == null)
		world.maxz++
		empty_levels = list(world.maxz)

		add_z_level(world.maxz, world.maxz, 1)

	return pick(empty_levels)


/obj/map_data
	name = "Map data"
	var/is_admin_level   = FALSE // Defines which Z-levels which are for admin functionality, for example including such areas as Central Command and the Syndicate Shuttle
	var/is_station_level = FALSE // Defines Z-levels on which the station exists
	var/is_player_level  = FALSE // Defines Z-levels a character can typically reach
	var/is_contact_level = FALSE // Defines Z-levels which, for example, a Code Red announcement may affect
	var/is_accessable_level = TRUE // Prob modifier for random access (space travelling)
	var/generate_asteroid= FALSE
	var/tmp/z_level
	var/height = -1	///< The number of Z-Levels in the map.

/obj/map_data/station
	name = "Station Level"
	is_station_level = TRUE
	is_player_level = TRUE
	is_contact_level = TRUE
	is_accessable_level = TRUE
	height = 5

/obj/map_data/admin
	name = "Admin Level"
	is_admin_level = TRUE
	is_accessable_level = FALSE
	height = 1

/obj/map_data/asteroid
	name = "Asteroid Level"
	is_player_level = TRUE
	is_contact_level = TRUE
	generate_asteroid = TRUE
	is_accessable_level = TRUE
	height = 1

