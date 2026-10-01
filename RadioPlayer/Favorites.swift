import Foundation

/// Избранные станции (зеркало Android Favorites): хранится в UserDefaults,
/// закрепляется вверху списка, переключается долгим тапом по плитке.
final class Favorites: ObservableObject {
    static let shared = Favorites()

    @Published private(set) var nids: Set<String>

    private let key = "omg_favorites"

    private init() {
        nids = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    func contains(_ nid: String) -> Bool { nids.contains(nid) }

    func toggle(_ nid: String) {
        if nids.contains(nid) {
            nids.remove(nid)
        } else {
            nids.insert(nid)
        }
        UserDefaults.standard.set(Array(nids), forKey: key)
    }
}
