/datum/component/robot_module
	dupe_mode = COMPONENT_DUPE_ALLOWED

	var/list/basic_modules = list()
	var/list/emag_modules = list()
	var/list/ratvar_modules = list()
	var/list/modules = list()
	var/list/added_modules = list()
	var/list/storages = list()

	var/can_be_pushed = TRUE
	var/magpulsing = FALSE
	var/clean_on_move = FALSE

/datum/component/robot_module/Initialize()
	if(!istype(parent, /mob/living/silicon/robot))
		COMPONENT_INCOMPATIBLE

/datum/component/robot_module/proc/get_usable_modules()
	. = modules.Copy()

/datum/component/robot_module/proc/get_inactive_modules(mob/living/silicon/robot/R)
	. = list()
	for(var/m in get_usable_modules())
		if(!(m in R.held_items))
			. += m

/datum/component/robot_module/proc/get_or_create_estorage(var/storage_type)
	for(var/datum/robot_energy_storage/S in storages)
		if(istype(S, storage_type))
			return S
	return new storage_type(src)

/datum/component/robot_module/proc/add_module(obj/item/I, nonstandard, requires_rebuild)
	if(istype(I, /obj/item/stack))
		var/obj/item/stack/S = I

		if(is_type_in_list(S, list(/obj/item/stack/sheet/iron, /obj/item/stack/rods, /obj/item/stack/tile/plasteel)))
			if(S.materials[/datum/material/iron])
				S.cost = S.materials[/datum/material/iron] * 0.25
			S.source = get_or_create_estorage(/datum/robot_energy_storage/metal)

		else if(istype(S, /obj/item/stack/sheet/glass))
			S.cost = 500
			S.source = get_or_create_estorage(/datum/robot_energy_storage/glass)

		else if(istype(S, /obj/item/stack/sheet/rglass/cyborg))
			var/obj/item/stack/sheet/rglass/cyborg/G = S
			G.source = get_or_create_estorage(/datum/robot_energy_storage/metal)
			G.glasource = get_or_create_estorage(/datum/robot_energy_storage/glass)

		else if(istype(S, /obj/item/stack/tile/brass))
			S.cost = 500
			S.source = get_or_create_estorage(/datum/robot_energy_storage/brass)

		else if(istype(S, /obj/item/stack/medical))
			S.cost = 250
			S.source = get_or_create_estorage(/datum/robot_energy_storage/medical)

		else if(istype(S, /obj/item/stack/cable_coil))
			S.cost = 1
			S.source = get_or_create_estorage(/datum/robot_energy_storage/wire)

		else if(istype(S, /obj/item/stack/marker_beacon))
			S.cost = 1
			S.source = get_or_create_estorage(/datum/robot_energy_storage/beacon)

		if(S?.source)
			S.materials = list()
			S.is_cyborg = 1

	if(I.loc != src)
		I.forceMove(src)
	modules += I
	ADD_TRAIT(I, TRAIT_NODROP, CYBORG_ITEM_TRAIT)
	I.mouse_opacity = MOUSE_OPACITY_OPAQUE
	if(nonstandard)
		added_modules += I
	if(requires_rebuild)
		rebuild_modules()
	return I

/datum/component/robot_module/proc/remove_module(obj/item/I, delete_after)
	basic_modules -= I
	modules -= I
	emag_modules -= I
	ratvar_modules -= I
	added_modules -= I
	rebuild_modules()
	if(delete_after)
		qdel(I)

/datum/component/robot_module/proc/respawn_consumable(mob/living/silicon/R, coeff = 1)
	for(var/datum/robot_energy_storage/st in storages)
		st.energy = min(st.max_energy, st.energy + coeff * st.recharge_rate)

	for(var/obj/item/I in get_usable_modules())
		if(istype(I, /obj/item/assembly/flash))
			var/obj/item/assembly/flash/F = I
			F.bulb.charges_left = INFINITY
			F.burnt_out = FALSE
			F.update_icon()
		else if(istype(I, /obj/item/melee/baton))
			var/obj/item/melee/baton/B = I
			if(B.cell)
				B.cell.charge = B.cell.maxcharge
		else if(istype(I, /obj/item/gun/energy))
			var/obj/item/gun/energy/EG = I
			if(!EG.chambered)
				EG.recharge_newshot() //try to reload a new shot.

	R.toner = R.tonermax

