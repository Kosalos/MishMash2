import UIKit

class GrammarViewController: UIViewController {
    var sList:[UISegmentedControl]! = nil
    
    @IBOutlet var c1:UISegmentedControl!
    @IBOutlet var c2:UISegmentedControl!
    @IBOutlet var c3:UISegmentedControl!
    @IBOutlet var c4:UISegmentedControl!
    @IBOutlet var c5:UISegmentedControl!
    @IBOutlet var c6:UISegmentedControl!
    @IBOutlet var c7:UISegmentedControl!
    @IBOutlet var c8:UISegmentedControl!
    @IBOutlet var c9:UISegmentedControl!
    @IBOutlet var cA:UISegmentedControl!
    @IBOutlet var cB:UISegmentedControl!
    @IBOutlet var cC:UISegmentedControl!

    @IBAction func cChanged(_ sender: UISegmentedControl) {
        let chr:Int8 = sender.selectedSegmentIndex == 4 ? Int8(0) : Int8(sender.selectedSegmentIndex + 49) // 49 = ASCII '1'
        setGrammarCharacter(Int32(sender.tag),chr)
        vc.updateGrammarString()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        sList = [ c1,c2,c3,c4,c5,c6,c7,c8,c9,cA,cB,cC ]
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        for i in 0 ..< sList.count {
            var index = Int(getGrammarCharacter(Int32(i)))
            if index == 0 { index = 4 } else { index -= 49 } // string terminator = End, else remove ASCII offset
            sList[i].selectedSegmentIndex = index
        }
    }
}
