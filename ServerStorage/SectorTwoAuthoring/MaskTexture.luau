local ImageDecode = require(script.Parent.ImportPipeline.Runtime.ImageDecode)
local CHANNELS = 4
local MAX_BLOCK_LENGTH = 65535
local ADLER_MODULUS = 65521
local CRC_POLYNOMIAL = 0xEDB88320
local BYTE_MASK = 0xFF
local PNG_SIGNATURE = "\137PNG\r\n\26\n"
local CRC_TABLE = {}
for index = 0, BYTE_MASK do
	local value = index
	for _ = 1, 8 do
		value = bit32.band(value, 1) == 1 and bit32.bxor(bit32.rshift(value, 1), CRC_POLYNOMIAL) or bit32.rshift(value, 1)
	end
	CRC_TABLE[index] = value
end
local function bigEndian(value)
	return string.char(bit32.band(bit32.rshift(value, 24), BYTE_MASK), bit32.band(bit32.rshift(value, 16), BYTE_MASK), bit32.band(bit32.rshift(value, 8), BYTE_MASK), bit32.band(value, BYTE_MASK))
end
local function crc32(data)
	local value = 0xFFFFFFFF
	for index = 1, #data do
		local lookup = bit32.band(bit32.bxor(value, string.byte(data, index)), BYTE_MASK)
		value = bit32.bxor(bit32.rshift(value, 8), CRC_TABLE[lookup])
	end
	return bit32.bxor(value, 0xFFFFFFFF)
end
local function chunk(kind, data)
	return bigEndian(#data) .. kind .. data .. bigEndian(crc32(kind .. data))
end
local function zlibStore(data)
	local pieces = {string.char(0x78, 0x01)}
	local first, second = 1, 0
	for index = 1, #data do
		first = (first + string.byte(data, index)) % ADLER_MODULUS
		second = (second + first) % ADLER_MODULUS
	end
	for start = 1, #data, MAX_BLOCK_LENGTH do
		local length = math.min(MAX_BLOCK_LENGTH, #data - start + 1)
		local inverse = MAX_BLOCK_LENGTH - length
		local last = start + length > #data
		table.insert(pieces, string.char(last and 1 or 0, length % 256, math.floor(length / 256), inverse % 256, math.floor(inverse / 256)))
		table.insert(pieces, string.sub(data, start, start + length - 1))
	end
	table.insert(pieces, bigEndian(second * 65536 + first))
	return table.concat(pieces)
end
local MaskTexture = {}
function MaskTexture.convert(source, maximumSize, color)
	local image = ImageDecode.decode(source, {maxSize = maximumSize, yield = function() task.wait() end})
	local stride = image.width * CHANNELS + 1
	local rows = buffer.create(stride * image.height)
	local red, green, blue = math.round(color.R * BYTE_MASK), math.round(color.G * BYTE_MASK), math.round(color.B * BYTE_MASK)
	for y = 0, image.height - 1 do
		for x = 0, image.width - 1 do
			local sourceOffset = (y * image.width + x) * CHANNELS
			local destination = y * stride + 1 + x * CHANNELS
			local mask = buffer.readu8(image.pixels, sourceOffset)
			local alpha = math.round(math.clamp((mask - 8) / 247, 0, 1) * 240)
			buffer.writeu8(rows, destination, red)
			buffer.writeu8(rows, destination + 1, green)
			buffer.writeu8(rows, destination + 2, blue)
			buffer.writeu8(rows, destination + 3, alpha)
		end
		if y % 32 == 0 then task.wait() end
	end
	local header = bigEndian(image.width) .. bigEndian(image.height) .. string.char(8, 6, 0, 0, 0)
	local png = PNG_SIGNATURE .. chunk("IHDR", header) .. chunk("IDAT", zlibStore(buffer.tostring(rows))) .. chunk("IEND", "")
	return buffer.fromstring(png)
end
return table.freeze(MaskTexture)
