/// 下タブの行き先。case の順が、そのままバーの並び順（左からカメラ／ホーム／一覧）になる。
/// 並びの決まりは `docs/screen-design.md` の「ナビゲーション」が正。
enum RootTab: CaseIterable {
    case camera
    case home
    case list

    var title: String {
        switch self {
        case .camera: "カメラ"
        case .home: "ホーム"
        case .list: "一覧"
        }
    }

    var systemImage: String {
        switch self {
        case .camera: "camera"
        case .home: "house"
        case .list: "square.grid.2x2"
        }
    }
}
