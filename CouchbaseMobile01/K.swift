//
//  K.swift
//  CouchbaseMobile01
//
//  Created by Daniel James on 6/1/20.
//  Copyright © 2020 Daniel James. All rights reserved.
//

struct K {
    static let cellNibName = "ContactCell"
    static let cellIdentifier = "ReusableCell"
    
    struct CBConnect {
        static let dbLiteName = "demo_sg"
        static let dbCBIP = "192.168.1.9"
        static let dbCBSGPort = "4984"
        static let dbCBBucket = "demobucket"
        static let dbCBUser = "sync_gateway"
        static let dbCBPassword = "password"
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
