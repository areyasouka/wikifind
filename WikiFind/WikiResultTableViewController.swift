import UIKit
import AVFoundation
import ActionSheetPicker_3_0
import GRDB

var dbQueue: DatabaseQueue!
var dbQueueReqNum = 0


fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}


extension UIImage {
    class func imageWithColor(color: UIColor) -> UIImage {
        let rect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 1, height: 1), false, 0)
        color.setFill()
        UIRectFill(rect)
        let image: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
}

@available(iOS 13.0, *)
class WikiResultTableViewController: UITableViewController, UISearchControllerDelegate, UISearchBarDelegate, UISearchResultsUpdating {
    
    // MARK: Properties
    
    static let MIN_RESULTS = 1
    static let MAX_TERM_RESULTS = 1000
    static let MAX_ENTITY_RESULTS = MAX_TERM_RESULTS // maybe not useful
    static let MIN_ENTITY_RESULTS_FOR_RETRY = 10
    static let MAX_DISPLAY_RESULTS = 20
    static let MAX_SCOPE_CHOICES = 6
    static let DB_VERSION = 20240910 // TODO: UPDATE DURING BUILD!
    
    var searchResults: SynchronizedArray<WikiResult>!
    
    var allLangs: [String]!
    
    var scopeChoices: [String]!
    var scopeChoicesLangs: [[String]]!
    var selectedScope: Int!
    var selectedLangs: [String]!
    var pickerChoices: [String]!
    var pickerChoicesLongForm: [String]!
    var pickerChoicesLangs: [[String]]!
    var langMap: [String: String]!
    
    var resultSearchController: UISearchController!
    var selectLangButton: UIButton!
    
    let synth = AVSpeechSynthesizer()
    
