import UIKit
import WebKit
import AVFoundation
import FontAwesome_swift

class ButtonView: UIView {
    var button: UIButton!
    var url: URL!
    var textToSpeak = ""
    var textToSpeakLang = ""
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        layer.zPosition = 100
        let borderAlpha : CGFloat = 0.7
        let cornerRadius : CGFloat = 5.0
        button = UIButton(frame: CGRect(x:0, y:0, width:frame.width, height:frame.height))
        button.layer.zPosition = 10
        button.layer.borderWidth = 1.0
        button.layer.borderColor = UIColor(white: 1.0, alpha: borderAlpha).cgColor
        button.layer.cornerRadius = cornerRadius
        button.backgroundColor = self.tintColor
        button.titleLabel?.font = UIFont.fontAwesome(ofSize: 30, style: .brands)
        button.setTitle(String.fontAwesomeIcon(name: .safari), for: .normal)
        self.addSubview(button)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("Init(coder:) has not been implemented")
    }
}

class WikiResultViewController: UIViewController, WKUIDelegate, WKNavigationDelegate {
    
    var wikiResult: WikiResult?
    var searchLangs = [String]()
    let synth = AVSpeechSynthesizer()
    
    @IBOutlet weak var webView1: WKWebView!
    @IBOutlet weak var webView2: WKWebView!
    
    // UIDocumentInteractionController instance is a class property
    var docController: UIDocumentInteractionController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let webViews = [webView1, webView2]
        for (i, lang) in self.searchLangs.enumerated() {
            let webView = webViews[i]
            var siteUrl = wikiResult!.siteUrls[lang]!
            siteUrl = siteUrl.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!
            let urlPath = "https://\(lang).wikipedia.org/wiki/\(siteUrl)"
            let url = URL(string: urlPath)
            let request = URLRequest(url: url!)
            webView?.uiDelegate = self
            webView?.navigationDelegate = self
            webView?.load(request)
            webView?.layer.zPosition = 1
            
            let safariButtonView = ButtonView(frame: CGRect(x:0, y:0, width:36, height:36))
            safariButtonView.url = url!
            safariButtonView.button.addTarget(self, action: #selector(self.buttonClicked), for: .touchUpInside)
            webView?.addSubview(safariButtonView)
            
            let speakButtonView = ButtonView(frame: CGRect(x:0, y:0, width:36, height:36))
            speakButtonView.textToSpeak = (wikiResult!.terms[lang] ?? "") + ": " + (wikiResult!.descriptions[lang] ?? "")
            speakButtonView.textToSpeakLang = ISO681toBCP47[lang]!
            speakButtonView.button.titleLabel?.font = UIFont.fontAwesome(ofSize: 30, style: .solid)
            speakButtonView.button.setTitle(String.fontAwesomeIcon(name: .volumeUp), for: .normal)
            speakButtonView.button.addTarget(self, action: #selector(self.textToSpeech), for: .touchUpInside)
            webView?.addSubview(speakButtonView)
            
            let views = ["safariButtonView" : safariButtonView, "speakButtonView" : speakButtonView]
            views.forEach { $1.translatesAutoresizingMaskIntoConstraints = false }
            webView?.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:[speakButtonView(36)]-[safariButtonView(36)]-|", options: .alignAllTop, metrics: nil, views: views))
            webView?.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[speakButtonView(36)]-[safariButtonView(36)]-|", options: [], metrics: nil, views: views))
        }
    }
    
    @objc func textToSpeech(sender: UIButton) {
        let utterance = AVSpeechUtterance(string:(sender.superview as! ButtonView).textToSpeak)
        //        utterance.rate = 0.3
        utterance.voice = AVSpeechSynthesisVoice(language: (sender.superview as! ButtonView).textToSpeakLang)
        synth.speak(utterance)
    }
    
    @objc func buttonClicked(sender: UIButton!) {
        UIApplication.shared.open((sender.superview as! ButtonView).url)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript(
            "divs = document.getElementsByClassName( 'banner-container' );" +
            "[].slice.call( divs ).forEach(function(div){ div.style.display = \"none\"; });" +
            "divs = document.getElementsByClassName( 'header' );" +
            "[].slice.call( divs ).forEach(function(div){ div.style.display = \"none\"; });"
        )
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
