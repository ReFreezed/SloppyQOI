--[[============================================================
--=
--=  QOI library test
--=
--============================================================]]

local RUN_TEST_SUITE             = 1==0 -- Needs folder "suite/" to have the contents from <https://qoiformat.org/benchmark/qoi_benchmark_suite.tar>.
local ANALYZE_TEST_SUITE_RESULTS = 1==0

local TEST_SUITE_START_INDEX = 1
local TEST_SUITE_END_INDEX   = 1/0
local TEST_ENCODING          = 1==1 -- Doesn't affect test suite.



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

	for i, path in ipairs(paths) do
		if i >= TEST_SUITE_START_INDEX and i <= TEST_SUITE_END_INDEX then
			print("["..i.."/"..#paths.."] "..path)

			local time          = love.timer.getTime()
			local ok, imageData = pcall(love.image.newImageData, path)
			local pngDecodeTime = love.timer.getTime() - time

			if not ok then
				io.stderr:write("Error: ", imageData, "\n")

			else
				local time          = love.timer.getTime()
				local qoiData, err  = qoi.encode(imageData)
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
						local time          = love.timer.getTime()
						local fileData      = imageData:encode("png", nil)
						local pngEncodeTime = love.timer.getTime() - time

						print("size", imageData:getDimensions())
						print("pngDecode", "-"               , pngDecodeTime*1000)
						print("qoiDecode", "-"               , qoiDecodeTime*1000)
						print("pngEncode", fileData:getSize(), pngEncodeTime*1000)
						print("qoiEncode", #qoiData          , qoiEncodeTime*1000)

						fileData:release()
						imageData2:release()
					end
				end

				imageData:release()
			end
		end
	end

	os.exit()
end



--
-- Analyze test suite results.
--
if ANALYZE_TEST_SUITE_RESULTS then
	local file = io.open(REPO_DIR.."/docs/Test suite results.txt")
	local s    = file:read"*a"
	file:close()

	local count          = 0
	local decodeTimeDiff = 0
	local encodeTimeDiff = 0
	local sizeDiff       = 0

	local pat = "%[%d+/%d+%] (%S[^\n]*)"
	         .. "\nsize\t(%d+)\t(%d+)"
	         .. "\npngDecode\t%-\t([%d.]+)"
	         .. "\nqoiDecode\t%-\t([%d.]+)"
	         .. "\npngEncode\t(%d+)\t([%d.]+)"
	         .. "\nqoiEncode\t(%d+)\t([%d.]+)"

	for path, w, h, pngDecodeTime, qoiDecodeTime, pngSize, pngEncodeTime, qoiSize, qoiEncodeTime in s:gmatch(pat) do
		count          = count + 1
		decodeTimeDiff = decodeTimeDiff + qoiDecodeTime / pngDecodeTime
		encodeTimeDiff = encodeTimeDiff + qoiEncodeTime / pngEncodeTime
		sizeDiff       = sizeDiff       + qoiSize       / pngSize
	end

	print("QOI compared to PNG")
	print("Decode: "..decodeTimeDiff/count)
	print("Encode: "..encodeTimeDiff/count)
	print("Size:   "..sizeDiff/count)

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
			assert(qoi.write(imageData, qoiPath))
			time          = love.timer.getTime() - time
			print("encode", time*1000, qoiPath)

			table.insert(images2, love.graphics.newImage(assert(qoi.read(qoiPath))))
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


