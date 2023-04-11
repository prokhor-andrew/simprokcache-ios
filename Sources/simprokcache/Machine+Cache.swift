//
//  File.swift
//  
//
//  Created by Andriy Prokhorenko on 06.04.2023.
//

import Foundation
import simprokmachine
import simproktools
import simprokstate


public extension Machine {
    
    private static func willGetOutline() -> Outline<CacheOutput, CacheInput, CacheInput, CacheOutput> {
        Outline.create { trigger in
            switch trigger {
            case .ext(.willGet(let key)):
                return OutlineTransition(
                    Outline.create { trigger in
                        switch trigger {
                        case .int(.didGet(let key, let value)):
                            return OutlineTransition(
                                .finale(),
                                effects: .ext(.didGet(key: key, value: value))
                            )
                        default:
                            return nil
                        }
                    },
                    effects: .int(.willGet(key: key))
                )
            default:
                return nil
            }
        }
    }
    
    private static func willSetOutline() -> Outline<CacheOutput, CacheInput, CacheInput, CacheOutput> {
        Outline.create { trigger in
            switch trigger {
            case .ext(.willSet(let value, let key)):
                return OutlineTransition(
                    Outline.create { trigger in
                        switch trigger {
                        case .int(.didSet(let key)):
                            return OutlineTransition(
                                .finale(),
                                effects: .ext(.didSet(key: key))
                            )
                        default:
                            return nil
                        }
                    },
                    effects: .int(.willSet(value: value, key: key))
                )
            default:
                return nil
            }
        }
    }

    private static func cancelling() -> Outline<CacheOutput, CacheInput, CacheInput, CacheOutput> {
        Outline.create { trigger in
            switch trigger {
            case .ext(.willStopListening(let key)):
                return OutlineTransition(
                    Outline.create { trigger in
                        switch trigger {
                        case .int(.didStopListening(let key)):
                            return OutlineTransition(
                                .finale(),
                                effects: .ext(.didStopListening(key: key))
                            )
                        default:
                            return nil
                        }
                    },
                    effects: .int(.willStopListening(key: key))
                )
            default:
                return nil
            }
        }
    }
    
    private static func listening() -> Outline<CacheOutput, CacheInput, CacheInput, CacheOutput> {
        Outline.create { trigger in
            switch trigger {
            case .ext(.willStartListening(let key)):
                return OutlineTransition(
                    Outline.create { trigger in
                        switch trigger {
                        case .int(.didStartListening(let key)):
                            return OutlineTransition(
                                .finale(),
                                effects: .ext(.didStartListening(key: key))
                            )
                        default:
                            return nil
                        }
                    }.switchOnTransition(
                        to: cancelling(),
                        doneOnFinale: false
                    ),
                    effects: .int(.willStartListening(key: key))
                )
            default:
                return nil
            }
        }
    }
    
    private class Holder2: NSObject {
   
        private let cache: UserDefaults
        
        private var key: String?
        private var onChange: Handler<Any?>?

        init(_ cache: UserDefaults) {
            self.cache = cache
        }

        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
            guard let key, let change, object != nil, key == keyPath else { return }
            onChange?(change[.newKey] as Any?)
        }
        
        func subscribe(key: String, onChange: @escaping Handler<Any?>) {
            self.key = key
            self.onChange = onChange
            
            cache.addObserver(self, forKeyPath: key, options: [.old, .new], context: nil)
        }
        
        func unsubscribe() {
            onChange = nil
            
            guard let key else { return }
            cache.removeObserver(self, forKeyPath: key, context: nil)
            
            self.key = nil
        }
    }
    
    private class Holder1 {
        
        let cache: UserDefaults
        
        init(_ cache: UserDefaults) {
            self.cache = cache
        }
    }
    
    static func cache(_ defaults: UserDefaults = .standard) -> Machine<Input, Output> where Input == IdData<String, CacheInput>, Output == IdData<String, CacheOutput> {
        
        let machine0 = Machine(Holder1(defaults)) { object, input, callback in
            guard let input else { return }
            
            let id = input.id
            let data = input.data
            
            switch data {
            case .willGet(let key):
                callback(
                    IdData(id: id, data: .didGet(key: key, value: object.cache.object(forKey: key)))
                )
            case .willSet(let value, let key):
                if let value = value {
                    object.cache.set(value, forKey: key)
                } else {
                    object.cache.removeObject(forKey: key)
                }
                callback(IdData(id: id, data: .didSet(key: key)))
            case .willStartListening, .willStopListening:
                break
            }
        }
        

        let machine1 = Machine(
            FeatureTransition(
                Outline.mergeFinaleWhenAll([
                    Outline.dynamic { _ in
                        willSetOutline()
                    },
                    
                    Outline.dynamic { _ in
                        willGetOutline()
                    }
                    
                ]).asFeature(SetOfMachines(machine0))
            )
        )
        
        
        let machine2 = Machine.source(
            typeIntTrigger: CacheOutput.self,
            typeIntEffect: CacheInput.self,
            typeExtTrigger: CacheInput.self,
            typeExtEffect: CacheOutput.self,
            typeRequest: String.self,
            typeResponse: Any?.self,
            typeLaunchReason: Void.self,
            typeCancelReason: Void.self,
            outlines: [
                { _ in listening() },
                { _ in cancelling() }
            ]
        ) {
            ()
        } mapReq: { _, event in
            switch event {
            case .willGet, .willSet:
                return ((), nil)
            case .willStartListening(let key):
                return ((), .int(.willLaunch(id: key, reason: (), isLaunchOnMain: false, request: key)))
            case .willStopListening(let key):
                return ((), .int(.willCancel(id: key, reason: ())))
            }
        } mapRes: { _, event in
            switch event {
            case .didLaunch(let key, _):
                return ((), .ext(.didStartListening(key: key)))
            case .didCancel(let key, _):
                return ((), .ext(.didStopListening(key: key)))
            case .didEmit(let key, let value):
                return ((), .ext(.didGetValueWhileListening(key: key, value: value)))
            }
        } holder: {
            Holder2(defaults)
        } onLaunch: { holder, key, callback in
            holder.subscribe(key: key) { callback(($0, false)) }
        } onCancel: { holder in
            holder.unsubscribe()
        }

        
        return machine1.and(machine2)
    }
}
