import Foundation

/// 取得の間隔。同じURLは24時間に1回まで、取得を拒否したサイトには一定期間接続しない
public enum TitleFetchThrottle {
    public static let interval: TimeInterval = 24 * 60 * 60

    public static func canAttempt(lastAttempt: Date?, now: Date) -> Bool {
        guard let lastAttempt else { return true }
        return now.timeIntervalSince(lastAttempt) >= interval
    }

    /// 拒否の応答を受けたサイトへの取得を再開できる日時。サイトが指定した待ち時間が長ければそちらに従う
    public static func pauseEnd(refusedAt: Date, retryAfter: TimeInterval?) -> Date {
        refusedAt.addingTimeInterval(max(interval, retryAfter ?? 0))
    }
}
