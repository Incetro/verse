//
//  File.swift
//  
//
//  Created by incetro on 12/25/21.
//

import Foundation

// MARK: - Value

extension Effect {

    /// Returns an effect that will return the given value
    ///
    /// ```
    /// return .value(Action.referralToast)
    /// ```
    ///
    /// - Parameters:
    ///     - value: target value
    /// - Returns: An effect that will be executed after `dueTime`
    public static func value(_ value: Output) -> Effect {
        .init(value: value)
    }
}
