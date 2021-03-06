/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import SnapKit
import Storage

protocol LoginTableViewCellDelegate: AnyObject {
    func didSelectOpenAndFillForCell(_ cell: LoginTableViewCell)
    func shouldReturnAfterEditingDescription(_ cell: LoginTableViewCell) -> Bool
    func infoItemForCell(_ cell: LoginTableViewCell) -> InfoItem?
}

private struct LoginTableViewCellUX {
    static let highlightedLabelFont = UIFont.systemFont(ofSize: 12)
    static let highlightedLabelTextColor = UIConstants.SystemBlueColor
    static let highlightedLabelEditingTextColor = UIColor.theme.tableView.headerTextLight

    static let descriptionLabelFont = UIFont.systemFont(ofSize: 16)
    static let descriptionLabelTextColor = UIColor.black

    static let HorizontalMargin: CGFloat = 14
    static let IconImageSize: CGFloat = 34

    static let indentWidth: CGFloat = 44
    static let IndentAnimationDuration: TimeInterval = 0.2

    static let editingDescriptionIndent: CGFloat = IconImageSize + HorizontalMargin
}

enum LoginTableViewCellStyle {
    case iconAndBothLabels
    case noIconAndBothLabels
    case iconAndDescriptionLabel
}

class LoginTableViewCell: UITableViewCell {

    fileprivate let labelContainer = UIView()

    weak var delegate: LoginTableViewCellDelegate?

    // In order for context menu handling, this is required
    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        guard let item = delegate?.infoItemForCell(self) else {
            return false
        }

        // Menu actions for password
        if item == .passwordItem {
            let showRevealOption = self.descriptionLabel.isSecureTextEntry ? (action == MenuHelper.SelectorReveal) : (action == MenuHelper.SelectorHide)
            return action == MenuHelper.SelectorCopy || showRevealOption
        }

        // Menu actions for Website
        if item == .websiteItem {
            return action == MenuHelper.SelectorCopy || action == MenuHelper.SelectorOpenAndFill
        }

        // Menu actions for Username
        if item == .usernameItem {
            return action == MenuHelper.SelectorCopy
        }

