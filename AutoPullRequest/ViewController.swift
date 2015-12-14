//
//  ViewController.swift
//  AutoPullRequest
//
//  Created by willsbor Kang on 2015/12/7.
//  Copyright © 2015年 gogolook. All rights reserved.
//

import Cocoa
import SSKeychain

class ViewController: NSViewController, NSTextFieldDelegate {
    @IBOutlet weak var githubAccountTextField: NSTextField!
    @IBOutlet weak var githubPasswordTextField: NSSecureTextField!
    @IBOutlet weak var githubRepoTextField: NSTextField!
    @IBOutlet weak var githubRepoBranchTextField: NSTextField!
    @IBOutlet weak var sourceDirTextField: NSTextField!
    @IBOutlet weak var workspaceTextField: NSTextField!
    @IBOutlet weak var processingAnimationIndicator: NSProgressIndicator!
    @IBOutlet weak var applyButton: NSButton!
    @IBOutlet weak var commitMessageTextField: NSTextField!
    @IBOutlet weak var sourceBrowseButton: NSButton!
    @IBOutlet weak var resetButton: NSButton!
    @IBOutlet weak var scriptButton: NSButton!
    @IBOutlet weak var logMessageTestScroll: NSScrollView!
    
    var repo_path = ""
    var repo_branch = ""
    
    var github_user = ""
    var github_password = ""
    
    var source_dir = ""
    var workspace_dir = ""
    var commit_message = ""
    
    //var python_script = "/Users/willsborkang/Documents/gogolook/iOS/XcassetsOven/AutoPullRequest.py"
    var python_script: String = "AutoPullRequest.py";
    
