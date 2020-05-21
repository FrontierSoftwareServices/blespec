//  Copyright © 2019 Frontier Software Services, LTD. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
import UIKit

open class BluetoothDataHistoryTableViewController: UITableViewController {
    
    private var rows = [[String: String]]()
    private var rowTitles = [[String]]()
    
    private var history = [BluetoothData]()
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
    }
    
    public func clear() {
        history.removeAll()
        self.rows.removeAll()
        self.rowTitles.removeAll()
        self.tableView.reloadData()
    }
    
    public func addBluetoothData(_ bluetoothData: BluetoothData) {
        history.append(bluetoothData)
        let props = bluetoothData.propertyDescriptions()
        self.rows.append(props)
        self.rowTitles.append(Array(props.keys).sorted())
        self.tableView.reloadData()
    }
    
    public func getHistory() -> [BluetoothData] {
        return history
    }
    
    // MARK: - Internal
    
    public override func numberOfSections(in tableView: UITableView) -> Int {
        return history.count
    }
    
    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rowTitles[section].count
    }
    
    open override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "\(section)"
    }
    
    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "detailStyle", for: indexPath)
        
        let name = rowTitles[indexPath.section][indexPath.row]
        cell.detailTextLabel?.text = rows[indexPath.section][name]
        cell.textLabel?.text = name
        
        return cell
    }
    
}
