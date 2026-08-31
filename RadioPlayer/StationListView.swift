import SwiftUI

/// Главный экран: шапка OMG + список станций / новостей + мини-плеер.
struct StationListView: View {
    @ObservedObject private var repo = RadioRepository.shared
    @ObservedObject private var player = PlayerManager.shared
    @State private var newsTab = false
    @State private var showPlayer = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.omgBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Шапка: логотип OMG + переключатель «Новости/Радио»
                    HStack {
                        Image("g12")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 40)
                        Spacer()
                        Button {
                            newsTab.toggle()
                            if newsTab {
                                Task { await repo.refreshNews() }
                            }
                        } label: {
                            Text(newsTab ? "Радио" : "Новости")
                                .font(.title2).fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 24)
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
                        } else if newsTab {
                            NewsListView(news: repo.news)
                        } else {
                            stationList
                        }
                    }
                    .refreshable { await repo.load(force: true) }
                }

                // Мини-плеер
                if let station = player.currentStation, !repo.stations.isEmpty {
                    VStack {
                        Spacer()
                        MiniPlayerView(station: station)
                            .onTapGesture { showPlayer = true }
                    }
                }
            }
            .fullScreenCover(isPresented: $showPlayer) {
                PlayerView()
            }
            .task {
                await repo.load()
                player.restoreSelection(stations: repo.stations)
            }
        }
    }

    private var stationList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(repo.stations.indices, id: \.self) { i in
                    let station = repo.stations[i]
                    NavigationLink {
                        StationDetailView(index: i)
                    } label: {
                        ZStack {
                            Color.white
                            StationLogo(station: station)
                                .padding(24)
                        }
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 76)
        }
    }
}

/// Мини-плеер над нижним краем: градиент, круглый логотип, prev/play/next.
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
                let sub = station.freqLabel(player.regionIndex)
                if !sub.isEmpty {
                    Text(sub)
                        .font(.footnote)
                        .foregroundStyle(.white)
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
