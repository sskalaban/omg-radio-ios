import SwiftUI

/// Полноэкранный плеер: фон, карусель логотипов с белыми кругами,
/// выбор города в правом верхнем углу, управление воспроизведением.
struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var repo = RadioRepository.shared
    @ObservedObject private var player = PlayerManager.shared

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Фон
                Image("player_bg")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                // Кнопка «Скрыть»
                VStack {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.compact.down")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .padding(12)
                        }
                        Spacer()
                    }
                    Spacer()
                }

                // Кнопка выбора города (правый верхний угол)
                if let station = player.currentStation, station.regions.count > 1 {
                    VStack {
                        HStack {
                            Spacer()
                            Menu {
                                ForEach(station.regions.indices, id: \.self) { i in
                                    let r = station.regions[i]
                                    Button("\(r.name) — \(r.wave) FM") {
                                        player.setRegion(i, stations: repo.stations)
                                    }
                                }
                            } label: {
                                Text(station.regionName(regionIndex: player.regionIndex))
                                    .font(.subheadline).fontWeight(.medium)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(Color(white: 1, opacity: 0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .padding(.trailing, 16)
                        }
                        .padding(.top, 40)
                        Spacer()
                    }
                }

                VStack(spacing: 0) {
                    // Карусель логотипов (белые круги)
                    LogoCarousel(
                        stations: repo.stations,
                        selection: Binding(
                            get: { player.stationIndex },
                            set: { newIndex in
                                if player.isPlaying {
                                    player.play(index: newIndex, stations: repo.stations)
                                } else {
                                    player.stationIndex = newIndex
                                }
                            }
                        )
                    )
                    .frame(height: geo.size.height * 0.30)
                    .padding(.top, geo.size.height * 0.10)

                    Spacer()
                }
                .ignoresSafeArea()

                // Нижняя панель с управлением
                VStack {
                    Spacer()
                    bottomPanel(geo: geo)
                }
                .ignoresSafeArea()
            }
        }
        .background(Color.omgBackground)
    }

    private func bottomPanel(geo: GeometryProxy) -> some View {
        let station = player.currentStation
        return VStack(spacing: 12) {
            Text(station?.title ?? "")
                .font(.title).fontWeight(.bold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            if let sub = station?.freqLabel(player.regionIndex), !sub.isEmpty {
                Text(sub)
                    .font(.title2).fontWeight(.light)
                    .foregroundStyle(.white)
            }

            // prev / play / next
            HStack(spacing: 34) {
                Button { player.prev(stations: repo.stations) } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.title)
                }
                Button { player.toggle(stations: repo.stations) } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 84))
                }
                Button { player.next(stations: repo.stations) } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.title)
                }
            }
            .foregroundStyle(.white)
            .padding(.top, 8)

            if player.isBuffering {
                ProgressView().tint(.white)
            }
        }
        .padding(.bottom, geo.size.height * 0.12)
        .frame(maxWidth: .infinity)
        .background(
            Color.playerGradient
                .opacity(0.95)
                .clipShape(BottomPanelShape())
                .ignoresSafeArea()
        )
    }
}

/// Карусель логотипов страницами с белыми круглыми подложками.
private struct LogoCarousel: View {
    let stations: [Station]
    @Binding var selection: Int

    var body: some View {
        TabView(selection: $selection) {
            ForEach(stations.indices, id: \.self) { i in
                ZStack {
                    Circle().fill(.white)
                    StationLogo(station: stations[i])
                        .padding(24)
                }
                .padding(28)
                .tag(i)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
}

/// Форма нижней панели плеера: прямоугольник с дугой сверху (упрощение path1).
private struct BottomPanelShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let curveHeight: CGFloat = 80
        path.move(to: CGPoint(x: 0, y: curveHeight))
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: curveHeight),
            control: CGPoint(x: rect.width / 2, y: -curveHeight)
        )
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}
