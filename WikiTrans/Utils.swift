import Foundation

let ISO681toBCP47: [String: String] = ["ar": "ar-SA",
                                       "cs": "cs-CZ",
                                       "da": "da-DK",
                                       "de": "de-DE",
                                       "el": "el-GR",
                                       "en": "en-US", // en-AU, en-GB, en-IE, en-ZA
                                       "es": "es-ES", // es-MX
                                       "fi": "fi-FI",
                                       "fr": "fr-FR", // fr-CA
                                       "hi": "hi-IN",
                                       "hu": "hu-HU",
                                       "id": "id-ID",
                                       "it": "it-IT",
                                       "ja": "ja-JP",
                                       "ko": "ko-KR",
                                       "nl": "nl-NL", // nl-BE
                                       "no": "no-NO",
                                       "pl": "pl-PL",
                                       "pt": "pt-BR", // pt-PT
                                       "ro": "ro-RO",
                                       "ru": "ru-RU",
                                       "sk": "sk-SK",
                                       "sv": "sv-SE",
                                       "th": "th-TH",
                                       "tr": "tr-TR",
                                       "zh": "zh-CN", // zh-HK, zh-TW
]


var GlobalMainQueue: DispatchQueue {
    return DispatchQueue.main
}

var GlobalUserInteractiveQueue: DispatchQueue {
    return DispatchQueue.global(qos: DispatchQoS.QoSClass.userInteractive)
}

var GlobalUserInitiatedQueue: DispatchQueue {
    return DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated)
}

var GlobalUtilityQueue: DispatchQueue {
    return DispatchQueue.global(qos: DispatchQoS.QoSClass.utility)
}

var GlobalBackgroundQueue: DispatchQueue {
    return DispatchQueue.global(qos: DispatchQoS.QoSClass.background)
}

open class SynchronizedArray<T> {
    fileprivate var array: [T] = []
    fileprivate let accessQueue = DispatchQueue(label: "SynchronizedArrayAccess", attributes: [])
    
    open func append(_ newElement: T) {
        self.accessQueue.async {
            self.array.append(newElement)
        }
    }
    
    var count: Int {
        // TODO
        var r = 0
        //        print(self.array.count)
        self.accessQueue.sync {
            r = self.array.count
        }
#if DEBUG
        print(r)
#endif
        return r
        //        return self.array.count
    }
    
    open func removeAll(_ keepCapacity: Bool) {
        self.accessQueue.sync {
            self.array.removeAll(keepingCapacity: keepCapacity)
        }
    }
    
    open func extend(_ newElements: [T]) {
        self.accessQueue.sync {
            self.array.append(contentsOf: newElements)
        }
    }
    
    open func update(_ newElements: [T]) {
        self.accessQueue.sync {
            self.array.removeAll(keepingCapacity: newElements.count <= self.array.count)
            self.array.append(contentsOf: newElements)
        }
    }
    
    open subscript(index: Int) -> T {
        set {
            self.accessQueue.async {
                self.array[index] = newValue
            }
        }
        get {
            var element: T!
            self.accessQueue.sync {
                element = self.array[index]
            }
            return element
        }
    }
}
