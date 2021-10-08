//
//  Locking.swift
//  verse
//
//  Created by incetro on 01/01/2021.
//  Copyright © 2021 Incetro Inc. All rights reserved.
//

import Foundation

// MARK: - UnsafeMutablePointer

extension UnsafeMutablePointer where Pointee == os_unfair_lock_s {

    @inlinable
    @discardableResult
    func sync<R>(_ work: () -> R) -> R {
        os_unfair_lock_lock(self)
        defer {
            os_unfair_lock_unlock(self)
        }
        return work()
    }
}

// MARK: - NSRecursiveLock

extension NSRecursiveLock {

    @inlinable
    @discardableResult
    func sync<R>(work: () -> R) -> R {
        lock()
        defer {
            unlock()
        }
        return work()
    }
}
