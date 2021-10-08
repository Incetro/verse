//
//  IdentifiedArray.swift
//  verse
//
//  Created by incetro on 01/01/2021.
//  Copyright © 2021 Incetro Inc. All rights reserved.
//

import Foundation

// MARK: - IdentifiedArray

/// An array of elements that can be identified by a given key path
///
/// A useful container of state that is intended to interface with `SwiftUI.ForEach`. For example,
/// your application may model a counter in an identifiable fashion:
///
///     // MARK: - CounterState
///
///     struct CounterState: Identifiable {
///         let id: UUID
///         var count = 0
///     }
///
///     // MARK: - CounterAction
///
///     enum CounterAction {
///         case increment
///         case decrement
///     }
///
///     // MARK: - Reducer
///
///     let counterReducer = Reducer<CounterState, CounterAction, Void> {
///         ...
///     }
///
/// This domain can be pulled back to a larger domain with the `forEach` method:
///
///     // MARK: - AppState
///
///     struct AppState {
///         var counters = IdentifiedArrayOf<CounterState>()
///     }
///
///     // MARK: - AppAction
///
///     enum AppAction {
///         case counter(id: UUID, action: CounterAction)
///     }
///
///     // MARK: - Reducer
///
///     let appReducer = counterReducer.forEach(
///         state: \AppState.counters,
///         action: /AppAction.counter(id:action:),
///         environment: { $0 }
///     )
///
/// And then SwiftUI can work with this array of identified elements in a list view:
///
///     // MARK: - AppView
///
///     struct AppView: View {
///
///         // MARK: - Properties
///
///         let store: Store<AppState, AppAction>
///
///         // MARK: - Body
///
///         var body: some View {
///             List {
///                 ForEachStore(
///                     self.store.scope(state: \.counters, action: AppAction.counter(id:action:)),
///                     content: CounterView.init(store:)
///                 )
///             }
///         }
///     }
public struct IdentifiedArray<ID, Element>: MutableCollection, RandomAccessCollection where ID: Hashable {

    // MARK: - Properties

    /// A key path to a value that identifies an element
    public let id: KeyPath<Element, ID>

    /// A raw array of each element's identifier
    public private(set) var ids: [ID]

    /// A raw array of the underlying elements.
    public var elements: [Element] {
        Array(self)
    }

    // TODO: Support multiple elements with the same identifier but different data.
    private var dictionary: [ID: Element]

    // MARK: - Initializers

    /// Initializes an identified array with a sequence of elements and a key
    /// path to an element's identifier.
    ///
    /// - Parameters:
    ///   - elements: A sequence of elements.
    ///   - id: A key path to a value that identifies an element.
    public init<S>(_ elements: S, id: KeyPath<Element, ID>) where S: Sequence, S.Element == Element {
        self.id = id
        let idsAndElements = elements.map {
            (id: $0[keyPath: id], element: $0)
        }
        self.ids = idsAndElements.map { $0.id }
        self.dictionary = Dictionary(idsAndElements, uniquingKeysWith: { $1 })
    }

    /// Initializes an empty identified array with a key path to an element's
    /// identifier.
    ///
    /// - Parameter id: A key path to a value that identifies an element.
    public init(id: KeyPath<Element, ID>) {
        self.init([], id: id)
    }

    // MARK: - Collection

    public var startIndex: Int {
        ids.startIndex
    }

    public var endIndex: Int {
        ids.endIndex
    }

    public func index(after i: Int) -> Int {
        ids.index(after: i)
    }

    public func index(before i: Int) -> Int {
        ids.index(before: i)
    }

    public subscript(position: Int) -> Element {
        // NB: `_read` crashes Xcode Preview compilation.
        get {
            dictionary[ids[position]].unsafelyUnwrapped
        }
        _modify {
            yield &dictionary[ids[position]]!
        }
    }

    #if DEBUG
    /// Direct access to an element by its identifier
    ///
    /// - Parameter id: the identifier of element to access. Must be a valid identifier for an
    ///   element of the array and will _not_ insert elements that are not already in the array, or
    ///   remove elements when passed `nil`. Use `append` or `insert(_:at:)` to insert elements. Use
    ///   `remove(id:)` to remove an element by its identifier
    /// - Returns: the element
    public subscript(id id: ID) -> Element? {
        get {
            dictionary[id]
        }
        set {
            if newValue != nil && dictionary[id] == nil {
                fatalError(
                    """
            Can't update element with identifier \(id) because no such element exists in the array.

            If you are trying to insert an element into the array, use the "append" or "insert" \
            methods.
            """
                )
            }
            if newValue == nil {
                fatalError(
                    """
            Can't update element with identifier \(id) with nil.

            If you are trying to remove an element from the array, use the "remove(id:) method."
            """
                )
            }
            if newValue![keyPath: self.id] != id {
                fatalError(
                    """
            Can't update element at identifier \(id) with element having mismatched identifier \
            \(newValue![keyPath: self.id]).

            If you would like to replace the element with identifier \(id) with an element with a \
            new identifier, remove the existing element and then insert the new element, instead.
            """
                )
            }
            dictionary[id] = newValue
        }
    }
    #else
    public subscript(id id: ID) -> Element? {
        /// NB: `_read` crashes Xcode Preview compilation.
        get {
            self.dictionary[id]
        }
        _modify {
            yield &self.dictionary[id]
        }
    }
    #endif

