//
//  ContactCell.swift
//  CouchbaseMobile01
//
//  Created by Daniel James on 6/1/20.
//  Copyright © 2020 Daniel James. All rights reserved.
//

import UIKit

class ContactCell: UITableViewCell {
    @IBOutlet weak var firstNameCell: UILabel!
    @IBOutlet weak var lastNameCell: UILabel!
    @IBOutlet weak var emailCell: UILabel!
    @IBOutlet weak var phoneCell: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
