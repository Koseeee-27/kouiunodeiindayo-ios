import SwiftUI

/// カメラ。中身は Issue #15 で作る。今は下タブの骨組みを確かめるための仮の画面。
/// 本物は iPhone 標準のカメラ（モーダル）なので画面全体を覆う。仮ビューも画面を覆って、下のページャーが透けないようにする。
struct CameraView: View {
    var body: some View {
        Text("カメラ")
            .font(.title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.background)
    }
}

#Preview {
    CameraView()
}
