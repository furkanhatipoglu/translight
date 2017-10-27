//
//  Extensions.swift
//  translight
//
//  Created by Erstream on 28/10/2017.
//  Copyright © 2017 Razeware LLC. All rights reserved.
//

import Foundation

//find keys from value
extension Dictionary where Value: Equatable {
  func allKeys(forValue val: Value) -> [Key] {
    return self.filter { $1 == val }.map { $0.0 }
  }
}
