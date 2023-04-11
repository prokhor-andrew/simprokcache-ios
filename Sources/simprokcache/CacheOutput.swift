//
//  File.swift
//  
//
//  Created by Andriy Prokhorenko on 10.04.2023.
//


public enum CacheOutput {
    case didGet(key: String, value: Any?)
    case didSet(key: String)
    
    case didStartListening(key: String)
    case didStopListening(key: String)
    
    case didGetValueWhileListening(key: String, value: Any?)
}
