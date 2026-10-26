import AVFoundation
import AudioToolbox
import Foundation
import Observation

/// Where the sound really starts, in seconds. Previews often open with silence
/// or a fade-in, which would make a 0.1 s clip useless, so skip ahead to the
/// first 10 ms that is at least 30% as loud as the clip overall (at most 4 s in).
public func soundStart(_ samples: UnsafeBufferPointer<Float>, sampleRate: Double) -> Double {
	let win = max(1, Int((sampleRate * 0.01).rounded()))
	let span = min(samples.count, Int(sampleRate * 10))
	var sum: Float = 0
	for i in 0..<span { sum += samples[i] * samples[i] }
	let overall = (sum / Float(max(1, span))).squareRoot()
	let threshold = max(0.01, overall * 0.3)
	let limit = min(samples.count, Int(sampleRate * 4))
	var i = 0
	while i + win <= limit {
		var s: Float = 0
		for j in i..<(i + win) { s += samples[j] * samples[j] }
		if (s / Float(win)).squareRoot() >= threshold { return max(0, Double(i) / sampleRate - 0.01) }
		i += win
	}
	return 0
}

/// Holds MP3 bytes for AudioToolbox's read callbacks.
private final class ByteSource {
	let data: Data
	init(_ data: Data) { self.data = data }
}

public struct AudioDecodeError: Error {}

/// Decode a preview (MP3) to PCM in memory. Previews are never written to disk.
public func decodeAudio(_ data: Data) throws -> AVAudioPCMBuffer {
	let source = ByteSource(data)
	let context = Unmanaged.passUnretained(source).toOpaque()
	var fileID: AudioFileID?
	let read: AudioFile_ReadProc = { client, position, requested, buffer, actual in
		let src = Unmanaged<ByteSource>.fromOpaque(client).takeUnretainedValue()
		let start = Int(position)
		let count = max(0, min(Int(requested), src.data.count - start))
		if count > 0 {
			src.data.withUnsafeBytes { raw in
				buffer.copyMemory(from: raw.baseAddress!.advanced(by: start), byteCount: count)
			}
		}
		actual.pointee = UInt32(count)
		return noErr
	}
	let size: AudioFile_GetSizeProc = { client in
		Int64(Unmanaged<ByteSource>.fromOpaque(client).takeUnretainedValue().data.count)
	}
	guard AudioFileOpenWithCallbacks(context, read, nil, size, nil, kAudioFileMP3Type, &fileID) == noErr, let fileID else {
		throw AudioDecodeError()
	}
	defer { AudioFileClose(fileID) }

	var extFile: ExtAudioFileRef?
	guard ExtAudioFileWrapAudioFileID(fileID, false, &extFile) == noErr, let ext = extFile else { throw AudioDecodeError() }
	defer { ExtAudioFileDispose(ext) }

	var fileFormat = AudioStreamBasicDescription()
	var propSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
	guard ExtAudioFileGetProperty(ext, kExtAudioFileProperty_FileDataFormat, &propSize, &fileFormat) == noErr else {
		throw AudioDecodeError()
	}
	let channels = AVAudioChannelCount(min(2, max(1, fileFormat.mChannelsPerFrame)))
	guard let format = AVAudioFormat(standardFormatWithSampleRate: fileFormat.mSampleRate, channels: channels) else {
		throw AudioDecodeError()
	}
	var client = format.streamDescription.pointee
	guard ExtAudioFileSetProperty(ext, kExtAudioFileProperty_ClientDataFormat, propSize, &client) == noErr else {
		throw AudioDecodeError()
	}

	// Previews are 30 s; leave room in case the header's length estimate is short.
	let capacity = AVAudioFrameCount(fileFormat.mSampleRate * 32)
	guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity), let floats = buffer.floatChannelData else {
		throw AudioDecodeError()
	}
	var total: AVAudioFrameCount = 0
	let list = AudioBufferList.allocate(maximumBuffers: Int(channels))
	defer { free(list.unsafeMutablePointer) }
	while total < capacity {
		var frames = min(8192, capacity - total)
		for ch in 0..<Int(channels) {
			list[ch] = AudioBuffer(mNumberChannels: 1, mDataByteSize: frames * 4, mData: floats[ch].advanced(by: Int(total)))
		}
		guard ExtAudioFileRead(ext, &frames, list.unsafeMutablePointer) == noErr else { throw AudioDecodeError() }
		if frames == 0 { break }
		total += frames
	}
	guard total > 0 else { throw AudioDecodeError() }
	buffer.frameLength = total
	return buffer
}

/// A decoded preview, immutable once made.
private final class Loaded: @unchecked Sendable {
	let buffer: AVAudioPCMBuffer
	/// Seconds of silence to skip at the start.
	let start: Double

	init(buffer: AVAudioPCMBuffer) {
		self.buffer = buffer
		start = soundStart(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)), sampleRate: buffer.format.sampleRate)
	}

	var duration: Double { Double(buffer.frameLength) / buffer.format.sampleRate }
}

/// Plays exact slices of a song's Deezer preview, so a 0.13 s clip is 0.13 s.
/// Previews are fetched fresh (their links expire) and kept in memory only.
@MainActor
@Observable
public final class ClipPlayer {
	public private(set) var playing = false
	public private(set) var loading = false
	/// Seconds played of the current clip.
	public private(set) var position: Double = 0
	/// Length of the current clip in seconds.
	public private(set) var length: Double = 0
	public var error: String?

