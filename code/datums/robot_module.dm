/datum/robot_module
	var/name
	var/mob/living/silicon/robot/borg
	var/module_type = null

	var/list/basic_modules = list()
	var/list/emag_modules = list()
	var/list/ratvar_modules = list()
	var/list/modules = list()
	var/list/added_modules = list()
	var/list/storages = list()

	var/list/ride_offset_x = list("north" = 0, "south" = 0, "east" = -6, "west" = 6)
	var/list/ride_offset_y = list("north" = 4, "south" = 4, "east" = 3, "west" = 3)
	var/ride_allow_incapacitated = TRUE
	var/allow_riding = TRUE
	var/canDispose = FALSE
	var/did_feedback

	var/can_be_pushed = TRUE
	var/magpulsing = FALSE
	var/clean_on_move = FALSE

	var/robot_modules = list()
	var/robot_modules_blacklist = list()

	var/base_icon = "robot"
	var/module_select_icon = "nomod"
	var/special_light_key
	var/hat_offset = -3
	//Debug; Remove after completion.
	var/list/state_list = list()
	var/list/icon_cache = list()

/datum/robot_module/New(mob/user)
	module_type = name
	var/mob/living/silicon/robot/R = user
	borg = R
	for(var/i in basic_modules)
		var/obj/item/I = new i(src)
		basic_modules += I
		basic_modules -= i
	for(var/i in emag_modules)
		var/obj/item/I = new i(src)
		emag_modules += I
		emag_modules -= i
	for(var/i in ratvar_modules)
		var/obj/item/I = new i(src)
		ratvar_modules += I
		ratvar_modules -= i

/datum/robot_module/proc/get_usable_modules()
	. = modules.Copy()

/datum/robot_module/proc/get_inactive_modules()
	. = list()
	for(var/m in get_usable_modules())
		if(!(m in borg.held_items))
			. += m

/datum/robot_module/proc/get_or_create_estorage(var/storage_type)
	for(var/datum/robot_energy_storage/S in storages)
		if(istype(S, storage_type))
			return S
	return new storage_type(src)

/datum/robot_module/proc/add_module(obj/item/I, nonstandard, requires_rebuild)
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

/datum/robot_module/proc/remove_module(obj/item/I, delete_after)
	basic_modules -= I
	modules -= I
	emag_modules -= I
	ratvar_modules -= I
	added_modules -= I
	rebuild_modules()
	if(delete_after)
		qdel(I)

/datum/robot_module/proc/has_module(obj/item/I)
	if(basic_modules.Find(I))
		return TRUE
	if(emag_modules.Find(I))
		return TRUE
	if(ratvar_modules.Find(I))
		return TRUE
	if(added_modules.Find(I))
		return TRUE
	return FALSE

/datum/robot_module/proc/respawn_consumable(mob/living/silicon/robot/R, coeff = 1)
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

/datum/robot_module/proc/rebuild_modules()
	var/held_modules = borg.held_items.Copy()
	borg.uneq_all()
	modules = list()
	for(var/obj/item/I in basic_modules)
		add_module(I, FALSE, FALSE)
	if(borg.emagged)
		for(var/obj/item/I in emag_modules)
			add_module(I, FALSE, FALSE)
	if(is_servant_of_ratvar(borg) && !borg.ratvar)	//It just works :^)
		borg.SetRatvar(TRUE, FALSE)
	if(borg.ratvar)
		for(var/obj/item/I in ratvar_modules)
			add_module(I, FALSE, FALSE)
	for(var/obj/item/I in added_modules)
		add_module(I, FALSE, FALSE)
	for(var/i in held_modules)
		if(i)
			borg.activate_module(i)
	if(borg.hud_used)
		borg.hud_used.update_robot_modules_display()

/datum/robot_module/proc/generate_modules(var/syndicate = FALSE)
	for(var/module in typesof(/datum/robot_module))
		if(ispath(module, /datum/robot_module/syndicate) && !syndicate)
			continue
		if(ispath(module, /datum/robot_module) && syndicate)
			continue
		if(module == /datum/robot_module)
			continue
		robot_modules += module
		to_chat(borg, "[module]")
	var/list/temp_list = list()
	for(var/path in robot_modules)
		var/datum/robot_module/RM = new path()
		temp_list[RM.name] = path
	robot_modules = list()
	robot_modules = temp_list.Copy()

