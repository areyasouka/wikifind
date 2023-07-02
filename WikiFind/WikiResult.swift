import UIKit

class WikiResult {
    // MARK: Properties
    
    var entityId: Int
    var entityLangs: String
    var terms: [String: String]
    var descriptions: [String: String]
    var siteUrls: [String: String]
    var matchedLangs: [String]
    var matchedTerms: [String]
    var matchedTermTypes: [Int]
    var matchedTermsAlphanum: [String]
    var matchedQueryIndex: [Int]
    
    // MARK: Initialization
    init(entityId: Int) {
        self.entityId = entityId
        self.entityLangs = ""
        self.terms = [String: String]()
        self.descriptions = [String: String]()
        self.siteUrls = [String: String]()
        self.matchedLangs = [String]()
        self.matchedTerms = [String]()
        self.matchedTermTypes = [Int]()
        self.matchedTermsAlphanum = [String]()
        self.matchedQueryIndex = [Int]()
    }
}
