local range = 15
local v = 1
local a = 100
local speed = 0.1 --0 or less for default maximum speed

local particle_texture = "extinguisher_shot.png"
local sound = "extinguisher"
local lastp = vector.zero

local function spray_foam(pos)
	local smp
	for z = -1,1 do
		for y = -1,1 do
			for x = -1,1 do
				local p = {x=pos.x+x, y=pos.y+y, z=pos.z+z}
				smp = vector.round(vector.divide(p, 3))
				if vector.equals(smp, lastp) then
					return
				end
				local nn = minetest.get_node(p).name
				if nn == "fire:basic_flame" then
					minetest.set_node(p, {name="party_foam:foam"})
					minetest.sound_play("fire_extinguish_flame",
						{pos = p, max_hear_distance = 16, gain = 0.15})
					minetest.check_for_falling(p)
				elseif math.random(0,3) >= 1 then
					if nn == "air" then
						minetest.set_node(p, {name="party_foam:foam"})
						minetest.check_for_falling(p)
					elseif nn == "default:lava_source" then
						minetest.set_node(p, {name="default:obsidian"})
					elseif nn == "default:lava_flowing" then
						minetest.set_node(p, {name="default:cobble"})
					end
				end
			end
		end
	end
	lastp = vector.new(smp)
end

local function extinguish_node(pos, player, sound)
	minetest.sound_stop(sound)
	spray_foam(pos)
end

local function extinguish(player)
	--local t1 = os.clock()

	local playerpos = player:get_pos()
	local dir = player:get_look_dir()

	local startpos = vector.new(playerpos)
	startpos.y = startpos.y+1.625
	local bl, pos = minetest.line_of_sight(startpos, vector.add(vector.multiply(dir, range), startpos), 1)
	local snd = minetest.sound_play(sound, {pos = playerpos, gain = 0.5, max_hear_distance = range})
	local delay = 1
	if pos then
		delay = vector.straightdelay(math.max(vector.distance(startpos, pos)-0.5, 0), v, a)
	end
	if not bl then
		minetest.after(delay, function(pos)
			extinguish_node(vector.round(pos), player, snd)
		end, pos, player, snd)
	end
	minetest.add_particle({
		pos = startpos,
		velocity = vector.multiply(dir, v),
		acceleration = vector.multiply(dir, a),
		expirationtime = delay,
		size = 1,
		texture = particle_texture.."^[transform"..math.random(0,7),
	})

	--print("[extinguisher] my shot was calculated after "..tostring(os.clock()-t1).."s")
end


local function stop_all_fire_sounds()
	local players = minetest.get_connected_players()
	for i = 1, #players do
		fire.update_player_sound(players[i])
	end
end

local c_fire, c_foam, c_lava, c_lavaf, c_obsidian, c_cobble
local function extinguish_fire(pos)
	local t1 = os.clock()
	c_fire = c_fire or minetest.get_content_id("fire:basic_flame")
	c_foam = c_foam or minetest.get_content_id("party_foam:foam")
	c_lava = c_lava or minetest.get_content_id("default:lava_source")
	c_lavaf = c_lavaf or minetest.get_content_id("default:lava_flowing")
	c_cobble = c_cobble or minetest.get_content_id("default:cobble")
	c_obsidian = c_obsidian or minetest.get_content_id("default:obsidian")
	local tab = vector.explosion_table(40)

	local manip = minetest.get_voxel_manip()
	local emerged_pos1, emerged_pos2 = manip:read_from_map(vector.add(pos, -40), vector.add(pos, 40))
	local area = VoxelArea:new({MinEdge=emerged_pos1, MaxEdge=emerged_pos2})
	local nodes = manip:get_data()

	for _,i in pairs(tab) do
		local ran = i[2]
		if not ran
		or math.random(2) == 1 then
			local p = area:indexp(vector.add(pos, i[1]))
			local d_p = nodes[p]
			if d_p == c_fire then
				nodes[p] = c_foam
			elseif d_p == c_lava then
				nodes[p] = c_obsidian
			elseif d_p == c_lavaf then
				nodes[p] = c_cobble
			end
		end
	end

	manip:set_data(nodes)
	manip:write_to_map()
	stop_all_fire_sounds()
	print(string.format("[extinguisher] exploded at ("..pos.x.."|"..pos.y.."|"..pos.z..") after ca. %.2fs", os.clock() - t1))
	--[[t1 = os.clock()
	manip:update_map()
	print(string.format("[extinguisher] map updated after ca. %.2fs", os.clock() - t1))]]
end

local function eexpl(pos)
	if minetest.get_node(pos).name ~= "party_foam:automatic" then
		return
	end
	minetest.sound_play("extinguisher_explosion", {pos=pos})
	minetest.set_node(pos, {name="party_foam:destroyed"})
	local startpos = minetest.find_node_near(pos, 2, {"fire:basic_flame"})
	if not startpos then
		return
	end
	extinguish_fire(startpos)
end


