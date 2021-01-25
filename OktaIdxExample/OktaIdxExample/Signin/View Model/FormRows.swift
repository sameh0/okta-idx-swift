//
//  FormRows.swift
//  OktaIdxExample
//
//  Created by Mike Nachbaur on 2021-01-14.
//

import Foundation
import OktaIdx

protocol SigninRowDelegate {
    func row(row: Signin.Row, changedValue: (String,Any))
    func value(for key: String) -> Any?
}

extension Signin {
    /// Represents a visual row in the remediation form's signin process.
    struct Row {
        /// The kind of element to display in this row
        let kind: Kind
        
        /// The parent form value, if present, that this row's value should be submitted under.
        let parent: IDXClient.Remediation.FormValue?
        
        /// Delegate to notfiy about user interactions and value changes
        weak private(set) var delegate: (AnyObject & SigninRowDelegate)?
        
        /// Row element kinds.
        enum Kind {
            case label(field: IDXClient.Remediation.FormValue)
            case message(message: IDXClient.Message)
            case text(field: IDXClient.Remediation.FormValue)
            case toggle(field: IDXClient.Remediation.FormValue)
            case option(field: IDXClient.Remediation.FormValue, option: IDXClient.Remediation.FormValue)
            case button(kind: [IDXButtonTableViewCell.Kind])
        }
    }
    
    /// Represents a section of rows for the remediation form's signin process
    struct Section {
        /// Array of rows to show in this section.
        let rows: [Row]
    }
}

extension IDXClient.Remediation.FormValue {
    typealias Section = Signin.Section
    typealias Row = Signin.Row
    typealias FormValue = IDXClient.Remediation.FormValue
    
    /// Returns an array of row elements to represent this form value's input.
    /// - Parameters:
    ///   - parent: Optional parent for this form value.
    ///   - delegate: The delegate to receive updates from this form row.
    /// - Returns: Array of row elements.
    func remediationRow(parent: FormValue? = nil, delegate: AnyObject & SigninRowDelegate) -> [Row] {
        if !visible && !mutable {
            if label != nil {
                // Fields that are not "visible" don't mean they shouldn't be displayed, just that they
                return [Row(kind: .label(field: self),
                            parent: parent,
                            delegate: delegate)]
            } else {
                return []
            }
        }
        
        var rows: [Row] = []
        
        switch type {
        case "boolean":
            rows.append(Row(kind: .toggle(field: self),
                            parent: parent,
                            delegate: delegate))
        case "object":
            if let options = options {
                options.forEach { option in
                    rows.append(Row(kind: .option(field: self, option: option),
                                    parent: parent,
                                    delegate: delegate))
                }
            } else if let form = form {
                rows.append(contentsOf: form.flatMap { nested in
                    nested.remediationRow(parent: self, delegate: delegate)
                })
            }
            
        default:
            rows.append(Row(kind: .text(field: self),
                            parent: parent,
                            delegate: delegate))
        }
        
        self.messages?.forEach { message in
            rows.append(Row(kind: .message(message: message),
                            parent: parent,
                            delegate: delegate))
        }
        
        return rows
    }
}

extension IDXClient.Response {
    typealias Section = Signin.Section
    typealias Row = Signin.Row
    typealias FormValue = IDXClient.Remediation.FormValue
    
    /// Converts a remediation option into a set of objects representing the form, so it can be rendered in the table view.
    /// - Parameters:
    ///   - response: Response object that is the parent for this remediation option
    ///   - delegate: A delegate object to receive updates as the form is changed.
    /// - Returns: Array of sections to be shown in the table view.
    func remediationForm(form: [FormValue], delegate: AnyObject & SigninRowDelegate) -> [Section] {
        var sections: [Section] = []
        
        if let messages = messages {
            sections.append(Section(rows: messages.map { message in
                Row(kind: .message(message: message),
                    parent: nil,
                    delegate: delegate)
            }))
        }
        
        sections.append(Section(rows: form.flatMap { nested in
            nested.remediationRow(delegate: delegate)
        }))

        var buttons: [IDXButtonTableViewCell.Kind] = []
        if canCancel {
            buttons.append(.cancel)
        }
        
        if remediation?.remediationOptions.count ?? 0 > 0 {
            buttons.append(.next)
        }
        
        sections.append(Section(rows: [Row(kind: .button(kind: buttons),
                                           parent: nil,
                                           delegate: delegate)]))
        
        return sections
    }
}