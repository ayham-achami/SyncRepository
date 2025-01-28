//
//  Realm+RepositoryConfiguration.swift
//

import Combine
import Foundation
import RealmSwift

// MARK: - MigrationObject + MigrationManageable
extension MigrationObject: DynamicManageable {

    public func value<T>(of property: String, type: T.Type) -> T? {
        self[property] as? T
    }

    public func set(value: Any?, of property: String) {
        self[property] = value
    }
}

// MARK: - Migration + MigrationContext
extension Migration: MigrationContext {

    public func forEach<T>(for model: T.Type, enumerate: @escaping (DynamicManageable, DynamicManageable) -> Void) where T: Manageable {
        self.enumerateObjects(ofType: model.className()) { (old, new) in
            guard let new = new, let old = old else { return }
            enumerate(old, new)
        }
    }

    public func renameProperty<T>(of model: T.Type, from oldName: String, to newName: String) where T: Manageable {
        renameProperty(onType: model.className(), from: oldName, to: newName)
    }

    public func create<T>(_ model: T.Type) where T: Manageable {
        create(model.className())
    }

    public func delete<T>(_ model: T.Type) where T: Manageable {
        deleteData(forType: model.className())
    }
}

// MARK: - Realm.Configuration + RepositoryConfiguration
extension Realm.Configuration {
    
    /// <#Description#>
    /// - Parameters:
    ///   - kind: <#type description#>
    ///   - configuration: <#configuration description#>
    init(_ kind: RealmRepository.Kind, _ configuration: RepositoryConfiguration) throws {
        let migration = { [weak configuration] (_ migration: Migration, _ oldSchemaVersion: UInt64) in
            guard let configuration = configuration else { return }
            let migrationController = MigrationContextProducer(configuration.repositorySchemaVersion, oldSchemaVersion, migration)
            configuration.repositoryDidBeginMigration(with: migrationController)
        }
        
        let objectTypes: [Object.Type]?
        let appGroup: String?
        switch configuration.drivenType {
        case .globle:
            appGroup = nil
            objectTypes = nil
        case let .package(types):
            appGroup = nil
            objectTypes = types.init().manageables
        case let .container(appGroupIdentifier, types):
            appGroup = appGroupIdentifier
            objectTypes = types.init().manageables
        }
        
        switch kind {
        case .basic:
            self.init(schemaVersion: configuration.repositorySchemaVersion, migrationBlock: migration, objectTypes: objectTypes)
            fileURL = try path(for: self, and: configuration, appGroup: appGroup, category: "Default", lastComponent: "\(configuration.userName).realm")
        case .inMemory:
            self.init(inMemoryIdentifier: "inMemory\(configuration.userName)", migrationBlock: migration, objectTypes: objectTypes)
        case .encryption:
            self.init(encryptionKey: try configuration.encryptionKey, schemaVersion: configuration.repositorySchemaVersion, migrationBlock: migration, objectTypes: objectTypes)
            fileURL = try path(for: self, and: configuration, appGroup: appGroup, category: "Encryption", lastComponent: "\(configuration.userName)Encryption.realm")
        }
    }
    
    /// <#Description#>
    /// - Parameters:
    ///   - kind: <#type description#>
    ///   - configuration: <#configuration description#>
    /// - Returns: <#description#>
    static func publish(_ kind: RealmRepository.Kind,
                        _ configuration: RepositoryConfiguration) -> Future<Realm.Configuration, Swift.Error> {
        Future { promise in
            do {
                promise(.success(try .init(kind, configuration)))
            } catch {
                promise(.failure(error))
            }
        }
    }
    
