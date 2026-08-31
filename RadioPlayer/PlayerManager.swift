import Foundation
import AVFoundation

/// Единая точка управления воспроизведением (зеркало PlayerManager из Android-версии).
@MainActor
final class PlayerManager: ObservableObject {
    static let shared = PlayerManager()

    @Published var stationIndex = 0
    @Published var regionIndex = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    @Published var highQuality: Bool {
        didSet { UserDefaults.standard.set(highQuality, forKey: "highQuality") }
    }

    private var player: AVPlayer?
    private var statusObserver: NSKeyValueObservation?
    private var timeControlObserver: NSKeyValueObservation?

    private init() {
        highQuality = UserDefaults.standard.object(forKey: "highQuality") as? Bool ?? true
        regionIndex = UserDefaults.standard.integer(forKey: "regionIndex")
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    var currentStation: Station? {
        let stations = RadioRepository.shared.stations
        return stations[safe: stationIndex]
    }

    func play(index: Int, stations: [Station]) {
        guard let station = stations[safe: index] else { return }
        stationIndex = index
        UserDefaults.standard.set(station.nid, forKey: "lastStationNid")
        let urlString = station.streamUrl(hq: highQuality, regionIndex: regionIndex)
        guard !urlString.isEmpty, let url = URL(string: urlString) else { return }

        isBuffering = true
        player?.pause()
        statusObserver = nil
        timeControlObserver = nil

        let player = AVPlayer(url: url)
        self.player = player

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
}