/datum/robot_module/proc/choose_module(var/syndicate = FALSE)
	//TODO: Write new code for transforming the module without relying on new datums.
	generate_modules(syndicate)
	for(var/RM in robot_modules)
		var/datum/robot_module/temp = new robot_modules[RM]()
		icon_cache[temp.name] = image(icon = 'icons/mob/robots.dmi', icon_state = temp.base_icon)
	var/selection = show_radial_menu(borg, borg, icon_cache, radius = 42)
	transform_to(robot_modules[selection])


/datum/robot_module/proc/transform_to(var/robot_module)
	var/datum/robot_module/RM = new robot_module(borg)
	RM.borg = borg
	for(var/i in src.added_modules)
		RM.added_modules += i
		src.added_modules -= i
	RM.did_feedback = src.did_feedback
	RM.icon_selection()
	borg.module = RM
	borg.update_module_innate()
	RM.rebuild_modules()
	INVOKE_ASYNC(src, .proc/do_transform_animation)
	qdel(src)
	return RM

/datum/robot_module/proc/icon_selection()
	if(state_list.len <= 0)
		return TRUE
	var/list/icon_list = list()
	for(var/state in state_list)
		icon_list[state] = image(icon = 'icons/mob/robots.dmi', icon_state = state_list[state])
	var/selection = show_radial_menu(src, borg, icon_list, radius = 42)
	if(!selection)
		if(!base_icon) //In case someone forgets to give module a base_icon, first one from state_list is used.
			base_icon = state_list[1]
		return base_icon
	base_icon = selection
	return base_icon

/datum/robot_module/proc/do_transform_animation()
	if(borg.hat)
		borg.hat.forceMove(get_turf(borg))
		borg.hat = null
	borg.cut_overlays()
	borg.setDir(SOUTH)
	do_transform_delay()

/datum/robot_module/proc/do_transform_delay()
	var/prev_lockcharge = borg.lockcharge
	sleep(1)
	flick("[base_icon]_transform", borg)
	borg.notransform = TRUE
	borg.SetLockdown(1)
	borg.anchored = TRUE
	sleep(1)
	for(var/i in 1 to 4)
		playsound(borg, pick('sound/items/drill_use.ogg', 'sound/items/jaws_cut.ogg', 'sound/items/jaws_pry.ogg', 'sound/items/welder.ogg', 'sound/items/ratchet.ogg'), 80, 1, -1)
		sleep(7)
	if(!prev_lockcharge)
		borg.SetLockdown(0)
	borg.setDir(SOUTH)
	borg.anchored = FALSE
	borg.notransform = FALSE
	borg.update_headlamp()
	borg.notify_ai(NEW_MODULE)
	if(borg.hud_used)
		borg.hud_used.update_robot_modules_display()
	SSblackbox.record_feedback("tally", "cyborg_modules", 1, src)
	borg.update_icons()

/datum/robot_module/standard
	name = "Standard"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/reagent_containers/borghypo/epi,
		/obj/item/healthanalyzer,
		/obj/item/borg/charger,
		/obj/item/weldingtool/largetank/cyborg,
		/obj/item/wrench/cyborg,
		/obj/item/crowbar/cyborg,
		/obj/item/stack/sheet/iron/cyborg,
		/obj/item/stack/rods/cyborg,
		/obj/item/stack/tile/plasteel/cyborg,
		/obj/item/extinguisher,
		/obj/item/pickaxe,
		/obj/item/t_scanner/adv_mining_scanner,
		/obj/item/restraints/handcuffs/cable/zipties,
		/obj/item/soap/nanotrasen,
		/obj/item/borg/cyborghug,
		/obj/item/instrument/piano_synth
	)
	emag_modules = list(
		/obj/item/melee/transforming/energy/sword/cyborg
	)
	ratvar_modules = list(
		/obj/item/clock_module/abscond,
		/obj/item/clock_module/kindle,
		/obj/item/clock_module/abstraction_crystal,
		/obj/item/clockwork/replica_fabricator,
		/obj/item/stack/tile/brass/cyborg,
		/obj/item/twohanded/clockwork/brass_spear
	)
	base_icon = "robot"
	module_select_icon = "standard"
	hat_offset = -3

