//
//  File.swift
//  
//
//  Created by Andriy Prokhorenko on 10.04.2023.
//


public enum CacheInput {
    case willGet(key: String)
    case willSet(value: Any?, key: String)
    
    case willStartListening(key: String)
    case willStopListening(key: String)
}
