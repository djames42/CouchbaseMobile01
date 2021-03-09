//
//  Couchbase.swift
//  CouchbaseMobile01
//
//  Created by Daniel James on 6/1/20.
//  Copyright © 2020 Couchbase. All rights reserved.
//

import UIKit
import Foundation
import CouchbaseLiteSwift

protocol CouchbaseDelegate {
    func didReceiveSync(_ sender: Couchbase, delegateDB: Database, statusMessage: String)
}

class Couchbase {
    var database: Database
    var replicator: Replicator?
    
    var delegate: CouchbaseDelegate?
    
    // class constructor which connects to/creates local DB
    //    and creates local Database object
    init() {
        do {
            database = try Database(name: K.CBConnect.dbLiteName)
        } catch {
            fatalError("Error opening database")
        }
    }
    
    // Simple getter
    func getDatabase() -> Database {
        return database
    }
    
    // return array of User(s) for each row of "type='contact'" in local DB
    func getContacts() -> [User] {
        var contacts: [User] = []
        let contactsQuery = QueryBuilder
            .select(
                SelectResult.expression(Meta.id),
                SelectResult.property(K.CBStore.firstName),
                SelectResult.property(K.CBStore.lastName),
                SelectResult.property(K.CBStore.phone),
                SelectResult.property(K.CBStore.email)
            )
            .from(DataSource.database(database))
            .where(Expression.property("type").equalTo(Expression.string("contact")))
            .orderBy(Ordering.property(K.CBStore.lastName).ascending())
        do {
            for dbContacts in try contactsQuery.execute()  {
                if let firstName = dbContacts.string(forKey: "first_name"),
                   let lastName = dbContacts.string(forKey: "last_name"),
                   let email = dbContacts.string(forKey: "email"),
                   let phone = dbContacts.string(forKey: "phone") {
                    
                    let contact = User(userID: 0,
                                       firstName: firstName,
                                       lastName: lastName,
                                       email: email,
                                       phone: phone)
                    contacts.append(contact)
                }
            }
        } catch {
            print("Failed to get contacts: \(error.localizedDescription)")
        }
        return contacts
    }
    
    // Given a User, add a row to the local DB
    func addUser(user: User) -> String {
        var existing: String = "Added "
        if database.document(withID: "contact::\(user.email)") != nil {
            print("Contact w/email exists. Overwriting")
            existing = "Updated "
        }
        let mutableDoc = MutableDocument(id: "contact::\(user.email)")
            .setString(user.firstName, forKey: K.CBStore.firstName)
            .setString(user.lastName, forKey: K.CBStore.lastName)
            .setString(user.phone, forKey: K.CBStore.phone)
            .setString(user.email, forKey: K.CBStore.email)
            .setString(K.CBStore.type, forKey: "type")
        do {
            try database.saveDocument(mutableDoc)
        } catch {
            fatalError("Error saving document")
        }
        return "\(existing) (ID: \(mutableDoc.id))"
    }
    
    func startReplication() {
        // ######################### Create replicators to push and pull changes to and from the cloud. ########
        let targetURL = "ws://\(K.CBConnect.dbSGIP):\(K.CBConnect.dbSGSGPort)/\(K.CBConnect.dbSGBucket)"  // ws://192.168.1.9:8091/bucket
        let targetEndpoint = URLEndpoint(url: URL(string: targetURL)!)  // Translate URL String to Endpoint
        let replConfig = ReplicatorConfiguration(database: database, target: targetEndpoint) // Map replication btw local DB and remote CB Server
        replConfig.replicatorType = .pushAndPull // Can also be .push or .pull for one-way sync
        replConfig.continuous = true  // continuous vs manual/triggered sync
        
        // Add authentication.
        replConfig.authenticator = BasicAuthenticator(username: K.CBConnect.dbSGUser, password: K.CBConnect.dbSGPassword)
        
        // Create replicator as configured above
        self.replicator = Replicator(config: replConfig)
        
        // Listen to replicator status change events. This code isn't necessary for replication to happen,
        // but does set up a listener to respond to replication events
        self.replicator!.addChangeListener { (change) in
            if let error = change.status.error as NSError? {
                print("\(Date().toString()): Error code :: \(error.code)")
            } else if change.status.activity == .stopped {
                print("\(Date().toString()): Replication stopped")
            } else if change.status.activity == .idle {
                print ("\(Date().toString()): Replication IDLE")
            } else if change.status.activity == .offline {
                print ("\(Date().toString()): Replication is Offline!")
            } else  if change.status.activity == .busy {
                print("\(Date().toString()): Replication is busy")
            } else {
                print ("\(Date().toString()): I see a change, or something else...")
            }
        }
        
        // Listen to replication change events. This code isn't necessary for replication to happen,
        // but does set up a listener to respond to replication events (such as the delegate call to
        // refresh the table view
        self.replicator?.addDocumentReplicationListener { ( replicator ) in
            for document in replicator.documents {
                if (document.error == nil) {
                    print("\(Date().toString()): Doc ID :: \(document.id)")
                    if (document.flags.contains(.deleted)) {
                        print("\(Date().toString()): Successfully replicated a deleted document")
                    }
                }
            }
            self.delegate?.didReceiveSync(self, delegateDB: self.database, statusMessage: "\(replicator.documents.count) document(s) were updated via sync gateway")
        }
        
        // Start the replication now that it's all set up
        self.replicator?.start()
    }
}

extension Date {
    func toString() -> String {
        let dateFormat = DateFormatter()
        dateFormat.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormat.string(from: self)
    }
}
