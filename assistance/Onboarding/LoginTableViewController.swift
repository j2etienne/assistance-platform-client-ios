//
//  LoginTableViewController.swift
//  Labels
//
//  Created by Nickolas Guendling on 30/07/15.
//  Copyright © 2015 Darmstadt University of Technology. All rights reserved.
//

import UIKit

import RealmSwift

class LoginTableViewController: UITableViewController {

    @IBOutlet var emailTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    
    override func viewWillAppear(animated: Bool) {
        if let userEmail = NSUserDefaults.standardUserDefaults().stringForKey("UserEmail"), password = NSUserDefaults.standardUserDefaults().stringForKey("UserPassword") {
            self.emailTextField.text = userEmail
            self.passwordTextField.text = password
            signIn(self)
        }
    }
    
    @IBAction func signIn(sender: AnyObject) {
        UserManager().login(emailTextField.text!, password: passwordTextField.text!) {
            result in
            
            do {
                let data = try result()
                
                NSUserDefaults.standardUserDefaults().setObject(self.emailTextField.text, forKey: "UserEmail")
                
                if let dataString = NSString(data: data as! NSData, encoding: NSUTF8StringEncoding) where dataString.length > 0,
                    let dataJSON = try? NSJSONSerialization.JSONObjectWithData(data as! NSData, options: .MutableLeaves) as! NSDictionary,
                    token = dataJSON["token"] as? String {
                        NSUserDefaults.standardUserDefaults().setObject(self.passwordTextField.text, forKey: "UserPassword")
                        NSUserDefaults.standardUserDefaults().setObject(token, forKey: "UserToken")
                }
                
                ModuleManager().resetModules()
                
                self.dismissViewControllerAnimated(true, completion: nil)
                
            } catch ServerConnection.Error.RequestError(let errorCode) {
                
                var errorMessage = "An unknown error occured."
                if let message = ServerConnection.errorMessage[errorCode] {
                    errorMessage = message
                }
                
                let alertController = UIAlertController(title: "Login failed", message: errorMessage, preferredStyle: .Alert)
                let cancelAction = UIAlertAction(title: "Okay", style: .Cancel, handler: nil)
                alertController.addAction(cancelAction)
                
                dispatch_async(dispatch_get_main_queue(), {
                    self.presentViewController(alertController, animated: true, completion: nil)
                })
                
            } catch { }
        }
    }

}
