//
//  CalendarControllerViewController.swift
//  rencontrer
//
//  Created by Ivan Chau on 11/4/15.
//  Copyright © 2015 Ivan Chau. All rights reserved.
//

import UIKit
import Foundation
import CVCalendar //Importing Calendar Module
//Delegates allow the ViewController to read and change special classes (UITables, CVCalendars, etc.)
class CalendarControllerViewController: UIViewController, UITableViewDataSource, CVCalendarViewDelegate, CVCalendarMenuViewDelegate {
    //global variables, representing parts in the View :)
    @IBOutlet weak var meetings : UILabel?
    @IBOutlet weak var tableView : UITableView!
    @IBOutlet weak var calendarView : CVCalendarView!
    @IBOutlet weak var calendarMenuView : CVCalendarMenuView!
   
    //Gmail initialization.
    private let kKeychainItemName = "rencontrer: Gmail API"
    private let kClientID = "637818622405-uddaldcou24vuk3jgsngna1fhs2vapmj.apps.googleusercontent.com"
    private let kClientSecret = "rzdqWU46tNGuNk91Tc70SKln"
    
    private let scopes = [kGTLAuthScopeGmailReadonly]
    
    private let service = GTLServiceGmail()
    var messagesCount = 0
    var doneCount = 0
    //MessagesArray is the messages returned from the Gmail API. Eventually we want to save these and only get new ones.
    var messagesArray = NSMutableArray()
    //tableArray is the array of messages that are deemed 'meetings'.
    var tableArray = NSMutableArray()
    // When the view loads, create necessary subviews
    // and initialize the Gmail API service
    
    override func viewDidLoad() {
        //viewDidLoad is a void function that is always called first automatically.
        super.viewDidLoad()
        self.tableView!.dataSource = self;
        //setting the tableView Delegate to the controller
        if let auth = GTMOAuth2ViewControllerTouch.authForGoogleFromKeychainForName(
            kKeychainItemName,
            clientID: kClientID,
            clientSecret: kClientSecret) {
                service.authorizer = auth
        }
        //setting up security gmail api
        
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
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.calendarView!.commitCalendarViewUpdate()
        self.calendarMenuView!.commitMenuViewUpdate()
        NSLog("viewLayedOut")
        //this is when the view lays out its views (the calendar needs this to run properly, otherwise it would be difficult to see)
    }
    func presentationMode() -> CalendarMode{
        NSLog("Presentation Set")
        return .MonthView
    }
    func firstWeekday() -> Weekday{
        NSLog("WeekDay Set")
        return .Sunday
    }
    func dayOfWeekTextColor() -> UIColor {
        return UIColor.whiteColor()
    }
    //above, setting up the basic requirements of being a Calendar Delegate -> you have to fulfill a couple of required functions to set up the Calendar.
    
    // Construct a query and get a list of upcoming labels from the gmail API
    func fetchMessages() {
        let em = GTLQueryGmail.queryForUsersMessagesList()
        service.executeQuery(em,
            delegate: self,
            didFinishSelector : "logResultWithTicket:finishedWithObject:error:")
        
    }
    //Fetching emails from Gmail API ^ with query to server (this only returns object IDS)
    func logResultWithTicket(ticket : GTLServiceTicket,
        finishedWithObject messResponse : GTLGmailListMessagesResponse,
        error : NSError?) {
            if let error = error {
                showAlert("Error", message: error.localizedDescription)
            }
            //if there is no error, read what the server returns. Now, get the contents of every message.
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
            //for every message content returned, dissect it.
            parseMailInfo(eachMessageResponse)
        }
    }
    
    func parseMailInfo(mailInfo : GTLGmailMessage){
        //dissect email
        doneCount++
        let labelId = mailInfo.labelIds[0] as! String
        if labelId == "INBOX" {
            //mailInformationDictionary is a dictionary : it's basically an array of key values. Example : {key : value, key1 : value1}
            let mailInformationDict = NSMutableDictionary()
            mailInformationDict.setValue(mailInfo.snippet as String, forKey: "snippet")
            mailInformationDict.setValue(mailInfo.identifier as String, forKey: "gmailId")
            mailInformationDict.setValue(mailInfo.internalDate, forKey: "internaldate")
            //setting basic info about the message into the dictionary
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
                //getting subject, from, and to from the server. It involves some unwrapping. Setting it as another value in dictionary.
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
                //getting to the actual body of the email (the text part that you're supposed to read), and decoding it.
                
            }
            messagesArray.addObject(mailInformationDict)
            //adding the mailInformationDictionary to the messagesArray as one of the messages We've Received. 
            //This piece of code will repeat for every message returned, as the function will be called more than once.
        }
        if messagesCount == doneCount{
            doneCount = 0
            self.findMeetings(messagesArray)
            //if the messages we pulled from the server is the same as the number that passes through the function, stop
            //now we need to find the emails that are meetings.
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
        //if you haven't signed in, this will generate a view for you to type in credentials.
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
            //credential views!
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
    func findMeetings(meetingsArray : NSMutableArray) {
        //algorithm
        for message in meetingsArray {
            let dictionary = NSMutableDictionary.init(dictionary: message as! NSMutableDictionary)
            if dictionary.objectForKey("body") != nil {
                let string = dictionary.objectForKey("body") as! String
                if string.rangeOfString("tomorrow") != nil && string.rangeOfString("meeting") != nil || string.rangeOfString("appointment") != nil {
                    let tame = NSMutableDictionary()
                    let text = string
                    let range: Range<String.Index> = text.rangeOfString("meeting")!
                    let index: Int = text.startIndex.distanceTo(range.startIndex) //will call successor/predecessor several t
                    let int = index + 30
                    let rtext = Range(start: text.startIndex.advancedBy(index - 20),
                        end: text.startIndex.advancedBy(int))
                    let snippString = text.substringWithRange(rtext)
                    let foo : NSTimeInterval = (dictionary.objectForKey("internaldate") as? Double)! / 1000
                    let date = NSDate(timeIntervalSince1970: foo)
                    tame.setObject(snippString, forKey: "snippet")
                    tame.setObject(dictionary.objectForKey("from")!, forKey:"from")
                    tame.setObject(date.description, forKey: "date")
                    self.tableArray.addObject(tame)
                    // going in to the body and checking if there is the word 'tomorrow' and 'meeting' in the body, taking a part of it, and making another dictionary. Add it to the tableArray!
                }
            }
        }
        //this will allow the tableView to now take the data we just got and put it into cells.
       
        //This function will make the tableView take the updated data from the now-populated array of messages (tableArray)
        self.tableView.reloadData()
    }
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell:MeetingTableViewCell = self.tableView.dequeueReusableCellWithIdentifier("MeetCell") as! MeetingTableViewCell
        let deal = tableArray[indexPath.row]
        /*cell.dateTime?.text = "Home : November 28, 2015"
        cell.from?.text = "Myself"
        cell.dateSent?.text = "11.27.15" */
        cell.from?.text = deal.valueForKey("from") as? String
        cell.dateSent?.text = deal.valueForKey("date") as? String
        cell.snippet?.text = "..." + (deal.valueForKey("snippet") as? String)! + "..."
        //for each object in the dissected emails array, take each of the data and put it in a cell.
        return cell
    }
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableArray.count
        //for each object in the array, make it a row in the tableView
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

