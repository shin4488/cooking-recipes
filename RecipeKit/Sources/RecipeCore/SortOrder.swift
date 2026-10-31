/// 並び順の値。小さいほど上に表示する
public enum SortOrder {
    /// 新しい記録は先頭に入れる
    public static func keyForNewItem(currentMinimum: Double?) -> Double {
        (currentMinimum ?? 1) - 1
    }

    /// 上下の記録の間に入れる値。間が詰まって入れられないときは nil を返し、全体を振り直す
    public static func keyBetween(above: Double?, below: Double?) -> Double? {
        switch (above, below) {
        case (nil, nil): return 0
        case (let above?, nil): return above + 1
        case (nil, let below?): return below - 1
        case (let above?, let below?):
            let key = (above + below) / 2
            return key > above && key < below ? key : nil
        }
    }
}
