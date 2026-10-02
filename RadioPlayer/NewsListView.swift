import SwiftUI

/// Список новостей: карточки с обложкой, датой и превью текста.
/// Тап открывает детальную страницу (sheet — NavigationStack на этом экране нет).
struct NewsListView: View {
    let news: [NewsItem]
    @State private var selected: NewsItem?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(news) { item in
                    VStack(alignment: .leading, spacing: 10) {
                        ZStack(alignment: .topTrailing) {
                            RemoteImage(url: item.image)
                                .frame(height: 190)
                                .clipShape(RoundedRectangle(cornerRadius: 14))

                            if !item.date.isEmpty {
                                Text(item.date)
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.black.opacity(0.4))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .padding(8)
                            }
                        }
                        .overlay(alignment: .bottomLeading) {
                            Text(item.title)
                                .font(.title3).fontWeight(.medium)
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.7), radius: 4)
                                .padding(12)
                        }

                        Text(item.body.strippingHtml())
                            .fontWeight(.light)
                            .foregroundStyle(.white)
                            .lineLimit(4)

                        Text("Читать далее")
                            .font(.body)
                            .foregroundStyle(.white)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selected = item }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 76)
        }
        .sheet(item: $selected) { item in
            NewsDetailView(item: item)
        }
    }
}

/// Детальная новость: градиентный фон, заголовок, дата, картинка, текст.
struct NewsDetailView: View {
    let item: NewsItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.newsGradient.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(item.title)
                        .font(.title).fontWeight(.bold)
                        .foregroundStyle(.white)
                    if !item.date.isEmpty {
                        Text(item.date)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    if !item.image.isEmpty {
                        RemoteImage(url: item.image)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    Text(item.body.strippingHtml())
                        .fontWeight(.light)
                        .foregroundStyle(.white)
                        .lineSpacing(5)

                    if let url = URL(string: item.link), !item.link.isEmpty {
                        Link("Читать на сайте", destination: url)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24).padding(.vertical, 12)
                            .background(Color(white: 1, opacity: 0.2))
                            .clipShape(Capsule())
                    }
                }
                .padding(20)
                .padding(.top, 44)
            }

            // Кнопка «скрыть новость» — круглая со стрелкой назад (как в Android-версии)
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3).fontWeight(.bold)
                            .foregroundStyle(.black.opacity(0.7))
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.85))
                            .clipShape(Circle())
                    }
                    .padding(.leading, 16)
                    .padding(.top, 8)
                    Spacer()
                }
                Spacer()
            }
        }
    }
}
