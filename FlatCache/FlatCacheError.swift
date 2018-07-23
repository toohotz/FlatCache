//
//  FlatCacheError.swift
//  FlatCache
//
//  Created by Kemar White on 7/10/18.
//  Copyright © 2018 Ryan Nystrom. All rights reserved.
//

import Foundation

enum FlatCacheError: Error {
    /// Indicates that a value could not be found for the key provided.  The associated `String` value corresponds to the key provided.
    case valueNotFound(String)
}