    func resetValue() {
        self.repo_path = "https://github.com/Gogolook-Inc/DesignImages.git"
        self.repo_branch = "whoscall-ios"
        
        self.github_user = "designer.gogolook@gmail.com"
        self.github_password = ""
        
        self.source_dir = ""
        self.workspace_dir = "/tmp/autopullrequest.workspace"
        
        self.representedObject = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.loadValues()

        // Do any additional setup after loading the view.
        
        self.workspaceTextField.enabled = false
        self.sourceDirTextField.enabled = false
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "controlTextDidChange:", name: NSControlTextDidChangeNotification, object: nil)
        
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
            self.githubAccountTextField.stringValue = self.github_user
            self.githubPasswordTextField.stringValue = self.github_password
            self.githubRepoTextField.stringValue = self.repo_path
            self.githubRepoBranchTextField.stringValue = self.repo_branch
            self.sourceDirTextField.stringValue = self.source_dir
            self.workspaceTextField.stringValue = self.workspace_dir
            self.commitMessageTextField.stringValue = self.commit_message
        }
    }
    
    override func controlTextDidChange(obj: NSNotification) {
        self.github_user = self.githubAccountTextField.stringValue
        self.github_password = self.githubPasswordTextField.stringValue
        self.repo_path = self.githubRepoTextField.stringValue
        self.repo_branch = self.githubRepoBranchTextField.stringValue
        self.source_dir = self.sourceDirTextField.stringValue
        self.workspace_dir = self.workspaceTextField.stringValue
        self.commit_message = self.commitMessageTextField.stringValue
        
        if let object = obj.object where object as! NSObject == self.githubAccountTextField {
            let password = SSKeychain.passwordForService("AutoPullRequest", account: self.github_user)
            if password != nil {
                self.github_password = password
                self.githubPasswordTextField.stringValue = self.github_password
            }
        }
    }
    
    internal func control(control: NSControl, textShouldBeginEditing fieldEditor: NSText) -> Bool {
        
        if control == self.sourceDirTextField {
            return false
        }
        else if control == self.workspaceTextField {
            return false
        }
        
        return true
    }
    
    func getNowDir() -> String {
        let pipe = NSPipe()
        let file = pipe.fileHandleForReading
        
        let task = NSTask()
        task.launchPath = "/bin/pwd"
        task.arguments = []
        task.standardOutput = pipe
        
        task.launch()
        
        let data = file.readDataToEndOfFile()
        file.closeFile()
        
        if let result = String(data: data, encoding: NSUTF8StringEncoding) {
//            let range =
//            var lenght = result.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) - 1
            let sub = result.substringToIndex(result.endIndex.advancedBy(-1))
            print("result = \(sub)")
            print("=========\n\n")
            return sub
        }
        else {
            return "."
        }
    }
    
    func exePython(command: [String]) -> String {
        var log = ""
        log += "=========\nexec = \(command.joinWithSeparator(" "))" + "\n"
        //let pid = NSProcessInfo.processInfo().processIdentifier
        let pipe = NSPipe()
        let file = pipe.fileHandleForReading
        let errorpipe = NSPipe()
        let errorfile = errorpipe.fileHandleForReading
        
        let task = NSTask()
        task.launchPath = "/usr/bin/python"
        task.arguments = command
        task.standardOutput = pipe
        task.standardError = errorpipe
        
        task.launch()
        
        let data = file.readDataToEndOfFile()
        file.closeFile()
        
        let errordata = errorfile.readDataToEndOfFile()
        errorfile.closeFile()
        
        log += "finished [\(command.joinWithSeparator(" "))]" + "\n"
        
        if let result = String(data: data, encoding: NSUTF8StringEncoding) {
            log += "result = \(result)" + "\n"
            log += "=========\n\n" + "\n"
        }
        if let errorResult = String(data: errordata, encoding: NSUTF8StringEncoding) {
            log += "errorResult = \(errorResult)" + "\n"
            log += "=========\n\n" + "\n"
        }
        
        log = log.stringByReplacingOccurrencesOfString(self.github_password, withString: "##########")
        return log
    }
    
    func _runCommand(launchPath: String, arguments: [String]) -> (errordata: NSData, data: NSData) {
        let pipe = NSPipe()
        let file = pipe.fileHandleForReading
        let errorpipe = NSPipe()
        let errorfile = errorpipe.fileHandleForReading
        
        let task = NSTask()
        task.launchPath = launchPath
        task.arguments = arguments
        task.standardOutput = pipe
        task.standardError = errorpipe
        
        task.launch()
        
        let data = file.readDataToEndOfFile()
        file.closeFile()
        
        let errordata = errorfile.readDataToEndOfFile()
        errorfile.closeFile()

        return (data, errordata)
    }
    
    func _checkAndInstall(finishedBlock: (Void) -> Void) {
        
        let (_, errordata) = self._runCommand("/usr/bin/hash", arguments: ["hub"])
        
        if let errorResult = String(data: errordata, encoding: NSUTF8StringEncoding) {
            if errorResult != "" {
                
                
                let alert = NSAlert()
                alert.addButtonWithTitle("install")
                alert.addButtonWithTitle("cancel")
                alert.messageText = "please install \"hub\" first\nhttps://github.com/github/hub"
                alert.alertStyle = .WarningAlertStyle
                
                if (alert.runModal() == NSAlertFirstButtonReturn) {
                    let (_, installErrorResult) = self._runCommand("/usr/bin/osascript", arguments: ["-e", "do shell script \"gem install hub\" with administrator privileges"])
                    
                    if let errorResult = String(data: installErrorResult, encoding: NSUTF8StringEncoding) {
                        if errorResult == "" {
                            let alert = NSAlert()
                            alert.addButtonWithTitle("OK")
                            alert.messageText = "install hub success"
                            alert.alertStyle = .WarningAlertStyle
                            
                            if (alert.runModal() == NSAlertFirstButtonReturn) {
                                finishedBlock()
                            }
                        }
                        else {
                            let alert = NSAlert()
                            alert.addButtonWithTitle("OK")
                            alert.messageText = "install hub success failed"
                            alert.alertStyle = .WarningAlertStyle
                            
                            alert.runModal()
                        }
                    }
                    else {
                        let alert = NSAlert()
                        alert.addButtonWithTitle("OK")
                        alert.messageText = "install hub success failed[" + errorResult + "]"
                        alert.alertStyle = .WarningAlertStyle
                        
                        alert.runModal()
                    }
                }
            }
            else {
                finishedBlock()
            }
        }
        else {
            finishedBlock()
        }
    }
    
    func _valueCheck(control: NSControl, message: String, condition: ((Void) -> Bool)) -> Bool {
        if condition() {
            let alert = NSAlert()
            alert.addButtonWithTitle("OK")
            alert.messageText = message
            alert.alertStyle = .WarningAlertStyle
            
            if (alert.runModal() == NSAlertFirstButtonReturn) {
                control.becomeFirstResponder()
            }
            return false
        }
        
        return true
    }
    
    @IBAction func clickAutoPullRequestButton(sender: AnyObject) {
        let pannel = NSOpenPanel()
        pannel.canChooseFiles = true
        pannel.canChooseDirectories = false
        pannel.canCreateDirectories = false
        pannel.allowsMultipleSelection = false
        pannel.allowedFileTypes = ["py"]
        
        let clicked = pannel.runModal()
        
        if clicked == NSFileHandlingPanelOKButton {
            if let url = pannel.URLs.first {
                var filePath = url.absoluteString
                filePath = filePath.stringByReplacingOccurrencesOfString("file://", withString: "")
                self.python_script = filePath
            }
        }
    }
    
    @IBAction func clickResetButton(sender: AnyObject) {
        let alert = NSAlert()
        alert.addButtonWithTitle("Reset")
        alert.addButtonWithTitle("Cancel")
        alert.messageText = "Reset Value to Default?"
        alert.alertStyle = .WarningAlertStyle
        
        if (alert.runModal() == NSAlertFirstButtonReturn) {
            self.resetValue()
            self.saveValues()
        }
        
    }
    
    @IBAction func clickBrowse(sender: AnyObject) {
        let pannel = NSOpenPanel()
        pannel.canChooseFiles = false
        pannel.canChooseDirectories = true
        pannel.canCreateDirectories = true
        pannel.allowsMultipleSelection = false
        
        let clicked = pannel.runModal()
        
        if clicked == NSFileHandlingPanelOKButton {
            if let url = pannel.URLs.first {
                var filePath = url.absoluteString
                filePath = filePath.stringByReplacingOccurrencesOfString("file://", withString: "")
                self.sourceDirTextField.stringValue = filePath
                self.source_dir = self.sourceDirTextField.stringValue
            }
        }
    }

    @IBAction func clickApply(sender: AnyObject) {
        self._checkAndInstall { () -> Void in
            self._clickApply(sender)
        }
    }
    
    func _clickApply(sender: AnyObject) {

        if !self._valueCheck(self.githubAccountTextField, message: "account is Empty", condition: {
            return self.github_user.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) == 0
        }) {
            return
        }

        if !self._valueCheck(self.githubPasswordTextField, message: "password is Empty", condition: {
            return self.github_password.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) == 0
        }) {
            return
        }
        
        if !self._valueCheck(self.sourceBrowseButton, message: "Select One Source Directory", condition: {
            return self.source_dir.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) == 0
        }) {
            return
        }
        
        if !self._valueCheck(self.commitMessageTextField, message: "Commit Message Can't be empty!!", condition: {
            return self.commit_message.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) == 0
        }) {
            return
        }
        
        self.processingAnimationIndicator.startAnimation(nil)
        self.applyButton.enabled = false
        self.scriptButton.enabled = false
        self.githubAccountTextField.enabled = false
        self.githubPasswordTextField.enabled = false
        self.githubRepoBranchTextField.enabled = false
        self.githubRepoTextField.enabled = false
        self.sourceBrowseButton.enabled = false
        self.commitMessageTextField.enabled = false
        self.resetButton.enabled = false
        
        self.saveValues()
        
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            var log = ""
            if let textView = self.logMessageTestScroll.contentView.documentView as? NSTextView {
                textView.string = log
            }
            

            log += self.exePython([self.python_script, "-c", self.workspace_dir, "--repo", self.repo_path, "--branch", self.repo_branch, "-a", self.github_user, "-x", self.github_password]) + "\n"
            log += self.exePython([self.python_script, "-w", self.workspace_dir, "-u", self.source_dir, "-p", self.commit_message, "--repo", self.repo_path, "--branch", self.repo_branch, "-a", self.github_user, "-x", self.github_password]) + "\n"
            
            if let textView = self.logMessageTestScroll.contentView.documentView as? NSTextView {
                textView.string = log
            }

            print(log)
            
            let alert = NSAlert()
            alert.addButtonWithTitle("OK")
            alert.messageText = "Task Finished"
            alert.alertStyle = .InformationalAlertStyle
            
            alert.runModal()
            
            self.commitMessageTextField.stringValue = ""
            self.commit_message = ""
            self.saveValues()
            
            self.processingAnimationIndicator.stopAnimation(nil)
            self.applyButton.enabled = true
            self.scriptButton.enabled = true
            self.githubAccountTextField.enabled = true
            self.githubPasswordTextField.enabled = true
            self.githubRepoBranchTextField.enabled = true
            self.githubRepoTextField.enabled = true
            self.sourceDirTextField.enabled = true
            self.sourceBrowseButton.enabled = true
            self.commitMessageTextField.enabled = true
            self.resetButton.enabled = true
        }
    }
    
    func saveValues() {
        NSUserDefaults.standardUserDefaults().setObject(self.github_user, forKey: "github_user")
//        NSUserDefaults.standardUserDefaults().setObject(self.github_password, forKey: "")
        NSUserDefaults.standardUserDefaults().setObject(self.repo_path, forKey: "repo_path")
        NSUserDefaults.standardUserDefaults().setObject(self.repo_branch, forKey: "repo_branch")
        NSUserDefaults.standardUserDefaults().setObject(self.source_dir, forKey: "source_dir")
        NSUserDefaults.standardUserDefaults().setObject(self.workspace_dir, forKey: "workspace_dir")
        NSUserDefaults.standardUserDefaults().setObject(self.commit_message, forKey: "commit_message")
        NSUserDefaults.standardUserDefaults().setObject(self.python_script, forKey: "python_script")
        NSUserDefaults.standardUserDefaults().synchronize()
        
        SSKeychain.setPassword(self.github_password, forService: "AutoPullRequest", account: self.github_user)
    }
    
    func loadValues() {
        self.resetValue()
        
        if let value = NSUserDefaults.standardUserDefaults().objectForKey("github_user") {
            self.github_user = value as! String
        }
        
        if let value = NSUserDefaults.standardUserDefaults().objectForKey("repo_path") {
            self.repo_path = value as! String
        }
        if let value = NSUserDefaults.standardUserDefaults().objectForKey("repo_branch") {
            self.repo_branch = value as! String
        }
        if let value = NSUserDefaults.standardUserDefaults().objectForKey("source_dir") {
            self.source_dir = value as! String
        }
        if let value = NSUserDefaults.standardUserDefaults().objectForKey("workspace_dir") {
            self.workspace_dir = value as! String
        }
        if let value = NSUserDefaults.standardUserDefaults().objectForKey("commit_message") {
            self.commit_message = value as! String
        }
        if let value = NSUserDefaults.standardUserDefaults().objectForKey("python_script") {
            self.python_script = value as! String
        }
        else {
            self.python_script = self.getNowDir() + "/" + "AutoPullRequest.py"
        }
        
        let password = SSKeychain.passwordForService("AutoPullRequest", account: self.github_user)
        if password != nil {
            self.github_password = password
            self.githubPasswordTextField.stringValue = self.github_password
        }
        
        self.representedObject = nil
    }
}

