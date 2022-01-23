//
//  CombinedState.swift
//  verse
//
//  Created by incetro on 01/01/2022.
//  Copyright © 2021 Incetro Inc. All rights reserved.
//

import Foundation

// MARK: - CombinedState

@dynamicMemberLookup
public struct CombinedState<SharedState, PrivateState> {

    // MARK: - Properties

    /// Shared state value
    var shared: SharedState

    /// Private state value
    var `private`: PrivateState

    // MARK: - DynamicMemberLookup

    subscript<T>(dynamicMember keyPath: WritableKeyPath<PrivateState, T>) -> T {
        get { self.private[keyPath: keyPath] }
        set { self.private[keyPath: keyPath] = newValue }
    }

    subscript<T>(dynamicMember keyPath: WritableKeyPath<SharedState, T>) -> T {
        get { self.shared[keyPath: keyPath] }
        set { self.shared[keyPath: keyPath] = newValue }
    }
}

// MARK: - Equatable

extension CombinedState: Equatable where SharedState: Equatable, PrivateState: Equatable {}