    /// <#Description#>
    /// - Parameters:
    ///   - realmConfiguration: <#realmConfiguration description#>
    ///   - repositoryConfiguration: <#repositoryConfiguration description#>
    ///   - lastComponent: <#lastComponent description#>
    /// - Returns: <#description#>
    private func path(for realmConfiguration: Realm.Configuration,
                      and repositoryConfiguration: RepositoryConfiguration,
                      appGroup: String?,
                      category: String,
                      lastComponent: String) throws -> URL {
        let fileManager = FileManager.default
        let destinationDirectory: URL
        let baseURL: URL? = if let appGroup {
            fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
        } else {
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        }
        if let directory = repositoryConfiguration.repositoryDirectory, let baseURL = baseURL {
            if #available(iOS 16.0, *) {
                destinationDirectory = baseURL
                    .appending(component: directory)
                    .appending(component: category)
            } else {
                destinationDirectory = baseURL
                    .appendingPathComponent(directory)
                    .appendingPathComponent(category)
            }
        } else if let defaultDirectory = realmConfiguration.fileURL {
            if #available(iOS 16.0, *) {
                destinationDirectory = defaultDirectory
                    .deletingLastPathComponent()
                    .appending(component: category)
            } else {
                destinationDirectory = defaultDirectory
                    .deletingLastPathComponent()
                    .appendingPathComponent(category)
            }
        } else {
            throw RepositoryError.initialization(fileURL: nil)
        }
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        if !repositoryConfiguration.isFileProtection {
            let protectedPath: String
            if #available(iOS 16.0, *) {
                protectedPath = destinationDirectory.path()
            } else {
                protectedPath = destinationDirectory.path
            }
            try fileManager.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                                          ofItemAtPath: protectedPath)
        }
        if #available(iOS 16.0, *) {
            return destinationDirectory.appending(component: lastComponent)
        } else {
            return destinationDirectory.appendingPathComponent(lastComponent)
        }
    }
}

// MARK: - Realm + RepositoryConfiguration
extension Realm {
    
    /// <#Description#>
    private class Cache {
        
        private var source = [String: Realm]()
        private let semaphore = DispatchSemaphore(value: 1)
        
        /// <#Description#>
        /// - Parameters:
        ///   - realm: <#realm description#>
        ///   - key: <#key description#>
        func store(_ realm: Realm, for key: String) {
            perform { source[key] = realm }
        }
        
        /// <#Description#>
        /// - Parameter key: <#key description#>
        /// - Returns: <#description#>
        func restore(for key: String) -> Realm? {
            perform { source[key] }
        }
        
        private func perform<T>(_ block: () -> T) -> T {
            semaphore.wait()
            defer { semaphore.signal() }
            return block()
        }
    }
    
    /// <#Description#>
    private static let inMemoryCache = Cache()
    
    /// <#Description#>
    /// - Parameters:
    ///   - kind: <#type description#>
    ///   - configuration: <#configuration description#>
    ///   - queue: <#queue description#>
    init(_ kind: RealmRepository.Kind, _ configuration: RepositoryConfiguration) throws {
        if case .inMemory = kind, let cachedRealm = Self.inMemoryCache.restore(for: configuration.userName) {
            self = cachedRealm
        } else {
            try self.init(configuration: try .init(kind, configuration))
        }
        guard case .inMemory = kind else { return }
        Self.inMemoryCache.store(self, for: configuration.userName)
    }
    
    /// <#Description#>
    /// - Parameters:
    ///   - kind: <#type description#>
    ///   - configuration: <#configuration description#>
    ///   - queue: <#queue description#>
    init(_ kind: RealmRepository.Kind, _ configuration: RepositoryConfiguration, _ queue: DispatchQueue) async throws {
        if case .inMemory = kind, let cachedRealm = Self.inMemoryCache.restore(for: configuration.userName) {
            self = cachedRealm
        } else {
            self = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Self, Swift.Error>) in
                do {
                    let realmConfiguration = try Configuration(kind, configuration)
                    Self.asyncOpen(configuration: realmConfiguration, callbackQueue: queue) { result in
                        switch result {
                        case let .success(realm):
                            continuation.resume(returning: realm)
                        case .failure:
                            continuation.resume(throwing: RepositoryError.initialization(fileURL: realmConfiguration.fileURL))
                        }
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        guard case .inMemory = kind else { return }
        Self.inMemoryCache.store(self, for: configuration.userName)
    }
    
    /// <#Description#>
    /// - Parameters:
    ///   - kind: <#type description#>
    ///   - configuration: <#configuration description#>
    ///   - queue: <#queue description#>
    /// - Returns: <#description#>
    static func publish(_ kind: RealmRepository.Kind,
                        _ configuration: RepositoryConfiguration,
                        _ queue: DispatchQueue) -> AnyPublisher<Realm, Swift.Error> {
        Realm.Configuration.publish(kind, configuration).create(queue)
    }
}

// MARK: - Publisher + Realm.Configuration
private extension Publisher where Self.Output == Realm.Configuration, Self.Failure == Swift.Error {
    
    /// <#Description#>
    /// - Parameter queue: <#queue description#>
    /// - Returns: <#description#>
    func create(_ queue: DispatchQueue) -> AnyPublisher<Realm, Self.Failure> {
        flatMap { configuration in
            Realm.asyncOpen(configuration: configuration).receive(on: queue)
        }.eraseToAnyPublisher()
    }
}