	public var volume: Double = 0.8 {
		didSet { engine.mainMixerNode.outputVolume = Float(min(1, max(0, volume))) }
	}

	@ObservationIgnored private let engine = AVAudioEngine()
	@ObservationIgnored private let node = AVAudioPlayerNode()
	@ObservationIgnored private var connectedFormat: AVAudioFormat?
	@ObservationIgnored private var cache: [Int: (at: Date, task: Task<Loaded, Error>)] = [:]
	@ObservationIgnored private var token = 0
	@ObservationIgnored private var ticker: Task<Void, Never>?
	@ObservationIgnored private let client: DeezerClient

	/// How long a decoded preview stays in memory.
	private let keepFor: TimeInterval = 10 * 60
	/// Fade in and out so short clips don't click.
	private let fade = 0.005

	public init(client: DeezerClient = .shared) {
		self.client = client
		engine.attach(node)
	}

	private func load(_ id: Int) -> Task<Loaded, Error> {
		if let hit = cache[id], Date().timeIntervalSince(hit.at) < keepFor { return hit.task }
		let client = self.client
		let task = Task.detached { () throws -> Loaded in
			let (_, preview) = try await client.track(id)
			guard let preview else { throw DeezerError(message: "This song has no preview right now.", code: 0) }
			let (data, response) = try await URLSession.shared.data(from: preview)
			guard (response as? HTTPURLResponse)?.statusCode ?? 200 < 400 else {
				throw DeezerError(message: "Couldn't load this song's preview.", code: 0)
			}
			return Loaded(buffer: try decodeAudio(data))
		}
		cache[id] = (Date(), task)
		Task { [weak self] in
			if (try? await task.value) == nil { self?.cache[id] = nil }
		}
		while cache.count > 6, let oldest = cache.min(by: { $0.value.at < $1.value.at })?.key { cache[oldest] = nil }
		return task
	}

	/// Fetch and decode a song's preview ahead of time.
	public func preload(_ id: Int) {
		_ = load(id)
	}

	/// Play the first `seconds` of the song (after any silence).
	public func play(_ id: Int, seconds: Double) {
		token += 1
		let t = token
		halt()
		error = nil
		loading = true
		Task {
			let loaded: Loaded
			do {
				loaded = try await load(id).value
			} catch {
				if t == token {
					loading = false
					self.error = (error as? DeezerError)?.message ?? "Couldn't play this song."
				}
				return
			}
			guard t == token else { return }
			loading = false
			start(loaded, seconds: seconds, token: t)
		}
	}

	private func start(_ loaded: Loaded, seconds: Double, token t: Int) {
		let length = max(fade * 2, min(seconds, loaded.duration - loaded.start))
		guard let clip = slice(loaded, length: length) else {
			error = "Couldn't play this song."
			return
		}
		do {
			#if os(iOS)
				try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
				try AVAudioSession.sharedInstance().setActive(true)
			#endif
			if connectedFormat != clip.format {
				engine.disconnectNodeOutput(node)
				engine.connect(node, to: engine.mainMixerNode, format: clip.format)
				connectedFormat = clip.format
			}
			engine.mainMixerNode.outputVolume = Float(volume)
			if !engine.isRunning { try engine.start() }
		} catch {
			self.error = "Couldn't start the sound."
			return
		}
		node.scheduleBuffer(clip, at: nil, options: .interrupts) { [weak self] in
			Task { @MainActor in
				guard let self, self.token == t else { return }
				self.finish()
			}
		}
		node.play()
		self.length = length
		position = 0
		playing = true
		let began = Date()
		ticker = Task { [weak self] in
			while !Task.isCancelled {
				guard let self, self.token == t, self.playing else { return }
				self.position = min(length, Date().timeIntervalSince(began))
				try? await Task.sleep(for: .milliseconds(33))
			}
		}
	}

	/// The clip as its own buffer, with short fades at both ends.
	private func slice(_ loaded: Loaded, length: Double) -> AVAudioPCMBuffer? {
		let src = loaded.buffer
		let rate = src.format.sampleRate
		let from = Int(loaded.start * rate)
		let count = min(Int(length * rate), Int(src.frameLength) - from)
		guard count > 0, let out = AVAudioPCMBuffer(pcmFormat: src.format, frameCapacity: AVAudioFrameCount(count)),
			let s = src.floatChannelData, let d = out.floatChannelData
		else { return nil }
		out.frameLength = AVAudioFrameCount(count)
		let ramp = max(1, Int(fade * rate))
		for ch in 0..<Int(src.format.channelCount) {
			for i in 0..<count {
				var g: Float = 1
				if i < ramp { g = Float(i) / Float(ramp) }
				if i >= count - ramp { g = min(g, Float(count - 1 - i) / Float(ramp)) }
				d[ch][i] = s[ch][from + i] * g
			}
		}
		return out
	}

	private func finish() {
		ticker?.cancel()
		playing = false
		position = 0
	}

	public func stop() {
		token += 1
		loading = false
		halt()
	}

	private func halt() {
		ticker?.cancel()
		node.stop()
		playing = false
		position = 0
	}
}