/datum/component/robot_module/proc/rebuild_modules(mob/living/silicon/robot/R)
	var/held_modules = R.held_items.Copy()
	R.uneq_all()
	modules = list()
	for(var/obj/item/I in basic_modules)
		add_module(I, FALSE, FALSE)
	if(R.emagged)
		for(var/obj/item/I in emag_modules)
			add_module(I, FALSE, FALSE)
	if(is_servant_of_ratvar(R) && !R.ratvar)	//It just works :^)
		R.SetRatvar(TRUE, FALSE)
	if(R.ratvar)
		for(var/obj/item/I in ratvar_modules)
			add_module(I, FALSE, FALSE)
	for(var/obj/item/I in added_modules)
		add_module(I, FALSE, FALSE)
	for(var/i in held_modules)
		if(i)
			R.activate_module(i)
	if(R.hud_used)
		R.hud_used.update_robot_modules_display()

/datum/component/robot_module/proc/transform_to(datum/module_type)
	//TODO: Write new code for transforming the module without relying on new datums.

/datum/component/robot_module/proc/do_transform_animation(/mob/living/silicon/R)
	if(R.hat)
		R.hat.forceMove(get_turf(R))
		R.hat = null
	R.cut_overlays()
	R.setDir(SOUTH)
	do_transform_delay(R)

/datum/component/robot_module/proc/do_transform_delay(/mob/living/silicon/R)
	var/prev_lockcharge = R.lockcharge
	sleep(1)
	flick("[cyborg_base_icon]_transform", R)
	R.notransform = TRUE
	R.SetLockdown(1)
	R.anchored = TRUE
	sleep(1)
	for(var/i in 1 to 4)
		playsound(R, pick('sound/items/drill_use.ogg', 'sound/items/jaws_cut.ogg', 'sound/items/jaws_pry.ogg', 'sound/items/welder.ogg', 'sound/items/ratchet.ogg'), 80, 1, -1)
		sleep(7)
	if(!prev_lockcharge)
		R.SetLockdown(0)
	R.setDir(SOUTH)
	R.anchored = FALSE
	R.notransform = FALSE
	R.update_headlamp()
	R.notify_ai(NEW_MODULE)
	if(R.hud_used)
		R.hud_used.update_robot_modules_display()
	SSblackbox.record_feedback("tally", "cyborg_modules", 1, src)

/datum/robot_energy_storage
	var/name = "generic energy storage"
	var/max_energy = 30000
	var/recharge_rate = 1000
	var/energy = 0

/datum/robot_energy_storage/New(var/datum/component/robot_module/R = null)
	energy = max_energy
	if(R)
		R.storages |= src
	return

/datum/robot_energy_storage/proc/use_charge(amount)
	if(energy >= amount)
		energy -= amount
		if(energy == 0)
			return 1
		return 2
	else
		return 0

/datum/robot_energy_storage/proc/add_charge(amount)
	energy = min(energy + amount, max_energy)

/datum/robot_energy_storage/metal
	name = "Metal Synthesizer"

/datum/robot_energy_storage/glass
	name = "Glass Synthesizer"

/datum/robot_energy_storage/brass
	name = "Brass Synthesizer"

/datum/robot_energy_storage/wire
	max_energy = 50
	recharge_rate = 2
	name = "Wire Synthesizer"

/datum/robot_energy_storage/medical
	max_energy = 2500
	recharge_rate = 250
	name = "Medical Synthesizer"

/datum/robot_energy_storage/beacon
	max_energy = 30
	recharge_rate = 1
	name = "Marker Beacon Storage"