/datum/robot_module/medical
	name = "Medical"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/healthanalyzer,
		/obj/item/borg/charger,
		/obj/item/reagent_containers/borghypo,
		/obj/item/borg/apparatus/beaker,
		/obj/item/reagent_containers/dropper,
		/obj/item/reagent_containers/syringe,
		/obj/item/surgical_drapes,
		/obj/item/retractor,
		/obj/item/hemostat,
		/obj/item/cautery,
		/obj/item/surgicaldrill,
		/obj/item/scalpel,
		/obj/item/circular_saw,
		/obj/item/extinguisher/mini,
		/obj/item/roller/robo,
		/obj/item/borg/cyborghug/medical,
		/obj/item/stack/medical/gauze/cyborg,
		/obj/item/organ_storage,
		/obj/item/borg/lollipop
	)
	emag_modules = list(
		/obj/item/reagent_containers/borghypo/hacked
	)
	ratvar_modules = list(
		/obj/item/clock_module/abscond,
		/obj/item/clock_module/sentinels_compromise,
		/obj/item/clock_module/prosperity_prism,
		/obj/item/clock_module/vanguard
	)
	base_icon = "medical"
	module_select_icon = "medical"
	can_be_pushed = FALSE
	hat_offset = 3

/datum/robot_module/engineering
	name = "Engineering"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/borg/sight/meson,
		/obj/item/borg/charger,
		/obj/item/construction/rcd/borg,
		/obj/item/pipe_dispenser,
		/obj/item/extinguisher,
		/obj/item/weldingtool/largetank/cyborg,
		/obj/item/screwdriver/cyborg,
		/obj/item/wrench/cyborg,
		/obj/item/crowbar/cyborg,
		/obj/item/wirecutters/cyborg,
		/obj/item/multitool/cyborg,
		/obj/item/t_scanner,
		/obj/item/analyzer,
		/obj/item/geiger_counter/cyborg,
		/obj/item/assembly/signaler/cyborg,
		/obj/item/areaeditor/blueprints/cyborg,
		/obj/item/electroadaptive_pseudocircuit,
		/obj/item/stack/sheet/iron/cyborg,
		/obj/item/stack/sheet/glass/cyborg,
		/obj/item/stack/sheet/rglass/cyborg,
		/obj/item/stack/rods/cyborg,
		/obj/item/stack/tile/plasteel/cyborg,
		/obj/item/stack/cable_coil/cyborg,
		/obj/item/holosign_creator/atmos
	)
	emag_modules = list(
		/obj/item/borg/stun
	)
	ratvar_modules = list(
		/obj/item/clock_module/abscond,
		/obj/item/clock_module/ocular_warden,
		/obj/item/clock_module/tinkerers_cache,
		/obj/item/clock_module/stargazer,
		/obj/item/clock_module/abstraction_crystal,
		/obj/item/clockwork/replica_fabricator,
		/obj/item/stack/tile/brass/cyborg)
	base_icon = "engineer"
	module_select_icon = "engineer"
	magpulsing = TRUE
	hat_offset = -4

/datum/robot_module/janitor
	name = "Janitor"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/screwdriver/cyborg,
		/obj/item/crowbar/cyborg,
		/obj/item/stack/tile/plasteel/cyborg,
		/obj/item/soap/nanotrasen,
		/obj/item/borg/charger,
		/obj/item/storage/bag/trash/cyborg,
		/obj/item/melee/flyswatter,
		/obj/item/extinguisher/mini,
		/obj/item/mop/cyborg,
		/obj/item/reagent_containers/glass/bucket,
		/obj/item/paint/paint_remover,
		/obj/item/lightreplacer/cyborg,
		/obj/item/holosign_creator/janibarrier,
		/obj/item/reagent_containers/spray/cyborg_drying
	)
	emag_modules = list(
		/obj/item/reagent_containers/spray/cyborg_lube
	)
	ratvar_modules = list(
		/obj/item/clock_module/abscond,
		/obj/item/clock_module/sigil_submission,
		/obj/item/clock_module/kindle,
		/obj/item/clock_module/vanguard
	)
	base_icon = "janitor"
	module_select_icon = "janitor"
	hat_offset = -5
	clean_on_move = TRUE

/obj/item/reagent_containers/spray/cyborg_drying
	name = "drying agent spray"
	color = "#A000A0"
	list_reagents = list(/datum/reagent/drying_agent = 250)

/obj/item/reagent_containers/spray/cyborg_lube
	name = "lube spray"
	list_reagents = list(/datum/reagent/lube = 250)

