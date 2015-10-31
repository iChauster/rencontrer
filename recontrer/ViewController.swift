//
//  ViewController.swift
//  recontrer
//
//  Created by Ivan Chau on 10/30/15.
//  Copyright © 2015 Ivan Chau. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    private let kKeychainItemName = "Gmail API"
    private let kClientID = "637818622405-uddaldcou24vuk3jgsngna1fhs2vapmj.apps.googleusercontent.com"
    private let kClientSecret = "rzdqWU46tNGuNk91Tc70SKln"
    
    private let scopes = [kGTLAuthScopeGmailReadonly]
    
    private let service = GTLServiceGmail()
    let output = UITextView()
    
    // When the view loads, create necessary subviews
    // and initialize the Gmail API service
    override func viewDidLoad() {
        super.viewDidLoad()
        
        output.frame = view.bounds
        output.editable = false
        output.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0)
        output.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]        
        view.addSubview(output);
        
        GTMOAuth2ViewControllerTouch.authForGoogleFromKeychainForName(
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
                fetchLabels()
        } else {
            presentViewController(
                createAuthController(),
                animated: true,
                completion: nil
            )
        }
    }
    
    // Construct a query and get a list of upcoming labels from the gmail API
    func fetchLabels() {
        output.text = "Getting labels..."
        
        let query = GTLQueryGmail.queryForUsersLabelsList()
        service.executeQuery(query,
            delegate: self,
            didFinishSelector: "displayResultWithTicket:finishedWithObject:error:"
        )
    }
    
    // Display the labels in the UITextView
    func displayResultWithTicket(ticket : GTLServiceTicket,
        finishedWithObject labelsResponse : GTLGmailListLabelsResponse,
        error : NSError?) {
            
            if let error = error {
                showAlert("Error", message: error.localizedDescription)
                return
            }
            
            var labelString = ""
            
            if !labelsResponse.labels.isEmpty {
                labelString += "Labels:\n"
                for label in labelsResponse.labels as! [GTLGmailLabel] {
                    labelString += "\(label.name)\n"
                }
            } else {
                labelString = "No labels found."
            }
            
            output.text = labelString
            
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
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}
