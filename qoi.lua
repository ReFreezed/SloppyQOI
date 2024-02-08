--[[============================================================
--=
--=  SloppyQOI - QOI image format encoder/decoder for LÖVE
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See the bottom of this file)
--=
--=  Following QOI v1.0 spec: https://qoiformat.org/
--=
--=  Encoder ported from Dominic Szablewski's C/C++ library
--=  - https://github.com/phoboslab/qoi
--=  - MIT License - Copyright © 2021 Dominic Szablewski
--=
--==============================================================

	local qoi = require("qoi")

	imageData, channels, colorSpace = qoi.decode( dataString )
	Decode QOI data.
	Returns nil and a message on error.

	dataString = qoi.encode( imageData [, channels=4, colorSpace="linear" ] )
	channels   = 3 | 4
	colorSpace = "linear" | "srgb"
	Encode an image to QOI data.
	The PixelFormat for imageData must currently be "rgba8".
	Returns nil and a message on error.

	imageData, channels, colorSpace = qoi.read( path )
	Read a QOI file (using love.filesystem).
	Returns nil and a message on error.

	success, error = qoi.write( imageData, path [, channels=4, colorSpace="linear" ] )
	channels       = 3 | 4
	colorSpace     = "linear" | "srgb"
	Write an image to a QOI file (using love.filesystem).
	The PixelFormat for imageData must currently be "rgba8".

	image = qoi.load( path )
	Load a QOI file as an image (like love.graphics.newImage).

	qoi._VERSION
	The current version of the library, e.g. "1.8.2".

--============================================================]]

local qoi = {
	_VERSION = "1.1.0",
}

local newTable = pcall(require, "table.new") and require"table.new" or nil -- LuaJIT 2.1 has table.new!

local CHARS = newTable and newTable(255, 0) or {}
for i = 0, 255 do
	CHARS[i] = string.char(i)
end



-- imageData, channels, colorSpace = qoi.decode( dataString )
-- Returns nil and a message on error.
function qoi.decode(s)
	assert(type(s) == "string")

	local pos = 1

	--
	-- Header.
	--
	local getByte = string.byte

	if s:sub(pos, pos+3) ~= "qoif" then
		return nil, "Invalid signature."
	end
	pos = pos + 4

	if #s < 14 then -- Header is 14 bytes.
		return nil, "Missing part of header."
	end

	local w = 256^3*getByte(s, pos) + 256^2*getByte(s, pos+1) + 256*getByte(s, pos+2) + getByte(s, pos+3)
	if w == 0 then  return nil, "Invalid width (0)."  end
	pos = pos + 4

	local h = 256^3*getByte(s, pos) + 256^2*getByte(s, pos+1) + 256*getByte(s, pos+2) + getByte(s, pos+3)
	if h == 0 then  return nil, "Invalid height (0)."  end
	pos = pos + 4

	local channels = getByte(s, pos)
	if not (channels == 3 or channels == 4) then
		return nil, "Invalid channel count."
	end
	pos = pos + 1

	local colorSpace = getByte(s, pos)
	if colorSpace > 1 then
		return nil, "Invalid color space value."
	end
	colorSpace = (colorSpace == 0 and "srgb" or "linear")
	pos        = pos + 1

	--
	-- Data stream.
	--
	local imageData        = require"love.image".newImageData(w, h, "rgba8")
	local imageDataPointer = require"ffi".cast("uint8_t*", imageData:getFFIPointer())

	local seen = {
		-- 64 RGBA pixels.
		0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
		0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
		0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
		0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
	}

	local prevR = 0 -- Note: All these color values are treated as signed bytes.
	local prevG = 0
	local prevB = 0
	-- prevA not needed.

	local r = 0
	local g = 0
	local b = 0
	local a = 255

	local run = 0

	local band   = require"bit".band
	local rshift = require"bit".rshift
	local lshift = require"bit".lshift

	for pixelIz = 0, 4*w*h-1, 4 do
		if run > 0 then
			run = run - 1

		else
			local byte1 = getByte(s, pos)
			if not byte1 then  return nil, "Unexpected end of data stream."  end
			pos = pos + 1

			-- QOI_OP_RGB 11111110
			if byte1 == 254--[[11111110]] then
				r, g, b = getByte(s, pos, pos+2)
				if not b then  return nil, "Unexpected end of data stream."  end
				pos = pos + 3

			-- QOI_OP_RGBA 11111111
			elseif byte1 == 255--[[11111111]] then
				r, g, b, a = getByte(s, pos, pos+3)
				if not a then  return nil, "Unexpected end of data stream."  end
				pos = pos + 4

			-- QOI_OP_INDEX 00xxxxxx
			elseif byte1 < 64--[[01000000]] then
				local hash4 = lshift(byte1, 2)

				r = seen[hash4+1]
				g = seen[hash4+2]
				b = seen[hash4+3]
				a = seen[hash4+4]

			-- QOI_OP_DIFF 01xxxxxx
			elseif byte1 < 128--[[10000000]] then
				byte1 = byte1 - 64--[[01000000]]

				r = prevR + rshift(band(byte1, 48--[[00110000]]), 4) - 2
				g = prevG + rshift(band(byte1, 12--[[00001100]]), 2) - 2
				b = prevB +        band(byte1, 3 --[[00000011]])     - 2

			-- QOI_OP_LUMA 10xxxxxx
			elseif byte1 < 192--[[11000000]] then
				local byte2 = getByte(s, pos)
				if not byte2 then  return nil, "Unexpected end of data stream."  end
				pos = pos + 1

				local diffG = byte1 + (-(128--[[10000000]]) - 32)

				g = prevG + diffG
				r = prevR + diffG + rshift(band(byte2, 240--[[11110000]]), 4) - 8
				b = prevB + diffG +        band(byte2, 15 --[[00001111]])     - 8

			-- QOI_OP_RUN 11xxxxxx
			else
				run = byte1 - 192--[[11000000]]
			end

			prevR = r
			prevG = g
			prevB = b
		end

		imageDataPointer[pixelIz  ] = r
		imageDataPointer[pixelIz+1] = g
		imageDataPointer[pixelIz+2] = b
		imageDataPointer[pixelIz+3] = a

		local hash4   = lshift(band(r*3+g*5+b*7+a*11, 63--[[00111111]]), 2)
		seen[hash4+1] = r
		seen[hash4+2] = g
		seen[hash4+3] = b
		seen[hash4+4] = a
	end

	if run > 0 then
		return nil, "Corrupt data."
	end

	if s:sub(pos, pos+7) ~= "\0\0\0\0\0\0\0\1" then
		return nil, "Missing data end marker."
	end
	pos = pos + 8

	if pos <= #s then
		return nil, "Junk after data."
	end

	return imageData, channels, colorSpace
