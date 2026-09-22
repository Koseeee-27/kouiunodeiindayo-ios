import SwiftUI

/// 記録の詳細。中身は Issue #13 で作る。ホーム・一覧から開く画面で、下タブには載らない。
struct RecordDetailView: View {
    var body: some View {
        Text("記録の詳細")
            .font(.title)
    }
}

#Preview {
    RecordDetailView()
}
