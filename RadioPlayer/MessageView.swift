import SwiftUI

/// Форма «Написать в прямой эфир»: имя, телефон, сообщение -> токен -> PBKDF2 -> POST.
struct MessageView: View {
    let station: Station
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var phone = ""
    @State private var message = ""
    @State private var sending = false
    @State private var sent = false
    @State private var error: String?

    var body: some View {
        ZStack {
            Color.omgBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Белая шапка с логотипом
                    ZStack {
                        Color.white
                        StationLogo(station: station)
                            .padding(32)
                    }
                    .frame(height: 200)

                    if sent {
                        VStack(spacing: 20) {
                            Text("Ваше сообщение успешно отправлено")
                                .font(.title2).fontWeight(.bold)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 72))
                                .foregroundStyle(.white)
                            Button("Закрыть") { dismiss() }
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Отправить сообщение")
                                .font(.title2).fontWeight(.bold)
                                .foregroundStyle(.white)

                            field("Имя", text: $name)
                            field("Телефон", text: $phone, keyboard: .phonePad)
                            ZStack(alignment: .topLeading) {
                                if message.isEmpty {
                                    Text("Сообщение")
                                        .foregroundStyle(.white.opacity(0.6))
                                        .padding(.top, 14).padding(.leading, 16)
                                }
                                TextEditor(text: $message)
                                    .frame(height: 140)
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(0.5))
                                    )
                                    .foregroundStyle(.white)
                            }

                            if let error {
                                Text(error)
                                    .foregroundStyle(Color(hex: 0xFFFF8A80))
                                    .font(.footnote)
                            }

                            if sending {
                                HStack {
                                    Spacer()
                                    ProgressView().tint(.white)
                                    Spacer()
                                }
                            } else {
                                Button {
                                    send()
                                } label: {
                                    HStack {
                                        Text("Отправить")
                                        Spacer()
                                        Image(systemName: "envelope")
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .frame(height: 48)
                                    .background(Color(white: 1, opacity: 0.2))
                                    .clipShape(Capsule())
                                }
                            }

                            Text("Отправляя сообщение, вы соглашаетесь с обработкой персональных данных, соглашение доступно по ссылке: omg56.ru/docs/soglasie_omg_radio.pdf")
                                .font(.caption)
                                .fontWeight(.light)
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        .padding(20)
                    }
                }
            }
        }
    }

    private func field(_ placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .padding(12)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.5))
            )
            .foregroundStyle(.white)
    }

    private func send() {
        guard !name.isEmpty, !phone.isEmpty, !message.isEmpty else {
            error = "Необходимо заполнить все поля"
            return
        }
        error = nil
        sending = true
        Task {
            do {
                try await RadioRepository.shared.sendMessage(
                    station: station, name: name, phone: phone, message: message
                )
                sent = true
            } catch {
                self.error = "Произошла ошибка. Повторите попытку позже."
            }
            sending = false
        }
    }
}
