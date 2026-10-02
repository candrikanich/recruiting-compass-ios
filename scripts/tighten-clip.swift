import AVFoundation
import CoreImage

// Usage: tighten <in.mp4> <out.mp4> [maxHold=0.9]
// Shortens every frozen stretch (UI test waiting on queries) to `maxHold` seconds; motion is untouched.
let args = CommandLine.arguments
let input = URL(fileURLWithPath: args[1])
let output = URL(fileURLWithPath: args[2])
let maxHold = args.count > 3 ? Double(args[3])! : 0.9
let step = 0.1

let asset = AVURLAsset(url: input)
let duration = CMTimeGetSeconds(asset.duration)
let gen = AVAssetImageGenerator(asset: asset)
gen.maximumSize = CGSize(width: 110, height: 240)
gen.requestedTimeToleranceBefore = .zero
gen.requestedTimeToleranceAfter = .zero

func pixels(_ image: CGImage) -> [UInt8] {
  let w = 55, h = 120
  var buf = [UInt8](repeating: 0, count: w * h * 4)
  let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
  return buf
}

func differs(_ a: [UInt8], _ b: [UInt8]) -> Bool {
  var diff = 0
  for i in stride(from: 0, to: a.count, by: 4) where abs(Int(a[i]) - Int(b[i])) > 12 { diff += 1 }
  return diff > 3
}

// Mark each sample as static when it matches the previous sample.
var times: [Double] = []
var isStatic: [Bool] = []
var previous: [UInt8]?
var t = 0.0
guard duration.isFinite, duration > 0 else {
  print("\(input.lastPathComponent): unreadable or unfinished recording, skipped")
  exit(0)
}
while t < duration {
  guard let cg = try? gen.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil) else {
    print("\(input.lastPathComponent): unreadable frame at \(t)s, skipped")
    exit(0)
  }
  let px = pixels(cg)
  isStatic.append(previous.map { !differs($0, px) } ?? false)
  previous = px
  times.append(t)
  t += step
}

// Cut the tail of each static run beyond maxHold.
var cuts: [(Double, Double)] = []
var runStart: Double?
for (i, s) in isStatic.enumerated() {
  if s, runStart == nil { runStart = times[i] - step }
  let runEnds = !s || i == isStatic.count - 1
  if runEnds, let start = runStart {
    let end = s ? duration : times[i] - step
    if end - start > maxHold { cuts.append((start + maxHold, end)) }
    runStart = nil
  }
}

let comp = AVMutableComposition()
let videoTrack = try await asset.loadTracks(withMediaType: .video)[0]
let track = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
var cursor = 0.0
var insertAt = CMTime.zero
func keep(_ from: Double, _ to: Double) throws {
  guard to - from > 0.01 else { return }
  let range = CMTimeRange(start: CMTime(seconds: from, preferredTimescale: 600),
                          end: CMTime(seconds: to, preferredTimescale: 600))
  try track.insertTimeRange(range, of: videoTrack, at: insertAt)
  insertAt = insertAt + range.duration
}
for (from, to) in cuts { try keep(cursor, from); cursor = to }
try keep(cursor, duration)
track.preferredTransform = try await videoTrack.load(.preferredTransform)

try? FileManager.default.removeItem(at: output)
let export = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality)!
try await export.export(to: output, as: .mp4)
print(String(format: "%@: %.1fs -> %.1fs (%d holds shortened)", input.lastPathComponent, duration,
             CMTimeGetSeconds(insertAt), cuts.count))
