-- This file is part of SUIT, copyright (c) 2016 Matthias Richter
local Layout = {}
Layout.__index =  Layout

function Layout.new(...)
	return setmetatable({_stack = {}}, Layout):reset(...)
end

function Layout:reset(x, y, padx, pady)
	self._x = x or 0
	self._y = y or 0
	self._padx = padx or 0
	self._pady = pady or self._padx
	self._w = nil
	self._h = nil
	self._widths = {}
	self._heights = {}
	self._isFirstCell = true

	self.bounds_left, self.bounds_right = nil, nil
	self.bounds_top, self.bounds_bottom = nil, nil
	return self
end

function Layout:setBounds(left, top, right, bottom)
	assert(right > left or not (right and left), "Bounds right edge must be more than left edge.")
	assert(bottom > top or not (bottom and top), "Bounds right edge must be more than left edge.")
	self.bounds_left = left
	self.bounds_top = top
	self.bounds_right = right
	self.bounds_bottom = bottom
end

function Layout:keepInBounds(x, y, w, h)
	local ox = self.bounds_left or 0
	local oy = self.bounds_top or 0
	x = self.bounds_left and math.max(x, self.bounds_left - ox) or x
	y = self.bounds_top and math.max(y, self.bounds_top - oy) or y
	x = self.bounds_right and math.min(x + w, self.bounds_right - ox) - w or x
	y = self.bounds_bottom and math.min(y + h, self.bounds_bottom - oy) - h or y
	return x, y, w, h
end

function Layout:getBoundsWidth()
	if self.bounds_left and self.bounds_right then return self.bounds_right - self.bounds_left end
end

function Layout:getBoundsHeight()
	if self.bounds_top and self.bounds_bottom then return self.bounds_bottom - self.bounds_top end
end

function Layout:getBoundsDimensions()
	return self:getBoundsWidth(), self:getBoundsHeight()
end

function Layout:padding(padx, pady)
	if padx then
		self._padx = padx
		self._pady = pady or padx
	end
	return self._padx, self._pady
end

function Layout:size()
	return self._w, self._h
end

function Layout:nextRow()
	return self._x, self._y + self._h + self._pady
end

Layout.nextDown = Layout.nextRow

function Layout:nextCol()
	return self._x + self._w + self._padx, self._y
end

Layout.nextRight = Layout.nextCol

function Layout:push(left, top, right, bottom)
	self._stack[#self._stack + 1] = {
		self.bounds_left,
		self.bounds_top,
		self.bounds_right,
		self.bounds_bottom,
		self._x,
		self._y,
		self._padx,
		self._pady,
		self._w,
		self._h,
		self._widths,
		self._heights
	}
	self:reset()
	self:setBounds(left, top, right, bottom)
	return self
end

