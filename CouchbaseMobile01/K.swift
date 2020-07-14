//
//  K.swift
//  CouchbaseMobile01
//
//  Created by Daniel James on 6/1/20.
//  Copyright © 2020 Couchbase. All rights reserved.
//

struct K {
    static let cellNibName = "ContactCell"
    static let cellIdentifier = "ReusableCell"
    
    struct CBConnect {
        static let dbLiteName = "demo_sg"
        static let dbSGIP = "192.168.1.9"
        static let dbSGSGPort = "4984"
        static let dbSGBucket = "demobucket"
        static let dbSGUser = "sync_gateway"
        static let dbSGPassword = "password"
    }

    struct CBStore {
        static let userID = "user_id"
        static let firstName = "first_name"
        static let lastName = "last_name"
        static let phone = "phone"
        static let email = "email"
        
        static let type = "contact"
    }
}
