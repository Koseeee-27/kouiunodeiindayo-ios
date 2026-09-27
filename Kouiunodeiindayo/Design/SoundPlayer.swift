import AVFoundation
import OSLog

/// 効果音の再生（機能24）。音源は `Resources/` に置いた caf（圧縮なし。読み込み・鳴り始めが速い）。
/// 音の種類は `.ambient`：消音スイッチ（マナーモード）がオンなら鳴らさず、ほかのアプリで流している音楽も止めない。
/// 鳴らせなかったとき（音源が無い・読めない）は、ログを残して何もしない（操作はそのまま続く）。
enum SoundPlayer {
    enum Sound: String {
        /// ハンコを押す音（「う、うまい」「うまい」を付けたとき）。
        /// 出典：Freesound「traditional stamp.wav」by I.fekry https://freesound.org/people/I.fekry/sounds/470710/
        /// ライセンスは Creative Commons 0（CC0。複製・加工・配布・商用利用が自由で、表記も要らない）なので、公開リポジトリに置いている。
        /// 元の wav は頭に 0.5 秒・後ろに 0.5 秒の無音があり、押してから鳴るまで遅れるので、0.495〜1.1 秒を切り出して caf にしている
        case stampPress = "stamp-press"
    }

    /// 音量の設定値のキー（`docs/data-model.md` の「設定値」）
    static let volumeStorageKey = "soundVolume"
    /// 音量の初期値（最大）
    static let defaultVolume = 1.0

    private static let logger = Logger(category: "SoundPlayer")
    /// 音源の拡張子
    static let fileExtension = "caf"
    /// 読み込んだ音。同じ音は使い回す（押すたびにファイルを読まない）
    private static var players: [Sound: AVAudioPlayer] = [:]
    private static var isSessionReady = false

    /// 先に読み込んでおく。初めて鳴らすときの遅れをなくすため、ハンコの絵が出たときに呼ぶ（2 回目からは何もしない）
    static func prepare(_ sound: Sound) {
        prepareSessionIfNeeded()
        _ = player(for: sound)
    }

    /// 頭から鳴らす。鳴っている途中でも、もう一度頭から鳴らす。音量は設定（`soundVolume`）に従い、0 なら鳴らさない
    static func play(_ sound: Sound) {
        let volume = currentVolume
        guard volume > 0 else { return }
        prepareSessionIfNeeded()
        guard let player = player(for: sound) else { return }
        player.volume = Float(volume)
        player.currentTime = 0
        player.play()
    }

    /// 設定の音量（0〜1）。まだ設定していなければ初期値
    private static var currentVolume: Double {
        let stored = UserDefaults.standard.object(forKey: volumeStorageKey) as? Double ?? defaultVolume
        return min(max(stored, 0), 1)
    }

    private static func player(for sound: Sound) -> AVAudioPlayer? {
        if let player = players[sound] {
            return player
        }
        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: Self.fileExtension) else {
            logger.error("効果音のファイルが見つからない: \(sound.rawValue, privacy: .public)")
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            players[sound] = player
            return player
        } catch {
            logger.error(
                "効果音を読み込めなかった: \(sound.rawValue, privacy: .public) \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// 音の種類を `.ambient` にする（1 回だけ）。失敗しても鳴らすのは試す
    /// （そのときは既定の音の種類になり、ほかのアプリの音楽を止めることがある）
    private static func prepareSessionIfNeeded() {
        guard !isSessionReady else { return }
        isSessionReady = true
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient)
        } catch {
            logger.error("音の種類を設定できなかった: \(error.localizedDescription, privacy: .public)")
        }
    }
}