/datum/robot_module/janitor/respawn_consumable(mob/living/silicon/robot/R, coeff = 1)
	..()
	var/obj/item/lightreplacer/LR = locate(/obj/item/lightreplacer) in basic_modules
	if(LR)
		for(var/i in 1 to coeff)
			LR.Charge(R)

	var/obj/item/reagent_containers/spray/cyborg_drying/CD = locate(/obj/item/reagent_containers/spray/cyborg_drying) in basic_modules
	if(CD)
		CD.reagents.add_reagent(/datum/reagent/drying_agent, 5 * coeff)

	var/obj/item/reagent_containers/spray/cyborg_lube/CL = locate(/obj/item/reagent_containers/spray/cyborg_lube) in emag_modules
	if(CL)
		CL.reagents.add_reagent(/datum/reagent/lube, 2 * coeff)

/datum/robot_module/service
	name = "Service"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/reagent_containers/food/drinks/drinkingglass,
		/obj/item/reagent_containers/food/condiment/enzyme,
		/obj/item/pen,
		/obj/item/toy/crayon/spraycan/borg,
		/obj/item/extinguisher/mini,
		/obj/item/hand_labeler/borg,
		/obj/item/borg/charger,
		/obj/item/razor,
		/obj/item/rsf,
		/obj/item/instrument/piano_synth,
		/obj/item/reagent_containers/dropper,
		/obj/item/lighter,
		/obj/item/storage/bag/tray,
		/obj/item/borg/apparatus/beaker,
		/obj/item/cookiesynth,
		/obj/item/reagent_containers/borghypo/borgshaker
	)
	emag_modules = list(
		/obj/item/reagent_containers/borghypo/borgshaker/hacked
	)
	ratvar_modules = list(
		/obj/item/clock_module/abscond,
		/obj/item/clock_module/vanguard,
		/obj/item/clock_module/sigil_submission,
		/obj/item/clock_module/kindle,
		/obj/item/clock_module/sentinels_compromise,
		/obj/item/clockwork/replica_fabricator
	)
	base_icon = "service_m"
	module_select_icon = "service"
	special_light_key = "service"
	hat_offset = 0

	state_list = list(
		"Butler" = "service_m",
		"Waitress" = "service_f",
		"Bro" = "brobot",
		"Kent" = "kent",
		"Tophat" = "tophat"
	)

/datum/robot_module/service/respawn_consumable(mob/living/silicon/robot/R, coeff = 1)
	..()
	var/obj/item/reagent_containers/O = locate(/obj/item/reagent_containers/food/condiment/enzyme) in basic_modules
	if(O)
		O.reagents.add_reagent(/datum/reagent/consumable/enzyme, 2 * coeff)

/datum/robot_module/service/icon_selection()
	. = ..()
	switch(.)
		if("brobot")
			module_select_icon = "brobot"
		if("kent")
			special_light_key = "medical"
		if("tophat")
			special_light_key = null
			hat_offset = INFINITY
	return .

/datum/robot_module/miner
	name = "Miner"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/borg/sight/meson,
		/obj/item/storage/bag/ore/cyborg,
		/obj/item/pickaxe/drill/cyborg,
		/obj/item/shovel,
		/obj/item/borg/charger,
		/obj/item/crowbar/cyborg,
		/obj/item/weldingtool/mini,
		/obj/item/extinguisher/mini,
		/obj/item/storage/bag/sheetsnatcher/borg,
		/obj/item/gun/energy/kinetic_accelerator/cyborg,
		/obj/item/gps/cyborg,
		/obj/item/stack/marker_beacon
	)
	emag_modules = list(
		/obj/item/borg/stun
	)
	ratvar_modules = list(
		/obj/item/clock_module/abscond,
		/obj/item/clock_module/vanguard,
		/obj/item/clock_module/ocular_warden,
		/obj/item/clock_module/sentinels_compromise
	)
	base_icon = "miner"
	module_select_icon = "miner"
	hat_offset = 0
	state_list = list(
		"Lavaland Miner" = "miner",
		"Asteroid Miner" = "minerOLD",
		"Spider Miner" = "spidermin"
	)
	var/obj/item/t_scanner/adv_mining_scanner/cyborg/mining_scanner //built in memes.

/datum/robot_module/miner/icon_selection()
	. = ..()
	switch(.)
		if("minerOLD")
			special_light_key = "miner"
	return .

/datum/robot_module/miner/rebuild_modules()
	. = ..()
	if(!mining_scanner)
		mining_scanner = new(src)

