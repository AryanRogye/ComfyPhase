//
//  UserDefaultsHelper.swift
//  WallpaperHandler
//
//  Created by Aryan Rogye on 10/1/26.
//

import Foundation

extension UserDefaults {
    public protocol UserDefaultsStorable {
        static func read(from defaults: UserDefaults, key: String) -> Self?
        func write(to defaults: UserDefaults, key: String)
    }

    public class Keys { public init() {} }

    public final class Key<T>: Keys {
        let key: String
        let defaultValue: T

        public init(_ key: String, default value: T) {
            self.key = key
            self.defaultValue = value
        }
    }
}

extension UserDefaults {
    subscript<T: UserDefaultsStorable>(key: Key<T>) -> T {
        get {
            T.read(from: self, key: key.key) ?? key.defaultValue
        }
        set {
            newValue.write(to: self, key: key.key)
        }
    }
}

// Native UserDefaults URL handling
extension UserDefaults {
    subscript(key: Key<URL?>) -> URL? {
        get {
            return url(forKey: key.key) ?? key.defaultValue
        }
        set {
            set(newValue, forKey: key.key)
        }
    }
}

extension UserDefaults {
    subscript<T: Codable>(key: Key<T>) -> T {
        get {
            guard
                let data = data(forKey: key.key),
                let value = try? JSONDecoder().decode(T.self, from: data)
                    else {
                return key.defaultValue
            }

            return value
        }

        set {
            guard let data = try? JSONEncoder().encode(newValue) else {
                return
            }

            set(data, forKey: key.key)
        }
    }
}

extension UserDefaults {
    @available(
        *,
         unavailable,
         message: "Do not conform a Codable type to UserDefaultsStorable. Codable types are stored automatically."
    )
    subscript<T: Codable & UserDefaultsStorable>(key: Key<T>) -> T {
        get {
            fatalError("Unreachable: Do not conform a Codable type to UserDefaultsStorable. Codable types are stored automatically.")
        }
        set {
            fatalError("Unreachable: Do not conform a Codable type to UserDefaultsStorable. Codable types are stored automatically.")
        }
    }
}
