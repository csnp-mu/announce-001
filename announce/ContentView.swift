import SwiftUI
import AVFoundation
import Combine
import UIKit
import UniformTypeIdentifiers
import Kronos
import Foundation

struct ScheduleItem: Identifiable {
    let id = UUID()
    let date: Date
    let displayName: String
    let resourceName: String
    let caption: String
}

struct AudioFileSetting: Identifiable {
    let id = UUID()
    let resourceName: String
    let displayName: String
    var fileURL: URL?
    var originalFileName: String?
}

final class AudioPlayerManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var currentTrackName = ""

    private var player: AVAudioPlayer?
    var customAudioFiles: [String: URL] = [:]
    var useDefaultAudio = true

    func play(resourceName: String, isMuted: Bool, volume: Float = 1.0) {
        guard !isMuted else { return }

        let customURL = !useDefaultAudio ? customAudioFiles[resourceName] : nil
        let bundledURL = Bundle.main.url(forResource: resourceName, withExtension: "wav")
        ?? Bundle.main.url(forResource: resourceName, withExtension: "mp3")
        ?? Bundle.main.url(forResource: resourceName, withExtension: "m4a")

        guard let audioURL = customURL ?? bundledURL else {
            print("❌ 音声ファイル未発見：\(resourceName)")
            return
        }
        
        print("🎵 再生試行：\(audioURL.lastPathComponent)")
        print("   URL: \(audioURL)")
        print("   拡張子：\(audioURL.pathExtension)")
        
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: audioURL.path) {
            print("❌ ファイルが存在しません：\(audioURL.path)")
            return
        }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: audioURL.path)
            let fileSize = attributes[.size] as? Int ?? 0
            print("📊 ファイルサイズ：\(fileSize) bytes")
            
            if fileSize == 0 {
                print("❌ ファイルが空です")
                return
            }
        } catch {
            print("❌ ファイル属性の読み込みエラー：\(error)")
        }

        do {
            player = try AVAudioPlayer(contentsOf: audioURL)
            player?.delegate = self
            player?.volume = volume
            player?.prepareToPlay()
            player?.play()
            isPlaying = true
            currentTrackName = resourceName
            
            print("✅ 再生成功：\(resourceName)")
        } catch {
            print("❌ 再生エラー：\(error.localizedDescription)")
            print("   エラーコード：\((error as NSError).code)")
            print("   使用形式：\(audioURL.pathExtension)")
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTrackName = ""
    }

    func setMuted(_ muted: Bool) {
        player?.volume = muted ? 0 : 1
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentTrackName = ""
        }
    }
}

