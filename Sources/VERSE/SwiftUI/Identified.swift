//
//  Identified.swift
//  verse
//
//  Created by incetro on 01/01/2021.
//  Copyright © 2021 Incetro Inc. All rights reserved.
//

// MARK: - Identified

/// A wrapper around a value and a hashable identifier that conforms to identifiable.
@dynamicMemberLookup
public struct Identified<ID, Value>: Identifiable where ID: Hashable {

    // MARK: - Properties

    /// Unique hashable id
    public let id: ID

    /// Identified value
    public var value: Value

    // MARK: - Initializers

    /// Initializes an identified value from a given value and a hashable identifier
    ///
    /// - Parameters:
    ///   - value: a value
    ///   - id: a hashable identifier
    public init(_ value: Value, id: ID) {
        self.id = id
        self.value = value
    }

    /// Initializes an identified value from a given value and a function that can return a hashable
    /// identifier from the value
    ///
    ///     Identified(uuid, id: \.self)
    ///
    /// - Parameters:
    ///   - value: a value
    ///   - id: a hashable identifier
    public init(_ value: Value, id: (Value) -> ID) {
        self.init(value, id: id(value))
    }

    /// NB: This overload works around a bug in key path function expressions and `\.self`.
    /// Initializes an identified value from a given value and a function that can return a hashable
    /// identifier from the value.
    ///
    ///     Identified(uuid, id: \.self)
    ///
    /// - Parameters:
    ///   - value: a value
    ///   - id: a key path from the value to a hashable identifier
    public init(_ value: Value, id: KeyPath<Value, ID>) {
        self.init(value, id: value[keyPath: id])
    }

    // MARK: - Subscripts

    public subscript<LocalValue>(
        dynamicMember keyPath: WritableKeyPath<Value, LocalValue>
    ) -> LocalValue {
        get { self.value[keyPath: keyPath] }
        set { self.value[keyPath: keyPath] = newValue }
    }
}

// MARK: - Decodable

extension Identified: Decodable where ID: Decodable, Value: Decodable {
}

// MARK: - Encodable

extension Identified: Encodable where ID: Encodable, Value: Encodable {
}

// MARK: - Equatable

extension Identified: Equatable where Value: Equatable {
}

// MARK: - Hashable

extension Identified: Hashable where Value: Hashable {
}
