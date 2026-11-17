import Foundation
import SwiftData
import Testing
@testable import BifazModels

@Suite("CloudKit compatibility of the schema")
struct CloudKitSchemaTests {
    @Test("Every relationship is optional, has an inverse and is not .deny")
    func relationships() {
        var checked = 0
        for entity in BifazStore.schema.entities {
            for rel in entity.relationships {
                checked += 1
                let id = "\(entity.name).\(rel.name)"
                #expect(rel.isOptional, "\(id) must be optional")
                #expect(rel.inverseKeyPath != nil || rel.inverseName != nil, "\(id) needs an inverse")
                #expect(rel.deleteRule != .deny, "\(id) must not use .deny")
                #expect(!rel.isUnique, "\(id) must not be unique")
                #expect(!rel.options.contains(.unique), "\(id) must not have the unique option")
            }
        }
        #expect(checked > 0)
    }

    @Test("No attribute is unique")
    func attributesNotUnique() {
        for entity in BifazStore.schema.entities {
            for attr in entity.attributes {
                #expect(!attr.isUnique, "\(entity.name).\(attr.name) must not be unique")
                #expect(!attr.options.contains(.unique), "\(entity.name).\(attr.name) has the unique option")
            }
        }
    }

    @Test("Every attribute is optional or has a default value")
    func attributesDefaults() {
        for entity in BifazStore.schema.entities {
            for attr in entity.attributes {
                #expect(attr.isOptional || attr.defaultValue != nil,
                        "\(entity.name).\(attr.name) needs a default value or must be optional")
            }
        }
    }

    @Test("No entity has uniqueness constraints")
    func noUniquenessConstraints() {
        for entity in BifazStore.schema.entities {
            #expect(entity.uniquenessConstraints.isEmpty, "\(entity.name) has uniqueness constraints")
        }
    }
}
