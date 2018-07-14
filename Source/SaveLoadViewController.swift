import UIKit

protocol SLCellDelegate: class {
    func didTapButton(_ sender: UIButton)
}

class SaveLoadCell: UITableViewCell {
    weak var delegate: SLCellDelegate?
    @IBOutlet var loadCell: UIButton!
    @IBAction func buttonTapped(_ sender: UIButton) {  delegate?.didTapButton(sender) }
}

//MARK:-

let versionNumber:Int32 = 0x55aa
let numEntries:Int = 50
var loadNextIndex:Int = -1   // first use will bump this to zero

class SaveLoadViewController: UIViewController,UITableViewDataSource, UITableViewDelegate,SLCellDelegate {
    var cc = Control()
    @IBOutlet var tableView: UITableView!
    
    func numberOfSections(in tableView: UITableView) -> Int { return 1 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { return numEntries }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SLCell", for: indexPath) as! SaveLoadCell
        cell.delegate = self
        cell.tag = indexPath.row
        
        let dateString = loadData(indexPath.row,&cc,false)
        var str:String = ""
        
        if dateString == "**" {
            str = "** unused **"
            cell.loadCell.backgroundColor = UIColor.darkGray
        }
        else {
            str = String(format:"%2d    %@", indexPath.row+1,dateString)
            cell.loadCell.backgroundColor = UIColor(red:0.1, green:0.5, blue:0.4, alpha:1)
        }
        
        cell.loadCell.setTitle(str, for: UIControlState.normal)
        return cell
    }

    func didTapButton(_ sender: UIButton) {
        func getCurrentCellIndexPath(_ sender: UIButton) -> IndexPath? {
            let buttonPosition = sender.convert(CGPoint.zero, to: tableView)
            if let indexPath: IndexPath = tableView.indexPathForRow(at: buttonPosition) {
                return indexPath
            }
            return nil
        }

        if let indexPath = getCurrentCellIndexPath(sender) {
            //Swift.print("Row ",indexPath.row, "        Tag ", sender.tag)
            
            if sender.tag == 0 {
                loadAndDismissDialog(indexPath.row,&control)
                if control.version != versionNumber { vc.randomize() }
            }
            
            if sender.tag == 1 {
                control.version = versionNumber
                saveAndDismissDialog(indexPath.row,control)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
    }

    //MARK:-

    var fileURL:URL! = nil
    let sz = MemoryLayout<Control>.size
    
    func determineURL(_ index:Int) {
        let name = String(format:"Store%d.dat",index)
        fileURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(name)
    }
    
    func saveAndDismissDialog(_ index:Int, _ ctrl:Control) {
        
        let alertController = UIAlertController(title: "Save Settings", message: "Confirm overwrite of Settings storage", preferredStyle: .alert)

        let OKAction = UIAlertAction(title: "Continue", style: .default) { (action:UIAlertAction!) in
            do {
                self.determineURL(index)
                var c = ctrl
                let data = NSData(bytes:&c, length:self.sz)
                
                try data.write(to: self.fileURL, options: .atomic)
            } catch {
                print(error)
            }
            
           self.dismiss(animated: false, completion:nil)
        }
        alertController.addAction(OKAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action:UIAlertAction!) in
            return
        }
        alertController.addAction(cancelAction)
        
        self.present(alertController, animated: true, completion:nil)
    }

    //MARK:-

    var dateString = String("")
    
    @discardableResult func loadData(_ index:Int, _ c: inout Control, _ loadFile:Bool) -> String {
        var dStr = String("**")
        
        determineURL(index)
        
        do {
            let key:Set<URLResourceKey> = [.creationDateKey]
            let value = try fileURL.resourceValues(forKeys: key)
            if let date = value.creationDate { dStr = date.toString() }
        } catch {
            // print(error)
        }

        if loadFile {
            let data = NSData(contentsOf: fileURL)
            data?.getBytes(&c, length:sz)
        }
        
        return dStr
    }
    
    func loadAndDismissDialog(_ index:Int, _ cc: inout Control) {
        loadData(index,&cc,true)
        self.dismiss(animated: false, completion: {()->Void in vc.loadedData() })
    }
    
    //MARK:-
    
    func loadNext() {
        var numTries:Int = 0
        
        while true {
            loadNextIndex += 1
            if loadNextIndex >= numEntries { loadNextIndex = 0 }
            
            determineURL(loadNextIndex)
            let data = NSData(contentsOf: fileURL)
            
            if data != nil {
                data?.getBytes(&control, length:sz)
                vc.loadedData()
                //Swift.print("Loaded (base 0): ",loadNextIndex.description)
                return
            }
            
            numTries += 1       // nothing found?
            if numTries >= numEntries-1 { return }
        }
    }
}

//MARK:-

extension Date {
    func toString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy hh:mm"
        return dateFormatter.string(from: self)
    }
}

