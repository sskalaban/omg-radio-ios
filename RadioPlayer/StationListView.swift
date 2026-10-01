import SwiftUI

/// Главный экран: шапка OMG + фильтр города + сетка станций (плитка на каждый
/// город вещания) / новости + мини-плеер с тенью + нижнее меню.
/// Зеркало Android StationListScreen + BottomMenu.
struct StationListView: View {
    @ObservedObject private var repo = RadioRepository.shared
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var favorites = Favorites.shared
    // Вкладка: 0 = Станции, 1 = Новости
    @State private var mainTab = 0
    @State private var showPlayer = false
    @State private var showMessage = false
    @State private var showCityMenu = false
    @State private var cityId: String = UserDefaults.standard.string(forKey: "cityFilter") ?? ""

    /// Города из региональных вариантов станций
    private var regions: [StationRegion] {
        var seen = Set<String>()
        var result: [StationRegion] = []
        for region in repo.stations.flatMap({ $0.regions }) where !region.regionId.isEmpty {
            if seen.insert(region.regionId).inserted {
                result.append(region)
            }
        }
        return result.sorted { $0.regionId < $1.regionId }
    }

    private var cityName: String {
        regions.first { $0.regionId == cityId }?.name ?? "Все города"
    }

    /// Элементы сетки: (индекс станции, индекс региона у станции).
    /// При «Все города» каждая станция — плиткой на каждый город вещания.
    private var tiles: [(index: Int, regionIndex: Int)] {
        var list: [(Int, Int)] = []
        for (i, s) in repo.stations.enumerated() {
            if !cityId.isEmpty {
                if let ri = s.regions.firstIndex(where: { $0.regionId == cityId }) {
                    list.append((i, ri))
                } else if s.regions.isEmpty {
                    list.append((i, 0))
                }
            } else if s.regions.isEmpty {
                list.append((i, 0))
            } else {
                for ri in s.regions.indices {
                    list.append((i, ri))
                }
            }
        }
        // Избранные вверху, порядок внутри групп — как в API
        return list.sorted { a, b in
            let fa = favorites.contains(repo.stations[a.0].nid)
            let fb = favorites.contains(repo.stations[b.0].nid)
            return fa && !fb
        }
    }