end

-- dataString = qoi.encode( imageData [, channels=4, colorSpace="linear" ] )
-- Returns nil and a message on error.
function qoi.encode(imageData, channels, colorSpace)
	channels   = channels   or 4
	colorSpace = colorSpace or "linear"

	assert(type(imageData) == "userdata")
	assert(channels == 3 or channels == 4)
	assert(colorSpace == "srgb" or colorSpace == "linear")

	if imageData:getFormat() ~= "rgba8" then
		return nil, "Unsupported format '"..imageData:getFormat().."'. (Only 'rgba8' is supported.)"
	end

	local w, h = imageData:getDimensions()
	if w >= 256^4 then  return nil, "Image is too wide."  end
	if h >= 256^4 then  return nil, "Image is too tall."  end

	local buffer = newTable and newTable(11+w*h*2+1, 0) or {} -- Assume pretty good case scenario for the file size (2 bytes per pixel).

	--
	-- Header.
	--
	local insert = table.insert
	local floor  = math.floor

	insert(buffer, "qoif")

	insert(buffer, CHARS[floor(w/256^3)      ])
	insert(buffer, CHARS[floor(w/256^2) % 256])
	insert(buffer, CHARS[floor(w/256  ) % 256])
	insert(buffer, CHARS[      w        % 256])

	insert(buffer, CHARS[floor(h/256^3)      ])
	insert(buffer, CHARS[floor(h/256^2) % 256])
	insert(buffer, CHARS[floor(h/256  ) % 256])
	insert(buffer, CHARS[      h        % 256])

	insert(buffer, (channels   == 3      and "\3" or "\4")) -- channels (3 or 4)
	insert(buffer, (colorSpace == "srgb" and "\0" or "\1")) -- color space (0=srgb, 1=linear)

	--
	-- Data stream.
	--
	local imageDataPointer = require"ffi".cast("uint8_t*", imageData:getFFIPointer()) -- @Incomplete: Support different ImageData PixelFormats.
	local maxPixelIz       = 4*(w*h-1)

	local seen = {
		-- 64 RGBA pixels.
		0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
		0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
		0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
		0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
	}

	local prevR = 0
	local prevG = 0
	local prevB = 0
	local prevA = 255

	local run = 0

	local band   = require"bit".band
	local lshift = require"bit".lshift

	for pixelIz = 0, 4*(w*h-1), 4 do
		local r = imageDataPointer[pixelIz  ]
		local g = imageDataPointer[pixelIz+1]
		local b = imageDataPointer[pixelIz+2]
		local a = imageDataPointer[pixelIz+3]

		if r == prevR and g == prevG and b == prevB and a == prevA then
			run = run + 1

			if run == 62 or pixelIz == maxPixelIz then
				insert(buffer, CHARS[192--[[11000000]]+(run-1)]) -- QOI_OP_RUN 11xxxxxx
				run = 0
			end

		else
			if run > 0 then
				insert(buffer, CHARS[192--[[11000000]]+(run-1)]) -- QOI_OP_RUN 11xxxxxx
				run = 0
			end

			local hash  = band(r*3+g*5+b*7+a*11, 63--[[00111111]])
			local hash4 = lshift(hash, 2)

			if r == seen[hash4+1] and g == seen[hash4+2] and b == seen[hash4+3] and a == seen[hash4+4] then
				insert(buffer, CHARS[--[[00000000+]]hash]) -- QOI_OP_INDEX 00xxxxxx

			else
				seen[hash4+1] = r
				seen[hash4+2] = g
				seen[hash4+3] = b
				seen[hash4+4] = a

				if a == prevA then
					local deltaR = (r - prevR + 128) % 256 - 128
					local deltaG = (g - prevG + 128) % 256 - 128
					local deltaB = (b - prevB + 128) % 256 - 128

					if     deltaR >= -2 and deltaR <= 1
					   and deltaG >= -2 and deltaG <= 1
					   and deltaB >= -2 and deltaB <= 1
					then
						insert(buffer, CHARS[64--[[01000000]] + (deltaR+2)*16 + (deltaG+2)*4 + (deltaB+2)]) -- QOI_OP_DIFF 01xxxxxx

					else
						local deltaRg = deltaR - deltaG -- Should we wrap these values too?
						local deltaBg = deltaB - deltaG

						if     deltaRg >= -8  and deltaRg <= 7
						   and deltaG  >= -32 and deltaG  <= 31
						   and deltaBg >= -8  and deltaBg <= 7
						then
							insert(buffer, CHARS[128--[[10000000]] + (deltaG +32)]) -- QOI_OP_LUMA 10xxxxxx
							insert(buffer, CHARS[(deltaRg+8)*16    + (deltaBg+8 )])

						else
							insert(buffer, "\254"--[[11111110]]) -- QOI_OP_RGB 11111110
							insert(buffer, CHARS[r])
							insert(buffer, CHARS[g])
							insert(buffer, CHARS[b])
						end
					end

				else
					insert(buffer, "\255"--[[11111111]]) -- QOI_OP_RGBA 11111111
					insert(buffer, CHARS[r])
					insert(buffer, CHARS[g])
					insert(buffer, CHARS[b])
					insert(buffer, CHARS[a])
				end
			end

			prevR = r
			prevG = g
			prevB = b
			prevA = a
		end
	end

	insert(buffer, "\0\0\0\0\0\0\0\1")

	return table.concat(buffer)
