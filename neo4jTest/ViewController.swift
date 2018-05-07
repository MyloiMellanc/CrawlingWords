//
//  ViewController.swift
//  neo4jTest
//
//  Created by Myloi Mellanc on 2018. 3. 1..
//  Copyright © 2018년 MyloiMellanc. All rights reserved.
//


import Cocoa
import AppKit
import WebKit
import Theo
//import CSV
import Kanna
import PackStream
import Bolt




extension String {
    var isKorean : Bool {
        get {
            return !isEmpty && range(of: "[^ㄱ-힣0-9 ]", options: .regularExpression) == nil
        }
    }
}


class ViewController: NSViewController, WKNavigationDelegate {

    @IBOutlet weak var targetBase: NSTextField!
    @IBOutlet weak var count: NSTextField!
    @IBOutlet weak var creationCount: NSTextField!
    
    var client : BoltClient? = nil
    
    func connectDatabase(host : String, portNumber : Int, user : String, password : String) throws {
        client = try BoltClient(hostname: host, port: portNumber, username: user, password: password, encrypted: true)
            
        client!.connect()
    }
    
    func createNewNodeInDatabase(text : String) throws {
        let node = Node(label: "Base", properties: ["Name" : text])
        
        let result = client!.createNodeSync(node: node)
        
        switch result {
        case let .failure(error):
            print(error.localizedDescription)
        default:
            break
        }
    }
    
    func mergeNewNodeInDatabase(text : String) {
        let cypher = "MERGE (:Base {Name : \(text)})"
        
        client!.executeCypherSync(cypher)
    }
    
    
    
    
    func createRelationInDatabase(base : String, target : String) {
        let query = """
                    MATCH (a:Base), (b:Base)
                    WHERE a.Name = '\(base)' AND b.Name = '\(target)'
                    MERGE (a)-[r:BaseLine]->(b)
                    RETURN r
                    """
        
        client!.executeCypherSync(query)
        
        
        self.creationCount.intValue = self.creationCount.intValue + 1
    }
    
    func endLining(base : String) {
        let query = "MATCH (a:Base) WHERE a.Name = '\(base)' SET a.Line = true RETURN a"
        
        client!.executeCypherSync(query)
    }
    
    
    var webView: WKWebView?
    var base : String?
    
    func loadRelatedWordByURL(text : String) {
        self.base = text
        self.targetBase.stringValue = text
        
        let url_base = "https://www.google.co.kr/search?q=\(text)&source=lnms&tbm=isch&sa=X&ved=0ahUKEwic-taB9IXVAhWDHpQKHXOjC14Q_AUIBigB&biw=1842&bih=990"
        
        let url_str = url_base.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        let url = URL(string: url_str!)
        
        let req = URLRequest(url: url!)
        
        self.webView?.load(req)
    }

    
    var workOn : Bool = true
    
    func startMakeRelation() {
        if self.workOn == true {
            
            let num = arc4random() % 150000
            let query = "MATCH (a:Base) WHERE NOT (a)-[]-() AND a.Line = false RETURN a.Name SKIP \(num) LIMIT 1;"
            
            
            
            if let result = client?.executeCypherSync(query) {
                let text = (result.value?.rows[0].first?.value)! as! String
                
                self.loadRelatedWordByURL(text: text)
            }
        }
    }
    
    
    
    @IBAction func stopAction(_ sender: Any) {
        self.workOn = false
    }
    
    
    
    
    
    var htmldata : String?
    
    
    
    /*
     *
     *  비동기 방식의 구글 검색결과를 위한 웹 페이지 로드 후의 콜백 함수
     *  로드 후, html 파싱을 통한 연관 태그 단어 저장 요청
     *
    */
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let baseStr = self.base
        
        webView.evaluateJavaScript("document.documentElement.outerHTML.toString()",
                                   completionHandler: { (html: Any?, error: Error?) in
                                    self.htmldata = html as? String
                                    
                                    
                                    do {
                                        let doc = try HTML(html: self.htmldata!, encoding: .utf8)
                                        
                                        for link in doc.css("a")
                                        {
                                            if link["data-ident"] != nil {
                                                let word : String = link.content!
                                                if (word.isKorean == true) {
                                                    if word.contains(" ") == true {
                                                        let arr = word.components(separatedBy: " ")
                                                        for relatedWord in arr {
                                                            self.createRelationInDatabase(base: baseStr!, target: relatedWord)
                                                        }
                                                    }
                                                    else {
                                                        self.createRelationInDatabase(base: baseStr!, target: word)
                                                    }
                                                }
                                            }
                                        }
                                    } catch {
                                        print("web error")
                                    }
                                    
        })
        
        self.endLining(base: baseStr!)
        
        
        //서버 요청 부하 감소를 위한 딜레이 설정
        sleep(2)
        
        
        
        
        
        
        self.count.intValue = self.count.intValue + 1
        
        
        //if next node exists, go loading url
        //정지 명령이 없을 시, 페이지 요청 지속 수행
        self.startMakeRelation()
        
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Connect Database
        do {
            try self.connectDatabase(host: "localhost", portNumber: 7687, user: "neo4j", password: "flrndnqk23")
        }
        catch {
            print("Connection Error")
            return
        }
 
        
        
        
        ////////////////////////////////////////////////////////////////////////
        //Initialize WebView for async web page
        
        self.webView = WKWebView()
        
        self.webView?.navigationDelegate = self
        self.webView?.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_1) AppleWebKit/604.3.5 (KHTML, like Gecko) Version/11.0.1 Safari/604.3.5"
        
        self.count.intValue = 0
        self.creationCount.intValue = 0
        
        
        
        
        //Start searching
        self.startMakeRelation()
 
        ////////////////////////////////////////////////////////////////////////
        
    }


}