enum DemoMode {
    case demo1, demo2, demo3, demo4, demo5, demo6
}

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var schedule: [ScheduleItem] = []
    @State private var currentTime = Date()
    @State private var countdownSeconds = 0
    @State private var nextDisplayName = "なし"
    @State private var isMuted = false
    @State private var isRunning = false
    @State private var demoMode: DemoMode = .demo2
    @State private var timeOffset: TimeInterval = 0

    @State private var csvStatusMessage = ""
    @State private var csvErrorMessage = ""
    @State private var showCSVError = false
    @State private var csvFileName = "test_schedule.csv"

    @State private var showingCSVPicker = false
    @State private var showingAudioFilePicker = false
    @State private var showingAudioFolderPicker = false
    @State private var currentAudioType = ""

    @State private var useCustomAudio = false
    @StateObject private var audioManager = AudioPlayerManager()
    @State private var audioSettings: [AudioFileSetting] = []
    @State private var showingAudioSettings = false
    @State private var audioStatusMessage = "標準音声（©音読さん）を使用中"
    @State private var audioErrorMessage = ""
    @State private var showAudioError = false

    @StateObject private var subscriptionManager = SubscriptionManager()
    @State private var showingSubscription = false
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private let allAudioTypes = [
        "01 移動開始", "02 課題読む", "03 課題開始", "04 課題終了一分前",
        "05 課題終了_移動開始", "06 課題終了",
        "13 課題終了_フィードバック開始", "14 フィードバック終了_移動開始",
        "17 開始2分前", "18 開始1分前", "19 休憩に入る", "20 放送終了のアナウンス",
        "26 テストラン開始1分前",
        "特別70 開始5分前", "特別71 休憩", "特別72 昼休憩",
        "特別73 休憩", "特別74 試験終了", "特別75 試験終了_集合",
        "特別76 課題準備",
        "custom01", "custom02", "custom03", "custom04", "custom05",
        "custom06", "custom07", "custom08", "custom09", "custom10"
    ]

    private let supportedAudioExtensions: Set<String> = [
        "wav", "mp3", "m4a", "aiff", "aif", "aac", "caf", "flac"
    ]

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .sheet(isPresented: $showingSubscription) {
            SubscriptionView()
        }
        .sheet(isPresented: $showingCSVPicker) {
            CSVFilePicker { url in
                handleCSVFilePick(url)
            }
        }
        .sheet(isPresented: $showingAudioFilePicker) {
            AudioFilePicker { url in
                handleAudioFilePick(url)
            }
        }
        .sheet(isPresented: $showingAudioFolderPicker) {
            FolderPicker { url in
                handleAudioFolderPick(url)
            }
        }
        .sheet(isPresented: $showingAudioSettings) {
            AudioSettingsView(
                audioSettings: $audioSettings,
                useCustomAudio: $useCustomAudio,
                audioManager: audioManager,
                onSelectFile: { resourceName in
                    currentAudioType = resourceName
                    showingAudioFilePicker = true
                },
                onSelectFolder: {
                    showingAudioFolderPicker = true
                },
                onReset: resetAudioFiles
            )
        }
        .onChange(of: isRunning) { newValue in
            UIApplication.shared.isIdleTimerDisabled = newValue
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onReceive(timer) { _ in
            currentTime = Date().addingTimeInterval(timeOffset)
            if isRunning { updateSchedule() }
        }
        .onAppear {
            setupAudio()
            initializeAudioSettings()
            loadCSV2()
            Clock.sync(from: "ntp.nict.jp") { _, offset in
                timeOffset = offset
            }
        }
        .alert("CSV 読み込みエラー", isPresented: $showCSVError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(csvErrorMessage)
        }
        .alert("音声ファイル設定", isPresented: $showAudioError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(audioErrorMessage)
        }
    }

    private var iPhoneLayout: some View {
        NavigationView {
            phoneContent
                .navigationTitle("announce")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var iPadLayout: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    HStack(alignment: .top, spacing: 24) {
                        VStack(spacing: 20) {
                            clockSection
                            countdownSection
                            playControlSection
                            muteSection
                            testAudioSection
                            csvSection
                            demoSection
                        }
                        .frame(width: min(max(geometry.size.width * 0.38, 320), 460))

                        scheduleSection
                            .frame(minWidth: 380, maxWidth: .infinity)
                    }
                    .padding()
                    .frame(minWidth: geometry.size.width)
                }
            }
            .navigationTitle("announce")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var phoneContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                clockSection
                countdownSection
                playControlSection
                muteSection
                testAudioSection
                csvSection
                demoSection
                scheduleSection
            }
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding()
        }
    }

    private var clockSection: some View {
        Text(currentTime.formatted(.dateTime.hour().minute().second()))
            .font(.system(size: 32, weight: .bold, design: .monospaced))
    }

    private var countdownSection: some View {
        VStack(spacing: 8) {
            Text("次再生まで：\(formatHMS(countdownSeconds))")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.orange)
            Text("📢 \(nextDisplayName)")
                .font(.title2.bold())
                .foregroundColor(.blue)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.blue.opacity(0.25))
        .cornerRadius(15)
    }

    private var playControlSection: some View {
        Button(action: toggleSchedule) {
            Label(
                isRunning ? "再生中（停止する）" : "停止中（再生する）",
                systemImage: isRunning ? "stop.circle.fill" : "play.circle.fill"
            )
        }
        .buttonStyle(.borderedProminent)
        .tint(isRunning ? .red : .green)
        .frame(maxWidth: .infinity)
    }

    private var muteSection: some View {
        HStack {
            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.3.fill")
                .foregroundColor(isMuted ? .red : .green)
            Text(isMuted ? "ミュート中" : "音声 ON")
                .font(.headline.bold())
                .foregroundColor(isMuted ? .red : .green)
            Spacer()
            Toggle("", isOn: $isMuted)
                .labelsHidden()
                .onChange(of: isMuted) { newValue in
                    audioManager.setMuted(newValue)
                }
        }
        .padding()
        .background(Color.gray.opacity(0.25))
        .cornerRadius(12)
    }

    private var testAudioSection: some View {
        Group {
            if horizontalSizeClass == .regular {
                HStack(spacing: 12) { testAudioButtons }
            } else {
                HStack(spacing: 12) { testAudioButtons }
            }
        }
        .buttonStyle(.borderedProminent)
    }

    @ViewBuilder
    private var testAudioButtons: some View {
        Button("閲覧") { audioManager.play(resourceName: "02 課題読む", isMuted: isMuted) }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 6)
        Button("開始") { audioManager.play(resourceName: "03 課題開始", isMuted: isMuted) }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 6)
        Button("終了") { audioManager.play(resourceName: "06 課題終了", isMuted: isMuted) }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 6)
    }

    private var csvSection: some View {
        VStack(spacing: 8) {
            Text("CSV: \(csvFileName)").font(.headline)
            Text(csvStatusMessage.isEmpty ? "未読み込み" : csvStatusMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.green.opacity(0.25))
        .cornerRadius(12)
    }

    private var demoSection: some View {
        VStack(spacing: 12) {
            Group {
                if horizontalSizeClass == .regular {
                    HStack(spacing: 8) { demoButtons }
                } else {
                    HStack(spacing: 8) { demoButtons }
                }
            }
  
// CSV 選択ボタン（サブスク制限）
            Button("📁 CSV 選択") { showingCSVPicker = true }
                .buttonStyle(.bordered)
                .padding(.top, 12)
//                // サブスク制限解除
//                .disabled(!subscriptionManager.isPremium)
//                .opacity(subscriptionManager.isPremium ? 1.0 : 0.5)

            Divider()
                .padding(.vertical, 12)

// 音声設定ボタン（サブスク制限）
            let configuredCount = audioSettings.filter { $0.fileURL != nil }.count
            let audioButtonText = useCustomAudio
                ? "音声設定 (\(configuredCount)/\(allAudioTypes.count))"
                : "音声設定"

            Button { showingAudioSettings = true } label: {
                Label(audioButtonText, systemImage: "speaker.wave.2.fill")
            }
            .buttonStyle(.bordered)
            .tint(useCustomAudio ? .green : .blue)
//            // サブスク制限解除
//            .disabled(!subscriptionManager.isPremium)
//            .opacity(subscriptionManager.isPremium ? 1.0 : 0.5)

            Text(audioStatusMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
//            // サブスク制限解除
//            // サブスク制限のメッセージ
//            if !subscriptionManager.isPremium {
//                Text("🔒 CSV 選択と音声設定はプレミアムプランで利用可能")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//                    .padding(.top, 8)
//            }
//            
//            // プレミアムプランセクション
//            Divider()
//                .padding(.vertical, 12)
//            
//            VStack(spacing: 8) {
//                Text("プレミアムプラン")
//                    .font(.headline)
//                    .foregroundColor(.primary)
//                
//                Text("カスタムスケジュールと音声ファイルを使用できます")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//                    .multilineTextAlignment(.center)
//                
//                Button {
//                    showingSubscription = true
//                } label: {
//                    Label(subscriptionManager.isPremium ? "管理" : "プレミアム", systemImage: "crown.fill")
//                        .frame(maxWidth: .infinity)
//                }
//                .buttonStyle(.borderedProminent)
//                .tint(subscriptionManager.isPremium ? .yellow : .orange)
//            }
//            .padding()
//            .frame(maxWidth: .infinity)
//            .background(Color.orange.opacity(0.1))
//            .cornerRadius(12)
        }
        .padding()
    }

//    @ViewBuilder
//    private var demoButtons: some View {
//        Button("🗓️ 1") {
//            demoMode = .demo1
//            schedule = demoSchedule1()
//            csvStatusMessage = "デモ 1 を使用中"
//            csvFileName = "領域 1・5 を 1 回分"
//        }
//        .buttonStyle(.borderedProminent)
//        .padding(.horizontal, 6)
//        Button("🗓️ 2") { loadCSV2(); demoMode = .demo2 }
//            .buttonStyle(.borderedProminent)
//            .padding(.horizontal, 6)
//        Button("🗓️ 3") { loadCSV3(); demoMode = .demo3 }
//            .buttonStyle(.borderedProminent)
//            .padding(.horizontal, 6)
//        Button("🗓️ 4") { loadCSV4(); demoMode = .demo4 }
//            .buttonStyle(.borderedProminent)
//            .padding(.horizontal, 6)
//        Button("🗓️ 5") { loadCSV5(); demoMode = .demo5 }
//            .buttonStyle(.borderedProminent)
//            .padding(.horizontal, 6)
//        Button("🗓️ 6") { loadCSV6(); demoMode = .demo6 }
//            .buttonStyle(.borderedProminent)
//            .padding(.horizontal, 6)
//    }
        
    
    @ViewBuilder
    private var demoButtons: some View {
        VStack(spacing: 12) {
            // 1 段目：ボタン 1, 2, 3
            HStack(spacing: 8) {
                Button("🗓️ 1") {
                    demoMode = .demo1
                    schedule = demoSchedule1()
                    csvStatusMessage = "デモ 1 を使用中"
                    csvFileName = "領域 1・5 1 回分"
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 6)
                
                Button("🗓️ 2") { loadCSV2(); demoMode = .demo2 }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 6)
                
                Button("🗓️ 3") { loadCSV3(); demoMode = .demo3 }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 6)
            }
            
            // 2 段目：ボタン 4, 5, 6
            HStack(spacing: 8) {
                Button("🗓️ 4") { loadCSV4(); demoMode = .demo4 }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 6)
                
                Button("🗓️ 5") { loadCSV5(); demoMode = .demo5 }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 6)
                
                Button("🗓️ 6") { loadCSV6(); demoMode = .demo6 }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 6)
            }
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("📋 全スケジュール (\(schedule.count) 件)")
                .font(.headline.bold())
                .padding(.horizontal)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(schedule) { item in
                        HStack(spacing: 12) {
                            Text(item.date, style: .time)
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 80, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.displayName)
                                    .font(.headline)
                                if !item.caption.isEmpty {
                                    Text(item.caption)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal)
                        .background(nextItemIs(item) ? Color.orange.opacity(0.25) : Color.clear)
                        .overlay(nextItemIs(item) ? RoundedRectangle(cornerRadius: 8).stroke(Color.orange, lineWidth: 2) : nil).id(item.id)
                    }
                }
            }
            .frame(minHeight: 200, maxHeight: 500)
            .background(Color.secondary.opacity(0.25))
            .cornerRadius(12)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func nextItemIs(_ item: ScheduleItem) -> Bool {
        guard let next = schedule.filter({ $0.date > currentTime }).min(by: { $0.date < $1.date }) else { return false }
        return abs(item.date.timeIntervalSince(next.date)) < 2
    }

    private func updateSchedule() {
        guard let next = schedule.filter({ $0.date > currentTime }).min(by: { $0.date < $1.date }) else {
            nextDisplayName = "なし"
            countdownSeconds = 0
            return
        }

        let diff = next.date.timeIntervalSince(currentTime)
        countdownSeconds = max(Int(diff) + 1, 0)
        nextDisplayName = next.displayName

        if diff <= 1 {
            if next.resourceName != "音声なし" {
                audioManager.play(resourceName: next.resourceName, isMuted: isMuted)
            } else {
                print("🔇 音声なし：スキップ")
            }
        }
    }

    private func formatHMS(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0 ? "\(h)h \(m)m \(s)s" : "\(m)m \(s)s"
    }

    private func toggleSchedule() {
        isRunning.toggle()
        if !isRunning {
            nextDisplayName = "なし"
        }
    }
    private func setupAudio() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            try session.setActive(true)
            
            print("✅ オーディオセッション設定完了")
            print("📢 カテゴリ：\(session.category)")
            print("🔊 モード：\(session.mode)")
            print("🎚️ オプション：\(session.categoryOptions)")
        } catch {
            print("❌ オーディオ設定エラー：\(error)")
        }
    }

    private func loadCSV2() {
        do {
            schedule = try ScheduleCSVLoader().loadBundledCSV(named: "demo15")
            csvFileName = "demo15.csv"
            csvStatusMessage = "CSV 読み込み成功：\(schedule.count) 件"
        } catch { showCSVErrorMessage(error) }
    }

    private func loadCSV3() {
        do {
            schedule = try ScheduleCSVLoader().loadBundledCSV(named: "demo234")
            csvFileName = "demo234.csv"
            csvStatusMessage = "CSV 読み込み成功：\(schedule.count) 件"
        } catch { showCSVErrorMessage(error) }
    }
    
    private func loadCSV4() {
        do {
            schedule = try ScheduleCSVLoader().loadBundledCSV(named: "技能評価15")
            csvFileName = "技能評価15.csv"
            csvStatusMessage = "CSV 読み込み成功：\(schedule.count) 件"
        } catch { showCSVErrorMessage(error) }
    }

    private func loadCSV5() {
        do {
            schedule = try ScheduleCSVLoader().loadBundledCSV(named: "総合評価15")
            csvFileName = "総合評価15.csv"
            csvStatusMessage = "CSV 読み込み成功：\(schedule.count) 件"
        } catch { showCSVErrorMessage(error) }
    }

    private func loadCSV6() {
        do {
            schedule = try ScheduleCSVLoader().loadBundledCSV(named: "初回面談")
            csvFileName = "初回面談.csv"
            csvStatusMessage = "CSV 読み込み成功：\(schedule.count) 件"
        } catch { showCSVErrorMessage(error) }
    }

    private func showCSVErrorMessage(_ error: Error) {
        csvErrorMessage = error.localizedDescription
        csvStatusMessage = "CSV 読み込み失敗"
        schedule = []
        showCSVError = true
    }

    private func handleCSVFilePick(_ sourceURL: URL) {
        let access = sourceURL.startAccessingSecurityScopedResource()
        defer { if access { sourceURL.stopAccessingSecurityScopedResource() } }

        do {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let destination = documents.appendingPathComponent(sourceURL.lastPathComponent)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            schedule = try ScheduleCSVLoader().parse(data: Data(contentsOf: destination))
            csvFileName = sourceURL.lastPathComponent
            csvStatusMessage = "CSV 読み込み成功：\(schedule.count) 件"
        } catch { showCSVErrorMessage(error) }
    }

    private func initializeAudioSettings() {
        audioSettings = allAudioTypes.map { AudioFileSetting(resourceName: $0, displayName: $0) }
        restoreAudioFiles()
    }

    private func handleAudioFilePick(_ sourceURL: URL) {
        guard !currentAudioType.isEmpty else {
            showAudioErrorMessage("設定先のアナウンス種別が選択されていません。")
            return
        }

        let access = sourceURL.startAccessingSecurityScopedResource()
        defer { if access { sourceURL.stopAccessingSecurityScopedResource() } }

        do {
            guard supportedAudioExtensions.contains(sourceURL.pathExtension.lowercased()) else {
                throw AudioImportError.unsupportedFile(sourceURL.lastPathComponent)
            }
            let destination = try copyAudioFileToDocuments(from: sourceURL, resourceName: currentAudioType)
            setAudioFile(destination, for: currentAudioType, originalFileName: sourceURL.lastPathComponent)
            saveAudioFilesToUserDefaults()
            audioStatusMessage = "\(currentAudioType) に音声を設定しました"
        } catch {
            showAudioErrorMessage("音声ファイルを設定できませんでした。\n\(error.localizedDescription)")
        }
    }

    private func handleAudioFolderPick(_ folderURL: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            let access = folderURL.startAccessingSecurityScopedResource()
            defer {
                if access {
                    folderURL.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: folderURL,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                )

                var importedFiles: [(resourceName: String, url: URL)] = []
                var unmatchedFileNames: [String] = []

                for sourceURL in contents {
                    guard isSupportedAudioFile(sourceURL) else {
                        continue
                    }

                    let sourceName = sourceURL
                        .deletingPathExtension()
                        .lastPathComponent

                    guard let resourceName = matchedAudioType(for: sourceName) else {
                        unmatchedFileNames.append(sourceURL.lastPathComponent)
                        continue
                    }

                    let destination = try copyAudioFileToDocuments(
                        from: sourceURL,
                        resourceName: resourceName
                    )

                    importedFiles.append(
                        (
                            resourceName: resourceName,
                            url: destination
                        )
                    )
                }

                DispatchQueue.main.async {
                    guard !importedFiles.isEmpty else {
                        let message: String

                        if unmatchedFileNames.isEmpty {
                            message = "対応音声ファイルが見つかりませんでした。"
                        } else {
                            message = "ファイル名がアナウンス名と一致しませんでした。"
                        }

                        showAudioErrorMessage(
                            "\(message)\n例：02 課題読む.mp3"
                        )
                        return
                    }

                    for importedFile in importedFiles {
                        setAudioFile(
                            importedFile.url,
                            for: importedFile.resourceName
                        )
                    }

                    saveAudioFilesToUserDefaults()
                    audioStatusMessage =
                        "フォルダから \(importedFiles.count) 件の音声を設定しました"
                }
            } catch {
                DispatchQueue.main.async {
                    showAudioErrorMessage(
                        "フォルダを読み込めませんでした。\n\(error.localizedDescription)"
                    )
                }
            }
        }
    }
    
    private func isSupportedAudioFile(_ url: URL) -> Bool {
        guard !url.hasDirectoryPath else {
            return false
        }

        let supportedExtensions: Set<String> = [
            "wav",
            "mp3",
            "m4a",
            "aiff",
            "aif",
            "aac",
            "caf",
            "flac"
        ]

        return supportedExtensions.contains(
            url.pathExtension.lowercased()
        )
    }
    
    private func matchedAudioType(for sourceName: String) -> String? {
        let normalizedSource = normalizeAudioName(sourceName)

        return allAudioTypes.first { audioType in
            let normalizedAudioType = normalizeAudioName(audioType)
            return normalizedSource == normalizedAudioType
        }
    }
    
    private func normalizeAudioName(_ value: String) -> String {
        value
            .replacingOccurrences(of: "　", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(
                of: "\\s+",
                with: " ",
                options: .regularExpression
            )
            .lowercased()
    }

    private func copyAudioFileToDocuments(from sourceURL: URL, resourceName: String) throws -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let ext = sourceURL.pathExtension.lowercased()

        for oldExt in supportedAudioExtensions {
            let oldURL = documents.appendingPathComponent("\(resourceName).\(oldExt)")
            if FileManager.default.fileExists(atPath: oldURL.path) {
                try FileManager.default.removeItem(at: oldURL)
            }
        }

        let destination = documents.appendingPathComponent("\(resourceName).\(ext)")
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return destination
    }

    private func setAudioFile(_ url: URL, for resourceName: String, originalFileName: String? = nil) {
        guard let index = audioSettings.firstIndex(where: { $0.resourceName == resourceName }) else { return }
        audioSettings[index].fileURL = url
        audioSettings[index].originalFileName = originalFileName
        audioManager.customAudioFiles[resourceName] = url
        audioManager.useDefaultAudio = false
        useCustomAudio = true
    }

    private func saveAudioFilesToUserDefaults() {
        let values = audioSettings.compactMap { setting -> (String, String)? in
            guard let url = setting.fileURL else { return nil }
            return (setting.resourceName, url.path)
        }
        UserDefaults.standard.set(Dictionary(uniqueKeysWithValues: values), forKey: "customAudioFiles")
    }

    private func restoreAudioFiles() {
        guard let dictionary = UserDefaults.standard.dictionary(forKey: "customAudioFiles") as? [String: String] else { return }

        for (resourceName, path) in dictionary {
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            audioManager.customAudioFiles[resourceName] = url
            if let index = audioSettings.firstIndex(where: { $0.resourceName == resourceName }) {
                audioSettings[index].fileURL = url
                audioSettings[index].originalFileName = url.lastPathComponent
            }
        }

        if !audioManager.customAudioFiles.isEmpty {
            audioManager.useDefaultAudio = false
            useCustomAudio = true
            audioStatusMessage = "カスタム音声を \(audioManager.customAudioFiles.count) 件読み込みました"
        }
    }

    private func resetAudioFiles() {
        audioManager.stop()
        audioManager.customAudioFiles.removeAll()
        audioManager.useDefaultAudio = true
        useCustomAudio = false
        for index in audioSettings.indices { audioSettings[index].fileURL = nil }
        UserDefaults.standard.removeObject(forKey: "customAudioFiles")

        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for audioType in allAudioTypes {
            for ext in supportedAudioExtensions {
                try? FileManager.default.removeItem(at: documents.appendingPathComponent("\(audioType).\(ext)"))
            }
        }
        audioStatusMessage = "標準音声（©音読さん）に戻しました"
    }

    private func showAudioErrorMessage(_ message: String) {
        audioErrorMessage = message
        showAudioError = true
    }

    private func demoSchedule1() -> [ScheduleItem] {
        let now = Date()
        return [
            (4, "閲覧", "02 課題読む"),
            (124, "開始", "03 課題開始"),
            (364, "終了 1 分前", "04 課題終了一分前"),
            (424, "終了", "06 課題終了")
        ].map { seconds, display, resource in
            ScheduleItem(
                date: now.addingTimeInterval(TimeInterval(seconds)),
                displayName: display,
                resourceName: resource,
                caption: "")
        }
    }
}