minetest.register_node("party_foam:foam", {
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "flowingliquid",
	alpha = 50,
	tiles = {"extinguisher_foam.png"},
  drawtype  = 'nodebox',
  node_box  = {
    type   = 'fixed',
    fixed  = {
     --  x1,    y1,    z1,    x2,    y2,   z2
      { -0.5,  -0.5,  -0.5,  -0.4,  -0.4,  -0.4 },
      { -0.5,  -0.5,   0.5,  -0.4,  -0.4,   0.4 },
      { -0.5,   0.5,  -0.5,  -0.4,   0.4,  -0.4 },

      { -0.4,  -0.4,  -0.4,  -0.2,  -0.2,  -0.2 },
      { -0.4,  -0.4,   0.4,  -0.2,  -0.2,   0.2 },
      { -0.4,   0.4,  -0.4,  -0.2,   0.2,  -0.2 },

      { -0.2,  -0.2,  -0.2,   0.2,   0.2,   0.2 },

      {  0.4,   0.4,  -0.4,   0.2,   0.2,  -0.2 },
      {  0.4,  -0.4,   0.4,   0.2,  -0.2,   0.2 },
      {  0.4,   0.4,   0.4,   0.2,   0.2,   0.2 },

      {  0.5,   0.5,  -0.5,   0.4,   0.4,  -0.4 },
      {  0.5,  -0.5,   0.5,   0.4,  -0.4,   0.4 },
      {  0.5,   0.5,   0.5,   0.4,   0.4,   0.4 },
    }, -- fixed
  }, -- node_box
	liquid_viscosity = 4,
  liquidtype = "flowing",
  liquid_alternative_flowing = "party_foam:foam",
  liquid_alternative_source = "party_foam:foam",
  liquid_renewable = true,
  liquid_range = 5,
  walkable = false,
  drowning = 1,
	drop = "",
	groups = {water = 3000, liquid = 3000, dig_immediate=3, puts_out_fire=1,
	          cools_lava = 1, not_in_creative_inventory=1},
	post_effect_color = {a=30, r=200, g=200, b=200},
})

local adtime = 0
local time = minetest.get_us_time()
local count = 0
minetest.register_abm({
	nodenames = {"party_foam:foam"},
	interval = 4,
	chance = 6,
	catch_up = false,
	action = function(pos)
		count = count+1
		local ct = minetest.get_us_time()
		if count > 10
		and ct-time < 1000000 then
			return
		end
		time = ct
		count = 0
		minetest.remove_node(pos)
		if adtime < 0.1 then
			minetest.check_for_falling(pos)
		end
	end,
})

minetest.register_node("party_foam:automatic", {
	description = "Extinguisher",
	tiles = {"extinguisher.png"},
	inventory_image = "extinguisher.png",
	wield_image = "extinguisher_pipe.png",
	drawtype = "plantlike",
	paramtype = "light",
	groups = {dig_immediate=2},
	sounds = {dig=""},
	on_punch = function(pos, _, player)
		minetest.sound_play("extinguisher_touch", {pos=pos, gain=0.25, max_hear_distance=8})
		if player:get_wielded_item():get_name() == "default:torch" then
			minetest.after(math.random()*5, eexpl, pos)
		end
	end,
	on_use = function() -- do not dig or punch nodes
	end,
})

minetest.register_node("party_foam:destroyed", {
	tiles = {"extinguisher_destroyed.png"},
	drawtype = "plantlike",
	paramtype = "light",
	groups = {dig_immediate=2},
	drop = {items = {{items =
		{"default:steel_ingot 4", "default:stick 2"}
	}}},
})

local timer = 0
minetest.register_globalstep(function(dtime)
	adtime = dtime
	timer = timer+dtime
	if timer < speed then
		return
	end
	timer = 0
	for _,player in pairs(minetest.get_connected_players()) do
		if player:get_wielded_item():get_name() == "party_foam:automatic"
		and player:get_player_control().LMB then
			extinguish(player)
		end
	end
end)

minetest.register_craftitem("party_foam:foam_ingredient", {
	description = "Foam Ingredient",
	inventory_image = "extinguisher_essence_2.png",
})

minetest.register_craftitem("party_foam:foam_bucket", {
	description = "Foam",
	inventory_image = "extinguisher_foam_bucket.png",
})

minetest.register_craft({
	output = "party_foam:foam_ingredient",
	recipe = {
		{"default:stone"},
		{"bucket:bucket_lava"},
		{"default:stone"},
	},
	replacements = {{"default:stone", "default:stone"}, {"default:stone", "default:stone"}},
})

minetest.register_craft({
	output = "party_foam:foam_bucket",
	recipe = {
		{"party_foam:foam_ingredient"},
		{"bucket:bucket_water"},
	},
})

minetest.register_craft({
	output = "party_foam:automatic",
	recipe = {
		{"group:stick", "", ""},
		{"default:steel_ingot", "group:stick", "group:stick"},
		{"party_foam:foam_bucket", "", ""},
	},
})
