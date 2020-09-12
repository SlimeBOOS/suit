-- This file is part of SUIT, copyright (c) 2016 Matthias Richter
local NONE = {}
local BASE = (...)
local default_theme = require(BASE .. ".theme")
local Layout = require(BASE .. ".layout")

local SUIT = {}
SUIT.widgets = {}

function SUIT.new(theme)
	return setmetatable({
		-- TODO: deep copy/copy on write? better to let user handle => documentation?
		theme = theme or default_theme,
		mouse_x = love.mouse.getX(),
		mouse_y = love.mouse.getY(),
		mouse_dx = 0,
		mouse_dy = 0,
		mouse_button_down = love.mouse.isDown(1),
		candidate_text = {text = "", start = 0, length = 0},

		transform_stack = {},
		dx = 0,
		dy = 0,
		sx = 1,
		sy = 1,

		draw_queue = {},

		entered_frame = false,
		exited_frame = false,
		layout = Layout.new()
	}, SUIT)
end

-- helper
function SUIT.getOptionsAndSize(opt, ...)
	if type(opt) == "table" then return opt, ... end
	return {}, opt, ...
end

function SUIT.registerWidget(name, callback)
	name = tostring(name)
	if type(callback) == "table" then
		for k, v in pairs(callback) do
			if type(k) == "string" and not k:match("^__") then SUIT.widgets[name .. k] = v end
		end
	else
		SUIT.widgets[name] = callback
	end
end

-- gui state
function SUIT:isHovered(id)
	return id == self.hovered
end

function SUIT:wasHovered(id)
	return id == self.hovered_last
end

function SUIT:isActive(id)
	return id == self.active
end

function SUIT:isHit(id)
	return id == self.hit
end

function SUIT:getStateName(id)
	if self:isActive(id) then
		return "active"
	elseif self:isHovered(id) then
		return "hovered"
	elseif self:isHit(id) then
		return "hit"
	end
	return "normal"
end

-- mouse handling
function SUIT:mouseInRect(x, y, w, h)
	return self.mouse_x >= x and self.mouse_y >= y and self.mouse_x <= x + w and self.mouse_y <= y + h
end

function SUIT:registerMouseHit(id, ul_x, ul_y, hit)
	if not self.hovered and hit(self.mouse_x - ul_x - self.dx, self.mouse_y - ul_y - self.dy) then
		self.hovered = id
		if self.active == nil and self.mouse_button_down then self.active = id end
	end
	return self:getStateName(id)
end

function SUIT:registerHitbox(id, x, y, w, h)
	return self:registerMouseHit(id, x, y, function(x, y)
		return x >= 0 and x <= w and y >= 0 and y <= h
	end)
end

function SUIT:mouseReleasedOn(id)
	if not self.mouse_button_down and self:isActive(id) and self:isHovered(id) then
		self.hit = id
		return true
	end
	return false
end

function SUIT:updateMouse(x, y, button_down)
	self.mouse_dx, self.mouse_dy = x - self.mouse_x, y - self.mouse_y
	self.mouse_x, self.mouse_y = x, y
	if button_down ~= nil then self.mouse_button_down = button_down end
end

function SUIT:getMousePosition()
	return self.mouse_x, self.mouse_y
end

-- keyboard handling
function SUIT:getPressedKey()
	return self.key_down, self.textchar
end

function SUIT:keypressed(key)
	self.key_down = key
end

function SUIT:textinput(char)
	self.textchar = char
end

function SUIT:textedited(text, start, length)
	self.candidate_text.text = text
	self.candidate_text.start = start
	self.candidate_text.length = length
end

function SUIT:grabKeyboardFocus(id)
	if self:isActive(id) then
		if love.system.getOS() == "Android" or love.system.getOS() == "iOS" then
			if id == NONE then
				love.keyboard.setTextInput(false)
			else
				love.keyboard.setTextInput(true)
			end
		end
		self.keyboardFocus = id
	end
	return self:hasKeyboardFocus(id)
end

function SUIT:hasKeyboardFocus(id)
	return self.keyboardFocus == id
end

function SUIT:keyPressedOn(id, key)
	return self:hasKeyboardFocus(id) and self.key_down == key
end

-- state update
function SUIT:enterFrame()
	if self.entered_frame then return end
	self.entered_frame = true

	if not self.mouse_button_down then
		self.active = nil
	elseif self.active == nil then
		self.active = NONE
	end

	self.hovered_last, self.hovered = self.hovered, nil
	self:updateMouse(love.mouse.getX(), love.mouse.getY(), love.mouse.isDown(1))
	self.key_down, self.textchar = nil, ""
	self:grabKeyboardFocus(NONE)
	self.hit = nil
end

function SUIT:exitFrame()
	if self.exited_frame then return end
	self.exited_frame = true
	self.dx = 0
	self.dy = 0
	self.sx = 1
	self.sy = 1
end

-- draw
function SUIT:registerDraw(f, ...)
	local args = {...}
	table.insert(self.draw_queue, function()
		f(unpack(args))
	end)
end

function SUIT:draw()
	self:enterFrame()
	love.graphics.push("all")
	for _, f in ipairs(self.draw_queue) do f() end
	self.draw_queue = {}
	love.graphics.pop()
	self:exitFrame()
	self.entered_frame = false
	self.exited_frame = false
end

function SUIT:__index(key)
	local value = rawget(self, key)
	if value ~= nil then return value end

	if SUIT.widgets[key] ~= nil then return SUIT.widgets[key] end

	local metatable = getmetatable(self)
	if metatable[key] ~= nil then return metatable[key] end
end

function SUIT:translate(x, y)
	table.insert(self.draw_queue, function()
		love.graphics.translate(x, y)
	end)
	self.dx = self.dx + x
	self.dy = self.dy + y
end

function SUIT:scale(x, y)
	table.insert(self.draw_queue, function()
		love.graphics.scale(x, y)
	end)
	self.sx = self.sx * x
	self.sy = self.sy * y
end

function SUIT:origin()
	table.insert(self.draw_queue, love.graphics.origin)
	self.dx = 0
	self.dy = 0
	self.sx = 1
	self.sy = 1
end

function SUIT:push(stack)
	table.insert(self.transform_stack, self.dx)
	table.insert(self.transform_stack, self.dy)
	table.insert(self.transform_stack, self.sx)
	table.insert(self.transform_stack, self.sy)

	table.insert(self.draw_queue, function()
		love.graphics.push(stack)
	end)
end

function SUIT:pop()
	self.sy = table.remove(self.transform_stack)
	self.sx = table.remove(self.transform_stack)
	self.dy = table.remove(self.transform_stack)
	self.dx = table.remove(self.transform_stack)

	table.insert(self.draw_queue, love.graphics.pop)
end

function SUIT:setScissor(x, y, width, height)
	table.insert(self.draw_queue, function()
		love.graphics.setScissor(x, y, width, height)
	end)
end

SUIT.registerWidget("Button", require(BASE .. ".widgets.button"))
SUIT.registerWidget("ImageButton", require(BASE .. ".widgets.imagebutton"))
SUIT.registerWidget("Label", require(BASE .. ".widgets.label"))
SUIT.registerWidget("Checkbox", require(BASE .. ".widgets.checkbox"))
SUIT.registerWidget("TextInput", require(BASE .. ".widgets.textinput"))
SUIT.registerWidget("Slider", require(BASE .. ".widgets.slider"))

return SUIT
