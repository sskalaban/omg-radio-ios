import SwiftUI

/// Диалог «Таймер сна»: 15/30/60 минут + выключить (как в Android-версии).
struct SleepTimerDialog: View {
    let remainingSec: Int
    let onSelect: (Int) -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 0) {
                Text("Таймер сна")
                    .font(.title3).fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.top, 20)
                    .padding(.bottom, 8)

                ForEach([(15, "15 минут"), (30, "30 минут"), (60, "60 минут")], id: \.0) { minutes, label in
                    Button {
                        onSelect(minutes)
                    } label: {
                        Text(label)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                    }
                }

                if remainingSec > 0 {
                    Button {
                        onSelect(0)
                    } label: {
                        Text("Выключить таймер")
                            .foregroundStyle(Color.omgPink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                    }
                }

                Button("ОТМЕНА", action: onClose)
                    .foregroundStyle(Color.omgPink)
                    .padding(.vertical, 14)
            }
            .background(Color(hex: 0xFF2A2D4D))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 48)
        }
    }
}

/// Диалог будильника (зеркало Android AlarmDialog): время, дни недели,
/// станция, громкость, нарастающий звук.
struct AlarmDialog: View {
    let stations: [Station]
    let onClose: () -> Void

    @ObservedObject private var alarm = AlarmStore.shared
    @State private var minutesOfDay: Int = 0
    @State private var days: Set<Int> = []
    @State private var stationNid: String = ""
    @State private var volume: Float = 0.7
    @State private var fadeIn = true
    @State private var showStationDialog = false

    private let dayNames = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    /// Текст «Сработает сегодня/завтра/в <день> в HH:MM» для текущего состояния диалога.
    private var fireLabel: String {
        if days.isEmpty { return "Выберите хотя бы один день" }
        let config = AlarmConfig(enabled: true, minutesOfDay: minutesOfDay, days: days)
        if config.isTodaySelectedButPassed {
            return "Время сегодня уже прошло — сработает сразу после сохранения"
        }
        // Ближайший выбранный день со временем в будущем
        let cal = Calendar.current
        let now = Date()
        let nowMinutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        for add in 0...7 {
            guard let date = cal.date(byAdding: .day, value: add, to: now) else { continue }
            let appleWeekday = cal.component(.weekday, from: date)
            let mappedDay = appleWeekday == 1 ? 7 : appleWeekday - 1
            let isFuture = add > 0 || minutesOfDay > nowMinutes
            if days.contains(mappedDay), isFuture {
                let dayLabel: String
                switch add {
                case 0: dayLabel = "сегодня"
                case 1: dayLabel = "завтра"
                default: dayLabel = dayNames[mappedDay - 1].lowercased()
                }
                return String(format: "Сработает %@ в %02d:%02d", dayLabel, minutesOfDay / 60, minutesOfDay % 60)
            }
        }
        return ""
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            ScrollView {
                VStack(spacing: 16) {
                    Text("Будильник")
                        .font(.title3).fontWeight(.bold)
                        .foregroundStyle(.white)

                    // Время: вертикальные степперы
                    HStack(spacing: 16) {
                        TimeStepper(
                            value: String(format: "%02d", minutesOfDay / 60),
                            onUp: { step(hours: 1) },
                            onDown: { step(hours: -1) }
                        )
                        Text(":")
                            .font(.title).fontWeight(.bold)
                            .foregroundStyle(.white)
                        TimeStepper(
                            value: String(format: "%02d", minutesOfDay % 60),
                            onUp: { step(minutes: 5) },
                            onDown: { step(minutes: -5) }
                        )
                    }

                    // Дни недели
                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { i in
                            let day = i + 1
                            let selected = days.contains(day)
                            Button {
                                if selected { days.remove(day) } else { days.insert(day) }
                            } label: {
                                Text(dayNames[i])
                                    .font(.caption)
                                    .frame(width: 36, height: 36)
                                    .background(selected ? Color.omgPink : Color.clear)
                                    .foregroundStyle(.white)
                                    .clipShape(Circle())
                            }
                        }
                    }

                    // Подсказка, когда сработает (как в Android-версии)
                    Text(fireLabel)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)

                    // Станция — одной строкой, список открывается по тапу
                    // (как в Android-версии; развёрнутый список обрезал диалог)
                    HStack {
                        Text("Станция: \(stations.first { $0.nid == stationNid }?.title ?? "текущая")")
                            .foregroundStyle(.white)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onTapGesture { showStationDialog = true }
                    .confirmationDialog("Станция", isPresented: $showStationDialog, titleVisibility: .hidden) {
                        ForEach(stations) { station in
                            Button(station.title) {
                                stationNid = station.nid
                            }
                        }
                        Button("Отмена", role: .cancel) {}
                    }

                    // Громкость
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Громкость: \(Int(volume * 100))%")
                            .foregroundStyle(.white)
                        Slider(value: $volume, in: 0.05...1)
                            .tint(.omgPink)
                    }

                    // Нарастающий звук
                    Toggle("Нарастающий звук", isOn: $fadeIn)
                        .foregroundStyle(.white)
                        .tint(.omgPink)

                    Text("В назначенное время придёт уведомление — по тапу запустится станция")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)

                    HStack {
                        if alarm.config.enabled {
                            Button("ВЫКЛЮЧИТЬ") {
                                alarm.saveAndSchedule(alarm.config.copy(enabled: false))
                                onClose()
                            }
                            .foregroundStyle(Color.omgPink)
                        }
                        Spacer()
                        Button("ОТМЕНА", action: onClose)
                            .foregroundStyle(.white.opacity(0.7))
                        Button("СОХРАНИТЬ") {
                            var config = alarm.config
                            config.enabled = true
                            config.minutesOfDay = minutesOfDay
                            config.days = days
                            config.stationNid = stationNid
                            config.volume = volume
                            config.fadeIn = fadeIn
                            alarm.saveAndSchedule(config)
                            onClose()
                        }
                        .fontWeight(.bold)
                        .foregroundStyle(Color.omgPink)
                    }
                }
                .padding(20)
            }
            .frame(maxHeight: 560)
            .background(Color(hex: 0xFF2A2D4D))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 32)
        }
        .onAppear {
            let c = alarm.config
            minutesOfDay = c.minutesOfDay
            days = c.days
            stationNid = c.stationNid
            volume = c.volume
            fadeIn = c.fadeIn
            if stationNid.isEmpty, let first = stations.first {
                stationNid = first.nid
            }
        }
    }

    private func step(hours: Int = 0, minutes: Int = 0) {
        minutesOfDay = ((minutesOfDay + hours * 60 + minutes) % 1440 + 1440) % 1440
    }
}

/// Вертикальный степпер: + над значением, − под ним (как в Android-версии).
private struct TimeStepper: View {
    let value: String
    let onUp: () -> Void
    let onDown: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            StepButton(label: "+", action: onUp)
            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
            StepButton(label: "−", action: onDown)
        }
    }
}

private struct StepButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.headline).fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Color.omgPink.opacity(0.25))
                .clipShape(Circle())
        }
    }
}

private extension AlarmConfig {
    func copy(enabled: Bool) -> AlarmConfig {
        var c = self
        c.enabled = enabled
        return c
    }
}
