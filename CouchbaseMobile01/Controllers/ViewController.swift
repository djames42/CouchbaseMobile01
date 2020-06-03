//
//  ViewController.swift
//  CouchbaseMobile01
//
//  Created by Daniel James on 6/1/20.
//  Copyright © 2020 Daniel James. All rights reserved.
//

import UIKit
import CouchbaseLiteSwift

class ViewController: UIViewController {
    @IBOutlet weak var firstNameTextField: UITextField!
    @IBOutlet weak var lastNameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var phoneNumberTextField: UITextField!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var syncStatusLabel: UILabel!
    
    var contacts: [User] = []
    
    var database = Couchbase()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.register(UINib(nibName: K.cellNibName, bundle: nil), forCellReuseIdentifier: K.cellIdentifier)
        
        database.startReplication()
        database.delegate = self
        
        // Call method to refresh table from local database
        populateData(queryDatabase: database.getDatabase())
        
        statusLabel.text = ""
        syncStatusLabel.text = ""
    }
    
    func populateData(queryDatabase: Database) {
        contacts = database.getContacts()
        tableView.reloadData()
    }

    @IBAction func addContactButton(_ sender: UIButton) {
        if let firstName = firstNameTextField.text,
                let lastName = lastNameTextField.text,
                let phoneNumber = phoneNumberTextField.text,
                let email = emailTextField.text {
            // Valid fields - add to database
            let docID = database.addUser(user: User(userID: 0, firstName: firstName, lastName: lastName, email: email, phone: phoneNumber))
            
            statusLabel.text = "\(K.CBStore.firstName):\(firstName) \(lastName) has been added (ID: \(`docID`))."
            self.populateData(queryDatabase: database.getDatabase())
        }
    }
}

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contacts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: K.cellIdentifier, for: indexPath) as! ContactCell
        cell.firstNameCell.text = contacts[indexPath.row].firstName
        cell.lastNameCell.text = contacts[indexPath.row].lastName
        cell.emailCell.text = contacts[indexPath.row].email
        cell.phoneCell.text = contacts[indexPath.row].phone
        return cell
    }
}

extension ViewController: CouchbaseDelegate {
    func didReceiveSync(_ sender: Couchbase, delegateDB: Database, statusMessage: String) {
        populateData(queryDatabase: delegateDB)
        syncStatusLabel.text = statusMessage
    }
}