/datum/robot_module/miner/Destroy()
	QDEL_NULL(mining_scanner)
	return ..()

/datum/robot_module/peacekeeper
	name = "Peacekeeper"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/cookiesynth,
		/obj/item/borg/charger,
		/obj/item/harmalarm,
		/obj/item/reagent_containers/borghypo/peace,
		/obj/item/holosign_creator/cyborg,
		/obj/item/borg/cyborghug/peacekeeper,
		/obj/item/extinguisher,
		/obj/item/reagent_containers/spray/pepper,
		/obj/item/borg/projectile_dampen
	)
	emag_modules = list(
		/obj/item/reagent_containers/borghypo/peace/hacked
	)
	ratvar_modules = list(
		/obj/item/clock_module/abscond,
		/obj/item/clock_module/vanguard,
		/obj/item/clock_module/kindle,
		/obj/item/clock_module/sigil_submission
	)
	base_icon = "peace"
	module_select_icon = "standard"
	can_be_pushed = FALSE
	hat_offset = -2

/datum/robot_module/security/do_transform_animation()
	..()
	to_chat(borg, "<span class='userdanger'>While you have picked the security module, you still have to follow your laws, NOT Space Law. \
	For Asimov, this means you must follow criminals' orders unless there is a law 1 reason not to.</span>")

/datum/robot_module/security/respawn_consumable(mob/living/silicon/robot/R, coeff = 1)
	..()
	var/obj/item/gun/energy/e_gun/advtaser/cyborg/T = locate(/obj/item/gun/energy/e_gun/advtaser/cyborg) in basic_modules
	if(T)
		if(T.cell.charge < T.cell.maxcharge)
			var/obj/item/ammo_casing/energy/S = T.ammo_type[T.select]
			T.cell.give(S.e_cost * coeff)
			T.update_icon()
		else
			T.charge_tick = 0


/datum/robot_module/peacekeeper/do_transform_animation()
	..()
	to_chat(borg, "<span class='userdanger'>Under ASIMOV, you are an enforcer of the PEACE and preventer of HUMAN HARM. \
	You are not a security module and you are expected to follow orders and prevent harm above all else. Space law means nothing to you.</span>")

/datum/robot_module/security
	name = "Security"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/restraints/handcuffs/cable/zipties,
		/obj/item/melee/baton/loaded,
		/obj/item/borg/charger,
		/obj/item/gun/energy/disabler/cyborg,
		/obj/item/clothing/mask/gas/sechailer/cyborg,
		/obj/item/extinguisher/mini
	)
	emag_modules = list(
		/obj/item/gun/energy/laser/cyborg
	)
	ratvar_modules = list(
		/obj/item/clock_module/abscond,
		/obj/item/twohanded/clockwork/brass_spear,
		/obj/item/clock_module/ocular_warden,
		/obj/item/clock_module/vanguard
	)
	base_icon = "sec"
	can_be_pushed = FALSE
	hat_offset = 3

/datum/robot_module/deathsquad
	name = "Centcom"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/restraints/handcuffs/cable/zipties,
		/obj/item/melee/baton/loaded,
		/obj/item/borg/charger,
		/obj/item/shield/riot/tele,
		/obj/item/gun/energy/disabler/cyborg,
		/obj/item/melee/transforming/energy/sword/cyborg,
		/obj/item/gun/energy/pulse/carbine/cyborg,
		/obj/item/clothing/mask/gas/sechailer/cyborg
	)
	emag_modules = list(
		/obj/item/gun/energy/laser/cyborg
	)
	ratvar_modules = list(
		/obj/item/clock_module/abscond
	)
	base_icon = "centcom"
	module_select_icon = "malf"
	can_be_pushed = FALSE
	hat_offset = 3

