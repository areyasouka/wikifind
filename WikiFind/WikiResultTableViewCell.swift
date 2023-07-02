import UIKit

class WikiResultTableViewCell: UITableViewCell {
    
    var termLabel1 = UILabel()
    var termLabel2 = UILabel()
    var descLabel1 = UILabel()
    var descLabel2 = UILabel()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        for (i, label) in [termLabel1, termLabel2, descLabel1, descLabel2].enumerated() {
            label.translatesAutoresizingMaskIntoConstraints = false
            label.numberOfLines = 0
            if i < 2 {
                label.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.subheadline)
            } else {
                label.textColor = UIColor.gray
                label.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.footnote)
            }
            self.contentView.addSubview(label)
        }
        let viewsDictionary = ["term1": termLabel1, "term2": termLabel2, "desc1": descLabel1, "desc2": descLabel2]
        for (i, label) in ["term1", "term2", "desc1", "desc2"].enumerated() {
            if i < 2 {
                self.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-10-[\(label)]-5-|", options: [], metrics: nil, views: viewsDictionary))
            } else {
                self.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-15-[\(label)]-5-|", options: [], metrics: nil, views: viewsDictionary))
            }
        }
        self.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-5-[term1]-2-[term2]-2-[desc1]-1-[desc2]-3-|", options: [], metrics: nil, views: viewsDictionary))
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
