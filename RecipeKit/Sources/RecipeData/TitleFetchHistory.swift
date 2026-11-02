import Foundation
import RecipeCore
import SwiftData

/// 通信制御のための記録（URLごとの最終試行日時・サイトごとの停止）の読み書き。
/// 読み書きできないときの取得の手順をテストで確かめられるよう、TitleFetchRepository から分ける
@MainActor
protocol TitleFetchHistory {
    func lastAttempt(url: String) throws -> Date?
    func recordAttempt(url: String, at date: Date) throws
    func pauseEnd(siteID: String) throws -> Date?
    /// 停止の期限は、すでに記録した期限より長いときだけ延ばす
    func pause(siteID: String, until: Date) throws
    /// 24時間を過ぎた試行日時と、期限を過ぎた停止を消す
    func purge(now: Date) throws
}

/// 端末内の保存先に置く通信制御の記録
struct StoredTitleFetchHistory: TitleFetchHistory {
    let container: ModelContainer

    func lastAttempt(url: String) throws -> Date? {
        try container.makeContext().fetch(FetchDescriptor<TitleFetchAttempt>(predicate: #Predicate { $0.url == url })).first?.attemptedAt
    }

    func recordAttempt(url: String, at date: Date) throws {
        let context = container.makeContext()
        if let attempt = try context.fetch(FetchDescriptor<TitleFetchAttempt>(predicate: #Predicate { $0.url == url })).first {
            attempt.attemptedAt = date
        } else {
            context.insert(TitleFetchAttempt(url: url, attemptedAt: date))
        }
        try context.save()
    }

    func pauseEnd(siteID: String) throws -> Date? {
        try container.makeContext().fetch(FetchDescriptor<TitleFetchPause>(predicate: #Predicate { $0.siteID == siteID })).first?.until
    }

    func pause(siteID: String, until: Date) throws {
        let context = container.makeContext()
        if let pause = try context.fetch(FetchDescriptor<TitleFetchPause>(predicate: #Predicate { $0.siteID == siteID })).first {
            pause.until = max(pause.until, until)
        } else {
            context.insert(TitleFetchPause(siteID: siteID, until: until))
        }
        try context.save()
    }

    func purge(now: Date) throws {
        let context = container.makeContext()
        let attempts = try context.fetch(FetchDescriptor<TitleFetchAttempt>()).filter {
            TitleFetchThrottle.canAttempt(lastAttempt: $0.attemptedAt, now: now)
        }
        let pauses = try context.fetch(FetchDescriptor<TitleFetchPause>()).filter {
            !TitleFetchThrottle.isPaused(until: $0.until, now: now)
        }
        guard !attempts.isEmpty || !pauses.isEmpty else { return }
        for item in attempts { context.delete(item) }
        for item in pauses { context.delete(item) }
        try context.save()
    }
}
