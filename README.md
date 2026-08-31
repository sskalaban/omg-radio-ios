# OMG Radio для iOS (SwiftUI)

Зеркало Android-версии OMG Radio: 13 станций с `dev.omg56.ru/omgserver` (включая выбор города для станций с несколькими регионами), полноэкранный плеер с каруселью логотипов, новости с `dev.omg56.ru/omgprooren`, форма «Написать в прямой эфир».

## Что внутри

- **SwiftUI**, iOS 16+, без внешних зависимостей (AVPlayer, URLSession, CommonCrypto)
- Проект генерируется через **XcodeGen** (`project.yml`) — не нужен Mac для редактирования структуры
- Сборка для iOS Simulator через **GitHub Actions** (macOS-раннер)

## Как получить сборку в облаке (шаги, один раз ~15 минут)

### 1. Залейте проект на GitHub

```bash
cd RadioPlayer-iOS
git init
git add .
git commit -m "OMG Radio iOS (SwiftUI)"
```

Создайте репозиторий на github.com (можно приватный — бесплатные минуты Actions работают и там, просто расходуются с коэффициентом ×10 для macOS) и запушьте:

```bash
git remote add origin https://github.com/<ваш-логин>/omg-radio-ios.git
git branch -M main
git push -u origin main
```

### 2. Дождитесь сборки

- Вкладка **Actions** в репозитории → workflow «Сборка iOS (симулятор)» запустится автоматически по пушу
- Через ~10-15 минут job станет зелёным → откройте его → внизу **Artifacts** → скачайте `RadioPlayer-simulator.zip`

### 3. Запустите в облачном симуляторе

**Appetize.io** (проще всего):
1. appetize.io → регистрация (бесплатный тир ~100 мин/мес)
2. **Upload app** → загрузите `RadioPlayer-simulator.zip`
3. Нажмите **Play** — настоящий iOS в браузере, приложение открывается и работает (станции, плеер, новости, потоки играют)

**BrowserStack App Live** (альтернатива):
1. browserstack.com/app-live → триал
2. Upload → тот же zip → выбирайте iPhone → приложение запустится

## Локальная сборка (если появится Mac)

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project RadioPlayer.xcodeproj -scheme RadioPlayer \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## Структура

- `RadioPlayer/Models.swift` — декодинг omgserver/omgprooren, модели
- `RadioPlayer/RadioRepository.swift` — загрузка станций/новостей, отправка сообщения
- `RadioPlayer/PlayerManager.swift` — AVPlayer-обёртка (состояние плеера, город, станция)
- `RadioPlayer/Crypto.swift` — PBKDF2-HMAC-SHA1 для токена формы
- `RadioPlayer/Theme.swift` — цвета/тема, StationLogo, RemoteImage
- `RadioPlayer/StationListView.swift` — главный экран + мини-плеер
- `RadioPlayer/PlayerView.swift` — полноэкранный плеер с каруселью и выбором города
- `RadioPlayer/StationDetailView.swift` — страница станции
- `RadioPlayer/NewsListView.swift` — новости + детальная
- `RadioPlayer/MessageView.swift` — форма сообщения
- `RadioPlayer/Assets.xcassets` — логотипы станций, фон плеера, иконка

## Ограничения первой версии

Пока не перенесены: будильник, сон-таймер, избранное, виджет, Android Auto (CarPlay). Потоки играют в foreground (фоновое воспроизведение требует capability `audio` — добавляется в `project.yml` одним ключом при необходимости).
