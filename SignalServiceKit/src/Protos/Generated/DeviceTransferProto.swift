//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalCoreKit
import SwiftProtobuf

// WARNING: This code is generated. Only edit within the markers.

public enum DeviceTransferProtoError: Error {
    case invalidProtobuf(description: String)
}

// MARK: - DeviceTransferProtoFile

public class DeviceTransferProtoFile: NSObject, Codable {

    // MARK: - DeviceTransferProtoFileBuilder

    public class func builder(identifier: String, relativePath: String, estimatedSize: UInt64) -> DeviceTransferProtoFileBuilder {
        return DeviceTransferProtoFileBuilder(identifier: identifier, relativePath: relativePath, estimatedSize: estimatedSize)
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    public func asBuilder() -> DeviceTransferProtoFileBuilder {
        let builder = DeviceTransferProtoFileBuilder(identifier: identifier, relativePath: relativePath, estimatedSize: estimatedSize)
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    public class DeviceTransferProtoFileBuilder: NSObject {

        private var proto = DeviceTransferProtos_File()

        fileprivate override init() {}

        fileprivate init(identifier: String, relativePath: String, estimatedSize: UInt64) {
            super.init()

            setIdentifier(identifier)
            setRelativePath(relativePath)
            setEstimatedSize(estimatedSize)
        }

        @available(swift, obsoleted: 1.0)
        public func setIdentifier(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.identifier = valueParam
        }

        public func setIdentifier(_ valueParam: String) {
            proto.identifier = valueParam
        }

        @available(swift, obsoleted: 1.0)
        public func setRelativePath(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.relativePath = valueParam
        }

        public func setRelativePath(_ valueParam: String) {
            proto.relativePath = valueParam
        }

        public func setEstimatedSize(_ valueParam: UInt64) {
            proto.estimatedSize = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        public func build() throws -> DeviceTransferProtoFile {
            return try DeviceTransferProtoFile(proto)
        }

        public func buildSerializedData() throws -> Data {
            return try DeviceTransferProtoFile(proto).serializedData()
        }
    }

    fileprivate let proto: DeviceTransferProtos_File

    public let identifier: String

    public let relativePath: String

    public let estimatedSize: UInt64

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DeviceTransferProtos_File,
                 identifier: String,
                 relativePath: String,
                 estimatedSize: UInt64) {
        self.proto = proto
        self.identifier = identifier
        self.relativePath = relativePath
        self.estimatedSize = estimatedSize
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    public convenience init(serializedData: Data) throws {
        let proto = try DeviceTransferProtos_File(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DeviceTransferProtos_File) throws {
        let identifier = proto.identifier

        let relativePath = proto.relativePath

        let estimatedSize = proto.estimatedSize

        // MARK: - Begin Validation Logic for DeviceTransferProtoFile -

        // MARK: - End Validation Logic for DeviceTransferProtoFile -

        self.init(proto: proto,
                  identifier: identifier,
                  relativePath: relativePath,
                  estimatedSize: estimatedSize)
    }

    public required convenience init(from decoder: Swift.Decoder) throws {
        let singleValueContainer = try decoder.singleValueContainer()
        let serializedData = try singleValueContainer.decode(Data.self)
        try self.init(serializedData: serializedData)
    }
    public func encode(to encoder: Swift.Encoder) throws {
        var singleValueContainer = encoder.singleValueContainer()
        try singleValueContainer.encode(try serializedData())
    }

    public override var debugDescription: String {
        return "\(proto)"
    }
}

#if DEBUG

extension DeviceTransferProtoFile {
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DeviceTransferProtoFile.DeviceTransferProtoFileBuilder {
    public func buildIgnoringErrors() -> DeviceTransferProtoFile? {
        return try! self.build()
    }
}

#endif

// MARK: - DeviceTransferProtoDefault

public class DeviceTransferProtoDefault: NSObject, Codable {

    // MARK: - DeviceTransferProtoDefaultBuilder

    public class func builder(key: String, encodedValue: Data) -> DeviceTransferProtoDefaultBuilder {
        return DeviceTransferProtoDefaultBuilder(key: key, encodedValue: encodedValue)
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    public func asBuilder() -> DeviceTransferProtoDefaultBuilder {
        let builder = DeviceTransferProtoDefaultBuilder(key: key, encodedValue: encodedValue)
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    public class DeviceTransferProtoDefaultBuilder: NSObject {

        private var proto = DeviceTransferProtos_Default()

        fileprivate override init() {}

        fileprivate init(key: String, encodedValue: Data) {
            super.init()

            setKey(key)
            setEncodedValue(encodedValue)
        }

        @available(swift, obsoleted: 1.0)
        public func setKey(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.key = valueParam
        }

        public func setKey(_ valueParam: String) {
            proto.key = valueParam
        }

        @available(swift, obsoleted: 1.0)
        public func setEncodedValue(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.encodedValue = valueParam
        }

        public func setEncodedValue(_ valueParam: Data) {
            proto.encodedValue = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        public func build() throws -> DeviceTransferProtoDefault {
            return try DeviceTransferProtoDefault(proto)
        }

        public func buildSerializedData() throws -> Data {
            return try DeviceTransferProtoDefault(proto).serializedData()
        }
    }

    fileprivate let proto: DeviceTransferProtos_Default

    public let key: String

    public let encodedValue: Data

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DeviceTransferProtos_Default,
                 key: String,
                 encodedValue: Data) {
        self.proto = proto
        self.key = key
        self.encodedValue = encodedValue
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    public convenience init(serializedData: Data) throws {
        let proto = try DeviceTransferProtos_Default(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DeviceTransferProtos_Default) throws {
        let key = proto.key

        let encodedValue = proto.encodedValue

        // MARK: - Begin Validation Logic for DeviceTransferProtoDefault -

        // MARK: - End Validation Logic for DeviceTransferProtoDefault -

        self.init(proto: proto,
                  key: key,
                  encodedValue: encodedValue)
    }

    public required convenience init(from decoder: Swift.Decoder) throws {
        let singleValueContainer = try decoder.singleValueContainer()
        let serializedData = try singleValueContainer.decode(Data.self)
        try self.init(serializedData: serializedData)
    }
    public func encode(to encoder: Swift.Encoder) throws {
        var singleValueContainer = encoder.singleValueContainer()
        try singleValueContainer.encode(try serializedData())
    }

    public override var debugDescription: String {
        return "\(proto)"
    }
}

#if DEBUG

extension DeviceTransferProtoDefault {
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DeviceTransferProtoDefault.DeviceTransferProtoDefaultBuilder {
    public func buildIgnoringErrors() -> DeviceTransferProtoDefault? {
        return try! self.build()
    }
}

#endif

// MARK: - DeviceTransferProtoDatabase

public class DeviceTransferProtoDatabase: NSObject, Codable {

    // MARK: - DeviceTransferProtoDatabaseBuilder

    public class func builder(key: Data, database: DeviceTransferProtoFile, wal: DeviceTransferProtoFile) -> DeviceTransferProtoDatabaseBuilder {
        return DeviceTransferProtoDatabaseBuilder(key: key, database: database, wal: wal)
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    public func asBuilder() -> DeviceTransferProtoDatabaseBuilder {
        let builder = DeviceTransferProtoDatabaseBuilder(key: key, database: database, wal: wal)
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    public class DeviceTransferProtoDatabaseBuilder: NSObject {

        private var proto = DeviceTransferProtos_Database()

        fileprivate override init() {}

        fileprivate init(key: Data, database: DeviceTransferProtoFile, wal: DeviceTransferProtoFile) {
            super.init()

            setKey(key)
            setDatabase(database)
            setWal(wal)
        }

        @available(swift, obsoleted: 1.0)
        public func setKey(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.key = valueParam
        }

        public func setKey(_ valueParam: Data) {
            proto.key = valueParam
        }

        @available(swift, obsoleted: 1.0)
        public func setDatabase(_ valueParam: DeviceTransferProtoFile?) {
            guard let valueParam = valueParam else { return }
            proto.database = valueParam.proto
        }

        public func setDatabase(_ valueParam: DeviceTransferProtoFile) {
            proto.database = valueParam.proto
        }

        @available(swift, obsoleted: 1.0)
        public func setWal(_ valueParam: DeviceTransferProtoFile?) {
            guard let valueParam = valueParam else { return }
            proto.wal = valueParam.proto
        }

        public func setWal(_ valueParam: DeviceTransferProtoFile) {
            proto.wal = valueParam.proto
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        public func build() throws -> DeviceTransferProtoDatabase {
            return try DeviceTransferProtoDatabase(proto)
        }

        public func buildSerializedData() throws -> Data {
            return try DeviceTransferProtoDatabase(proto).serializedData()
        }
    }

    fileprivate let proto: DeviceTransferProtos_Database

    public let key: Data

    public let database: DeviceTransferProtoFile

    public let wal: DeviceTransferProtoFile

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DeviceTransferProtos_Database,
                 key: Data,
                 database: DeviceTransferProtoFile,
                 wal: DeviceTransferProtoFile) {
        self.proto = proto
        self.key = key
        self.database = database
        self.wal = wal
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    public convenience init(serializedData: Data) throws {
        let proto = try DeviceTransferProtos_Database(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DeviceTransferProtos_Database) throws {
        let key = proto.key

        let database = try DeviceTransferProtoFile(proto.database)

        let wal = try DeviceTransferProtoFile(proto.wal)

        // MARK: - Begin Validation Logic for DeviceTransferProtoDatabase -

        // MARK: - End Validation Logic for DeviceTransferProtoDatabase -

        self.init(proto: proto,
                  key: key,
                  database: database,
                  wal: wal)
    }

    public required convenience init(from decoder: Swift.Decoder) throws {
        let singleValueContainer = try decoder.singleValueContainer()
        let serializedData = try singleValueContainer.decode(Data.self)
        try self.init(serializedData: serializedData)
    }
    public func encode(to encoder: Swift.Encoder) throws {
        var singleValueContainer = encoder.singleValueContainer()
        try singleValueContainer.encode(try serializedData())
    }

    public override var debugDescription: String {
        return "\(proto)"
    }
}

#if DEBUG

extension DeviceTransferProtoDatabase {
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DeviceTransferProtoDatabase.DeviceTransferProtoDatabaseBuilder {
    public func buildIgnoringErrors() -> DeviceTransferProtoDatabase? {
        return try! self.build()
    }
}

#endif

// MARK: - DeviceTransferProtoManifest

public class DeviceTransferProtoManifest: NSObject, Codable {

    // MARK: - DeviceTransferProtoManifestBuilder

    public class func builder(grdbSchemaVersion: UInt64) -> DeviceTransferProtoManifestBuilder {
        return DeviceTransferProtoManifestBuilder(grdbSchemaVersion: grdbSchemaVersion)
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    public func asBuilder() -> DeviceTransferProtoManifestBuilder {
        let builder = DeviceTransferProtoManifestBuilder(grdbSchemaVersion: grdbSchemaVersion)
        if let _value = database {
            builder.setDatabase(_value)
        }
        builder.setAppDefaults(appDefaults)
        builder.setStandardDefaults(standardDefaults)
        builder.setFiles(files)
        if hasEstimatedTotalSize {
            builder.setEstimatedTotalSize(estimatedTotalSize)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    public class DeviceTransferProtoManifestBuilder: NSObject {

        private var proto = DeviceTransferProtos_Manifest()

        fileprivate override init() {}

        fileprivate init(grdbSchemaVersion: UInt64) {
            super.init()

            setGrdbSchemaVersion(grdbSchemaVersion)
        }

        public func setGrdbSchemaVersion(_ valueParam: UInt64) {
            proto.grdbSchemaVersion = valueParam
        }

        @available(swift, obsoleted: 1.0)
        public func setDatabase(_ valueParam: DeviceTransferProtoDatabase?) {
            guard let valueParam = valueParam else { return }
            proto.database = valueParam.proto
        }

        public func setDatabase(_ valueParam: DeviceTransferProtoDatabase) {
            proto.database = valueParam.proto
        }

        public func addAppDefaults(_ valueParam: DeviceTransferProtoDefault) {
            var items = proto.appDefaults
            items.append(valueParam.proto)
            proto.appDefaults = items
        }

        public func setAppDefaults(_ wrappedItems: [DeviceTransferProtoDefault]) {
            proto.appDefaults = wrappedItems.map { $0.proto }
        }

        public func addStandardDefaults(_ valueParam: DeviceTransferProtoDefault) {
            var items = proto.standardDefaults
            items.append(valueParam.proto)
            proto.standardDefaults = items
        }

        public func setStandardDefaults(_ wrappedItems: [DeviceTransferProtoDefault]) {
            proto.standardDefaults = wrappedItems.map { $0.proto }
        }

        public func addFiles(_ valueParam: DeviceTransferProtoFile) {
            var items = proto.files
            items.append(valueParam.proto)
            proto.files = items
        }

        public func setFiles(_ wrappedItems: [DeviceTransferProtoFile]) {
            proto.files = wrappedItems.map { $0.proto }
        }

        public func setEstimatedTotalSize(_ valueParam: UInt64) {
            proto.estimatedTotalSize = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        public func build() throws -> DeviceTransferProtoManifest {
            return try DeviceTransferProtoManifest(proto)
        }

        public func buildSerializedData() throws -> Data {
            return try DeviceTransferProtoManifest(proto).serializedData()
        }
    }

    fileprivate let proto: DeviceTransferProtos_Manifest

    public let grdbSchemaVersion: UInt64

    public let database: DeviceTransferProtoDatabase?

    public let appDefaults: [DeviceTransferProtoDefault]

    public let standardDefaults: [DeviceTransferProtoDefault]

    public let files: [DeviceTransferProtoFile]

    public var estimatedTotalSize: UInt64 {
        return proto.estimatedTotalSize
    }
    public var hasEstimatedTotalSize: Bool {
        return true
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DeviceTransferProtos_Manifest,
                 grdbSchemaVersion: UInt64,
                 database: DeviceTransferProtoDatabase?,
                 appDefaults: [DeviceTransferProtoDefault],
                 standardDefaults: [DeviceTransferProtoDefault],
                 files: [DeviceTransferProtoFile]) {
        self.proto = proto
        self.grdbSchemaVersion = grdbSchemaVersion
        self.database = database
        self.appDefaults = appDefaults
        self.standardDefaults = standardDefaults
        self.files = files
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    public convenience init(serializedData: Data) throws {
        let proto = try DeviceTransferProtos_Manifest(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DeviceTransferProtos_Manifest) throws {
        let grdbSchemaVersion = proto.grdbSchemaVersion

        var database: DeviceTransferProtoDatabase?
        if proto.hasDatabase {
            database = try DeviceTransferProtoDatabase(proto.database)
        }

        var appDefaults: [DeviceTransferProtoDefault] = []
        appDefaults = try proto.appDefaults.map { try DeviceTransferProtoDefault($0) }

        var standardDefaults: [DeviceTransferProtoDefault] = []
        standardDefaults = try proto.standardDefaults.map { try DeviceTransferProtoDefault($0) }

        var files: [DeviceTransferProtoFile] = []
        files = try proto.files.map { try DeviceTransferProtoFile($0) }

        // MARK: - Begin Validation Logic for DeviceTransferProtoManifest -

        // MARK: - End Validation Logic for DeviceTransferProtoManifest -

        self.init(proto: proto,
                  grdbSchemaVersion: grdbSchemaVersion,
                  database: database,
                  appDefaults: appDefaults,
                  standardDefaults: standardDefaults,
                  files: files)
    }

    public required convenience init(from decoder: Swift.Decoder) throws {
        let singleValueContainer = try decoder.singleValueContainer()
        let serializedData = try singleValueContainer.decode(Data.self)
        try self.init(serializedData: serializedData)
    }
    public func encode(to encoder: Swift.Encoder) throws {
        var singleValueContainer = encoder.singleValueContainer()
        try singleValueContainer.encode(try serializedData())
    }

    public override var debugDescription: String {
        return "\(proto)"
    }
}

#if DEBUG

extension DeviceTransferProtoManifest {
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DeviceTransferProtoManifest.DeviceTransferProtoManifestBuilder {
    public func buildIgnoringErrors() -> DeviceTransferProtoManifest? {
        return try! self.build()
    }
}

#endif
