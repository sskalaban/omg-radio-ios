import Foundation
import AVFoundation
import MediaPlayer

/// Единая точка управления воспроизведением (зеркало PlayerManager из Android-версии).
@MainActor
final class PlayerManager: ObservableObject {
    static let shared = PlayerManager()

    @Published var stationIndex = 0
    @Published var regionIndex = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    /// Название текущего трека из ICY-метаданных потока (как в Android-версии).
    @Published private(set) var trackTitle: String?
    @Published var highQuality: Bool {
        didSet { UserDefaults.standard.set(highQuality, forKey: "highQuality") }
    }

    private var player: AVPlayer?
    private var statusObserver: NSKeyValueObservation?
    private var timeControlObserver: NSKeyValueObservation?
    private var metadataObserver: NSKeyValueObservation?

    // Сон-таймер
    @Published private(set) var sleepRemainingSec: Int = 0
    private var sleepTimer: Timer?
    private var sleepEndAt: Date?

    // Будильник: громкость/нарастание и отложенный запуск до загрузки станций
    private var volumeRampTimer: Timer?
    private var pendingAlarm: (nid: String, volume: Float, fadeIn: Bool)?

    private init() {
        highQuality = UserDefaults.standard.object(forKey: "highQuality") as? Bool ?? true
        regionIndex = UserDefaults.standard.integer(forKey: "regionIndex")
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        setupRemoteCommands()
    }

    var currentStation: Station? {
        let stations = RadioRepository.shared.stations
        return stations[safe: stationIndex]
    }

    func play(index: Int, stations: [Station]) {
        guard let station = stations[safe: index] else { return }
        stationIndex = index
        trackTitle = nil
        UserDefaults.standard.set(station.nid, forKey: "lastStationNid")
        let urlString = station.streamUrl(hq: highQuality, regionIndex: regionIndex)
        guard !urlString.isEmpty, let url = URL(string: urlString) else { return }

        isBuffering = true
        player?.pause()
        statusObserver = nil
        timeControlObserver = nil
        metadataObserver = nil

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player

        // ICY-метаданные: исполнитель — название песни
        metadataObserver = item.observe(\.timedMetadata, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let meta = item.timedMetadata else { return }
                for m in meta where m.commonKey?.rawValue == "title" {
                    guard let value = m.stringValue?.trimmingCharacters(in: .whitespaces),
                          !value.isEmpty, value != station.title else { continue }
                    self?.trackTitle = value
                }
            }
        }