function Layout:pop()
	assert(#self._stack > 0, "Nothing to pop")
	local w, h = self._w, self._h
	self.bounds_left, self.bounds_top, self.bounds_right, self.bounds_bottom, self._x, self._y, self._padx, self._pady, self._w, self._h, self._widths, self._heights =
		unpack(self._stack[#self._stack])
	self._isFirstCell = false
	self._stack[#self._stack] = nil

	self._w, self._h = math.max(w or 0, self._w or 0), math.max(h or 0, self._h or 0)

	return w, h
end

--- recursive binary search for position of v
local function insert_sorted_helper(t, i0, i1, v)
	if i1 <= i0 then
		table.insert(t, i0, v)
		return
	end

	local i = i0 + math.floor((i1 - i0) / 2)
	if t[i] < v then
		return insert_sorted_helper(t, i + 1, i1, v)
	elseif t[i] > v then
		return insert_sorted_helper(t, i0, i - 1, v)
	else
		table.insert(t, i, v)
	end
end

local function insert_sorted(t, v)
	if v <= 0 then return end
	insert_sorted_helper(t, 1, #t, v)
end

local function calc_width_height(self, w, h)
	local bounds_w, bounds_h = self:getBoundsDimensions()

	if w == "" or w == nil then
		w = self._w
	elseif w == "full" and bounds_w then
		w = bounds_w
	elseif w == "max" then
		w = self._widths[#self._widths]
	elseif w == "min" then
		w = self._widths[1]
	elseif w == "median" then
		w = self._widths[math.ceil(#self._widths / 2)] or 0
	elseif type(w) ~= "number" then
		error("width: invalid value (" .. tostring(w) .. ")", 3)
	end

	if h == "" or h == nil then
		h = self._h
	elseif h == "full" and bounds_h then
		h = bounds_h
	elseif h == "max" then
		h = self._heights[#self._heights]
	elseif h == "min" then
		h = self._heights[1]
	elseif h == "median" then
		h = self._heights[math.ceil(#self._heights / 2)] or 0
	elseif type(h) ~= "number" then
		error("width: invalid value (" .. tostring(w) .. ")", 3)
	end

	if not w or not h then error("Invalid cell size", 3) end

	w = bounds_w and math.min(w, bounds_w) or w
	h = bounds_h and math.min(h, bounds_h) or h
	insert_sorted(self._widths, w)
	insert_sorted(self._heights, h)
	return w, h
end

function Layout:row(w, h)
	w, h = calc_width_height(self, w, h)
	local x, y = self._x, self._y + (self._h or 0)

	if not self._isFirstCell then y = y + self._pady end
	self._isFirstCell = false

	self._y, self._w, self._h = y, w, h

	return x, y, w, h
end

Layout.down = Layout.row

function Layout:up(w, h)
	w, h = calc_width_height(self, w, h)
	local x, y = self._x, self._y - (self._h and h or 0)

	if not self._isFirstCell then y = y - self._pady end
	self._isFirstCell = false

	self._y, self._w, self._h = y, w, h

	return x, y, w, h
end

function Layout:col(w, h)
	w, h = calc_width_height(self, w, h)

	local x, y = self._x + (self._w or 0), self._y

	if not self._isFirstCell then x = x + self._padx end
	self._isFirstCell = false

	self._x, self._w, self._h = x, w, h

	return x, y, w, h
end

Layout.right = Layout.col

function Layout:left(w, h)
	w, h = calc_width_height(self, w, h)

	local x, y = self._x - (self._w and w or 0), self._y

	if not self._isFirstCell then x = x - self._padx end
	self._isFirstCell = false

	self._x, self._w, self._h = x, w, h

	return x, y, w, h
end

local function layout_iterator(t, idx)
	idx = (idx or 1) + 1
	if t[idx] == nil then return nil end
	return idx, unpack(t[idx])
end

local function layout_retained_mode(self, t, constructor, string_argument_to_table, fill_width,
																																				fill_height)
	-- sanity check
	local p = t.pos or {0, 0}
	if type(p) ~= "table" then
		error("Invalid argument `pos' (table expected, got " .. type(p) .. ")", 2)
	end
	local pad = t.padding or {}
	if type(p) ~= "table" then
		error("Invalid argument `padding' (table expected, got " .. type(p) .. ")", 2)
	end

	self:push(p[1] or 0, p[2] or 0)
	self:padding(pad[1] or self._padx, pad[2] or self._pady)

	-- first pass: get dimensions, add layout info
	local layout = {n_fill_w = 0, n_fill_h = 0}
	for i, v in ipairs(t) do
		if type(v) == "string" then v = string_argument_to_table(v) end
		local x, y, w, h = 0, 0, v[1], v[2]
		if v[1] == "fill" then w = 0 end
		if v[2] == "fill" then h = 0 end

		x, y, w, h = constructor(self, w, h)

		if v[1] == "fill" then
			w = "fill"
			layout.n_fill_w = layout.n_fill_w + 1
		end
		if v[2] == "fill" then
			h = "fill"
			layout.n_fill_h = layout.n_fill_h + 1
		end
		layout[i] = {x, y, w, h, unpack(v, 3)}
	end

	-- second pass: extend "fill" cells and shift others accordingly
	local fill_w = fill_width(layout, t.min_width or 0, self._x + self._w - p[1])
	local fill_h = fill_height(layout, t.min_height or 0, self._y + self._h - p[2])
	local dx, dy = 0, 0
	for _, v in ipairs(layout) do
		v[1], v[2] = v[1] + dx, v[2] + dy
		if v[3] == "fill" then
			v[3] = fill_w
			dx = dx + v[3]
		end
		if v[4] == "fill" then
			v[4] = fill_h
			dy = dy + v[4]
		end
	end

	-- finally: return layout with iterator
	local w, h = self:pop()
	layout.cell = function(self, i)
		if self ~= layout then -- allow either colon or dot syntax
			i = self
		end
		return unpack(layout[i])
	end
	layout.size = function()
		return w, h
	end
	return setmetatable(layout, {
		__call = function()
			return layout_iterator, layout, 0
		end
	})
end

function Layout:rows(t)
	return layout_retained_mode(self, t, self.row, function(v)
		return {nil, v}
	end, function()
		return self._widths[#self._widths]
	end, -- fill width
	function(l, mh, h)
		return (mh - h) / l.n_fill_h
	end) -- fill height
end

function Layout:cols(t)
	return layout_retained_mode(self, t, self.col, function(v)
		return {v}
	end, function(l, mw, w)
		return (mw - w) / l.n_fill_w
	end, -- fill width
	function()
		return self._heights[#self._heights]
	end) -- fill height
end

return Layout