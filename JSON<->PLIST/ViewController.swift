//
//  ViewController.swift
//  JSON<->PLIST
//
//  Created by 谭钧豪 on 16/6/23.
//  Copyright © 2016年 谭钧豪. All rights reserved.
//

import Cocoa

class ViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, XMLParserDelegate {
    
    var dataBase:OpaquePointer? = nil
    let dataBasePath = Bundle.main().resourcePath!+"/store.db"
    var cPath:[CChar]!
    var datas:NSMutableArray = NSMutableArray()
    
    @IBOutlet weak var tableView:NSTableView!
    @IBOutlet var inputTextView:NSTextView!
    @IBOutlet var outputTextView:NSTextView!

    

    override func viewDidLoad() {
        super.viewDidLoad()
        inputTextView.isAutomaticSpellingCorrectionEnabled = false
        inputTextView.isVerticallyResizable = true
        outputTextView.isAutomaticSpellingCorrectionEnabled = false
        self.title = "HI"
        print("数据库文件路径"+dataBasePath)
        if FileManager.default().fileExists(atPath: dataBasePath){
            cPath = dataBasePath.cString(using: String.Encoding.utf8)
            if sqlite3_open(cPath, &dataBase)==SQLITE_OK{
                var errmsg:UnsafeMutablePointer<Int8>?
                let createsql = "CREATE TABLE IF NOT EXISTS INFO(ID INTEGER PRIMARY KEY AUTOINCREMENT,JSON TEXT,PLIST TEXT)".cString(using: String.Encoding.utf8)!
                if sqlite3_exec(dataBase, createsql, nil, nil, &errmsg) != SQLITE_OK{
                    print("创建失败")
                }else{
                    print("创建成功")
                }
            }else{
                print("打开数据库文件失败")
            }
        }else{
            print("文件不存在")
        }
        // Do any additional setup after loading the view.
    }
    
    @IBAction func convert(_ sender: NSButton) {
        if plistToJsonButton.state == 1{
            plistToJson()
        }else if jsonToPlistButton.state == 1{
            jsonToPlist()
        }else{
            print("请选择类型")
        }
    }
    

    
    
//    Foundation类 Core Foundation类型 XML标签 储存格式
//    NSString CFString <string> UTF-8编码的字符串
//    NSNumber CFNumber <real>, <integer> 十进制数字符串
//    NSNumber CFBoolean <true />, or <false /> 无数据（只有标签）
//    NSDate CFDate <date> ISO8601格式的日期字符串
//    NSData CFData <data> Base64编码的数据
//    NSArray CFArray <array> 可以包含任意数量的子元素
//    NSDictionary CFDictionary <dict> 交替包含<key>标签和plist元素标签
    
    func plistType(object:AnyObject) -> (String,Bool){
        if let classForCoder = object.classForCoder{
            if "\(classForCoder)".contains("String"){
                return ("string",true)
            }else if "\(classForCoder)".contains("Number"){
                if "\(object)".contains("."){
                    return ("real",true)
                }else{
                    return ("integer",true)
                }
            }else if "\(classForCoder)".contains("Date"){
                return ("date",true)
            }else if "\(classForCoder)".contains("Data"){
                return ("data",true)
            }else if "\(classForCoder)".contains("Array"){
                return ("array",false)
            }else if "\(classForCoder)".contains("Dict"){
                return ("dict",false)
            }else{
                print(classForCoder)
            }
        }
        return ("value",true)
    }
    
    
    func jsonDeal(object:AnyObject) -> String{
        var result = ""
        if object.isKind(of: NSDictionary.self){
            result = "<dict>"
            for (key,value) in object as! NSDictionary{
                let (type,canBeValue) = self.plistType(object: value)
                if canBeValue{
                    result += "<key>\(key)</key><\(type)>\(value)</\(type)>"
                }else{
                    result += "<key>\(key)</key>"+jsonDeal(object: value)
                }
            }
            result += "</dict>"
            return result
        }else if object.isKind(of: NSArray.self){
            result = "<array>"
            for element in object as! NSArray{
                let (type,canBeValue) = self.plistType(object: element)
                if canBeValue{
                    result += "<\(type)>\(element)</\(type)>"
                }else{
                    result += jsonDeal(object: element)
                }
            }
            result += "</array>"
            return result
        }else{
            return "\(object)"
        }
    }
    
