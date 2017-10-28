import Cocoa


let lastCheckDateKey = "lastCheckDateKey"
let updateIsAvailableKey = "updateIsAvalibleKey"


class MainViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate {

    enum buttonStatusEnum {
      case about
      case downloadApp
      case downloading
    }
    
    @IBOutlet weak var noteTextField: NSTextField!
    @IBOutlet weak var updateButton: CustomButton!
    @IBOutlet weak var activityIndicator: NSProgressIndicator!
    @IBOutlet var resultTextField: NSTextView!
    @IBOutlet weak var currentLanguageButton: NSPopUpButton!
    @IBOutlet weak var targetLanguageButton: NSPopUpButton!
    @IBOutlet weak var languageExchangeButton: NSButton!
    
  
    let updateAvailableText = "New update is available!"
    let aboutText = "About"
  
    var buttonStatus = buttonStatusEnum.about
  
    var currentLanguageValue = "en"
    var targetLanguageValue = "tr"
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let languages = Array(Languages().lanDict.keys).sorted() // get keys and sort
    
    currentLanguageButton.addItems(withTitles: languages)
    currentLanguageButton.selectItem(withTitle: "English")
    
    targetLanguageButton.addItems(withTitles: languages)
    targetLanguageButton.selectItem(withTitle: "Turkish")
    
    noteTextField.delegate = self
    activityIndicator.isDisplayedWhenStopped = false
    
