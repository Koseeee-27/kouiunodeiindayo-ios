import SwiftUI

/// ドラッグ中、手前のカードの上寄りに押すハンコ風のジャンル名。濃さは呼ぶ側が進んだ距離で決める。
/// 見た目は仮。#23 で合わせる。
struct SortStampView: View {
    let genre: Genre

    var body: some View {
        Text(genre.title)
            .font(.largeTitle.weight(.heavy))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(.red)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.red, lineWidth: 4)
            }
            .rotationEffect(.degrees(-12))
            // 押せるラベルと同じ内容なので、読み上げない
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

#Preview {
    SortStampView(genre: .dessert)
        .padding()
}
