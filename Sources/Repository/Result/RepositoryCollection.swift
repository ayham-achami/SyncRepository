//
//  RepositoryCollection.swift
//
//  The MIT License (MIT)
//
//  Copyright (c) 2019 Community Arch
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Combine
import RealmSwift
import Foundation

/// <#Description#>
public protocol RepositoryResultCollectionProtocol {
    
    associatedtype Index
    associatedtype Element: Manageable
}

/// <#Description#>
public protocol RepositoryResultCollection: RepositoryResultCollectionProtocol where Element: ManageableSource {
    
    /// <#Description#>
    var isEmpty: Bool { get async }
    
    /// <#Description#>
    var count: Int { get async }
    
    /// <#Description#>
    var description: String { get async }
    
    /// <#Description#>
    var throwIfEmpty: Self { get async throws }
    
    /// <#Description#>
    var queue: DispatchQueue { get }
    
    /// <#Description#>
    var controller: RepositoryController { get }
    
    /// <#Description#>
    var unsafe: UnsafeRepositoryResult<Element> { get }
    
    /// <#Description#>
    subscript(_ index: Index) -> Element { get async }
    
    /// <#Description#>
    /// - Parameter descriptors: <#descriptors description#>
    /// - Returns: <#description#>
    func sorted(with descriptors: [Sorted]) async -> Self
    
    /// <#Description#>
    /// - Parameter descriptors: <#descriptors description#>
    /// - Returns: <#description#>
    func sorted(with descriptors: [PathSorted<Element>]) async -> Self
    
    /// <#Description#>
    /// - Parameter predicate: <#predicate description#>
    /// - Returns: <#description#>
    func filter(by predicate: NSPredicate) async -> Self
    
    /// <#Description#>
    /// - Parameter isIncluded: <#isIncluded description#>
    /// - Returns: <#description#>
    func filter(_ isIncluded: @escaping ((Query<Element>) -> Query<Bool>)) async -> Self
    
    /// <#Description#>
    /// - Parameter isIncluded: <#isIncluded description#>
    /// - Returns: <#description#>
    func filter(_ isIncluded: @escaping (Element) throws -> Bool) async throws -> [Element]
    
    /// <#Description#>
    /// - Parameter predicate: <#predicate description#>
    /// - Returns: <#description#>
    func first(where predicate: @escaping (Element) throws -> Bool) async throws -> Element?
    
    /// <#Description#>
    /// - Parameter predicate: <#predicate description#>
    /// - Returns: <#description#>
    func last(where predicate: @escaping (Element) throws -> Bool) async throws -> Element?
    
    /// <#Description#>
    /// - Parameter transform: <#transform description#>
    /// - Returns: <#description#>
    func map<T>(_ transform: @escaping (Element) throws -> T) async throws -> [T]
    
    /// <#Description#>
    /// - Parameter transform: <#transform description#>
    /// - Returns: <#description#>
    func compactMap<T>(_ transform: @escaping (Element) throws -> T?) async throws -> [T]
}

extension RepositoryResultCollection {
    
    /// <#Description#>
    /// - Parameter body: <#body description#>
    /// - Returns: <#description#>
    func perform<T>(_ body: @escaping () -> T) async -> T {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: body())
            }
        }
    }
    
    /// <#Description#>
    /// - Parameter body: <#body description#>
    /// - Returns: <#description#>
    func performThrowing<T>(_ body: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    continuation.resume(returning: try body())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - Publisher + RepositoryController
public extension Publisher where Self.Output: RepositoryResultCollection,
                                 Self.Output.Element: ManageableSource,
                                 Self.Failure == Swift.Error {
    
    /// <#Description#>
    func lazy() -> AnyPublisher<LazyRepository, Self.Failure> {
        flatMap { $0.controller.publishLazy }.eraseToAnyPublisher()
    }
    
    /// <#Description#>
    func manageable() -> AnyPublisher<ManageableRepository, Self.Failure> {
        flatMap { $0.controller.publishManageable }.eraseToAnyPublisher()
    }
    
    /// <#Description#>
    func represented() -> AnyPublisher<RepresentedRepository, Self.Failure> {
        flatMap { $0.controller.publishRepresented }.eraseToAnyPublisher()
    }
    
    /// <#Description#>
    /// - Returns: <#description#>
    func throwIfEmpty() -> AnyPublisher<Self.Output, Self.Failure> {
        tryMap { result in
            try apply { .init(result: result, unsafe: try result.unsafe.throwIfEmpty) }
        }.eraseToAnyPublisher()
    }
    
    /// <#Description#>
    /// - Parameter predicate: <#predicate description#>
    /// - Returns: <#description#>
    func filter(by predicate: NSPredicate) -> AnyPublisher<Self.Output, Self.Failure> {
        map { result in
            apply { .init(result: result, unsafe: result.unsafe.filter(by: predicate)) }
        }.eraseToAnyPublisher()
    }
    
    /// <#Description#>
    /// - Parameter isIncluded: <#isIncluded description#>
    /// - Returns: <#description#>
    func filter(_ isIncluded: @escaping ((Query<Self.Output.Element>) -> Query<Bool>)) -> AnyPublisher<Self.Output, Self.Failure> {
        map { result in
            apply { .init(result: result, unsafe: result.unsafe.filter(isIncluded)) }
        }.eraseToAnyPublisher()
    }
    
    /// <#Description#>
    /// - Parameter descriptors: <#descriptors description#>
    /// - Returns: <#description#>
    func sorted(with descriptors: [Sorted]) -> AnyPublisher<Self.Output, Self.Failure> {
        map { result in
            apply { .init(result: result, unsafe: result.unsafe.sorted(with: descriptors)) }
        }.eraseToAnyPublisher()
    }
    
    /// <#Description#>
    /// - Parameter descriptors: <#descriptors description#>
    /// - Returns: <#description#>
    func sorted(with descriptors: [PathSorted<Self.Output.Element>]) -> AnyPublisher<Self.Output, Self.Failure> {
        map { result in
            apply { .init(result: result, unsafe: result.unsafe.sorted(with: descriptors)) }
        }.eraseToAnyPublisher()
    }
    
    /// <#Description#>
    /// - Parameter body: <#body description#>
    /// - Returns: <#description#>
    private func apply(_ body: @escaping () throws -> (Container<Self.Output>)) rethrows -> Self.Output {
        let container = try body()
        // swiftlint:disable:next force_cast
        return RepositoryResult(container.result.queue, container.unsafe, container.result.controller) as! Self.Output
    }
}

// MARK: - RepositoryResult + ManageableType
public extension RepositoryResultCollection where Element: ManageableSource,
                                                  Element.ManageableType.RepresentedType == Element {
    
    /// <#Description#>
    /// - Returns: <#description#>
    func mapRepresented() async -> RepositoryRepresentedResult<Element.ManageableType> {
        await perform { .init(queue, unsafe, controller) }
    }
}

// MARK: - Publisher + ManageableRepresented
public extension Publisher where Self.Output: RepositoryResultCollection,
                                 Self.Output.Element: ManageableSource,
                                 Self.Output.Element.ManageableType.RepresentedType == Self.Output.Element {
    
    /// <#Description#>
    /// - Returns: <#description#>
    func mapRepresented() -> AnyPublisher<RepositoryRepresentedResult<Self.Output.Element.ManageableType>, Self.Failure> {
        map { RepositoryRepresentedResult<Self.Output.Element.ManageableType>($0.queue, $0.unsafe, $0.controller) } .eraseToAnyPublisher()
    }
}