        timeControlObserver = player.observe(\.timeControlStatus, options: [.new]) { [weak self] p, _ in
            Task { @MainActor in
                switch p.timeControlStatus {
                case .waitingToPlayAtSpecifiedRate:
                    self?.isBuffering = true
                case .playing:
                    self?.isBuffering = false
                    self?.isPlaying = true
                case .paused:
                    self?.isBuffering = false
                    self?.isPlaying = false
                @unknown default:
                    break
                }
            }
        }
        player.play()
        updateNowPlaying(station: station)
    }

    // MARK: - Now Playing / медиа-кнопки (CarPlay, экран блокировки, руль)

    /// Кнопки play/pause/next/prev на экране блокировки, в CarPlay и на руле.
    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.play(index: self.stationIndex, stations: RadioRepository.shared.stations)
            }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.toggle(stations: RadioRepository.shared.stations)
            }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.next(stations: RadioRepository.shared.stations)
            }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.prev(stations: RadioRepository.shared.stations)
            }
            return .success
        }
    }

    /// Название станции и логотип на экране блокировки и в CarPlay Now Playing.
    private func updateNowPlaying(station: Station) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: station.title,
            MPMediaItemPropertyArtist: station.freqLabel(regionIndex: regionIndex),
            MPNowPlayingInfoPropertyIsLiveStream: true,
        ]
        if let local = station.localLogo, let image = UIImage(named: local) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        // Удалённый логотип — в фоне, затем обновление артворка
        if station.localLogo == nil, !station.logo.isEmpty, let url = URL(string: station.logo) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data, let image = UIImage(data: data) else { return }
                Task { @MainActor in
                    MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtwork] =
                        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                }
            }.resume()
        }
    }

    func toggle(stations: [Station]) {
        guard let player else {
            play(index: stationIndex, stations: stations)
            return
        }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    func next(stations: [Station]) { step(1, stations: stations) }
    func prev(stations: [Station]) { step(-1, stations: stations) }

    private func step(_ delta: Int, stations: [Station]) {
        guard !stations.isEmpty else { return }
        let newIndex = (stationIndex + delta + stations.count) % stations.count
        // Как в Android-версии: при работающем плеере переключаем поток, иначе только выбор
        if isPlaying {
            play(index: newIndex, stations: stations)
        } else {
            stationIndex = newIndex
            UserDefaults.standard.set(stations[newIndex].nid, forKey: "lastStationNid")
        }
    }

    func setRegion(_ index: Int, stations: [Station]) {
        guard index != regionIndex else { return }
        regionIndex = index
        UserDefaults.standard.set(index, forKey: "regionIndex")
        if isPlaying {
            play(index: stationIndex, stations: stations)
        }
    }

    func restoreSelection(stations: [Station]) {
        let nid = UserDefaults.standard.string(forKey: "lastStationNid") ?? ""
        if let i = stations.firstIndex(where: { $0.nid == nid }) {
            stationIndex = i
        }
    }

    /// Выбор станции без запуска воспроизведения (тап по плитке до play).
    func selectStation(_ index: Int, stations: [Station]) {
        guard stations.indices.contains(index) else { return }
        stationIndex = index
        UserDefaults.standard.set(stations[index].nid, forKey: "lastStationNid")
    }

    /// Тихий выбор региона (плитка города на главной): без перезапуска потока.
    func setRegionSilent(_ index: Int) {
        regionIndex = index
        UserDefaults.standard.set(index, forKey: "regionIndex")
    }

    // MARK: - Сон-таймер

    /// minutes <= 0 — выключить. По истечении ставит на паузу (как в Android-версии).
    func setSleepTimer(minutes: Int) {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepEndAt = nil
        guard minutes > 0 else {
            sleepRemainingSec = 0
            return
        }
        sleepEndAt = Date().addingTimeInterval(TimeInterval(minutes * 60))
        sleepRemainingSec = minutes * 60
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickSleepTimer()
            }
        }
    }

    private func tickSleepTimer() {
        guard let end = sleepEndAt else { return }
        let left = Int(end.timeIntervalSinceNow)
        if left <= 0 {
            sleepRemainingSec = 0
            sleepTimer?.invalidate()
            sleepTimer = nil
            sleepEndAt = nil
            player?.pause()
            isPlaying = false
        } else {
            sleepRemainingSec = left
        }
    }

    // MARK: - Будильник (запуск по тапу на уведомление)

    func playAlarm(stationNid: String, volume: Float, fadeIn: Bool) {
        let stations = RadioRepository.shared.stations
        guard !stations.isEmpty else {
            // Станции ещё не загружены — запустим по их прибытию
            pendingAlarm = (stationNid, volume, fadeIn)
            return
        }
        let index = stations.firstIndex(where: { $0.nid == stationNid }) ?? 0
        play(index: index, stations: stations)
        applyAlarmVolume(volume, fadeIn: fadeIn)
    }

    /// Вызывается репозиторием после загрузки станций.
    func runPendingAlarmIfAny(stations: [Station]) {
        guard let pending = pendingAlarm else { return }
        pendingAlarm = nil
        let index = stations.firstIndex(where: { $0.nid == pending.nid }) ?? 0
        play(index: index, stations: stations)
        applyAlarmVolume(pending.volume, fadeIn: pending.fadeIn)
    }

    private func applyAlarmVolume(_ target: Float, fadeIn: Bool) {
        volumeRampTimer?.invalidate()
        volumeRampTimer = nil
        guard let player else { return }
        if fadeIn {
            player.volume = 0
            var step = 0
            let steps = 45
            volumeRampTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
                guard let self, let player = self.player else {
                    timer.invalidate()
                    return
                }
                step += 1
                player.volume = target * Float(step) / Float(steps)
                if step >= steps {
                    timer.invalidate()
                    self.volumeRampTimer = nil
                }
            }
        } else {
            player.volume = target
        }
    }
}
