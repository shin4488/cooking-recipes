import Foundation

/// 取得の間隔。同じURLは24時間に1回まで、取得を拒否したサイトには一定期間接続しない
public enum TitleFetchThrottle {
    public static let interval: TimeInterval = 24 * 60 * 60

    /// 取得してよいか。拒否したサイトへの取得を止めている間と、同じURLを24時間以内に試した場合は取得しない
    public static func canFetch(pausedUntil: Date?, lastAttempt: Date?, now: Date) -> Bool {
        !isPaused(until: pausedUntil, now: now) && canAttempt(lastAttempt: lastAttempt, now: now)
    }

    public static func canAttempt(lastAttempt: Date?, now: Date) -> Bool {
        guard let lastAttempt else { return true }
        return now.timeIntervalSince(lastAttempt) >= interval
    }

    /// 拒否したサイトへの取得を止めているか。止める期限の日時になったら再開する
    public static func isPaused(until: Date?, now: Date) -> Bool {
        guard let until else { return false }
        return now < until
    }

    /// 拒否の応答を受けたサイトへの取得を再開できる日時。サイトが指定した待ち時間が長ければそちらに従う
    public static func pauseEnd(refusedAt: Date, retryAfter: TimeInterval?) -> Date {
        refusedAt.addingTimeInterval(max(interval, retryAfter ?? 0))
    }
}