end



-- imageData, channels, colorSpace = qoi.read( path )
-- Returns nil and a message on error.
function qoi.read(path)
	assert(type(path) == "string")

	local s, err = love.filesystem.read(path)
	if not s then  return nil, err  end

	return qoi.decode(s)
end

-- success, error = qoi.write( imageData, path [, channels=4, colorSpace="linear" ] )
function qoi.write(imageData, path, channels, colorSpace)
	channels   = channels   or 4
	colorSpace = colorSpace or "linear"

	assert(type(imageData) == "userdata")
	assert(type(path) == "string")
	assert(channels == 3 or channels == 4)
	assert(colorSpace == "srgb" or colorSpace == "linear")

	local s, err = qoi.encode(imageData, channels, colorSpace)
	if not s then  return false, err  end

	local ok, err = love.filesystem.write(path, s)
	if not ok then  return false, err  end

	return true
end



-- image = qoi.load( path )
-- Substitute for love.graphics.newImage().
function qoi.load(path)
	assert(type(path) == "string")

	local imageData, err = qoi.read(path)
	if not imageData then  error(err, 2)  end

	local image = require"love.graphics".newImage(imageData)
	imageData:release()

	return image
end



return qoi

--==============================================================
--=
--=  MIT License
--=
--=  Copyright © 2022 Marcus 'ReFreezed' Thunström
--=
--=  Permission is hereby granted, free of charge, to any person obtaining a copy
--=  of this software and associated documentation files (the "Software"), to deal
--=  in the Software without restriction, including without limitation the rights
--=  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--=  copies of the Software, and to permit persons to whom the Software is
--=  furnished to do so, subject to the following conditions:
--=
--=  The above copyright notice and this permission notice shall be included in all
--=  copies or substantial portions of the Software.
--=
--=  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--=  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--=  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--=  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--=  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--=  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--=  SOFTWARE.
--=
--==============================================================
