import UIKit

var wgTableStrings:[String] = []
var wgTableIndex:Int = 0

class WidgetGroupViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 25
        
        let path = IndexPath(row: wgTableIndex, section: 0)
        tableView.selectRow(at: path, animated: false, scrollPosition: .top)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int { return 1 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { return wgTableStrings.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FLCell", for: indexPath)

        let backgroundView = UIView()
        backgroundView.backgroundColor = .darkGray
        cell.selectedBackgroundView = backgroundView

        cell.textLabel?.textColor = .white
        cell.textLabel?.text = wgTableStrings[indexPath.row]
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        wgTableIndex = indexPath.row
        self.dismiss(animated: false, completion: { ()->Void in vc.functionNameChanged() })
    }
}
