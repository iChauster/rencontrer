//
//  CalendarControllerViewController.swift
//  recontrer
//
//  Created by Ivan Chau on 11/4/15.
//  Copyright © 2015 Ivan Chau. All rights reserved.
//

import UIKit
import Foundation

class CalendarControllerViewController: UIViewController, UITableViewDataSource {
    @IBOutlet weak var meetings : UILabel?
    @IBOutlet weak var tableView : UITableView!
   
    private let kKeychainItemName = "recontrer: Gmail API"
    private let kClientID = "637818622405-uddaldcou24vuk3jgsngna1fhs2vapmj.apps.googleusercontent.com"
    private let kClientSecret = "rzdqWU46tNGuNk91Tc70SKln"
    
    private let scopes = [kGTLAuthScopeGmailReadonly]
    
    private let service = GTLServiceGmail()
    var messagesCount = 0
    var doneCount = 0
    var messagesArray = NSMutableArray()
    // When the view loads, create necessary subviews
    // and initialize the Gmail API service
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView!.dataSource = self;
        self.service.authorizer = GTMOAuth2ViewControllerTouch.authForGoogleFromKeychainForName(
            kKeychainItemName,
            clientID: kClientID,
            clientSecret: kClientSecret
        )
        
    }
    
    // When the view appears, ensure that the Gmail API service is authorized
    // and perform API calls
    override func viewDidAppear(animated: Bool) {
        if let authorizer = service.authorizer,
            canAuth = authorizer.canAuthorize where canAuth {
                fetchMessages()
        } else {
            presentViewController(
                createAuthController(),
                animated: true,
                completion: nil
            )
        }
    }
    
    
    // Construct a query and get a list of upcoming labels from the gmail API
    func fetchMessages() {
        let em = GTLQueryGmail.queryForUsersMessagesList()
        service.executeQuery(em,
            delegate: self,
            didFinishSelector : "logResultWithTicket:finishedWithObject:error:")
        
    }
    
    func logResultWithTicket(ticket : GTLServiceTicket,
        finishedWithObject messResponse : GTLGmailListMessagesResponse,
        error : NSError?) {
            if let error = error {
                showAlert("Error", message: error.localizedDescription)
            }
            if !messResponse.messages.isEmpty {
                for message in messResponse.messages as! [GTLGmailMessage]{
                    messagesCount = messResponse.messages.count
                    let identity = message.identifier
                    let search = GTLQueryGmail.queryForUsersMessagesGet()
                    search.identifier = identity
                    service.executeQuery(search,
                        delegate: self,
                        didFinishSelector: "parseWithTicket:finishedWithObject:error:")
                }
            }else{
                NSLog("Bad")
            }
    }
    func parseWithTicket(ticket : GTLServiceTicket, finishedWithObject eachMessageResponse : GTLGmailMessage, error : NSError?) {
        if let error = error {
            showAlert("Error 2", message: error.localizedDescription)
            return
        } else {
            parseMailInfo(eachMessageResponse)
        }
    }
    
    func parseMailInfo(mailInfo : GTLGmailMessage){
        doneCount++
        let labelId = mailInfo.labelIds[0] as! String
        if labelId == "INBOX" {
            let mailInformationDict = NSMutableDictionary()
            mailInformationDict.setValue(mailInfo.snippet as String, forKey: "snippet")
            mailInformationDict.setValue(mailInfo.identifier as String, forKey: "gmailId")
            mailInformationDict.setValue(mailInfo.internalDate, forKey: "internaldate")
            
            let payloadArray = mailInfo.payload.headers as NSArray
            
            for obj in payloadArray {
                let payloadObj = obj as! GTLGmailMessagePartHeader
                if payloadObj.name == "Subject" {
                    mailInformationDict.setValue(payloadObj.value, forKey: "subject")
                }
                
                if payloadObj.name == "From" {
                    let fromStr = payloadObj.value
                    let index2 = fromStr.rangeOfString("<", options: .BackwardsSearch)?.startIndex
                    var substring2 = ""
                    if index2 != nil {
                        substring2 = fromStr.substringToIndex(index2!)
                    } else {
                        substring2 = fromStr as String
                    }
                    
                    mailInformationDict.setValue(substring2, forKey: "from")
                }
                
                if payloadObj.name == "To" {
                    let fromStr = payloadObj.value
                    let index2 = fromStr.rangeOfString("<", options: .BackwardsSearch)?.startIndex
                    var substringTo = ""
                    if index2 != nil {
                        substringTo = fromStr.substringToIndex(index2!)
                    } else {
                        substringTo = fromStr as String
                    }
                    
                    mailInformationDict.setValue(substringTo, forKey: "to")
                }
            }
            var parts = mailInfo.payload.parts
            var decodedBody: NSString?
            if parts != nil {
                let body: AnyObject? = parts[0].valueForKey("body")
                if body!.valueForKey("data") != nil {
                    var base64DataString =  body!.valueForKey("data") as! String
                    base64DataString = base64DataString.stringByReplacingOccurrencesOfString("_", withString: "/", options: NSStringCompareOptions.LiteralSearch, range: nil)
                    base64DataString = base64DataString.stringByReplacingOccurrencesOfString("-", withString: "+", options: NSStringCompareOptions.LiteralSearch, range: nil)
                    
                    let decodedData = NSData(base64EncodedString: base64DataString, options:NSDataBase64DecodingOptions(rawValue: 0))
                    decodedBody = NSString(data: decodedData!, encoding: NSUTF8StringEncoding)
                    mailInformationDict.setValue(decodedBody, forKey: "body")
                }
                
            }
            messagesArray.addObject(mailInformationDict)
        }
        if messagesCount == doneCount{
            doneCount = 0
            self.findMeetings(messagesArray)
        }
        
        
        
    }
    // Creates the auth controller for authorizing access to Gmail API
    private func createAuthController() -> GTMOAuth2ViewControllerTouch {
        //let scopeString = " ".join(scopes)
        let scopeString = scopes.joinWithSeparator(" ")
        return GTMOAuth2ViewControllerTouch(
            scope: scopeString,
            clientID: kClientID,
            clientSecret: kClientSecret,
            keychainItemName: kKeychainItemName,
            delegate: self,
            finishedSelector: "viewController:finishedWithAuth:error:"
        )
    }
    
    // Handle completion of the authorization process, and update the Gmail API
    // with the new credentials.
    func viewController(vc : UIViewController,
        finishedWithAuth authResult : GTMOAuth2Authentication, error : NSError?) {
            
            if let error = error {
                service.authorizer = nil
                showAlert("Authentication Error", message: error.localizedDescription)
                return
            }
            
            service.authorizer = authResult
            dismissViewControllerAnimated(true, completion: nil)
    }
    
    // Helper for showing an alert
    func showAlert(title : String, message: String) {
        let alert = UIAlertView(
            title: title,
            message: message,
            delegate: nil,
            cancelButtonTitle: "OK"
        )
        alert.show()
    }
    func findMeetings(meetingsArray : NSMutableArray){
        //algorithm
        for message in meetingsArray{
            let dictionary = NSMutableDictionary.init(dictionary: message as! NSMutableDictionary)
            if dictionary.objectForKey("body") != nil {
                let string = dictionary.objectForKey("body") as! String
                if string.rangeOfString("tomorrow") != nil && string.rangeOfString("meeting") != nil{
                    NSLog(string)
                    let text = string
                    let range: Range<String.Index> = text.rangeOfString("meeting")!
                    let index: Int = text.startIndex.distanceTo(range.startIndex) //will call successor/predecessor several t
                    NSLog(index.description)
                    let int = index + 30
                    let rtext = Range(start: text.startIndex.advancedBy(index - 20),
                        end: text.startIndex.advancedBy(int))
                    let snippString = text.substringWithRange(rtext)
                    NSLog(snippString)
                    
                }
            }
        }
    }
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell:MeetingTableViewCell = self.tableView.dequeueReusableCellWithIdentifier("MeetCell") as! MeetingTableViewCell
        cell.dateTime?.text = "Home : November 28, 2015"
        cell.from?.text = "Myself"
        cell.dateSent?.text = "11.27.15"
        return cell
    }
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

