local SAMPLE_RATE = 800
local MAX_SAMPLES_PER_REQUEST = 8192
local BUCKET_DURATION = 0.05
local SILENCE_RATIO = 0.08
local MIN_SILENCE = 0.15
local SPOKEN_NUMBER_WEIGHTS = { 5, 10, 20, 40 }
local EXTRA_DIGIT_WEIGHT = 10
local MISSED_SENTENCE_COST = 1.2
local MISSED_COMMA_COST = 0.35
local SKIPPED_SILENCE_COST_PER_SECOND = 1
local SILENCE_LENGTH_REWARD = 1
local SEGMENT_PATTERN = "[^,;:%.!?]+[,;:%.!?]*"
local CLOSING_MARK_PATTERN = "([,;:%.!?])%s*$"
local COMMA_MARK_PATTERN = "[,;:]"
local MATCH_STEP = 1
local MISS_STEP = 2
local SKIP_STEP = 3

export type Window = {
	start: number,
	finish: number,
}

type Silence = {
	start: number,
	finish: number,
}

type Segment = {
	weight: number,
	isSentenceEnd: boolean,
}

type Layout = {
	segments: { Segment },
	lastSegmentOfLine: { number },
}

type Voicing = {
	isVoiced: { boolean },
	first: number,
	last: number,
}

local SpeechTimeline = {}

local function numberWeight(digitCount: number): number
	local tableSize = #SPOKEN_NUMBER_WEIGHTS
	if digitCount <= tableSize then
		return SPOKEN_NUMBER_WEIGHTS[digitCount]
	end
	return SPOKEN_NUMBER_WEIGHTS[tableSize] + EXTRA_DIGIT_WEIGHT * (digitCount - tableSize)
end

