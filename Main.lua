local GUI = require("GUI")
local system = require("System")
local color = require("Color")
local screen = require("Screen")

---------------------------------------------------------------------------------

local VISUALIZATION_MODE_HSB           = 1
local VISUALIZATION_MODE_INTERPOLATION = 2
local VISUALIZATION_MODE_BW            = 3

---------------------------------------------------------------------------------

local function mandelbrot(cReal, cImag, iterations_limit)
	local zReal, zImag = 0, 0

	for iteration = 1, iterations_limit do
		if math.sqrt(zReal*zReal + zImag*zImag) > 2 then
			return iteration / iterations_limit
		end

		-- z(n+1) = z^2(n) + c
		zReal, zImag = zReal*zReal - zImag*zImag + cReal, 2*zReal*zImag + cImag
	end

	return 1
end

---------------------------------------------------------------------------------

local workspace, window = system.addWindow(GUI.filledWindow(1, 1, 102, 40, 0x2D2D2D))
window.backgroundPanel.width = 22
window.backgroundPanel.height = window.height
window.backgroundPanel.colors.transparency = nil

---------------------------------------------------------------------------------

local image = window:addChild(GUI.object(window.backgroundPanel.width + 1, 1, 1, 1))
image.data = {}
image.visualizationMode = VISUALIZATION_MODE_HSB
image.useSemiPixels = true
image.heightMultiplier = 2

image.objectSizeToViewport = function(image, objectWidth, objectHeight)
	return
		(objectWidth  / image.width ) * image.viewport.size.x,
		(objectHeight / image.height) * image.viewport.size.y
end

image.objectCoordsToViewport = function(image, objectX, objectY)
	local viewportDeltaX, viewportDeltaY = image:objectSizeToViewport(objectX, objectY)
	return 
		image.viewport.position.x + viewportDeltaX,
		image.viewport.position.y + viewportDeltaY
end

image.screenCoordsToViewport = function(image, screenX, screenY)
	return image:objectCoordsToViewport(screenX - image.x, screenY - image.y)
end

---------------------------------------------------------------------------------

local layout = window:addChild(GUI.layout(1, 4, window.backgroundPanel.width, window.backgroundPanel.height - 3, 1, 1))
layout:setFitting(1, 1, true, false, 2, 0)
layout:setAlignment(1, 1, GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)

layout:addChild(GUI.label(1, 1, 1, 1, 0xC3C3C3, "Iterations limit"):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP))
local slider = layout:addChild(GUI.slider(1, 1, 36, 0x66DB80, 0x0, 0xFFFFFF, 0xFFFFFF, 10, 500, 100, false))

layout:addChild(GUI.label(1, 1, 1, 1, 0xC3C3C3, "Visualization mode"):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP))
local comboBox = layout:addChild(GUI.comboBox(1, 1, 36, 1, 0xF0F0F0, 0x2D2D2D, 0x444444, 0x999999))
local fromColorSelector = layout:addChild(GUI.colorSelector(1, 1, 1, 1, 0x000000, "From"))
local toColorSelector = layout:addChild(GUI.colorSelector(1, 1, 1, 1, 0xFFFFFF, "To"))

local semiPixelSwitch = layout:addChild(GUI.switchAndLabel(1, 1, 16, 6, 0x66DB80, 0x0, 0xF0F0F0, 0xC3C3C3, "Semipixels:", image.useSemiPixels)).switch

fromColorSelector.hidden = true
toColorSelector.hidden = true

comboBox:addItem("HSB").onTouch = function() 
	image.visualizationMode = VISUALIZATION_MODE_HSB
	fromColorSelector.hidden = true
	toColorSelector.hidden = true
end

comboBox:addItem("Interpolation").onTouch = function()
	image.visualizationMode = VISUALIZATION_MODE_INTERPOLATION 
	fromColorSelector.hidden = false
	toColorSelector.hidden = false
end

comboBox:addItem("B/W").onTouch = function() 
	image.visualizationMode = VISUALIZATION_MODE_BW 
	fromColorSelector.hidden = true
	toColorSelector.hidden = true
end

---------------------------------------------------------------------------------

local function updateImage()
	image.data = {}

	for x = 1, image.width do
		image.data[x] = {}

		for y = 1, image.height * image.heightMultiplier do
			local viewportX, viewportY = image:objectCoordsToViewport(x, y / image.heightMultiplier)
			image.data[x][y] = mandelbrot(viewportX, viewportY, slider.value)
		end
	end
