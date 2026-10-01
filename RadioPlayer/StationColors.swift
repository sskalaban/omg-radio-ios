import SwiftUI
import UIKit

/// Доминантный цвет логотипа станции для градиента фона плеера
/// (зеркало Android rememberStationColors / Palette). Кэшируется по nid.
final class StationColors {
    static let shared = StationColors()

    private var cache: [String: Color] = [:]
    private var loading: Set<String> = []

    private init() {}

    /// Цвет из кэша; если ещё не вычислялся — дефолтный розовый и запуск вычисления.
    func color(for station: Station, completion: @escaping (Color) -> Void) {
        if let cached = cache[station.nid] {
            completion(cached)
            return
        }
        guard !loading.contains(station.nid) else { return }
        loading.insert(station.nid)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let computed = self?.computeColor(for: station)
            DispatchQueue.main.async {
                self?.loading.remove(station.nid)
                if let computed {
                    self?.cache[station.nid] = computed
                    completion(computed)
                }
            }
        }
    }

    /// Насыщенный средний цвет логотипа (белёсые пиксели отбрасываем —
    /// логотипы на белом фоне, иначе градиент «выбеливается»).
    private func computeColor(for station: Station) -> Color? {
        var image: UIImage? = nil
        if let local = station.localLogo {
            image = UIImage(named: local)
        }
        if image == nil, !station.logo.isEmpty, let url = URL(string: station.logo),
           let data = try? Data(contentsOf: url) {
            image = UIImage(data: data)
        }
        guard let cgImage = image?.cgImage else { return nil }

        let size = 24
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        guard let context = CGContext(
            data: &pixels,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))

        var rSum = 0.0, gSum = 0.0, bSum = 0.0, weightSum = 0.0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let r = Double(pixels[i]), g = Double(pixels[i + 1]), b = Double(pixels[i + 2])
            // Пропускаем почти белые и почти чёрные
            if r > 235, g > 235, b > 235 { continue }
            if r < 25, g < 25, b < 25 { continue }
            let maxc = max(r, max(g, b)), minc = min(r, min(g, b))
            let saturation = maxc > 0 ? (maxc - minc) / maxc : 0
            // Вес = насыщенность: цветные пиксели важнее серых
            let weight = 0.2 + saturation
            rSum += r * weight
            gSum += g * weight
            bSum += b * weight
            weightSum += weight
        }
        guard weightSum > 0 else { return nil }
        return Color(
            .sRGB,
            red: rSum / weightSum / 255,
            green: gSum / weightSum / 255,
            blue: bSum / weightSum / 255,
            opacity: 1
        )
    }
}