    var body: some View {
        ZStack {
            Color.omgBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Шапка: логотип OMG по центру
                ZStack {
                    Image("g12")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 40)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 80)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.newsGradient)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                )

                Group {
                    if repo.isLoading && repo.stations.isEmpty {
                        Spacer()
                        ProgressView().tint(.white)
                        Spacer()
                    } else if repo.isError && repo.stations.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Text("Нет подключения к интернету")
                                .foregroundStyle(.white)
                            Button("Повторить") {
                                Task { await repo.load(force: true) }
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32).padding(.vertical, 10)
                            .background(Color(white: 0.2))
                            .clipShape(Capsule())
                        }
                        Spacer()
                    } else if mainTab == 1 {
                        NewsListView(news: repo.news)
                    } else {
                        stationGrid
                    }
                }
                .refreshable { await repo.load(force: true) }

                // Резерв под мини-плеер
                if !repo.stations.isEmpty {
                    Spacer().frame(height: 72)
                }

                // Нижнее меню: Станции / Новости / Написать
                bottomMenu
            }

            // Мини-плеер с тенью, над меню
            if let station = player.currentStation, !repo.stations.isEmpty {
                VStack(spacing: 0) {
                    Spacer()
                    MiniPlayerView(station: station)
                        .shadow(radius: 12)
                        .onTapGesture { showPlayer = true }
                        .padding(.bottom, 60)
                }
            }
        }
        .fullScreenCover(isPresented: $showPlayer) {
            PlayerView()
        }
        .sheet(isPresented: $showMessage) {
            if let station = player.currentStation {
                MessageView(station: station)
            }
        }
        .task {
            await repo.load()
            player.restoreSelection(stations: repo.stations)
        }
    }

    // MARK: - Нижнее меню

    private var bottomMenu: some View {
        HStack(spacing: 0) {
            menuItem(icon: "radio", label: "Станции", selected: mainTab == 0) {
                mainTab = 0
            }
            menuItem(icon: "newspaper", label: "Новости", selected: mainTab == 1) {
                mainTab = 1
                Task { await repo.refreshNews() }
            }
            menuItem(icon: "envelope", label: "Написать", selected: false) {
                showMessage = true
            }
        }
        .frame(height: 60)
        .background(Color.omgToolbarDark)
    }

    private func menuItem(icon: String, label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 11))
            }
            .foregroundStyle(selected ? Color.omgPink : Color.white.opacity(0.6))
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Сетка станций

    private var stationGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                ],
                spacing: 8
            ) {
                // Кнопка выбора города — на всю ширину
                cityPicker
                    .gridCellColumns(3)

                ForEach(tiles, id: \.self) { tile in
                    let station = repo.stations[tile.index]
                    tileView(station: station, index: tile.index, regionIndex: tile.regionIndex)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)
        }
    }

    private var cityPicker: some View {
        HStack {
            Button {
                showCityMenu = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "mappin")
                        .font(.system(size: 14))
                    Text(cityName)
                        .font(.subheadline).fontWeight(.medium)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.omgTile)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            Spacer()
        }
        .padding(.bottom, 2)
        .confirmationDialog("Город", isPresented: $showCityMenu, titleVisibility: .hidden) {
            Button("Все города") {
                cityId = ""
                UserDefaults.standard.set("", forKey: "cityFilter")
            }
            ForEach(regions) { region in
                Button(region.name) {
                    cityId = region.regionId
                    UserDefaults.standard.set(region.regionId, forKey: "cityFilter")
                }
            }
            Button("Отмена", role: .cancel) {}
        }
    }

    private func tileView(station: Station, index: Int, regionIndex: Int) -> some View {
        let isFavorite = favorites.contains(station.nid)
        let isPlaying = player.isPlaying && player.stationIndex == index && player.regionIndex == regionIndex
        let cityLabel = station.regions[safe: regionIndex]?.name ?? ""

        return VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Circle().fill(.white)
                    StationLogo(station: station)
                        .frame(width: 60, height: 60)
                }
                .frame(width: 84, height: 84)
                .frame(maxWidth: .infinity)

                if isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: 0xFFFFD54F))
                }
            }

            Text(station.title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.top, 8)

            Text(station.freqLabel(regionIndex: regionIndex))
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
                .padding(.top, 2)

            if !cityLabel.isEmpty {
                Text(cityLabel)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
                    .padding(.top, 1)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.omgTile)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isPlaying ? Color.omgPink : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            tapTile(index: index, regionIndex: regionIndex)
        }
        .onLongPressGesture {
            favorites.toggle(station.nid)
        }
    }

    /// Тап по плитке: включаем эфир станции с регионом плитки;
    /// тап по играющей — пауза. Без переходов (как в Android-версии).
    private func tapTile(index: Int, regionIndex: Int) {
        let stations = repo.stations
        let wasPlayingThis = player.isPlaying && player.stationIndex == index
        player.selectStation(index, stations: stations)
        if let st = stations[safe: index], st.regions.indices.contains(regionIndex) {
            player.setRegionSilent(regionIndex)
        }
        if wasPlayingThis {
            player.toggle(stations: stations)
        } else {
            player.play(index: index, stations: stations)
        }
    }
}

/// Мини-плеер: градиент, круглый логотип, название, prev/play/next.
struct MiniPlayerView: View {
    let station: Station
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var repo = RadioRepository.shared

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(.white)
                StationLogo(station: station)
                    .frame(width: 44, height: 44)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(station.title)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                let sub = player.trackTitle ?? station.freqLabel(regionIndex: player.regionIndex)
                if !sub.isEmpty {
                    Text(sub)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
            Spacer()
            Group {
                Button { player.prev(stations: repo.stations) } label: {
                    Image(systemName: "backward.end.fill")
                }
                Button { player.toggle(stations: repo.stations) } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                }
                Button { player.next(stations: repo.stations) } label: {
                    Image(systemName: "forward.end.fill")
                }
            }
            .foregroundStyle(.white)
            .font(.title3)
        }
        .padding(.horizontal, 16)
        .frame(height: 72)
        .background(Color.playerGradient)
    }
}