end

slider.onValueChanged = updateImage
fromColorSelector.onColorSelected = updateImage
toColorSelector.onColorSelected = updateImage

semiPixelSwitch.onStateChanged = function(switch)
	image.useSemiPixels = switch.state
	image.heightMultiplier = (switch.state	 and 2) or 1
	updateImage()
end

image.draw = function(image)
	screen.drawRectangle(image.x, image.y, image.width, image.height, 0xF0F0F0, 0x878787, " ")

	for x = 1, #image.data do 
		for y = 1, #image.data[x] do
			local pixel
			if image.visualizationMode == VISUALIZATION_MODE_BW then
				pixel = image.data[x][y] == 1 and 0 or 0xFFFFFF
			elseif image.visualizationMode == VISUALIZATION_MODE_INTERPOLATION then
				pixel = color.transition(fromColorSelector.color, toColorSelector.color, image.data[x][y])
			else
				pixel = color.RGBToInteger(color.HSBToRGB(image.data[x][y] * 360, 1, 1))
			end

			if image.useSemiPixels then
				screen.semiPixelSet(image.x + x - 1, (image.y - 1) * 2 + y, pixel)
			else
				screen.set(image.x + x - 1, image.y + y - 1, pixel, 0, " ")
			end
		end
	end

	screen.drawSemiPixelRectangle(image.x + image.width / 2,     image.y + image.height + 2, 1, 3, 0xFFFFFF)
	screen.drawSemiPixelRectangle(image.x + image.width / 2 - 1, image.y + image.height + 3, 3, 1, 0xFFFFFF)
end

---------------------------------------------------------------------------------

window.onResize = function(width, height)
	layout.height = window.height
	window.backgroundPanel.height = window.height

	local newImageWidth, newImageHeight = window.width - window.backgroundPanel.width, window.height
	local scaleX, scaleY = newImageWidth / image.width, newImageHeight / height
	image.width, image.height = newImageWidth, newImageHeight

	if not image.viewport then
		image.viewport = {
			position = {
				x = -2,
				y = -2
			},
		
			-- sw / sh = vw / vh

			size = {
				x = 4,
				y = 4 * ((image.height * image.heightMultiplier) / image.width)
			}
		}
	else
		image.viewport.size.x = image.viewport.size.x * scaleX
		image.viewport.size.y = image.viewport.size.y * scaleY
	end

	workspace:draw()
	updateImage()
end

image.eventHandler = function(workspace, image, e1, e2, e3, e4, e5, ...)
	local function onMove(x, y)
		image.viewport.position.x = image.viewport.position.x + x * image.viewport.size.x * 0.05
		image.viewport.position.y = image.viewport.position.y + y * image.viewport.size.y * 0.05
		updateImage()
	end

	local function onZoom(zoom, cx, cy)
		local diffX = image.viewport.size.x * zoom * 0.2
		local diffY = image.viewport.size.y * zoom * 0.2
		
		image.viewport.size.x = image.viewport.size.x + diffX
		image.viewport.size.y = image.viewport.size.y + diffY

		image.viewport.position.x = image.viewport.position.x - diffX * (cx or 0.5)
		image.viewport.position.y = image.viewport.position.y - diffY * (cy or 0.5)
		updateImage()
	end

	if e1 == "key_down" then
		if     e3 == 119 then onMove( 0, -1) -- W
		elseif e3 == 97  then onMove(-1,  0) -- A
		elseif e3 == 115 then onMove( 0,  1) -- S
		elseif e3 == 100 then onMove( 1,  0) -- D

		elseif e3 == 113 then onZoom( 1)     -- Q
		elseif e3 == 101 then onZoom(-1)     -- E
		end
	elseif e1 == "touch" then
		image.dragStart = {
			mousePosition = {
				x = e3,
				y = e4
			},			
			viewportPosition = {
				x = image.viewport.position.x,
				y = image.viewport.position.y
			}
		}
	elseif e1 == "drag" then
		local x, y = image:objectSizeToViewport(image.dragStart.mousePosition.x - e3, image.dragStart.mousePosition.y - e4)

		image.viewport.position.x = image.dragStart.viewportPosition.x + x
		image.viewport.position.y = image.dragStart.viewportPosition.y + y
		updateImage()
	elseif e1 == "scroll" then
		onZoom(e5 * -0.5, (e3 - image.x) / image.width, (e4 - image.y) / image.height)
	end
end

---------------------------------------------------------------------------------

window:resize(window.width, window.height)