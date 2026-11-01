import AudioToolbox

/// タイマーの音を鳴らす窓口。ViewModel はこのプロトコル越しに呼ぶ。
protocol SoundPlayer {
    /// 学習フェーズの開始音を鳴らす。
    func playStartSound()
    /// 学習フェーズの終了音、またはタイマー全体の終了音を鳴らす。
    func playEndSound()
}

/// システムサウンドの番号(SystemSoundID)。差し替えるときはここだけ変える。
enum SoundConfig {
    /// 開始音: Tink(短く高い音)
    static let startSoundID: SystemSoundID = 1057
    /// 終了音: jbl_begin
    static let endSoundID: SystemSoundID = 1111
}

/// iOS のシステムサウンドで鳴らす実装。音声ファイルは使わない。
struct SystemSoundPlayer: SoundPlayer {
    func playStartSound() {
        AudioServicesPlaySystemSound(SoundConfig.startSoundID)
    }

    func playEndSound() {
        AudioServicesPlaySystemSound(SoundConfig.endSoundID)
    }
}

/// 何も鳴らさない実装。Preview やテストで使う。
struct SilentSoundPlayer: SoundPlayer {
    func playStartSound() {}
    func playEndSound() {}
}
