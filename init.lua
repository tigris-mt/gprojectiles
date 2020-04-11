gprojectiles = {
	mt = {},
}

function gprojectiles.new_context(entity)
	return setmetatable({
		data = entity._data,
		entity = entity,
		object = entity.object,
	}, {__index = gprojectiles.mt})
end

function gprojectiles.register(name, def)
	def = b.t.combine({
		-- Initial entity properties.
		initial_properties = {},
		-- Entity groups.
		groups = {},

		on_collide = function(self, thing) end,
	}, def, {
		initial_properties = b.t.combine({
			physical = false,
			static_save = false,
		}, def.initial_properties),
		groups = b.t.combine({
			immortal = 1,
		}, def.groups),
	})

	minetest.register_entity(name, {
		initial_properties = def.initial_properties,
		groups = def.groups,

		on_step = function(self, dtime)
			if self.canceled then
				self.object:remove()
				return
			end
			local pos = self.object:get_pos()
			self.old_pos = self.old_pos or pos

			local context = gprojectiles.new_context(self)

			for thing in minetest.raycast(self.old_pos, pos, true, true) do
				-- Don't collide with self.
				if not (thing.type == "object" and thing.ref == self.object) then
					def.on_collide(context, thing)
					-- Don't continue if we got canceled.
					if self.canceled then
						return
					end
				end
			end
		end,
	})
end

function gprojectiles.spawn(name, def)
	def = b.t.combine({
		-- Initial acceleration.
		gravity = vector.new(0, 0, 0),
		-- Player name to blame.
		blame_player = nil,
		-- Initial position.
		pos = nil,
		-- Direction/velocity.
		velocity = nil,
		-- Leave the origin before processing.
		leave_origin = false,
		-- Initial data to pass in the context.
		data = {},
	}, def)

	local object = minetest.add_entity(vector.add(def.pos, def.leave_origin and vector.normalize(def.velocity) or vector.new()), name)
	if object then
		local entity = object:get_luaentity()
		entity._data = table.copy(def.data)
		entity._player_blame = def.blame_player

		object:set_velocity(def.velocity)
		object:set_acceleration(def.gravity)
	end
	return object
end

function gprojectiles.mt:cancel()
	self.entity.canceled = true
end
