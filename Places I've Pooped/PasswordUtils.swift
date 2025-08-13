//
//  PasswordUtils.swift
//  Places I've Pooped
//

import Foundation
import CryptoKit

struct PasswordUtils {
    
    // MARK: - Password Hashing
    static func hashPassword(_ password: String) -> String {
        let salt = UUID().uuidString
        let saltedPassword = password + salt
        let hashedData = SHA256.hash(data: saltedPassword.data(using: .utf8)!)
        let hashedString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
        return "\(hashedString):\(salt)"
    }
    
    static func verifyPassword(_ password: String, against hashedPassword: String) -> Bool {
        let components = hashedPassword.split(separator: ":")
        guard components.count == 2 else { return false }
        
        let storedHash = String(components[0])
        let salt = String(components[1])
        let saltedPassword = password + salt
        let hashedData = SHA256.hash(data: saltedPassword.data(using: .utf8)!)
        let hashedString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
        
        return storedHash == hashedString
    }
    
    // MARK: - Input Validation
    static func validateEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    static func validateUsername(_ username: String) -> (isValid: Bool, errorMessage: String?) {
        // Username requirements: 3-20 characters, alphanumeric and underscores only
        if username.count < 3 {
            return (false, "Username must be at least 3 characters")
        }
        if username.count > 20 {
            return (false, "Username must be 20 characters or less")
        }
        
        let usernameRegex = "^[a-zA-Z0-9_]+$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        if !usernamePredicate.evaluate(with: username) {
            return (false, "Username can only contain letters, numbers, and underscores")
        }
        
        return (true, nil)
    }
    
    static func validatePassword(_ password: String) -> (isValid: Bool, errorMessage: String?) {
        // Password requirements: at least 6 characters
        if password.count < 6 {
            return (false, "Password must be at least 6 characters")
        }
        
        return (true, nil)
    }
}