    func initDatabase() throws {
        let dbFileName = "wdsqlite.db"
        let bundleDatabasePath = Bundle.main.path(forResource: "wdsqlite", ofType: "db")
        
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let databasePath = documentsURL.appendingPathComponent(dbFileName).path
        var oldVersion = false
        if fileManager.fileExists(atPath: databasePath) {
            oldVersion = true
            let dbQueue = try DatabaseQueue(path: databasePath)
            try dbQueue.inDatabase { db in
                let version = try Int.fetchOne(db, sql: "select version from meta")!
                if (version >= WikiResultTableViewController.DB_VERSION) {
                    oldVersion = false
                }
            }
#if DEBUG
            print("db already in documents oldVersion=\(oldVersion)")
#endif
            if oldVersion {
                do {
                    try fileManager.removeItem(atPath: databasePath)
                } catch let error as NSError {
                    let alert: UIAlertController = UIAlertController(title: "Error Occured", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
        if !fileManager.fileExists(atPath: databasePath) {
#if DEBUG
            print("copying file '\(String(describing: bundleDatabasePath))' to '\(databasePath)'")
#endif
            do {
                try fileManager.copyItem(atPath: bundleDatabasePath!, toPath: databasePath)
                let dbQueue = try DatabaseQueue(path: databasePath)
                try dbQueue.inDatabase { db in
                    try db.execute(sql: "create index if not exists term_entity_id on term(entity_id, term_language, term_type); create index if not exists term_search on term(term_language, entity_languages, term_text_alphanum)")
                }
            } catch let error as NSError { // TODO is this for storage space issue?
                let alert: UIAlertController = UIAlertController(title: "Error Occured", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }
        
        dbQueue = try DatabaseQueue(path: databasePath)
        try dbQueue.inDatabase { db in
            let rows = try Row.fetchCursor(db, sql: "select * from summary")
            while let row = try rows.next() {
                let termLang: String = row["term_language"]
                let termType: Int = row["term_type"]
                // let langCount = rs.longForColumn("term_type_count")
                if termType == 1 {
                    self.allLangs.append(termLang)
                }
#if DEBUG
                // print("\(termLang) termType=\(termType) count=\(langCount)")
#endif
            }
        }
        
        for lang in self.allLangs {
            for lang2 in self.allLangs {
                if lang != lang2 && !self.pickerChoices.contains(lang2+"-"+lang) {
                    self.pickerChoices.append(lang+"-"+lang2)
                    self.pickerChoicesLongForm.append(self.langMap[lang]!+" ⇄ "+self.langMap[lang2]!)
                    self.pickerChoicesLangs.append([lang, lang2])
                    if self.scopeChoices.count == WikiResultTableViewController.MAX_SCOPE_CHOICES {
                        self.scopeChoices.append("...")
                    } else if self.scopeChoices.count < WikiResultTableViewController.MAX_SCOPE_CHOICES && lang+"-"+lang2 != "en-fr" {
                        self.scopeChoices.append(lang+"-"+lang2)
                        self.scopeChoicesLangs.append([lang, lang2])
                    }
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.searchResults = SynchronizedArray<WikiResult>()
        
        self.allLangs = [String]()
        
        self.scopeChoices = [String]()
        self.scopeChoicesLangs = [[String]]()
        self.selectedScope = 0
        self.selectedLangs = [String]()
        self.pickerChoices = [String]()
        self.pickerChoicesLongForm = [String]()
        self.pickerChoicesLangs = [[String]]()
        self.langMap = ["en": "English", "fr": "French", "ja": "Japanese", "zh": "Chinese", "de": "German", "es": "Spanish", "ko": "Korean"]
        
        definesPresentationContext = true
        
        self.resultSearchController = UISearchController(searchResultsController: nil)
        self.resultSearchController.searchResultsUpdater = self
        self.resultSearchController.searchBar.delegate = self
        self.resultSearchController.searchBar.autocapitalizationType = UITextAutocapitalizationType.none
        self.resultSearchController.searchBar.autocorrectionType = UITextAutocorrectionType.yes
        self.resultSearchController.searchBar.showsBookmarkButton = false
        self.resultSearchController.searchBar.showsCancelButton = false // TODO doesnt work bug
        self.resultSearchController.searchBar.showsScopeBar = true
        self.resultSearchController.delegate = self
        navigationController?.navigationBar.prefersLargeTitles = false
        self.navigationItem.searchController = self.resultSearchController
        
        let progressHUD = ProgressHUD(text: "Building index\n(~1 min)")
        self.view.addSubview(progressHUD)
        progressHUD.show()
        GlobalUserInitiatedQueue.async {
            try! self.initDatabase()
            GlobalMainQueue.async {
                progressHUD.hide()
                self.resultSearchController.searchBar.scopeButtonTitles = self.scopeChoices
                self.resultSearchController.searchBar.becomeFirstResponder()
                self.tableView.reloadData()
            }
        }
    }
    
    func didPresentSearchController(_ searchController: UISearchController) {
        searchController.searchBar.setShowsCancelButton(false, animated: false)
    }
    
    struct SearchResults {
        var results: [WikiResult]
    }
    
    func filterContentForSearchText(_ inSearchText: String, searchLangs: [String], threadReqNum: Int) throws -> SearchResults? {
        if !inSearchText.isEmpty {
            var returnResults: [WikiResult]? = nil
            var results = [Int: WikiResult]()
            let nonalphaChars = CharacterSet.alphanumerics.inverted
            let cleanSearchText2 = inSearchText.components(separatedBy: nonalphaChars).joined(separator: "")
            let cleanSearchText3 = inSearchText.components(separatedBy: nonalphaChars).joined(separator: "%")
            let searchStrs = [
                "\(cleanSearchText2)%",
                "%\(cleanSearchText2)%",
                "%\(cleanSearchText3)%",
            ]
            let langCombinations = ["de,en", "de,en,es", "de,en,es,fr", "de,en,es,fr,ja", "de,en,es,fr,ja,ko", "de,en,es,fr,ja,ko,zh", "de,en,es,fr,ja,zh", "de,en,es,fr,ko", "de,en,es,fr,ko,zh", "de,en,es,fr,zh", "de,en,es,ja", "de,en,es,ja,ko", "de,en,es,ja,ko,zh", "de,en,es,ja,zh", "de,en,es,ko", "de,en,es,ko,zh", "de,en,es,zh", "de,en,fr", "de,en,fr,ja", "de,en,fr,ja,ko", "de,en,fr,ja,ko,zh", "de,en,fr,ja,zh", "de,en,fr,ko", "de,en,fr,ko,zh", "de,en,fr,zh", "de,en,ja", "de,en,ja,ko", "de,en,ja,ko,zh", "de,en,ja,zh", "de,en,ko", "de,en,ko,zh", "de,en,zh", "de,es", "de,es,fr", "de,es,fr,ja", "de,es,fr,ja,ko", "de,es,fr,ja,ko,zh", "de,es,fr,ja,zh", "de,es,fr,ko", "de,es,fr,ko,zh", "de,es,fr,zh", "de,es,ja", "de,es,ja,ko", "de,es,ja,ko,zh", "de,es,ja,zh", "de,es,ko", "de,es,ko,zh", "de,es,zh", "de,fr", "de,fr,ja", "de,fr,ja,ko", "de,fr,ja,ko,zh", "de,fr,ja,zh", "de,fr,ko", "de,fr,ko,zh", "de,fr,zh", "de,ja", "de,ja,ko", "de,ja,ko,zh", "de,ja,zh", "de,ko", "de,ko,zh", "de,zh", "en,es", "en,es,fr", "en,es,fr,ja", "en,es,fr,ja,ko", "en,es,fr,ja,ko,zh", "en,es,fr,ja,zh", "en,es,fr,ko", "en,es,fr,ko,zh", "en,es,fr,zh", "en,es,ja", "en,es,ja,ko", "en,es,ja,ko,zh", "en,es,ja,zh", "en,es,ko", "en,es,ko,zh", "en,es,zh", "en,fr", "en,fr,ja", "en,fr,ja,ko", "en,fr,ja,ko,zh", "en,fr,ja,zh", "en,fr,ko", "en,fr,ko,zh", "en,fr,zh", "en,ja", "en,ja,ko", "en,ja,ko,zh", "en,ja,zh", "en,ko", "en,ko,zh", "en,zh", "es,fr", "es,fr,ja", "es,fr,ja,ko", "es,fr,ja,ko,zh", "es,fr,ja,zh", "es,fr,ko", "es,fr,ko,zh", "es,fr,zh", "es,ja", "es,ja,ko", "es,ja,ko,zh", "es,ja,zh", "es,ko", "es,ko,zh", "es,zh", "fr,ja", "fr,ja,ko", "fr,ja,ko,zh", "fr,ja,zh", "fr,ko", "fr,ko,zh", "fr,zh", "ja,ko", "ja,ko,zh", "ja,zh", "ko,zh"]
            let langCombosToSearch = langCombinations.filter() { nil != $0.range(of: searchLangs[0]) && nil != $0.range(of: searchLangs[1]) }
            let langCombosToSearchStr = langCombosToSearch.joined(separator: "','")
            // TODO include bool for other langs if after term_type order by if not enough results?
            // length(entity_languages) desc,
            var rowIdsMatched = [Int]()
#if DEBUG
            var startTime = Date()
#endif
            for (queryIndex, searchStr) in searchStrs.enumerated() {
                // \(chrCountConditionStr)
                let query = "select rowid, * from term where (term_language = '\(searchLangs[0])' or term_language = '\(searchLangs[1])') and entity_languages in ('\(langCombosToSearchStr)') and term_text_alphanum like '\(searchStr)' limit \(WikiResultTableViewController.MAX_TERM_RESULTS)" // order by length(term_text), entity_id
#if DEBUG
                print(query)
#endif
                try dbQueue.inDatabase { db in
                    if threadReqNum != dbQueueReqNum {
                        return
                    }
                    let rows = try Row.fetchCursor(db, sql: query)
                    while let row = try rows.next() {
                        let rowId: Int = row["rowid"]
                        if rowIdsMatched.contains(rowId) {
                            continue
                        }
                        rowIdsMatched.append(rowId)
                        let entityId: Int = row["entity_id"]
                        let wr = results[entityId] ?? WikiResult(entityId: entityId)
                        let matchedTerm: String = (row["term_text"] ?? "").isEmpty ? (row["term_text_alphanum"] ?? "") : row["term_text"]
                        if !(matchedTerm.isEmpty) {
                            wr.matchedTerms.append(matchedTerm)
                            wr.matchedTermsAlphanum.append(row["term_text_alphanum"])
                            wr.matchedLangs.append(row["term_language"])
                            wr.matchedTermTypes.append(row["term_type"])
                            wr.entityLangs = row["entity_languages"]
                            wr.matchedQueryIndex.append(queryIndex)
                            results[entityId] = wr
                            if results.count == WikiResultTableViewController.MAX_ENTITY_RESULTS {
                                break
                            }
#if DEBUG
                            //                                print("\(rowCount++) - \(searchStr)")
#endif
                        }
                    }
                }
                if results.count > WikiResultTableViewController.MIN_ENTITY_RESULTS_FOR_RETRY {
                    break
                }
            }
#if DEBUG
            print("query time=\(Date().timeIntervalSince(startTime))")
#endif
            
            let entityIdsStr = results.keys.map{String($0)}.joined(separator: ",")
            let query = "select * from term where entity_id in (\(entityIdsStr)) and term_type = 1 and (term_language = '\(searchLangs[0])' or term_language = '\(searchLangs[1])')"
#if DEBUG
            print(query)
            startTime = Date()
#endif
            try dbQueue.inDatabase { db in
                if threadReqNum != dbQueueReqNum {
                    return
                }
                let rows = try Row.fetchCursor(db, sql: query)
                while let row = try rows.next() {
                    let entityId: Int = row["entity_id"]
                    let termLang: String = row["term_language"]
                    let termText: String = (row["term_text"] ?? "").isEmpty ? row["term_text_alphanum"] : row["term_text"]
                    results[entityId]!.terms[termLang] = termText
                    if !(row["description"] ?? "").isEmpty {
                        results[entityId]!.descriptions[termLang] = row["description"]
                    }
                    results[entityId]!.siteUrls[termLang] = (row["site_url"] ?? "").isEmpty ? termText : row["site_url"]
                }
            }
#if DEBUG
            print("query time=\(Date().timeIntervalSince(startTime))")
#endif
            
            var resToDel = [Int]()
            for (_, res) in results {
                for lang in searchLangs {
                    if res.terms[lang] == nil {
                        resToDel.append(res.entityId)
                    }
                }
            }
            for eid in resToDel {
                results.removeValue(forKey: eid)
            }
            
            func sortResults(_ wr1: WikiResult, wr2: WikiResult) -> Bool {
                let m1 = wr1.matchedQueryIndex.min() < wr2.matchedQueryIndex.min()
                let m2 = wr1.matchedQueryIndex.min() == wr2.matchedQueryIndex.min() && wr1.matchedTerms[0].count < wr2.matchedTerms[0].count
                let m3 = wr1.matchedQueryIndex.min() == wr2.matchedQueryIndex.min() && wr1.matchedTerms[0].count == wr2.matchedTerms[0].count && wr1.matchedTermTypes.min() < wr2.matchedTermTypes.min()
                let m4 = wr1.matchedQueryIndex.min() == wr2.matchedQueryIndex.min() && wr1.matchedTerms[0].count == wr2.matchedTerms[0].count && wr1.matchedTermTypes.min() == wr2.matchedTermTypes.min() && wr1.entityId < wr2.entityId
                return m1 || m2 || m3 || m4
            }
            let sortedResults = Array(results.values.sorted(by: sortResults).prefix(WikiResultTableViewController.MAX_DISPLAY_RESULTS))
            returnResults = sortedResults
            return returnResults != nil ? SearchResults(results: returnResults!) : nil
        }
        return nil
    }
    
    // MARK: - TableViewDelegate
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.searchResults.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "WikiResultTableViewCell", for: indexPath) as! WikiResultTableViewCell
        let wr = self.searchResults[(indexPath as NSIndexPath).row]
        let termLabels = [cell.termLabel1, cell.termLabel2]
        let descLabels = [cell.descLabel1, cell.descLabel2]
        for (lang, (termLabel, descLabel)) in zip(self.selectedLangs, zip(termLabels, descLabels)) {
            let term = wr.terms[lang] ?? ""
            let desc = wr.descriptions[lang] ?? " " // keep space
            var matchTerms = [String]()
            for (mlang, mterm) in zip(wr.matchedLangs, wr.matchedTerms) {
                if lang == mlang && term.uppercased() != mterm.uppercased() {
                    matchTerms.append(mterm)
                }
            }
            let matchTermStr = matchTerms.joined(separator: ", ")
            termLabel.text = term
            descLabel.text = matchTerms.count > 0 ? "["+matchTermStr+"] "+desc : desc
        }
        cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
        return cell
    }
    
    @objc func doSearch() {
        self.selectedLangs = self.scopeChoicesLangs[self.selectedScope]
        dbQueueReqNum += 1
        let searchText = self.resultSearchController.searchBar.text!
        GlobalUserInitiatedQueue.async {
            let threadReqNum = dbQueueReqNum
            do {
                if let sr = try self.filterContentForSearchText(searchText, searchLangs: self.selectedLangs!, threadReqNum: threadReqNum) {
                    GlobalMainQueue.async {
#if DEBUG
                        print("dbQueueReqNum=\(dbQueueReqNum) threadReqNum=\(threadReqNum)")
#endif
                        if dbQueueReqNum == threadReqNum {
                            self.searchResults.update(sr.results)
                            self.tableView.reloadData()
                            if !sr.results.isEmpty {
                                self.synth.stopSpeaking(at: .immediate)
                                self.speak(text: sr.results[0].terms[self.selectedLangs[0]]!, lang: self.selectedLangs[0])
                                self.speak(text: sr.results[0].terms[self.selectedLangs[1]]!, lang: self.selectedLangs[1])
                            }
                        }
                    }
                }
            } catch let error {
                print(error.localizedDescription)
            }
        }
    }
    
    // MARK: - UISearchControllerDelegate
    func updateSearchResults(for searchController: UISearchController) {
#if DEBUG
        print("UISearchControllerDelegate updateSearchResults")
#endif
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.doSearch), object: nil)
        self.perform(#selector(self.doSearch), with: nil, afterDelay: 0.5)
    }
    
    // MARK: - UISearchBarDelegate
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
#if DEBUG
        print("UISearchBarDelegate searchBar")
#endif
        if selectedScope == self.scopeChoices.count-1 {
            self.selectLang(searchBar)
        } else {
            self.selectedScope = selectedScope
            doSearch()
        }
    }
    
    
    func selectLang(_ searchBar: UISearchBar) {
        let picker = ActionSheetStringPicker(title: "Languages", rows: self.pickerChoicesLongForm, initialSelection: self.selectedScope, doneBlock: {
            picker, index, value in
            let pickerChoice = self.pickerChoices[index]
            var index2 = index
            if self.scopeChoices.contains(pickerChoice) {
                index2 = self.scopeChoices.firstIndex(of: pickerChoice)!
            } else {
                self.scopeChoices[self.scopeChoices.count-1] = pickerChoice
                self.scopeChoices.append("...")
                self.scopeChoicesLangs.append(self.pickerChoicesLangs[index])
                index2 = self.scopeChoices.count - 2
                searchBar.scopeButtonTitles = self.scopeChoices
            }
            searchBar.selectedScopeButtonIndex = index2
            self.selectedScope = index2
            self.doSearch()
            return
        }, cancel: {
            ActionStringCancelBlock in return
        }, origin: searchBar)
        
        searchBar.endEditing(true)
        picker?.show()
    }
    
    func speak(text: String, lang: String) {
        let utterance = AVSpeechUtterance(string: text)
        //        utterance.rate = 0.3
        utterance.voice = AVSpeechSynthesisVoice(language: ISO681toBCP47[lang]!)
        synth.speak(utterance)
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // The number of columns of data
    func numberOfComponentsInPickerView(_ pickerView: UIPickerView) -> Int {
        return 1
    }
    
    // The number of rows of data
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerChoices.count
    }
    
    // The data to return for the row and component (column) that's being passed in
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        self.selectedScope = row
        doSearch()
        return pickerChoices[row]
    }
    func pickerView(_ pickerView: UIPickerView, didSelect numbers: [Int]) {
        print(numbers)
    }
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if segue.identifier == "ShowDetail" {
            let wrDetailViewController = segue.destination as! WikiResultViewController
            // Get the cell that generated this segue.
            if let selectedMealCell = sender as? WikiResultTableViewCell {
                let indexPath = tableView.indexPath(for: selectedMealCell)!
                let selectedWikiResult = self.searchResults[(indexPath as NSIndexPath).row]
                wrDetailViewController.wikiResult = selectedWikiResult
                wrDetailViewController.searchLangs = self.selectedLangs
                wrDetailViewController.title = (selectedWikiResult.terms[self.selectedLangs[0]] ?? "") + " " + (selectedWikiResult.terms[self.selectedLangs[1]] ?? "")
            }
        }
    }
}

// http://stackoverflow.com/questions/28785715/how-to-display-an-activity-indicator-with-text-on-ios-8-with-swift
@available(iOS 13.0, *)
class ProgressHUD: UIVisualEffectView {
    
    var text: String? {
        didSet {
            label.text = text
        }
    }
    let activityIndictor: UIActivityIndicatorView = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.medium)
    let label: UILabel = UILabel()
    let blurEffect = UIBlurEffect(style: .dark)
    let vibrancyView: UIVisualEffectView
    
    init(text: String) {
        self.text = text
        self.vibrancyView = UIVisualEffectView(effect: UIVibrancyEffect(blurEffect: blurEffect))
        super.init(effect: blurEffect)
        self.setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.text = ""
        self.vibrancyView = UIVisualEffectView(effect: UIVibrancyEffect(blurEffect: blurEffect))
        super.init(coder: aDecoder)
        self.setup()
        
    }
    
    func setup() {
        contentView.addSubview(vibrancyView)
        vibrancyView.contentView.addSubview(activityIndictor)
        vibrancyView.contentView.addSubview(label)
        activityIndictor.startAnimating()
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        if let superview = self.superview {
            
            let width = superview.frame.size.width / 1.7
            let height: CGFloat = 75.0
            self.frame = CGRect(x: superview.frame.size.width / 2 - width / 2,
                                y: superview.frame.height / 2 - height,
                                width: width,
                                height: height)
            vibrancyView.frame = self.bounds
            
            let activityIndicatorSize: CGFloat = 40
            activityIndictor.frame = CGRect(x: 5, y: height / 2 - activityIndicatorSize / 2,
                                            width: activityIndicatorSize,
                                            height: activityIndicatorSize)
            
            layer.cornerRadius = 8.0
            layer.masksToBounds = true
            label.text = text
            label.textAlignment = NSTextAlignment.center
            label.frame = CGRect(x: activityIndicatorSize + 5, y: 0, width: width - activityIndicatorSize - 15, height: height)
            label.textColor = UIColor.gray
            label.font = UIFont.boldSystemFont(ofSize: 16)
            label.lineBreakMode = NSLineBreakMode.byWordWrapping
            label.numberOfLines = 2
        }
    }
    
    func show() {
        self.isHidden = false
    }
    
    func hide() {
        self.isHidden = true
    }
}