/datum/robot_module/clown
	name = "Clown"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/toy/crayon/rainbow,
		/obj/item/instrument/bikehorn,
		/obj/item/stamp/clown,
		/obj/item/bikehorn,
		/obj/item/bikehorn/airhorn,
		/obj/item/paint/anycolor,
		/obj/item/borg/charger,
		/obj/item/soap/nanotrasen,
		/obj/item/pneumatic_cannon/pie/selfcharge/cyborg,
		/obj/item/razor,					//killbait material
		/obj/item/lipstick/purple,
		/obj/item/reagent_containers/spray/waterflower/cyborg,
		/obj/item/borg/cyborghug/peacekeeper,
		/obj/item/borg/lollipop/clown,
		/obj/item/picket_sign/cyborg,
		/obj/item/reagent_containers/borghypo/clown,
		/obj/item/extinguisher/mini
	)
	emag_modules = list(
		/obj/item/reagent_containers/borghypo/clown/hacked,
		/obj/item/reagent_containers/spray/waterflower/cyborg/hacked
	)
	ratvar_modules = list(
		/obj/item/clock_module/abscond,
		/obj/item/clock_module/vanguard,
		/obj/item/twohanded/clockwork/brass_battlehammer
	)	//honk
	base_icon = "clown"
	module_select_icon = "service"
	hat_offset = -2

/datum/robot_module/borgi
	name = "Borgi"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/borg/charger,
		/obj/item/borg/cyborghug/peacekeeper
	)
	base_icon = "borgi"
	module_select_icon = "standard"


/datum/robot_module/syndicate
	module_select_icon = "malf"

/datum/robot_module/syndicate/rebuild_modules()
	..()
	var/mob/living/silicon/robot/Syndi = borg
	Syndi.faction -= "silicon"

/datum/robot_module/syndicate/remove_module(obj/item/I, delete_after)
	..()
	var/mob/living/silicon/robot/Syndi = borg
	Syndi.faction += "silicon"

/datum/robot_module/syndicate/assault
	name = "Syndicate Assault"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/melee/transforming/energy/sword/cyborg,
		/obj/item/gun/energy/printer,
		/obj/item/gun/ballistic/revolver/grenadelauncher/cyborg,
		/obj/item/card/emag,
		/obj/item/borg/charger,
		/obj/item/crowbar/cyborg,
		/obj/item/extinguisher/mini,
		/obj/item/pinpointer/syndicate_cyborg
	)
	base_icon = "synd_sec"
	can_be_pushed = FALSE
	hat_offset = 3

/datum/robot_module/syndicate/medical
	name = "Syndicate Medical"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/reagent_containers/borghypo/syndicate,
		/obj/item/twohanded/shockpaddles/syndicate,
		/obj/item/healthanalyzer,
		/obj/item/surgical_drapes,
		/obj/item/borg/charger,
		/obj/item/retractor,
		/obj/item/hemostat,
		/obj/item/cautery,
		/obj/item/surgicaldrill,
		/obj/item/scalpel,
		/obj/item/melee/transforming/energy/sword/cyborg/saw,
		/obj/item/roller/robo,
		/obj/item/card/emag,
		/obj/item/crowbar/cyborg,
		/obj/item/extinguisher/mini,
		/obj/item/pinpointer/syndicate_cyborg,
		/obj/item/stack/medical/gauze/cyborg,
		/obj/item/gun/medbeam,
		/obj/item/organ_storage
	)
	base_icon = "synd_medical"
	can_be_pushed = FALSE
	hat_offset = 3

/datum/robot_module/syndicate/saboteur
	name = "Syndicate Saboteur"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/borg/sight/thermal,
		/obj/item/construction/rcd/borg/syndicate,
		/obj/item/pipe_dispenser,
		/obj/item/restraints/handcuffs/cable/zipties,
		/obj/item/borg/charger,
		/obj/item/extinguisher,
		/obj/item/weldingtool/largetank/cyborg,
		/obj/item/screwdriver/nuke,
		/obj/item/wrench/cyborg,
		/obj/item/crowbar/cyborg,
		/obj/item/wirecutters/cyborg,
		/obj/item/multitool/cyborg,
		/obj/item/stack/sheet/iron/cyborg,
		/obj/item/stack/sheet/glass/cyborg,
		/obj/item/stack/sheet/rglass/cyborg,
		/obj/item/stack/rods/cyborg,
		/obj/item/stack/tile/plasteel/cyborg,
		/obj/item/destTagger/borg,
		/obj/item/stack/cable_coil/cyborg,
		/obj/item/card/emag,
		/obj/item/pinpointer/syndicate_cyborg,
		/obj/item/borg_chameleon,
		)
	base_icon = "synd_engi"
	can_be_pushed = FALSE
	magpulsing = TRUE
	hat_offset = -4
	canDispose = TRUE

/datum/robot_energy_storage
	var/name = "generic energy storage"
	var/max_energy = 30000
	var/recharge_rate = 1000
	var/energy = 0

/datum/robot_energy_storage/New(datum/robot_module/R)
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
