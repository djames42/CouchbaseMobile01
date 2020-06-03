//
//  Couchbase.swift
//  CouchbaseMobile01
//
//  Created by Daniel James on 6/1/20.
//  Copyright © 2020 Daniel James. All rights reserved.
//

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
        let mutableDoc = MutableDocument()
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
        return mutableDoc.id
    }
    
    func startReplication() {
        // ######################### Create replicators to push and pull changes to and from the cloud. ########
        let targetURL = "ws://\(K.CBConnect.dbCBIP):\(K.CBConnect.dbCBSGPort)/\(K.CBConnect.dbCBBucket)"  // ws://111.222.333.444:8091/bucket
        let targetEndpoint = URLEndpoint(url: URL(string: targetURL)!)  // Translate URL String to Endpoint
        let replConfig = ReplicatorConfiguration(database: database, target: targetEndpoint) // Map replication btw local DB and remote CB Server
        replConfig.replicatorType = .pushAndPull
        replConfig.continuous = true  // continuous vs manual/triggered sync
        
        // Add authentication.
        replConfig.authenticator = BasicAuthenticator(username: K.CBConnect.dbCBUser, password: K.CBConnect.dbCBPassword)
        
        // Create replicator as configured above
        self.replicator = Replicator(config: replConfig)
        
        // Listen to replicator status change events. This code isn't necessary for replication to happen,
        // but does set up a listener to respond to replication events
//        self.replicator!.addChangeListener { (change) in
//            if let error = change.status.error as NSError? {
//                print("Error code :: \(error.code)")
//            } else if change.status.activity == .stopped {
//                print("Replication stopped")
//            } else if change.status.activity == .idle {
//                print ("Replication IDLE")
//            } else  if change.status.activity == .busy {
//                print("Replication is busy")
//            } else {
//                print ("I see a change, or something else...")
//            }
//        }
        
        // Listen to replication change events. This code isn't necessary for replication to happen,
        // but does set up a listener to respond to replication events (such as the delegate call to
        // refresh the table view
        self.replicator?.addDocumentReplicationListener { ( replicator ) in
            for document in replicator.documents {
                if (document.error == nil) {
                    print("Doc ID :: \(document.id)")
                    if (document.flags.contains(.deleted)) {
                        print("Successfully replicated a deleted document")
                    }
                }
            }
            self.delegate?.didReceiveSync(self, delegateDB: self.database, statusMessage: "\(replicator.documents.count) document(s) were updated via sync gateway")
        }
        
        // Actually start the replication now that it's all set up
        self.replicator?.start()
    }
}
