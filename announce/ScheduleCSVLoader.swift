import Foundation

enum ScheduleCSVLoaderError: LocalizedError {
    case fileNotFound(String)
    case invalidEncoding
    case emptyFile
    case missingHeader
    case invalidRow(Int, String)
    case invalidDateTime(Int, String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let name):
            return "CSV ファイルが見つかりません：\(name)"
        case .invalidEncoding:
            return "CSV を UTF-8 または Shift-JIS として読み込めません。"
        case .emptyFile:
            return "CSV ファイルが空です。"
        case .missingHeader:
            return "CSV の見出しが必要です：Date,Time,Announce"
        case .invalidRow(let line, let text):
            return "\(line) 行目の形式が不正です：\(text)"
        case .invalidDateTime(let line, let value):
            return "\(line) 行目の日付または時刻を解釈できません：\(value)"
        }
    }
}

struct ScheduleCSVLoader {
    private let calendar: Calendar
    private let timeZone: TimeZone

    init(
        calendar: Calendar = Calendar(identifier: .gregorian),
        timeZone: TimeZone = .current
    ) {
        var calendar = calendar
        calendar.timeZone = timeZone
        self.calendar = calendar
        self.timeZone = timeZone
    }

    func loadBundledCSV(named name: String) throws -> [ScheduleItem] {
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: "csv"
        ) else {
            throw ScheduleCSVLoaderError.fileNotFound("\(name).csv")
        }

        let data = try Data(contentsOf: url)
        return try parse(data: data)
    }

    func parse(data: Data) throws -> [ScheduleItem] {
        guard let text = decode(data: data) else {
            throw ScheduleCSVLoaderError.invalidEncoding
        }

        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            throw ScheduleCSVLoaderError.emptyFile
        }

        let header = parseCSVLine(lines[0])
            .map { normalizeHeader($0) }

        guard header.count >= 3,
              header[0] == "date",
              header[1] == "time",
              header[2] == "announce" else {
            throw ScheduleCSVLoaderError.missingHeader
        }

        var items: [ScheduleItem] = []
        
        let today = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = timeZone
        dateFormatter.dateFormat = "yyyy/MM/dd"
        let todayString = dateFormatter.string(from: today)

        for (index, line) in lines.dropFirst().enumerated() {
            let lineNumber = index + 2
            let columns = parseCSVLine(line)

            guard columns.count >= 3 else {
                throw ScheduleCSVLoaderError.invalidRow(lineNumber, line)
            }

            var dateText = columns[0].trimmingCharacters(in: .whitespaces)
            let timeText = columns[1].trimmingCharacters(in: .whitespaces)
            var announceText = columns[2].trimmingCharacters(in: .whitespaces)
            let captionText = columns.count >= 4 ? columns[3] : ""

            if timeText.isEmpty {
                continue
            }
            
            if dateText.isEmpty {
                dateText = todayString
            }
            
            if announceText.isEmpty || announceText == "0" {
                announceText = "音声なし"
            }

            guard let date = makeDate(
                dateText: dateText,
                timeText: timeText
            ) else {
                throw ScheduleCSVLoaderError.invalidDateTime(
                    lineNumber,
                    "\(dateText) \(timeText)"
                )
            }
            
            let resourceName = removeAudioExtension(from: announceText)
            let normalizedResourceName = normalizeResourceName(resourceName)

            items.append(
                ScheduleItem(
                    date: date,
                    displayName: normalizedResourceName,
                    resourceName: normalizedResourceName,
                    caption: captionText.trimmingCharacters(in: .whitespaces)
                )
            )
        }

        return items.sorted { $0.date < $1.date }
    }

    private func decode(data: Data) -> String? {
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }

        return String(data: data, encoding: .shiftJIS)
    }

    private func makeDate(
        dateText: String,
        timeText: String
    ) -> Date? {
        let combined = "\(dateText) \(timeText)"

        let formats = [
            "yyyy/MM/dd HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy/MM/dd H:mm:ss",
            "yyyy-MM-dd H:mm:ss",
            "yyyy/MM/dd HH:mm",
            "yyyy-MM-dd HH:mm",
            "yyyy/MM/dd H:mm",
            "yyyy-MM-dd H:mm"
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone

        for format in formats {
            formatter.dateFormat = format

            if let date = formatter.date(from: combined) {
                return date
            }
        }

        return nil
    }

    private func normalizeHeader(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            .lowercased()
    }

    private func removeAudioExtension(from value: String) -> String {
        let extensions = [".wav", ".mp3", ".m4a"]

        for fileExtension in extensions {
            if value.lowercased().hasSuffix(fileExtension) {
                return String(
                    value.dropLast(fileExtension.count)
                )
            }
        }

        return value
    }
    
    private func normalizeResourceName(_ value: String) -> String {
        if value == "音声なし" {
            return value
        }
        
        let components = value.components(separatedBy: " ")
        guard let first = components.first,
              let number = Int(first),
              components.count > 1 else {
            return value
        }
        
        let paddedNumber = String(format: "%02d", number)
        return "\(paddedNumber) \(components.dropFirst().joined(separator: " "))"
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var columns: [String] = []
        var current = ""
        var isInsideQuotes = false

        for character in line {
            if character == "\"" {
                isInsideQuotes.toggle()
            } else if character == "," && !isInsideQuotes {
                columns.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }

        columns.append(current)
        return columns
    }
}
