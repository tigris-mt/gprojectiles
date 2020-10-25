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

			-- Calculate stuff like knockback with old position.
			self.object:set_pos(self.old_pos)

			if minetest.get_node(self.old_pos).name == "ignore" or minetest.get_node(pos).name == "ignore" then
				minetest.log("warning", ("[gprojectiles] projectile %s at %s -> %s was out of bounds, deleting"):format(name, minetest.pos_to_string(self.old_pos), minetest.pos_to_string(pos)))
				self.object:remove()
				return
			end

			if not b.box.collide_point(b.WORLD.box, self.old_pos) or not b.box.collide_point(b.WORLD.box, pos) then
				minetest.log("warning", ("[gprojectiles] projectile %s at %s -> %s was outside world, deleting"):format(name, minetest.pos_to_string(self.old_pos), minetest.pos_to_string(pos)))
				self.object:remove()
				return
			end

			local context = gprojectiles.new_context(self)

			for thing in minetest.raycast(self.old_pos, pos, true, true) do
				-- Don't collide with self.
				if not (thing.type == "object" and (thing.ref == self.object or thing.ref == self._skip_first)) then
					def.on_collide(context, thing)
					-- Don't continue if we got canceled.
					if self.canceled then
						break
					end
				end
			end

			if self._skip_first and (not self._skip_first:get_pos() or vector.distance(pos, self._skip_first:get_pos()) >= 3) then
				self._skip_first = nil
			end

			-- Restore old position.
			self.object:set_pos(pos)
			self.old_pos = pos
		end,
	})
end

function gprojectiles.spawn(name, def)
	def = b.t.combine({
		-- Initial acceleration.
		gravity = vector.new(0, 0, 0),
		-- Blame, as a b ref_table or nil.
		blame = nil,
		-- Initial position.
		pos = nil,
		-- Direction/velocity.
		velocity = nil,
		-- Skip this ObjectRef the first time (avoid hitting shooter at start)
		skip_first = nil,
		-- Initial data to pass in the context.
		data = {},
	}, def)

	local object = minetest.add_entity(vector.add(def.pos, def.leave_origin and vector.normalize(def.velocity) or vector.new()), name)
	if object then
		local entity = object:get_luaentity()
		entity._gprojectile = true
		entity._data = table.copy(def.data)
		entity._blame = def.blame
		entity._skip_first = def.skip_first
		entity._skip = 2

		object:set_velocity(def.velocity)
		object:set_acceleration(def.gravity)
	end
	return object
end

function gprojectiles.mt:cancel()
	self.entity.canceled = true
end