        return false
    }

    lazy var descriptionLabel: UITextField = {
        let label = UITextField()
        label.font = LoginTableViewCellUX.descriptionLabelFont
        label.textColor = LoginTableViewCellUX.descriptionLabelTextColor
        label.backgroundColor = UIColor.Photon.White100
        label.isUserInteractionEnabled = false
        label.autocapitalizationType = .none
        label.autocorrectionType = .no
        label.accessibilityElementsHidden = true
        label.adjustsFontSizeToFitWidth = false
        label.delegate = self
        label.isAccessibilityElement = true
        return label
    }()

    // Exposing this label as internal/public causes the Xcode 7.2.1 compiler optimizer to
    // produce a EX_BAD_ACCESS error when dequeuing the cell. For now, this label is made private
    // and the text property is exposed using a get/set property below.
    fileprivate lazy var highlightedLabel: UILabel = {
        let label = UILabel()
        label.font = LoginTableViewCellUX.highlightedLabelFont
        label.textColor = LoginTableViewCellUX.highlightedLabelTextColor
        label.backgroundColor = UIColor.Photon.White100
        label.numberOfLines = 1
        return label
    }()

    fileprivate lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.backgroundColor = UIColor.Photon.White100
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    fileprivate var showingIndent: Bool = false

    fileprivate var customIndentView = UIView()

    fileprivate var customCheckmarkIcon = UIImageView(image: UIImage(named: "loginUnselected"))

    /// Override the default accessibility label since it won't include the description by default
    /// since it's a UITextField acting as a label.
    override var accessibilityLabel: String? {
        get {
            if descriptionLabel.isSecureTextEntry {
                return highlightedLabel.text ?? ""
            } else {
                return "\(highlightedLabel.text ?? ""), \(descriptionLabel.text ?? "")"
            }
        }
        set {
            // Ignore sets
        }
    }

    var style: LoginTableViewCellStyle = .iconAndBothLabels {
        didSet {
            if style != oldValue {
                configureLayoutForStyle(style)
            }
        }
    }

    var descriptionTextSize: CGSize? {
        guard let descriptionText = descriptionLabel.text else {
            return nil
        }

        let attributes = [
            NSAttributedStringKey.font: LoginTableViewCellUX.descriptionLabelFont
        ]

        return descriptionText.size(withAttributes: attributes)
    }

    var displayDescriptionAsPassword: Bool = false {
        didSet {
            descriptionLabel.isSecureTextEntry = displayDescriptionAsPassword
        }
    }

    var editingDescription: Bool = false {
        didSet {
            if editingDescription != oldValue {
                descriptionLabel.isUserInteractionEnabled = editingDescription

                highlightedLabel.textColor = editingDescription ?
                    LoginTableViewCellUX.highlightedLabelEditingTextColor : LoginTableViewCellUX.highlightedLabelTextColor

                // Trigger a layout configuration if we changed to editing/not editing the description.
                configureLayoutForStyle(self.style)
            }
        }
    }

    var highlightedLabelTitle: String? {
        get {
            return highlightedLabel.text
        }
        set(newTitle) {
            highlightedLabel.text = newTitle
        }
    }

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        indentationWidth = 0
        selectionStyle = .none

        contentView.backgroundColor = UIColor.Photon.White100
        labelContainer.backgroundColor = UIColor.Photon.White100

        labelContainer.addSubview(highlightedLabel)
        labelContainer.addSubview(descriptionLabel)

        contentView.addSubview(iconImageView)
        contentView.addSubview(labelContainer)

        customIndentView.addSubview(customCheckmarkIcon)
        addSubview(customIndentView)

        configureLayoutForStyle(self.style)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        delegate = nil
        descriptionLabel.isSecureTextEntry = false
        descriptionLabel.keyboardType = .default
        descriptionLabel.returnKeyType = .default
        descriptionLabel.isUserInteractionEnabled = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Adjust indent frame
        var indentFrame = CGRect(width: LoginTableViewCellUX.indentWidth, height: frame.height)

        if !showingIndent {
            indentFrame.origin.x = -LoginTableViewCellUX.indentWidth
        }

        customIndentView.frame = indentFrame
        customCheckmarkIcon.frame.center = CGPoint(x: indentFrame.width / 2, y: indentFrame.height / 2)

        // Adjust content view frame based on indent
        var contentFrame = self.contentView.frame
        contentFrame.origin.x += showingIndent ? LoginTableViewCellUX.indentWidth : 0
        contentView.frame = contentFrame
    }

    fileprivate func configureLayoutForStyle(_ style: LoginTableViewCellStyle) {
        switch style {
        case .iconAndBothLabels:
            iconImageView.snp.remakeConstraints { make in
                make.centerY.equalTo(contentView)
                make.leading.equalTo(contentView).offset(LoginTableViewCellUX.HorizontalMargin)
                make.height.width.equalTo(LoginTableViewCellUX.IconImageSize)
            }

            labelContainer.snp.remakeConstraints { make in
                make.centerY.equalTo(contentView)
                make.trailing.equalTo(contentView).offset(-LoginTableViewCellUX.HorizontalMargin)
                make.leading.equalTo(iconImageView.snp.trailing).offset(LoginTableViewCellUX.HorizontalMargin)
            }

            highlightedLabel.snp.remakeConstraints { make in
                make.leading.top.equalTo(labelContainer)
                make.bottom.equalTo(descriptionLabel.snp.top)
                make.width.equalTo(labelContainer)
            }

            descriptionLabel.snp.remakeConstraints { make in
                make.leading.bottom.equalTo(labelContainer)
                make.top.equalTo(highlightedLabel.snp.bottom)
                make.width.equalTo(labelContainer)
            }
        case .iconAndDescriptionLabel:
            iconImageView.snp.remakeConstraints { make in
                make.centerY.equalTo(contentView)
                make.leading.equalTo(contentView).offset(LoginTableViewCellUX.HorizontalMargin)
                make.height.width.equalTo(LoginTableViewCellUX.IconImageSize)
            }

            labelContainer.snp.remakeConstraints { make in
                make.centerY.equalTo(contentView)
                make.trailing.equalTo(contentView).offset(-LoginTableViewCellUX.HorizontalMargin)
                make.leading.equalTo(iconImageView.snp.trailing).offset(LoginTableViewCellUX.HorizontalMargin)
            }

            highlightedLabel.snp.remakeConstraints { make in
                make.height.width.equalTo(0)
            }

            descriptionLabel.snp.remakeConstraints { make in
                make.top.leading.bottom.equalTo(labelContainer)
                make.width.equalTo(labelContainer)
            }
        case .noIconAndBothLabels:
            // Currently we only support modifying the description for this layout which is why
            // we factor in the editingOffset when calculating the constraints.
            let editingOffset = editingDescription ? LoginTableViewCellUX.editingDescriptionIndent : 0

            iconImageView.snp.remakeConstraints { make in
                make.centerY.equalTo(contentView)
                make.leading.equalTo(contentView).offset(LoginTableViewCellUX.HorizontalMargin)
                make.height.width.equalTo(0)
            }

            labelContainer.snp.remakeConstraints { make in
                make.centerY.equalTo(contentView)
                make.trailing.equalTo(contentView).offset(-LoginTableViewCellUX.HorizontalMargin)
                make.leading.equalTo(iconImageView.snp.trailing).offset(editingOffset)
            }

            highlightedLabel.snp.remakeConstraints { make in
                make.leading.top.equalTo(labelContainer)
                make.bottom.equalTo(descriptionLabel.snp.top)
                make.width.equalTo(labelContainer)
            }

            descriptionLabel.snp.remakeConstraints { make in
                make.leading.bottom.equalTo(labelContainer)
                make.top.equalTo(highlightedLabel.snp.bottom)
                make.width.equalTo(labelContainer)
            }
        }

        setNeedsUpdateConstraints()
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        showingIndent = editing

        let adjustConstraints = { [unowned self] in

            // Shift over content view
            var contentFrame = self.contentView.frame
            contentFrame.origin.x += editing ? LoginTableViewCellUX.indentWidth : -LoginTableViewCellUX.indentWidth
            self.contentView.frame = contentFrame

            // Shift over custom indent view
            var indentFrame = self.customIndentView.frame
            indentFrame.origin.x += editing ? LoginTableViewCellUX.indentWidth : -LoginTableViewCellUX.indentWidth
            self.customIndentView.frame = indentFrame
        }

        animated ? UIView.animate(withDuration: LoginTableViewCellUX.IndentAnimationDuration, animations: adjustConstraints) : adjustConstraints()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        customCheckmarkIcon.image = UIImage(named: selected ? "loginSelected" : "loginUnselected")
    }
}

// MARK: - Menu Selectors
extension LoginTableViewCell: MenuHelperInterface {

    func menuHelperReveal() {
        displayDescriptionAsPassword = false
    }

    func menuHelperSecure() {
        displayDescriptionAsPassword = true
    }

    func menuHelperCopy() {
        // Copy description text to clipboard
        UIPasteboard.general.string = descriptionLabel.text
    }

    func menuHelperOpenAndFill() {
        delegate?.didSelectOpenAndFillForCell(self)
    }
}

// MARK: - Cell Decorators
extension LoginTableViewCell {
    func updateCellWithLogin(_ login: LoginData) {
        descriptionLabel.text = login.hostname
        highlightedLabel.text = login.username
        iconImageView.image = UIImage(named: "faviconFox")
    }
}

extension LoginTableViewCell: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return self.delegate?.shouldReturnAfterEditingDescription(self) ?? true
    }

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if descriptionLabel.isSecureTextEntry {
            displayDescriptionAsPassword = false
        }
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if descriptionLabel.isSecureTextEntry {
            displayDescriptionAsPassword = true
        }
    }
}
