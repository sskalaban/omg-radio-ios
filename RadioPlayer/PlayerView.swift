import SwiftUI

/// Полноэкранный плеер: тёмный фон с градиентом в цвете станции сверху,
/// зацикленная карусель логотипов с белыми кругами, управление, действия.
/// Отображается как выезжающая панель (drag вверх/вниз — в StationListView).
struct PlayerView: View {
    let onClose: () -> Void
    let onWriteMessage: () -> Void
    let onShowInfo: () -> Void

    @ObservedObject private var repo = RadioRepository.shared
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var alarm = AlarmStore.shared

    @State private var showRegionMenu = false
    @State private var showAlarmDialog = false
    @State private var showSleepDialog = false
    @State private var gradientColor = Color.omgPink

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Тёмный фон + цветной градиент сверху (низ — чёрный)
                Color.omgBackground.ignoresSafeArea()
                LinearGradient(
                    colors: [gradientColor.opacity(0.5), gradientColor.opacity(0)],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.4)
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Карусель логотипов (белые круги, зацикленная)
                    LoopCarousel(
                        stations: repo.stations,
                        selection: player.stationIndex,
                        onSwipeSelect: { index in
                            if player.isPlaying {
                                player.play(index: index, stations: repo.stations)
                            } else {
                                player.selectStation(index, stations: repo.stations)
                            }
                        }
                    )
                    // Ширина карусели ограничена экраном: иначе её контент
                    // шире экрана и сдвигает центрирование всех контролов влево
                    .frame(width: geo.size.width, height: geo.size.height * 0.30)
                    .clipped()
                    .padding(.top, geo.size.height * 0.12)

                    // Название, частота, трек
                    Text(player.currentStation?.title ?? "")
                        .font(.title).fontWeight(.bold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.top, geo.size.height * 0.04)

                    Text(player.currentStation?.freqLabel(regionIndex: player.regionIndex) ?? "")
                        .font(.title2).fontWeight(.light)
                        .foregroundStyle(.white)
                        .padding(.top, 4)

                    if let track = player.trackTitle {
                        Text(track)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                            .padding(.top, 6)
                            .padding(.horizontal, 24)
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
                    .padding(.top, geo.size.height * 0.03)

                    Spacer()

                    // Действия: написать / будильник / таймер сна / инфо
                    HStack {
                        actionIcon("envelope", active: false) { onWriteMessage() }
                        Spacer()
                        actionIconWithLabel(
                            "alarm",
                            active: alarm.config.enabled,
                            label: alarm.config.enabled ? alarm.config.timeLabel : " "
                        ) { showAlarmDialog = true }
                        Spacer()
                        actionIconWithLabel(
                            "timer",
                            active: player.sleepRemainingSec > 0,
                            label: player.sleepRemainingSec > 0 ? "\(player.sleepRemainingSec / 60 + 1)м" : " "
                        ) { showSleepDialog = true }
                        Spacer()
                        actionIcon("info.circle", active: false) { onShowInfo() }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, geo.size.height * 0.04)

                    if player.isBuffering {
                        ProgressView().tint(.white)
                            .padding(.bottom, 8)
                    }
                }
                // Весь столбец — шириной с экран: контролы центрируются по экрану
                .frame(maxWidth: .infinity)

                // Кнопка «Скрыть»
                VStack {
                    HStack {
                        Button(action: onClose) {
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

                // Выпадающий список городов
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
        .onAppear { updateGradient() }
        .onChange(of: player.stationIndex) { _ in updateGradient() }
    }

    /// Градиент в цвете логотипа станции; смена — плавная (как в Android-версии)
    private func updateGradient() {
        guard let station = player.currentStation else { return }
        StationColors.shared.color(for: station) { color in
            withAnimation(.easeInOut(duration: 0.9)) {
                gradientColor = color
            }
        }
    }

    private func actionIcon(_ name: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.title2)
                .foregroundStyle(active ? Color.yellow : .white)
                .frame(width: 32, height: 32)
        }
    }

    private func actionIconWithLabel(_ name: String, active: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: name)
                    .font(.title2)
                    .foregroundStyle(active ? Color.yellow : .white)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(width: 44)
        }
    }
}

/// Зацикленная карусель логотипов: центральная большая, боковые маленькие
/// близко к центру, плавный scale/alpha по смещению (зеркало Android LogoCarousel).
private struct LoopCarousel: View {
    let stations: [Station]
    let selection: Int
    let onSwipeSelect: (Int) -> Void

    @State private var page = 0
    @State private var dragOffset: CGFloat = 0
    @State private var animating = false

    var body: some View {
        GeometryReader { geo in
            let size = stations.count
            if size > 0 {
                let pageW = geo.size.width - 200   // как padding 100dp в Android-версии
                let spacing: CGFloat = 4
                let step = pageW + spacing
                let diameter = min(185, pageW, geo.size.height)

                HStack(spacing: spacing) {
                    ForEach(-2...2, id: \.self) { k in
                        let idx = ((page + k) % size + size) % size
                        let distance = min(1, abs(CGFloat(k) - dragOffset / step))
                        let scale = 1 - 0.48 * distance
                        let alpha = 1 - 0.55 * distance
                        ZStack {
                            Circle().fill(.white)
                            StationLogo(station: stations[idx])
                                .frame(width: diameter * 0.85, height: diameter * 0.85)
                        }
                        .frame(width: diameter, height: diameter)
                        .frame(width: pageW, height: geo.size.height)
                        .scaleEffect(scale)
                        .opacity(alpha)
                    }
                }
                .offset(x: geo.size.width / 2 - 2 * step - pageW / 2 + dragOffset)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            // Только горизонтальные жесты (вертикаль — сворачивание плеера)
                            if abs(value.translation.width) > abs(value.translation.height) {
                                dragOffset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            var stepDirection = 0
                            if value.translation.width < -pageW * 0.2
                                || value.predictedEndTranslation.width < -pageW * 0.6 {
                                stepDirection = 1
                            } else if value.translation.width > pageW * 0.2
                                || value.predictedEndTranslation.width > pageW * 0.6 {
                                stepDirection = -1
                            }
                            withAnimation(.easeOut(duration: 0.25)) {
                                dragOffset = CGFloat(-stepDirection) * step
                            }
                            if stepDirection != 0 {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                                    page += stepDirection
                                    dragOffset = 0
                                    onSwipeSelect(((page % size) + size) % size)
                                }
                            } else {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
                .onAppear {
                    page = selection
                }
                .onChange(of: selection) { newSelection in
                    guard !animating else { return }
                    let current = ((page % size) + size) % size
                    guard newSelection != current else { return }
                    let diff = (newSelection - current + size) % size
                    if diff == 1 || diff == size - 1 {
                        // Соседняя — плавно листаем на один шаг
                        let dir = diff == 1 ? 1 : -1
                        animating = true
                        withAnimation(.easeOut(duration: 0.25)) {
                            dragOffset = CGFloat(-dir) * step
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                            page += dir
                            dragOffset = 0
                            animating = false
                        }
                    } else {
                        // Далёкая станция (тап по плитке) — мгновенно, без промежуточных
                        page = page - ((page % size) + size) % size + newSelection
                        dragOffset = 0
                    }
                }
            }
        }
    }
}
