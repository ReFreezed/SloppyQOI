--[[============================================================
--=
--=  SloppyQOI library test
--=
--============================================================]]

local RUN_TEST_SUITE             = 1==0 -- Needs folder "suite/" to have the contents from <https://qoiformat.org/benchmark/qoi_benchmark_suite.tar>.
local ANALYZE_TEST_SUITE_RESULTS = 1==0 -- Outputs to stdout!

local TEST_SUITE_START_INDEX = 1
local TEST_SUITE_END_INDEX   = 1/0

local TEST_SUITE_RESULTS_FILE = "Test suite results (2022-04-28).txt" -- For ANALYZE_TEST_SUITE_RESULTS.

local TEST_ENCODING = 1==1 -- Limited effect on test suite.



local REPO_DIR = love.filesystem.getSource():gsub("[/\\][^/\\]+$", "")

io.stdout:setvbuf("no")
io.stderr:setvbuf("no")

package.preload.qoi = function()
	return assert(loadfile(REPO_DIR.."/qoi.lua"))()
end



--
-- Test suite.
--
if RUN_TEST_SUITE then
	local qoi = require"qoi"

	local function collectPngFiles(dir, paths)
		for _, filename in ipairs(love.filesystem.getDirectoryItems(dir)) do
			local path = dir .. "/" .. filename

			if love.filesystem.getInfo(path, "directory") then
				collectPngFiles(path, paths)
			elseif filename:find"%.png$" then
				table.insert(paths, path)
			end
		end
	end

	local paths = {}
	collectPngFiles("suite", paths)

	for i = math.max(TEST_SUITE_START_INDEX, 1), math.min(TEST_SUITE_END_INDEX, #paths) do
		local path = paths[i]

		print()
		print("["..i.."/"..#paths.."] "..path)

		local fileData      = love.filesystem.newFileData(path)
		local time          = love.timer.getTime()
		local ok, imageData = pcall(love.image.newImageData, fileData)
		local pngDecodeTime = love.timer.getTime() - time
		fileData:release()

		if not ok then
			io.stderr:write("Error: ", imageData, "\n")

		else
			local time          = love.timer.getTime()
			local qoiData, err  = qoi.encode(imageData, 4, "srgb")
			local qoiEncodeTime = love.timer.getTime() - time

			if not qoiData then
				io.stderr:write("Error: ", err, "\n")

			else
				local time            = love.timer.getTime()
				local imageData2, err = qoi.decode(qoiData)
				local qoiDecodeTime   = love.timer.getTime() - time

				if not imageData2 then
					io.stderr:write("Error: ", err, "\n")

				else
					local fileData2 = nil
					local time      = love.timer.getTime()
					if TEST_ENCODING then
						fileData2 = imageData:encode("png", nil)
					end
					local pngEncodeTime = love.timer.getTime() - time

					local pngSize = fileData2 and fileData2:getSize() or 0

					print("size", imageData:getDimensions())
					print("pngDecode", "-"     , pngDecodeTime*1000)
					print("qoiDecode", "-"     , qoiDecodeTime*1000)
					print("pngEncode", pngSize , pngEncodeTime*1000)
					print("qoiEncode", #qoiData, qoiEncodeTime*1000)

					if fileData2 then
						fileData2:release()
					end
					imageData2:release()
				end
			end

			imageData:release()
		end
	end

	os.exit()
end



--
-- Analyze test suite results.
--
if ANALYZE_TEST_SUITE_RESULTS then
	local file = io.open(REPO_DIR.."/docs/"..TEST_SUITE_RESULTS_FILE)
	local s    = file:read"*a"
	file:close()

	local folders = {}

	local count = {total=0}

	local decodeTimeDiff = {total=0}
	local encodeTimeDiff = {total=0}
	local sizeDiff       = {total=0}

	local decodeTimeSumPng = {total=0}
	local decodeTimeSumQoi = {total=0}
	local encodeTimeSumPng = {total=0}
	local encodeTimeSumQoi = {total=0}

	local sizeSumPng = {total=0}
	local sizeSumQoi = {total=0}

	local pat = "%[%d+/%d+%] (%S[^\n]*)"
	         .. "\nsize\t(%d+)\t(%d+)"
	         .. "\npngDecode\t%-\t([%d.]+)"
	         .. "\nqoiDecode\t%-\t([%d.]+)"
	         .. "\npngEncode\t(%d+)\t([%d.]+)"
	         .. "\nqoiEncode\t(%d+)\t([%d.]+)"

	for path, w, h, pngDecodeTime, qoiDecodeTime, pngSize, pngEncodeTime, qoiSize, qoiEncodeTime in s:gmatch(pat) do
		local folder = path:match"([^/]+)/[^/]+$"

		if not count[folder] then
			count           [folder] = 0
			decodeTimeDiff  [folder] = 0
			encodeTimeDiff  [folder] = 0
			sizeDiff        [folder] = 0
			decodeTimeSumPng[folder] = 0
			decodeTimeSumQoi[folder] = 0
			encodeTimeSumPng[folder] = 0
			encodeTimeSumQoi[folder] = 0
			sizeSumPng      [folder] = 0
			sizeSumQoi      [folder] = 0
			table.insert(folders, folder)
		end

		count.total   = count.total   + 1
		count[folder] = count[folder] + 1

		decodeTimeDiff.total   = decodeTimeDiff.total   + qoiDecodeTime / pngDecodeTime
		decodeTimeDiff[folder] = decodeTimeDiff[folder] + qoiDecodeTime / pngDecodeTime
		encodeTimeDiff.total   = encodeTimeDiff.total   + qoiEncodeTime / pngEncodeTime
		encodeTimeDiff[folder] = encodeTimeDiff[folder] + qoiEncodeTime / pngEncodeTime
		sizeDiff.total         = sizeDiff.total         + qoiSize       / pngSize
		sizeDiff[folder]       = sizeDiff[folder]       + qoiSize       / pngSize

		decodeTimeSumPng.total   = decodeTimeSumPng.total   + pngDecodeTime
		decodeTimeSumPng[folder] = decodeTimeSumPng[folder] + pngDecodeTime
		decodeTimeSumQoi.total   = decodeTimeSumQoi.total   + qoiDecodeTime
		decodeTimeSumQoi[folder] = decodeTimeSumQoi[folder] + qoiDecodeTime
		encodeTimeSumPng.total   = encodeTimeSumPng.total   + pngEncodeTime
		encodeTimeSumPng[folder] = encodeTimeSumPng[folder] + pngEncodeTime
		encodeTimeSumQoi.total   = encodeTimeSumQoi.total   + qoiEncodeTime
		encodeTimeSumQoi[folder] = encodeTimeSumQoi[folder] + qoiEncodeTime

		sizeSumPng.total   = sizeSumPng.total   + pngSize
		sizeSumPng[folder] = sizeSumPng[folder] + pngSize
		sizeSumQoi.total   = sizeSumQoi.total   + qoiSize
		sizeSumQoi[folder] = sizeSumQoi[folder] + qoiSize

		--[[ When QOI is slower than PNG.
		if 2*tonumber(pngDecodeTime) < tonumber(qoiDecodeTime) then
			print(path)
			print("-qoi", qoiDecodeTime)
			print("-png", pngDecodeTime)
			print()
		end
		--]]

		--[[ Compession ratio.
		local rawSize = w * h * 4 -- 32 bits per pixel.
		print(string.format("png/qoi %2d%%/%2d%%  %s", pngSize/rawSize*100, qoiSize/rawSize*100, path))
		--]]
	end

	table.insert(folders, "total")

	for _, folder in ipairs(folders) do
		print(folder)
		print("  QOI compared to PNG, per file:")
		print("    Decode: "..decodeTimeDiff[folder]/count[folder])
		print("    Encode: "..encodeTimeDiff[folder]/count[folder])
		print("    Size:   "..sizeDiff[folder]/count[folder])
		print("  Average time:")
		print("    DecodePNG: "..decodeTimeSumPng[folder]/count[folder])
		print("    DecodeQOI: "..decodeTimeSumQoi[folder]/count[folder])
		print("    EncodePNG: "..encodeTimeSumPng[folder]/count[folder])
		print("    EncodeQOI: "..encodeTimeSumQoi[folder]/count[folder])
		print("  Size sum:")
		print("    PNG: "..sizeSumPng[folder])
		print("    QOI: "..sizeSumQoi[folder])
		print()
	end

	os.exit()
end



--
-- Simple testing.
--
local imageDatas = {}
local images1    = {}
local images2    = {}
local imageIndex = 1

function love.load()
	love.keyboard.setKeyRepeat(true)

	local basenames = {
		"dice",
		"kodim10",
		"kodim23",
		"qoi_logo",
		"testcard",
		"testcard_rgba",
		"wikipedia_008",
	}
	local qoi = require"qoi"

	for _, basename in ipairs(basenames) do
		local pngPath   = "images/" .. basename .. ".png"
		local time      = love.timer.getTime()
		local imageData = love.image.newImageData(pngPath)
		time            = love.timer.getTime() - time
		print("decode", time*1000, pngPath)

		local qoiPath   = "images/" .. basename .. ".qoi"
		local time      = love.timer.getTime()
		local imageData = assert(qoi.read(qoiPath))
		time            = love.timer.getTime() - time
		print("decode", time*1000, qoiPath)

		table.insert(imageDatas, imageData)
		table.insert(images1   , love.graphics.newImage(imageData))

		print()
	end

	if TEST_ENCODING then
		for i, basename in ipairs(basenames) do
			local imageData = imageDatas[i]
			print()

			local pngPath = basename .. ".png"
			local time    = love.timer.getTime()
			imageData:encode("png", pngPath)
			time          = love.timer.getTime() - time
			print("encode", time*1000, pngPath)

			local qoiPath = basename .. ".qoi"
			local time    = love.timer.getTime()
			assert(qoi.write(imageData, qoiPath, 4, "srgb"))
			time          = love.timer.getTime() - time
			print("encode", time*1000, qoiPath)

			local imageData2 = assert(qoi.read(qoiPath))
			table.insert(images2, love.graphics.newImage(imageData2))
		end
	end
end

function love.keypressed(key)
	if key == "escape" then
		love.event.quit()
	elseif key == "right" then
		imageIndex = (imageIndex  ) % #images1 + 1
	elseif key == "left" then
		imageIndex = (imageIndex-2) % #images1 + 1
	end
end

function love.draw()
	love.graphics.clear(0, 1, .5)
	love.graphics.draw(images1[imageIndex])
	if images2[imageIndex] then
		love.graphics.draw(images2[imageIndex], images1[imageIndex]:getWidth(), 0)
	end
end

function love.errorhandler(err)
	io.stderr:write(debug.traceback(tostring(err), 2), "\n")
	os.exit(1)
end