    func jsonToPlist(){
        let inputString = inputTextView.string!
        var jsonObject:AnyObject?
        var outputString = ""
        do{
            jsonObject = try JSONSerialization.jsonObject(with: inputString.data(using: String.Encoding.utf8)!, options: JSONSerialization.ReadingOptions.mutableLeaves)
            outputString = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">"
            if jsonObject != nil{
                outputString = outputString+jsonDeal(object: jsonObject!)+"</plist>"
            }else{
                outputString = "数据格式出错，请确认数据格式是否正确"
            }
        }catch{
            outputString = "数据出错，错误原因:\((error as NSError).description)"
        }
        outputTextView.string = outputString
    }
    
    var jsonString:String = ""
    func plistToJson(){
        jsonString = ""
        let inputString = inputTextView.string!
        let parser = XMLParser(data: inputString.data(using: String.Encoding.utf8)!)
        parser.delegate = self
        parser.parse()
        
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: NSError) {
        jsonString = parseError.description
    }

    
    var keyNeedComma = [Bool]()
    var arrayNeedComma = [Int:Int]()
    var curArrayIncreate = 0
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        
        if keyNeedComma.count != 0{
            if !elementName.contains("key"){
                keyNeedComma.removeFirst()
            }
        }
        
        if arrayNeedComma.count != 0{
            if !elementName.contains("array"){
                arrayNeedComma[curArrayIncreate-1]! += 1
            }
        }
        
        if elementName.contains("dict"){
            jsonString += "{"
        }else if elementName.contains("array"){
            arrayNeedComma[curArrayIncreate] = 0
            curArrayIncreate += 1
            jsonString += "["
        }else if elementName.contains("string"){
            jsonString += "\""
        }else if elementName.contains("key"){
            if keyNeedComma.count > 0{
                jsonString += ","
                keyNeedComma.removeFirst()
            }
            jsonString += "\""
            keyNeedComma.append(true)
            keyNeedComma.append(true)
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        jsonString += string
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName.contains("dict"){
            jsonString += "}"
        }else if elementName.contains("array"){
            curArrayIncreate -= 1
            arrayNeedComma.removeValue(forKey: curArrayIncreate)
            if jsonString.characters.last == ","{
                jsonString.remove(at: jsonString.index(before: jsonString.endIndex))
            }
            jsonString += "]"
        }else if elementName.contains("key"){
            jsonString += "\":"
        }else if elementName.contains("string"){
            jsonString += "\""
        }
        
        if arrayNeedComma.count != 0{
            if !elementName.contains("array"){
                arrayNeedComma[curArrayIncreate-1]! -= 1
                if arrayNeedComma[curArrayIncreate-1] == 0{
                    jsonString += ","
                }
            }
        }
    }
    
    
    func parserDidEndDocument(_ parser: XMLParser) {
        outputTextView.string = jsonString
    }
    
    
    
    
    @IBOutlet weak var jsonToPlistButton: NSButton!
    @IBOutlet weak var plistToJsonButton: NSButton!
    
    @IBAction func select(_ sender: NSButtonCell) {
        if sender.tag == 1{
            plistToJsonButton.cell?.isSelectable = false
        }else{
            jsonToPlistButton.cell?.isSelectable = false
        }
    }
    
    
    func getData(){
        var prepareStatement:OpaquePointer?
        if sqlite3_open(cPath, &dataBase)==SQLITE_OK{
            let searchsql = "SELECT * FROM INFO".cString(using: String.Encoding.utf8)
            datas = NSMutableArray()
            if sqlite3_prepare_v2(dataBase, searchsql, -1, &prepareStatement, nil)==SQLITE_OK{
                while sqlite3_step(prepareStatement)==SQLITE_ROW{
                    let dic = NSMutableDictionary()
                    let infoID = NSNumber(value: sqlite3_column_int(prepareStatement, 0))
                    let jsonString = String(sqlite3_column_text(prepareStatement, 1)) as NSString
                    let plistString = String(sqlite3_column_text(prepareStatement, 2)) as NSString
                    dic.addEntries(from: ["id":infoID])
                    dic.addEntries(from: ["json":jsonString])
                    dic.addEntries(from: ["plist":plistString])
                    datas.add(dic)
                }
            }
        }
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return datas.count
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}








