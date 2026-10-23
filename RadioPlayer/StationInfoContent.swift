import SwiftUI

/// Этаж «О станции» на общей странице плеера: название, «В эфире», избранное
/// и play, описание, соцсети, телефоны, программы. Прокручивается вместе
/// с плеером единым скроллом страницы (зеркало Android StationInfoContent).
struct StationInfoContent: View {
    let station: Station

    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var favorites = Favorites.shared
    @State private var fullDescription = false

    var body: some View {
        let info = StationInfos.forNid(station.nid)

        VStack(spacing: 0) {
            // Название станции и «В эфире»
            Text(station.title)
                .font(.title2).fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.top, 8)

            if player.isPlaying {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: 0xFF3DDC5A))
                        .frame(width: 8, height: 8)
                    Text("В эфире")
                        .font(.footnote)
                        .foregroundStyle(Color(hex: 0xFF3DDC5A))
                }
                .padding(.top, 4)
            }

            // Кнопки: избранное и play/pause
            HStack(spacing: 20) {
                Button {
                    favorites.toggle(station.nid)
                } label: {
                    ZStack {
                        Circle().fill(Color.omgTile)
                        Image(systemName: favorites.contains(station.nid) ? "heart.fill" : "heart")
                            .font(.title3)
                            .foregroundStyle(
                                favorites.contains(station.nid) ? Color.omgPink : .white
                            )
                    }
                    .frame(width: 64, height: 64)
                }

                Button {
                    player.toggle(stations: RadioRepository.shared.stations)
                } label: {
                    ZStack {
                        Circle().fill(Color.omgTile)
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                    .frame(width: 64, height: 64)
                }
            }
            .padding(.top, 20)

            // «О станции 0+»
            HStack(spacing: 8) {
                Text("О станции")
                    .font(.title3).fontWeight(.bold)
                    .foregroundStyle(.white)
                Text("0+")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
            }
            .padding(.top, 28)

            // Описание (обрезано/полное)
            let description = info?.description ?? station.body.strippingHtml()
            if !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineSpacing(6)
                    .lineLimit(fullDescription ? nil : 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)

                if !fullDescription {
                    Button {
                        fullDescription = true
                    } label: {
                        Text("Показать полное описание")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .padding(.top, 6)
                }
            }

            // Соцсети: ВКонтакте, Сайт
            let socials = socialLinks(info: info)
            if !socials.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(socials, id: \.label) { item in
                            if let url = URL(string: item.url) {
                                Link(destination: url) {
                                    HStack(spacing: 8) {
                                        Image(systemName: item.icon)
                                            .font(.subheadline)
                                        Text(item.label)
                                            .font(.subheadline).fontWeight(.medium)
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16).padding(.vertical, 10)
                                    .background(Color.omgTile)
                                    .clipShape(RoundedRectangle(cornerRadius: 22))
                                }
                            }
                        }
                    }
                }
                .padding(.top, 20)
            }

            // Телефоны
            if let info, !info.phones.isEmpty {
                VStack(spacing: 0) {
                    ForEach(info.phones.indices, id: \.self) { i in
                        let (label, number) = info.phones[i]
                        let tel = "tel://" + number.filter { $0.isNumber || $0 == "+" }
                        if let url = URL(string: tel) {
                            Link(destination: url) {
                                HStack(spacing: 12) {
                                    Image(systemName: "phone")
                                        .font(.footnote)
                                        .foregroundStyle(.white.opacity(0.6))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(label)
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.5))
                                        Text(number)
                                            .font(.subheadline)
                                            .foregroundStyle(.white)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 20)
            }

            // Программы
            if let info, !info.programs.isEmpty {
                Text("Программы")
                    .font(.title3).fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 24)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(info.programs, id: \.self) { program in
                            VStack(spacing: 0) {
                                ZStack {
                                    Color.white
                                    StationLogo(station: station)
                                        .frame(width: 72, height: 72)
                                }
                                .frame(height: 100)
                                Text(program)
                                    .font(.subheadline).fontWeight(.medium)
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12).padding(.vertical, 10)
                            }
                            .frame(width: 190)
                            .background(Color.omgTile)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .padding(.top, 12)
            }

            Spacer().frame(height: 32)
        }
        .padding(.horizontal, 20)
    }

    private struct Social: Hashable {
        let label: String
        let icon: String
        let url: String
    }

    private func socialLinks(info: StationInfo?) -> [Social] {
        var result: [Social] = []
        if let vk = info?.vkLink, !vk.isEmpty {
            result.append(Social(label: "ВКонтакте", icon: "person.2", url: vk))
        }
        // Сайт из первого региона станции
        if let siteLink = RadioRepository.shared.stations
            .first(where: { $0.nid == station.nid })?
            .regions.first?.siteLink,
           !siteLink.isEmpty {
            result.append(Social(label: "Сайт", icon: "globe", url: siteLink))
        }
        return result
    }
}
