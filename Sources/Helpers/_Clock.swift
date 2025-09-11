//
//  _Clock.swift
//  Supabase
//
//  Created by Guilherme Souza on 08/01/25.
//

import ConcurrencyExtras
import Foundation

package protocol _Clock: Sendable {
  func sleep(for duration: TimeInterval) async throws
}

/// Clock implementation using Task.sleep for all platforms
struct SimpleClock: _Clock {
  func sleep(for duration: TimeInterval) async throws {
    try await Task.sleep(nanoseconds: NSEC_PER_SEC * UInt64(duration))
  }
}

/// Test clock implementation for debugging/testing
struct TestClock: _Clock {
  private let _sleep: @Sendable (TimeInterval) async throws -> Void
  
  init(sleep: @escaping @Sendable (TimeInterval) async throws -> Void) {
    self._sleep = sleep
  }
  
  func sleep(for duration: TimeInterval) async throws {
    try await _sleep(duration)
  }
}

// Resolves clock instance - using simple implementation for all platforms
let _resolveClock: @Sendable () -> any _Clock = {
  SimpleClock()
}

private let __clock = LockIsolated(_resolveClock())

#if DEBUG
  package var _clock: any _Clock {
    get {
      __clock.value
    }
    set {
      __clock.setValue(newValue)
    }
  }
#else
  package var _clock: any _Clock {
    __clock.value
  }
#endif
