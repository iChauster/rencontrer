//
//  MeetingTableViewCell.swift
//  recontrer
//
//  Created by Ivan Chau on 11/4/15.
//  Copyright © 2015 Ivan Chau. All rights reserved.
//

import UIKit

class MeetingTableViewCell: UITableViewCell {
    @IBOutlet weak var from : UILabel?
    @IBOutlet weak var dateTime : UILabel?
    @IBOutlet weak var dateSent : UILabel?
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