private enum AudioImportError: LocalizedError {
    case unsupportedFile(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFile(let name): return "対応していない音声形式です：\(name)"
        }
    }
}

struct AudioSettingsView: View {
    @Binding var audioSettings: [AudioFileSetting]
    @Binding var useCustomAudio: Bool
    @ObservedObject var audioManager: AudioPlayerManager
    let onSelectFile: (String) -> Void
    let onSelectFolder: () -> Void
    let onReset: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var previewPlayer: AVAudioPlayer?
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("一括設定")) {
                    Button(action: onSelectFolder) {
                        Label("フォルダから一括設定", systemImage: "folder.fill")
                    }
                    Text("フォルダ直下の音声ファイルを読み込みます。ファイル名（拡張子を除く）が各アナウンス名と一致するものを自動設定します。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("音声ファイル設定")) {
                    ForEach(audioSettings) { setting in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(setting.displayName).font(.headline)
                                if let fileURL = setting.fileURL {

                                    Text("✅ \(setting.originalFileName ?? fileURL.lastPathComponent)")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                        .lineLimit(1)
                                } else {
                                    Text("標準音声（©音読さん）を使用")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            
                            Button(action: {
                                playPreview(for: setting)
                            }) {
                                Image(systemName: "play.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 4)
                            
                            Button("選択") { onSelectFile(setting.resourceName) }
                                .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section(header: Text("再生方法")) {
                    Toggle("カスタム音声を使用", isOn: $useCustomAudio)
                        .onChange(of: useCustomAudio) { enabled in
                            audioManager.useDefaultAudio = !enabled
                        }
                    Text(useCustomAudio ? "設定済みの項目はカスタム音声、それ以外は標準音声（©音読さん）で再生します。" : "すべて標準音声（©音読さん）で再生します。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    Button(role: .destructive, action: onReset) {
                        Label("音声設定をリセット", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("音声設定")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }
    
    private func playPreview(for setting: AudioFileSetting) {
        if let customURL = setting.fileURL {
            do {
                previewPlayer = try AVAudioPlayer(contentsOf: customURL)
                previewPlayer?.play()
            } catch {
                print("❌ カスタム音声の再生エラー：\(error)")
            }
        } else {
            if let defaultURL = Bundle.main.url(forResource: setting.resourceName, withExtension: "wav")
                ?? Bundle.main.url(forResource: setting.resourceName, withExtension: "mp3")
                ?? Bundle.main.url(forResource: setting.resourceName, withExtension: "m4a") {
                do {
                    previewPlayer = try AVAudioPlayer(contentsOf: defaultURL)
                    previewPlayer?.play()
                } catch {
                    print("❌ デフォルト音声の再生エラー：\(error)")
                }
            } else {
                print("❌ 音声ファイルが見つかりません：\(setting.resourceName)")
            }
        }
    }
}
