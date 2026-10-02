import CarPlay
import UIKit

/// Сцена CarPlay: список станций с логотипами, тап включает эфир,
/// Now Playing — из MPNowPlayingInfoCenter (настраивается в PlayerManager).
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private var interfaceController: CPInterfaceController?
    private var stationsObserver: NSObjectProtocol?
    /// Кэш логотипов для CarPlay-элементов (локальный ресурс или скачанный)
    private var logoCache: [String: UIImage] = [:]

    // MARK: - Подключение / отключение CarPlay

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        rebuildTemplate()
        preloadRemoteLogos()

        // Станции могли быть не загружены в момент подключения — пересобираем
        // шаблон, когда репозиторий их получит
        stationsObserver = NotificationCenter.default.addObserver(
            forName: RadioRepository.stationsDidLoadNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuildTemplate()
            self?.preloadRemoteLogos()
        }
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        if let observer = stationsObserver {
            NotificationCenter.default.removeObserver(observer)
            stationsObserver = nil
        }
    }

    // MARK: - Шаблон списка станций

    private func rebuildTemplate() {
        guard let interfaceController else { return }
        let stations = RadioRepository.shared.stations
        guard !stations.isEmpty else { return }

        let items: [CPListItem] = stations.indices.map { i in
            let station = stations[i]
            let item = CPListItem(
                text: station.title,
                detailText: station.freqLabel(regionIndex: 0),
                image: logoImage(for: station)
            )
            item.handler = { [weak self] _, completion in
                Task { @MainActor in
                    PlayerManager.shared.play(index: i, stations: RadioRepository.shared.stations)
                    completion()
                }
                self?.interfaceController?.pushTemplate(
                    CPNowPlayingTemplate.shared,
                    animated: true,
                    completion: nil
                )
            }
            return item
        }

        let section = CPListSection(items: items)
        let template = CPListTemplate(title: "OMG Radio", sections: [section])
        interfaceController.setRootTemplate(template, animated: false, completion: nil)
    }

    // MARK: - Логотипы

    private func logoImage(for station: Station) -> UIImage? {
        if let cached = logoCache[station.nid] { return cached }
        if let local = station.localLogo, let image = UIImage(named: local) {
            logoCache[station.nid] = image
            return image
        }
        return nil
    }

    /// Удалённые логотипы — в фоне, затем пересборка шаблона
    private func preloadRemoteLogos() {
        let stations = RadioRepository.shared.stations
        for station in stations where logoCache[station.nid] == nil {
            guard station.localLogo == nil, !station.logo.isEmpty,
                  let url = URL(string: station.logo) else { continue }
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let data, let image = UIImage(data: data) else { return }
                DispatchQueue.main.async {
                    self?.logoCache[station.nid] = image
                    self?.rebuildTemplate()
                }
            }.resume()
        }
    }
}