local function spokenWeight(text: string): number
	local weight = 0
	for digits in string.gmatch(text, "%d+") do
		weight += numberWeight(#digits)
	end
	local letters = string.gsub(text, "%d", "")
	return weight + (utf8.len(letters) or #letters)
end

local function layoutSegments(lines: { string }): Layout
	local segments: { Segment } = {}
	local lastSegmentOfLine = {}
	for index, line in lines do
		local segmentCountBefore = #segments
		for text in string.gmatch(line, SEGMENT_PATTERN) do
			if string.find(text, "%S") then
				local closingMark = string.match(text, CLOSING_MARK_PATTERN)
				table.insert(segments, {
					weight = spokenWeight(text),
					isSentenceEnd = closingMark == nil or string.find(closingMark, COMMA_MARK_PATTERN) == nil,
				})
			end
		end
		if #segments == segmentCountBefore then
			table.insert(segments, { weight = spokenWeight(line), isSentenceEnd = true })
		end
		lastSegmentOfLine[index] = #segments
	end
	return { segments = segments, lastSegmentOfLine = lastSegmentOfLine }
end

local function proportionalWindows(lines: { string }, length: number): { Window }
	local weights = {}
	local totalWeight = 0
	for index, line in lines do
		weights[index] = math.max(1, spokenWeight(line))
		totalWeight += weights[index]
	end
	local windows = {}
	local cursor = 0
	for index, weight in weights do
		local duration = length * weight / totalWeight
		windows[index] = { start = cursor, finish = cursor + duration }
		cursor += duration
	end
	return windows
end

local function readLevels(audio: AudioTextToSpeech): { number }?
	local length = audio.TimeLength
	local bucketCount = math.max(1, math.ceil(length / BUCKET_DURATION))
	local sums = table.create(bucketCount, 0)
	local counts = table.create(bucketCount, 0)
	local chunkDuration = MAX_SAMPLES_PER_REQUEST / SAMPLE_RATE
	local chunkStart = 0
	while chunkStart < length do
		local chunkEnd = math.min(length, chunkStart + chunkDuration)
		local requestedSamples = math.max(1, math.ceil((chunkEnd - chunkStart) * SAMPLE_RATE))
		local ok, samples = pcall(audio.GetWaveformAsync, audio, NumberRange.new(chunkStart, chunkEnd), requestedSamples)
		if not ok or #samples == 0 then
			return nil
		end
		local sampleDuration = (chunkEnd - chunkStart) / #samples
		for index, sample in samples do
			local sampleTime = chunkStart + (index - 0.5) * sampleDuration
			local bucket = math.clamp(math.floor(sampleTime / BUCKET_DURATION) + 1, 1, bucketCount)
			sums[bucket] += math.abs(sample)
			counts[bucket] += 1
		end
		chunkStart = chunkEnd
	end
	local levels = table.create(bucketCount, 0)
	for bucket = 1, bucketCount do
		if counts[bucket] > 0 then
			levels[bucket] = sums[bucket] / counts[bucket]
		end
	end
	return levels
end

local function detectVoicing(levels: { number }): Voicing?
	local peak = 0
	for _, level in levels do
		peak = math.max(peak, level)
	end
	local threshold = peak * SILENCE_RATIO
	local isVoiced = {}
	local first: number? = nil
	local last: number? = nil
	for bucket, level in levels do
		isVoiced[bucket] = level > threshold
		if isVoiced[bucket] then
			first = first or bucket
			last = bucket
		end
	end
	if not first or not last then
		return nil
	end
	return { isVoiced = isVoiced, first = first, last = last }
end

local function findSilences(voicing: Voicing): { Silence }
	local silences = {}
	local silentSince: number? = nil
	for bucket = voicing.first, voicing.last do
		if not voicing.isVoiced[bucket] then
			silentSince = silentSince or bucket
		elseif silentSince then
			local silence = { start = (silentSince - 1) * BUCKET_DURATION, finish = (bucket - 1) * BUCKET_DURATION }
			if silence.finish - silence.start >= MIN_SILENCE - 1e-6 then
				table.insert(silences, silence)
			end
			silentSince = nil
		end
	end
	return silences
end

local function expectedBoundaryTimes(voicing: Voicing, segments: { Segment }): { number }
	local totalWeight = 0
	for _, segment in segments do
		totalWeight += segment.weight
	end
	local targets = {}
	local weightSoFar = 0
	for index = 1, #segments - 1 do
		weightSoFar += segments[index].weight
		targets[index] = weightSoFar / totalWeight
	end
	local voicedTotal = 0
	for bucket = voicing.first, voicing.last do
		if voicing.isVoiced[bucket] then
			voicedTotal += 1
		end
	end
	local times = {}
	local voicedSoFar = 0
	for bucket = voicing.first, voicing.last do
		if voicing.isVoiced[bucket] then
			voicedSoFar += 1
		end
		while #times < #targets and voicedSoFar >= targets[#times + 1] * voicedTotal do
			table.insert(times, bucket * BUCKET_DURATION)
		end
	end
	return times
end

local function missedBoundaryCost(segment: Segment): number
	return if segment.isSentenceEnd then MISSED_SENTENCE_COST else MISSED_COMMA_COST
end

local function alignBoundaries(expected: { number }, segments: { Segment }, silences: { Silence }): { [number]: Silence }
	local boundaryCount = #expected
	local silenceCount = #silences
	local cost: { [number]: { [number]: number } } = {}
	local step: { [number]: { [number]: number } } = {}
	for boundary = 0, boundaryCount do
		cost[boundary] = {}
		step[boundary] = {}
		for silence = 0, silenceCount do
			local best = if boundary == 0 and silence == 0 then 0 else math.huge
			local bestStep = SKIP_STEP
			if boundary > 0 and silence > 0 then
				local candidate = silences[silence]
				local matchCost = cost[boundary - 1][silence - 1]
					+ math.abs(expected[boundary] - (candidate.start + candidate.finish) / 2)
					- SILENCE_LENGTH_REWARD * (candidate.finish - candidate.start)
				if matchCost < best then
					best, bestStep = matchCost, MATCH_STEP
				end
			end
			if boundary > 0 then
				local missCost = cost[boundary - 1][silence] + missedBoundaryCost(segments[boundary])
				if missCost < best then
					best, bestStep = missCost, MISS_STEP
				end
			end
			if silence > 0 then
				local candidate = silences[silence]
				local skipCost = cost[boundary][silence - 1]
					+ SKIPPED_SILENCE_COST_PER_SECOND * (candidate.finish - candidate.start)
				if skipCost < best then
					best, bestStep = skipCost, SKIP_STEP
				end
			end
			cost[boundary][silence] = best
			step[boundary][silence] = bestStep
		end
	end
	local matched = {}
	local boundary, silence = boundaryCount, silenceCount
	while boundary > 0 or silence > 0 do
		local chosen = step[boundary][silence]
		if chosen == MATCH_STEP then
			matched[boundary] = silences[silence]
			boundary -= 1
			silence -= 1
		elseif chosen == MISS_STEP then
			boundary -= 1
		else
			silence -= 1
		end
	end
	return matched
end

function SpeechTimeline.windows(audio: AudioTextToSpeech, lines: { string }): { Window }
	local levels = readLevels(audio)
	local voicing = if levels then detectVoicing(levels) else nil
	if not voicing then
		return proportionalWindows(lines, audio.TimeLength)
	end
	local layout = layoutSegments(lines)
	local expected = expectedBoundaryTimes(voicing, layout.segments)
	local matched = alignBoundaries(expected, layout.segments, findSilences(voicing))
	local windows = {}
	local start = (voicing.first - 1) * BUCKET_DURATION
	for index = 1, #lines do
		local finish = voicing.last * BUCKET_DURATION
		local nextStart = finish
		if index < #lines then
			local boundary = layout.lastSegmentOfLine[index]
			local silence = matched[boundary]
			finish = if silence then silence.start else expected[boundary]
			nextStart = if silence then silence.finish else expected[boundary]
		end
		windows[index] = { start = start, finish = math.max(start, finish) }
		start = nextStart
	end
	return windows
end

return SpeechTimeline