    public mutating func insert(_ newElement: Element, at i: Int) {
        let id = newElement[keyPath: id]
        dictionary[id] = newElement
        ids.insert(id, at: i)
    }

    public mutating func insert<C>(
        contentsOf newElements: C, at i: Int
    ) where C: Collection, Element == C.Element {
        for newElement in newElements.reversed() {
            insert(newElement, at: i)
        }
    }

    /// Removes and returns the element with the specified identifier
    ///
    /// - Parameter id: the identifier of the element to remove
    /// - Returns: the removed element
    @discardableResult
    public mutating func remove(id: ID) -> Element {
        let element = dictionary[id]
        assert(element != nil, "Unexpectedly found nil while removing an identified element.")
        dictionary[id] = nil
        ids.removeAll(where: { $0 == id })
        return element.unsafelyUnwrapped
    }

    @discardableResult
    public mutating func remove(at position: Int) -> Element {
        remove(id: ids.remove(at: position))
    }

    public mutating func removeAll(where shouldBeRemoved: (Element) throws -> Bool) rethrows {
        var ids: [ID] = []
        for (index, id) in zip(self.ids.indices, self.ids).reversed() {
            if try shouldBeRemoved(self.dictionary[id]!) {
                self.ids.remove(at: index)
                ids.append(id)
            }
        }
        for id in ids where !self.ids.contains(id) {
            dictionary[id] = nil
        }
    }

    public mutating func remove(atOffsets offsets: IndexSet) {
        for offset in offsets.reversed() {
            _ = remove(at: offset)
        }
    }

    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        ids.move(fromOffsets: source, toOffset: destination)
    }

    public mutating func sort(by areInIncreasingOrder: (Element, Element) throws -> Bool) rethrows {
        try ids.sort {
            try areInIncreasingOrder(dictionary[$0].unsafelyUnwrapped, dictionary[$1].unsafelyUnwrapped)
        }
    }

    public mutating func shuffle<T>(using generator: inout T) where T: RandomNumberGenerator {
        ids.shuffle(using: &generator)
    }

    public mutating func shuffle() {
        var rng = SystemRandomNumberGenerator()
        self.shuffle(using: &rng)
    }

    public mutating func reverse() {
        ids.reverse()
    }
}

// MARK: - CustomDebugStringConvertible

extension IdentifiedArray: CustomDebugStringConvertible {
    public var debugDescription: String {
        self.elements.debugDescription
    }
}

// MARK: - CustomReflectable

extension IdentifiedArray: CustomReflectable {
    public var customMirror: Mirror {
        Mirror(reflecting: self.elements)
    }
}

// MARK: - CustomStringConvertible

extension IdentifiedArray: CustomStringConvertible {
    public var description: String {
        self.elements.description
    }
}

// MARK: - Decodable

extension IdentifiedArray: Decodable where Element: Decodable & Identifiable, ID == Element.ID {
    public init(from decoder: Decoder) throws {
        self.init(try [Element](from: decoder))
    }
}

// MARK: - Encodable

extension IdentifiedArray: Encodable where Element: Encodable {
    public func encode(to encoder: Encoder) throws {
        try self.elements.encode(to: encoder)
    }
}

// MARK: - Equatable

extension IdentifiedArray: Equatable where Element: Equatable {}

// MARK: - Hashable

extension IdentifiedArray: Hashable where Element: Hashable {}

// MARK: - Comparable

extension IdentifiedArray where Element: Comparable {
    public mutating func sort() {
        sort(by: <)
    }
}

// MARK: - ExpressibleByArrayLiteral

extension IdentifiedArray: ExpressibleByArrayLiteral where Element: Identifiable, ID == Element.ID {
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

// MARK: - Identifiable

extension IdentifiedArray where Element: Identifiable, ID == Element.ID {
    public init<S>(_ elements: S) where S: Sequence, S.Element == Element {
        self.init(elements, id: \.id)
    }
}

// MARK: - RangeReplaceableCollection

extension IdentifiedArray: RangeReplaceableCollection where Element: Identifiable, ID == Element.ID {

    public init() {
        self.init([], id: \.id)
    }

    public mutating func replaceSubrange<C, R>(_ subrange: R, with newElements: C)
    where C: Collection, R: RangeExpression, Element == C.Element, Index == R.Bound {
        let replacingIds = self.ids[subrange]
        let newIds = newElements.map { $0.id }
        ids.replaceSubrange(subrange, with: newIds)

        for element in newElements {
            self.dictionary[element.id] = element
        }

        for id in replacingIds where !self.ids.contains(id) {
            self.dictionary[id] = nil
        }
    }
}

/// A convenience type to specify an `IdentifiedArray` by an identifiable element.
public typealias IdentifiedArrayOf<Element> = IdentifiedArray<Element.ID, Element> where Element: Identifiable
