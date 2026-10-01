import SwiftUI

// MARK: - Цвета фирменной темы (как в Android-версии)

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    static let omgBackground = Color(hex: 0xFF0C1027)
    static let omgToolbarDark = Color(hex: 0xFF070A19)
    static let omgTile = Color(hex: 0xFF232847)
    static let omgPink = Color(hex: 0xFFE5097F)
    static let omgBlue = Color(hex: 0xFF3A3C8D)
    static let omgNewsStart = Color(hex: 0xFF121345)
    static let omgNewsEnd = Color(hex: 0xFF8E044E)

    static let playerGradient = LinearGradient(
        colors: [omgPink, omgBlue],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let newsGradient = LinearGradient(
        colors: [omgNewsStart, omgNewsEnd],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - Логотип станции: локальный ресурс, иначе — удалённый с заглушкой

struct StationLogo: View {
    let station: Station
    var body: some View {
        if let local = station.localLogo, UIImage(named: local) != nil {
            Image(local)
                .resizable()
                .scaledToFit()
        } else {
            RemoteImage(url: station.logo, placeholderText: station.title)
        }
    }
}

// MARK: - Удалённая картинка с заглушкой «градиент + название»

struct RemoteImage: View {
    let url: String
    var placeholderText: String = ""
    var contentMode: ContentMode = .fill

    /// URL с кириллицей и пробелами (например, «ФОТОБАНК 2026») — кодируем аккуратно
    private var safeURL: URL? {
        if let u = URL(string: url) { return u }
        return URL(string: url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url)
    }

    var body: some View {
        AsyncImage(url: safeURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: contentMode)
            default:
                ZStack {
                    Color.playerGradient
                    if !placeholderText.isEmpty {
                        Text(placeholderText)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(8)
                    }
                }
            }
        }
    }
}
