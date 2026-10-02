import Foundation

/// Загрузка станций/новостей с сервера и отправка сообщений в эфир.
@MainActor
final class RadioRepository: ObservableObject {
    static let shared = RadioRepository()

    /// Шлётся после каждой успешной загрузки станций (для CarPlay-шаблона).
    static let stationsDidLoadNotification = Notification.Name("omg.stationsDidLoad")

    @Published private(set) var stations: [Station] = []
    @Published private(set) var news: [NewsItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isError = false

    private let stationsURL = URL(string: "https://dev.omg56.ru/omgserver")!
    private let newsURL = URL(string: "https://dev.omg56.ru/omgprooren")!
    private let tokenURL = URL(string: "https://serv.omg56.ru/rest/wa?action=3")!
    private let messageURL = URL(string: "https://serv.omg56.ru/rest/wa")!

    private var loaded = false

    /// Загрузка при старте. Список станций всегда заменяется актуальным:
    /// новые станции появляются, пропавшие исчезают.
    func load(force: Bool = false) async {
        if loaded && !force { return }
        isLoading = true
        isError = false
        defer { isLoading = false }
        do {
            async let stationsTask = fetchStations()
            async let newsTask = fetchNews()
            let (s, n) = try await (stationsTask, newsTask)
            stations = s
            news = n
            loaded = true
            NotificationCenter.default.post(name: Self.stationsDidLoadNotification, object: nil)
            PlayerManager.shared.runPendingAlarmIfAny(stations: s)
        } catch {
            print("RadioRepository load failed: \(error)")
            isError = true
        }
    }

    /// Обновление новостей при входе в раздел.
    func refreshNews() async {
        if let n = try? await fetchNews() {
            news = n
        }
    }

    private func fetchStations() async throws -> [Station] {
        let (data, _) = try await URLSession.shared.data(from: stationsURL)
        let response = try JSONDecoder().decode(ServerResponse.self, from: data)
        let names = Dictionary(uniqueKeysWithValues: response.regions.map {
            ($0.region_id.trimmingCharacters(in: .whitespaces), $0.region_name.trimmingCharacters(in: .whitespaces))
        })
        return response.radios.map { $0.toStation(regionNames: names) }.filter { $0.hasStream }
    }

    private func fetchNews() async throws -> [NewsItem] {
        let (data, _) = try await URLSession.shared.data(from: newsURL)
        return try JSONDecoder().decode(NewsResponse.self, from: data).news
    }

    /// Отправка сообщения в прямой эфир: токен -> PBKDF2-хэш -> POST (как в Android-версии).
    func sendMessage(station: Station, name: String, phone: String, message: String) async throws {
        let (tokenData, _) = try await URLSession.shared.data(from: tokenURL)
        let token = try JSONDecoder().decode(TokenResponse.self, from: tokenData).data
        let hash = Crypto.pbkdf2Hex(token: token)

        let nidInt = Int(station.nid) ?? 0
        let body: [String: Any] = [
            "stationID": nidInt,
            "name": name.trimmingCharacters(in: .whitespaces),
            "message": message.trimmingCharacters(in: .whitespaces),
            "phone": phone.trimmingCharacters(in: .whitespaces),
            "token": hash,
        ]
        var request = URLRequest(url: messageURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
