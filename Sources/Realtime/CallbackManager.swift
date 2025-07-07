import ConcurrencyExtras
import Foundation

@RealtimeActor
final class CallbackManager {
  private var id = 0
  private(set) var serverChanges: [PostgresJoinConfig] = []
  private(set) var callbacks: [RealtimeCallback] = []

  @discardableResult
  func addBroadcastCallback(
    event: String,
    callback: @escaping @Sendable (JSONObject) -> Void
  ) -> Int {
    id += 1
    callbacks.append(
      .broadcast(
        BroadcastCallback(
          id: id,
          event: event,
          callback: callback
        )
      )
    )
    return id
  }

  @discardableResult
  func addPostgresCallback(
    filter: PostgresJoinConfig,
    callback: @escaping @Sendable (AnyAction) -> Void
  ) -> Int {
    id += 1
    callbacks.append(
      .postgres(
        PostgresCallback(
          id: id,
          filter: filter,
          callback: callback
        )
      )
    )
    return id
  }

  @discardableResult
  func addPresenceCallback(callback: @escaping @Sendable (any PresenceAction) -> Void) -> Int {
    id += 1
    callbacks.append(.presence(PresenceCallback(id: id, callback: callback)))
    return id
  }

  @discardableResult
  func addSystemCallback(callback: @escaping @Sendable (RealtimeMessageV2) -> Void) -> Int {
    id += 1
    callbacks.append(.system(SystemCallback(id: id, callback: callback)))
    return id
  }

  func setServerChanges(changes: [PostgresJoinConfig]) {
    serverChanges = changes
  }

  func removeCallback(id: Int) {
    callbacks.removeAll { $0.id == id }
  }

  func triggerPostgresChanges(ids: [Int], data: AnyAction) {
    let filters = serverChanges.filter {
      ids.contains($0.id)
    }
    let postgresCallbacks = callbacks.compactMap {
      if case let .postgres(callback) = $0 {
        return callback
      }
      return nil
    }

    let callbacks = postgresCallbacks.filter { cc in
      filters.contains { sc in
        cc.filter == sc
      }
    }

    for item in callbacks {
      item.callback(data)
    }
  }

  func triggerBroadcast(event: String, json: JSONObject) {
    let broadcastCallbacks = callbacks.compactMap {
      if case let .broadcast(callback) = $0 {
        return callback
      }
      return nil
    }
    let callbacks = broadcastCallbacks.filter { $0.event == event }
    callbacks.forEach { $0.callback(json) }
  }

  func triggerPresenceDiffs(
    joins: [String: PresenceV2],
    leaves: [String: PresenceV2],
    rawMessage: RealtimeMessageV2
  ) {
    let presenceCallbacks = callbacks.compactMap {
      if case let .presence(callback) = $0 {
        return callback
      }
      return nil
    }
    for presenceCallback in presenceCallbacks {
      presenceCallback.callback(
        PresenceActionImpl(
          joins: joins,
          leaves: leaves,
          rawMessage: rawMessage
        )
      )
    }
  }

  func triggerSystem(message: RealtimeMessageV2) {
    let systemCallbacks = callbacks.compactMap {
      if case .system(let callback) = $0 {
        return callback
      }
      return nil
    }

    for systemCallback in systemCallbacks {
      systemCallback.callback(message)
    }
  }
}

struct PostgresCallback {
  var id: Int
  var filter: PostgresJoinConfig
  var callback: @Sendable (AnyAction) -> Void
}

struct BroadcastCallback {
  var id: Int
  var event: String
  var callback: @Sendable (JSONObject) -> Void
}

struct PresenceCallback {
  var id: Int
  var callback: @Sendable (any PresenceAction) -> Void
}

struct SystemCallback {
  var id: Int
  var callback: @Sendable (RealtimeMessageV2) -> Void
}

enum RealtimeCallback {
  case postgres(PostgresCallback)
  case broadcast(BroadcastCallback)
  case presence(PresenceCallback)
  case system(SystemCallback)

  var id: Int {
    switch self {
    case let .postgres(callback): callback.id
    case let .broadcast(callback): callback.id
    case let .presence(callback): callback.id
    case let .system(callback): callback.id
    }
  }

  var isPresence: Bool {
    if case .presence = self {
      return true
    } else {
      return false
    }
  }
}
