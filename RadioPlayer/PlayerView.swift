import SwiftUI

/// Полноэкранный плеер: фон, карусель логотипов с белыми кругами,
/// выбор города в правом верхнем углу, управление воспроизведением.
struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var repo = RadioRepository.shared
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var alarm = AlarmStore.shared
    @State private var showRegionMenu = false
    @State private var showAlarmDialog = false
    @State private var showSleepDialog = false

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
                            Button {
                                showRegionMenu.toggle()
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
                    .zIndex(10)
                }

                // Выпадающий список городов (кастомный оверлей вместо Menu — надёжно везде)
                if showRegionMenu, let station = player.currentStation {
                    VStack {
                        HStack {
                            Spacer()
                            VStack(spacing: 0) {
                                ForEach(station.regions.indices, id: \.self) { i in
                                    let r = station.regions[i]
                                    Button {
                                        player.setRegion(i, stations: repo.stations)
                                        showRegionMenu = false
                                    } label: {
                                        Text("\(r.name) — \(r.wave) FM")
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                    }
                                }
                            }
                            .background(Color.black.opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.trailing, 16)
                        }
                        .padding(.top, 92)
                        Spacer()
                    }
                    .zIndex(20)
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
                    .frame(height: geo.size.height * 0.34)
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

                // Диалог таймера сна
                if showSleepDialog {
                    SleepTimerDialog(
                        remainingSec: player.sleepRemainingSec,
                        onSelect: { minutes in
                            player.setSleepTimer(minutes: minutes)
                            showSleepDialog = false
                        },
                        onClose: { showSleepDialog = false }
                    )
                    .zIndex(30)
                }

                // Диалог будильника
                if showAlarmDialog {
                    AlarmDialog(
                        stations: repo.stations,
                        onClose: { showAlarmDialog = false }
                    )
                    .zIndex(31)
                }
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

            if let sub = station?.freqLabel(regionIndex: player.regionIndex), !sub.isEmpty {
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

            // Действия: будильник / таймер сна
            HStack(spacing: 64) {
                Button { showAlarmDialog = true } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "alarm")
                            .font(.title2)
                            .foregroundStyle(alarm.config.enabled ? Color.yellow : .white)
                        Text(alarm.config.enabled ? alarm.config.timeLabel : " ")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                Button { showSleepDialog = true } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "timer")
                            .font(.title2)
                            .foregroundStyle(player.sleepRemainingSec > 0 ? Color.yellow : .white)
                        Text(player.sleepRemainingSec > 0 ? "\(player.sleepRemainingSec / 60 + 1)м" : " ")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .padding(.top, 12)

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
                        .padding(14)
                        .scaleEffect(0.7)
                }
                .padding(14)
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
