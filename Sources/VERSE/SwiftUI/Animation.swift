//
//  Animation.swift
//  verse
//
//  Created by incetro on 01/01/2021.
//  Copyright © 2021 Incetro Inc. All rights reserved.
//

import SwiftUI

// MARK: - ViewStore

extension ViewStore {

    /// Sends an action to the store with a given animation
    ///
    /// - Parameters:
    ///   - action: an action
    ///   - animation: an animation
    public func send(_ action: Action, animation: Animation?) {
        withAnimation(animation) {
            self.send(action)
        }
    }
}
