import SwiftUI

/// Экран станции: белая шапка с логотипом, название, play/pause,
/// «Написать в прямой эфир», описание.
struct StationDetailView: View {
    let index: Int
    @ObservedObject private var repo = RadioRepository.shared
    @ObservedObject private var player = PlayerManager.shared
    @State private var showMessage = false

    private var station: Station? { repo.stations[safe: index] }
    private var isPlayingThis: Bool {
        player.isPlaying && player.stationIndex == index
    }

    var body: some View {
        ZStack {
            Color.omgBackground.ignoresSafeArea()
            if let station {
                ScrollView {
                    VStack(spacing: 0) {
                        // Белая шапка с логотипом
                        ZStack {
                            Color.white
                            StationLogo(station: station)
                                .padding(32)
                        }
                        .frame(height: 228)

                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(station.title)
                                        .font(.title2).fontWeight(.bold)
                                        .foregroundStyle(.white)
                                    let sub = station.freqLabel(regionIndex: player.regionIndex)
                                    if !sub.isEmpty {
                                        Text(sub)
                                            .foregroundStyle(.white)
                                    }
                                }
                                Spacer()
                                Button {
                                    guard station.hasStream else { return }
                                    if isPlayingThis {
                                        player.toggle(stations: repo.stations)
                                    } else {
                                        player.play(index: index, stations: repo.stations)
                                    }
                                } label: {
                                    Image(systemName: isPlayingThis ? "pause.circle" : "play.circle")
                                        .font(.system(size: 56))
                                        .foregroundStyle(.white)
                                }
                            }

                            Button {
                                showMessage = true
                            } label: {
                                HStack {
                                    Text("Написать в прямой эфир")
                                        .font(.body)
                                    Spacer()
                                    Image(systemName: "envelope")
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .frame(height: 48)
                                .background(Color(white: 1, opacity: 0.2))
                                .clipShape(Capsule())
                            }

                            if !station.body.isEmpty {
                                Text(station.body.strippingHtml())
                                    .fontWeight(.light)
                                    .foregroundStyle(.white)
                                    .lineSpacing(4)
                            }
                        }
                        .padding(20)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showMessage) {
            if let station {
                MessageView(station: station)
            }
        }
    }
}
