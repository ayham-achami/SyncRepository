//
//  MigrationController.swift
//

import Foundation

/// Протокол контекст миграции, логику необходимых действий при миграции
public protocol MigrationContext {

    /// Внести изменения на всех объектов определенной записи в сессии миграции
    ///
    /// - Parameters:
    ///   - model: Тип записи
    ///   - enumerate: Перечисляет все объекты данного типа, предоставляя как старые, так и новые версии каждого объекта.
    func forEach<T>(for model: T.Type,
                    enumerate: @escaping (DynamicManageable, DynamicManageable) -> Void) where T: Manageable

    /// Переименовывает свойство данной записи из `oldName` в` newName`.
    ///
    /// - Parameters:
    ///   - model: Тип записи
    ///   - oldName: Старое название
    ///   - newName: Новое название
    func renameProperty<T>(of model: T.Type,
                           from oldName: String,
                           to newName: String) where T: Manageable

    /// Создавать новую запись в хранилище
    ///
    /// - Parameter model: Тип записи
    func create<T>(_ model: T.Type) where T: Manageable
    
    /// Создать новую запись в хранилище
    /// - Parameters:
    ///   - model: Тип записи
    ///   - value: Подготовленное значение для записи
    func create<T>(_ model: T.Type, value: T) where T: Manageable

    /// Удалить запись из хранилища
    ///
    /// - Parameter model: Тип записи
    func delete<T>(_ model: T.Type) where T: Manageable
}

/// Протокол контроля миграции
public protocol MigrationController {

    /// Новая версия хранилища
    var newSchemaVersion: UInt64 { get }
    /// Старая версия хранилища
    var oldSchemaVersion: UInt64 { get }
    /// Контекст миграции
    var context: MigrationContext { get }
}
