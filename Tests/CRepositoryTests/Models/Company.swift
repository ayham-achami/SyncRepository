//
//  Company.swift
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

import RealmSwift
import Foundation
import CRepository

// MARK: - Company
struct Company: Equatable {
    
    let id: Int
    let name: String
    let logoId: Int?
}

// MARK: - Company + ManageableRepresented
extension Company: ManageableRepresented {
    
    typealias RepresentedType = ManageableCompany
    
    init(from represented: Self.RepresentedType) {
        self.id = represented.id
        self.name = represented.name
        self.logoId = represented.logoId
    }
}

// MARK: - Company + ManageableSource
final class ManageableCompany: Object, ManageableSource {
    
    @Persisted(primaryKey: true) var id: Int = .zero
    @Persisted var name: String = ""
    @Persisted var logoId: Int?
    
    required convenience init(from company: Company) {
        self.init()
        self.id = company.id
        self.name = company.name
        self.logoId = company.logoId
    }
    
    convenience init(id: Int, name: String, logoId: Int?) {
        self.init()
        self.id = id
        self.name = name
        self.logoId = logoId
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? ManageableCompany else { return false }
        return id == other.id && name == other.name && logoId == other.logoId
    }
}
