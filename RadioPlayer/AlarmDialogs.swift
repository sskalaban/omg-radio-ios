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

    private let dayNames = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

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

                    // Станция
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Станция")
                            .foregroundStyle(.white.opacity(0.8))
                            .font(.footnote)
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(stations) { station in
                                    Button {
                                        stationNid = station.nid
                                    } label: {
                                        Text(station.title)
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                stationNid == station.nid
                                                    ? Color.omgPink.opacity(0.4)
                                                    : Color.clear
                                            )
                                    }
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.3))
                            )
                        }
                        .frame(maxHeight: 150)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

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
