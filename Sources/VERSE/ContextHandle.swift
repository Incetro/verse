//
//  ContextHandle.swift
//  verse
//
//  Created by incetro on 01/01/2022.
//  Copyright © 2021 Incetro Inc. All rights reserved.
//

import Foundation

// MARK: - ContextHandle

public class ContextHandle<Context> {

    // MARK: - Properties

    /// Shared state context
    @Published public var context: Context

    // MARK: - Initializers

    /// Default initializer
    /// - Parameter context: shared state context
    public init(_ context: Context) {
        self.context = context
    }
}