    setButtonTitle(text: aboutText)
  }
  
  override func viewWillAppear() {
    NSApp.activate(ignoringOtherApps: true)
    noteTextField.becomeFirstResponder()
  }
  
  override func viewDidAppear() {
    checkUpdates()
  }

  func setButtonTitle (text: String) {
    let pstyle = NSMutableParagraphStyle()
    pstyle.alignment = .left
    let buttonColor = NSColor(red: 195/255, green: 195/255, blue: 195/255, alpha: 1.0)
    updateButton.attributedTitle = NSAttributedString(string: text, attributes: [ NSAttributedStringKey.foregroundColor: buttonColor,
                                                                                  NSAttributedStringKey.paragraphStyle: pstyle,
                                                                                  NSAttributedStringKey.font: NSFont.boldSystemFont(ofSize: 12)])
  }
  
  func checkUpdates () {
    
    if AppUpdateFunctions().getUpdateStatusFromDisc() {
      buttonStatus = .downloadApp
      setButtonTitle(text: updateAvailableText)
      return
    }
    
    let lastCheckDate = AppUpdateFunctions().getLastCheckDateFromDisc()
    let currentDate = Helper().getCurrentDateWithString()
    
    // checking once a day is enough
    if lastCheckDate == currentDate {
      return
    }
    
    UserDefaults.standard.set(currentDate, forKey: lastCheckDateKey)
    
    AppUpdateFunctions().getUpdateDataFromRemote { (data) in
      if let storeVersion =  AppUpdateFunctions().parseUpdateJsonData(data: data), let currentVersion = Helper().getAppVersion() {
        let updateAvailabilityResult = AppUpdateFunctions().compareVersionStrings(storeVersion: String(storeVersion), currentVersion: currentVersion)
        
        if updateAvailabilityResult {
          
          DispatchQueue.main.async {
            // Update ui on the main thread
            self.buttonStatus = .downloadApp
            self.setButtonTitle(text: self.updateAvailableText)
            UserDefaults.standard.set(true, forKey: updateIsAvailableKey)
          }
        }
      }
    }
  }
  
    @IBAction func textFieldActions(_ sender: NSTextFieldCell) {
        translate(text: noteTextField.stringValue)
    }
  
    @IBAction func currentLanguageButtonPressed(_ sender: NSPopUpButton) {

      currentLanguageValue = Languages().lanDict[(sender.selectedItem?.title ?? "en")] ?? "en"
    }
  
    @IBAction func targetLanguageButtonPressed(_ sender: NSPopUpButton) {

      targetLanguageValue = Languages().lanDict[(sender.selectedItem?.title ?? "tr")] ?? "tr"
    }
    
    @IBAction func languageExchangeButtonPressed(_ sender: NSButton) {
      let currentLanguageHolder = currentLanguageValue
      currentLanguageValue = targetLanguageValue
      targetLanguageValue = currentLanguageHolder
      
      let language = Languages()

      currentLanguageButton.selectItem(withTitle: language.lanDict.allKeys(forValue: currentLanguageValue).first!)
      targetLanguageButton.selectItem(withTitle: language.lanDict.allKeys(forValue: targetLanguageValue).first!)
      
    }
    
    func translate (text: String) {
    
    setActivityIndicatorStartAnimation()
      
    let params = ROGoogleTranslateParams(source: currentLanguageValue,
                                         target: targetLanguageValue,
                                         text:  text)
    
    let translator = ROGoogleTranslate(with: googleApiKey)
    
    translator.translate(params: params) { (result) in
 
      // make UI changes on the main thread
      DispatchQueue.main.async {
            self.setActivityIndicatorStopAnimation()
            self.resultTextField.textContainer?.textView?.string = result
      }
   
    }
  }
  
  
  
  
    
    @IBAction func updateButtonPressed(_ sender: NSButton) {
      
      switch buttonStatus {
      case .downloadApp:
        UserDefaults.standard.set(false, forKey: updateIsAvailableKey)
        setButtonTitle(text: aboutText)
        downloadNewSetupFile()
        break
      case .about:
        launchGithubLink()
        break
      case .downloading:
        break
      }
    }
    
  func launchGithubLink () {
    if let url = URL(string: "https://github.com/furkanhatipoglu/translight"), NSWorkspace.shared.open(url) {
      
    }
  }
  
  
  func downloadNewSetupFile () {

    let errorTitle = "An error occurred"
    let errorOccured = "While downloading the new version, an error occured."
    
    
    let appDownloadUrl = URL(string:  "http://web.itu.edu.tr/hatipoglufu/translight/translight.zip")
    
    // check url is ok.
    if appDownloadUrl == nil {
      _ = self.createAlertView(question: errorTitle, text: errorOccured)
      return
    }
    
   self.setDownloadingProperties()
   
    URLSession.shared.dataTask(with: appDownloadUrl!, completionHandler: { (responseData, response, error) in
      // check response data is nil or not.
      if responseData == nil {
        _ = self.createAlertView(question: errorTitle, text: errorOccured)
      } else {
        
        let documentsPath = NSSearchPathForDirectoriesInDomains(.downloadsDirectory, .userDomainMask, true)[0];
        let filePathUrl = URL(fileURLWithPath: "\(documentsPath)/translight.zip")
        
        DispatchQueue.main.async {
          
          self.setNotDownladingProperties()
          
          // write to downloads folder
          do {
            try responseData?.write(to: filePathUrl, options: .atomic)
            _ = self.createAlertView(question: "The download is complete.", text: "New version of translight app is saved to downloads folder. Just click it.")
          } catch {
            _ = self.createAlertView(question: errorTitle, text: errorOccured)
          }
        }
      }
    }).resume()
  }
  
  func setDownloadingProperties () {
    buttonStatus = .downloading
    setButtonTitle(text: "Downloading")
    setActivityIndicatorStartAnimation()
   }
  
  func setActivityIndicatorStartAnimation () {
    activityIndicator.startAnimation(self)
  }
  
  func setNotDownladingProperties () {
    buttonStatus = .about
    setButtonTitle(text: "About")
    setActivityIndicatorStopAnimation()
  }
  
  func setActivityIndicatorStopAnimation () {
    self.activityIndicator.stopAnimation(self)
  }
  
  func createAlertView(question: String, text: String) -> Bool {
    let alert = NSAlert()
    alert.messageText = question
    alert.informativeText = text
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
    return alert.runModal() == .alertFirstButtonReturn
  }
  
  static func freshController() -> MainViewController {
    let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
    let identifier = NSStoryboard.SceneIdentifier(rawValue: "MainViewController")
    guard let viewcontroller = storyboard.instantiateController(withIdentifier: identifier) as? MainViewController else {
      fatalError("Why cant i find MainViewController? - Check Main.storyboard")
    }
    return viewcontroller
  }

}
