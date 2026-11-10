// phoneuse-ocr: the Mac's text recognition for `phoneuse text`, `tap-on`, `open` and `type` (phoneuse/vision.py).
// Apple's Vision framework, so the app needs no OCR model of its own. Reads one image path per line on stdin and
// writes one JSON line per image: {"lines": [{"text", "x", "y", "w", "h", "conf"}]}, positions as fractions of
// the image (x, y the centre; y down), the same as the RapidOCR service on Linux. An error is {"error": "..."}.
import Foundation
import Vision

/// Recognition is English-only, yet Vision still returns Cyrillic or Greek letters that look like Latin ones
/// ("3AM" came back as "ЗАМ" on the Weather app). Any such letter in the output is a misread: map it back.
let latin: [Character: Character] = [
    "А": "A", "В": "B", "Е": "E", "З": "3", "К": "K", "М": "M", "Н": "H", "О": "O", "Р": "P", "С": "C",
    "Т": "T", "Х": "X", "У": "Y", "І": "I", "Ј": "J", "Ѕ": "S", "Ԛ": "Q", "Ԝ": "W",
    "а": "a", "е": "e", "о": "o", "р": "p", "с": "c", "у": "y", "х": "x", "і": "i", "ј": "j", "ѕ": "s",
    "Α": "A", "Β": "B", "Ε": "E", "Ζ": "Z", "Η": "H", "Ι": "I", "Κ": "K", "Μ": "M", "Ν": "N", "Ο": "O",
    "Ρ": "P", "Τ": "T", "Υ": "Y", "Χ": "X", "ο": "o", "ν": "v",
]

func toLatin(_ s: String) -> String { String(s.map { latin[$0] ?? $0 }) }

func recognize(_ path: String) -> [String: Any] {
    let url = URL(fileURLWithPath: path)
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false  // UI labels, names and numbers: read them as written
    // Latin script: left to guess, Vision read "3AM" as Cyrillic "ЗАМ" on the Weather app
    request.recognitionLanguages = ["en-US"]
    request.automaticallyDetectsLanguage = false
    request.minimumTextHeight = 0.006        // the status bar and small captions on a 2622-pixel-tall screen
    let handler = VNImageRequestHandler(url: url, options: [:])
    do {
        try handler.perform([request])
    } catch {
        return ["error": "\(error.localizedDescription)"]
    }
    var lines: [[String: Any]] = []
    for obs in request.results ?? [] {
        guard let top = obs.topCandidates(1).first else { continue }
        let b = obs.boundingBox  // normalized, origin at the bottom left
        func r(_ v: CGFloat) -> Double { (Double(v) * 10000).rounded() / 10000 }
        lines.append(["text": toLatin(top.string), "x": r(b.midX), "y": r(1 - b.midY), "w": r(b.width), "h": r(b.height),
                      "conf": (Double(top.confidence) * 1000).rounded() / 1000])
    }
    return ["lines": lines]
}

setvbuf(stdout, nil, _IOLBF, 0)
while let line = readLine() {
    let path = line.trimmingCharacters(in: .whitespacesAndNewlines)
    if path.isEmpty { continue }
    let reply = autoreleasepool { recognize(path) }
    let data = (try? JSONSerialization.data(withJSONObject: reply)) ?? Data("{\"error\":\"encoding\"}".utf8)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}
