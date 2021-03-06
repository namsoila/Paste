//
//  SearchViewController
//  Paste
//
//  Created by Dasmer Singh on 12/20/15.
//  Copyright © 2015 Dastronics Inc. All rights reserved.
//

import UIKit
import SVProgressHUD
import EmojiKit

final class SearchViewController: UIViewController {

    // MARK: - Properties

    private var results: [Emoji] = [] {
        didSet {
            tableView.reloadData()
        }
    }

    private var recents: [Emoji] {
        set {
            RecentEmojiStore.set(newValue)
        }

        get {
            return RecentEmojiStore.get()
        }
    }

    private lazy var searchTextFieldView: SearchTextFieldView = {
        let view = SearchTextFieldView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.placeholder = "Type an emoji name to search"
        view.backgroundColor = .whiteColor()
        view.delegate = self
        return view
    }()

    private lazy var tableViewController: UITableViewController = {
        let viewController = UITableViewController()
        viewController.view.translatesAutoresizingMaskIntoConstraints = false
        viewController.tableView.dataSource = self
        viewController.tableView.delegate = self
        return viewController
    }()

    private lazy var fetcher: EmojiFetcher = {
        return EmojiFetcher()
    }()

    private var tableView: UITableView {
        return tableViewController.tableView
    }


    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Emoji Search"
        automaticallyAdjustsScrollViewInsets = false

        navigationController?.navigationBar.tintColor = .blackColor()
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "☰", style: .Plain, target: self, action: "optionsButtonAction:")

        view.backgroundColor = .whiteColor()

        view.addSubview(searchTextFieldView)

        let separatorView = UIView(frame: .zero)
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        separatorView.backgroundColor = .grayColor()
        view.addSubview(separatorView)

        addChildViewController(tableViewController)
        view.addSubview(tableViewController.view)
        tableViewController.didMoveToParentViewController(self)

        let views: [String: AnyObject] = [
            "topLayoutGuide": topLayoutGuide,
            "searchView": searchTextFieldView,
            "separatorView": separatorView,
            "tableView": tableViewController.view
        ]

        var constraints = [NSLayoutConstraint]()
        constraints += NSLayoutConstraint.constraintsWithVisualFormat("H:|[searchView]|", options: [], metrics: nil, views: views)
                constraints += NSLayoutConstraint.constraintsWithVisualFormat("H:|[separatorView]|", options: [], metrics: nil, views: views)
        constraints += NSLayoutConstraint.constraintsWithVisualFormat("H:|[tableView]|", options: [], metrics: nil, views: views)
        constraints += NSLayoutConstraint.constraintsWithVisualFormat("V:|[topLayoutGuide][searchView(50)][separatorView(1)][tableView]|", options: [], metrics: nil, views: views)
        NSLayoutConstraint.activateConstraints(constraints)

        tableView.registerClass(TableViewCell.self, forCellReuseIdentifier: TableViewCell.reuseIdentifier)

        reset()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        searchTextFieldView.becomeFirstResponder()
    }


    // MARK: - Private

    func reset() {
        fetcher.cancelFetches()
        results = recents
    }

    @objc private func optionsButtonAction(sender: AnyObject?) {
        presentViewController(UINavigationController(rootViewController: OptionsViewController()), animated: true, completion: nil)
    }
}


extension SearchViewController: SearchTextFieldViewDelegate {

    func searchTextFieldView(searchTextFieldView: SearchTextFieldView, didChangeText text: String) {
        if (text.characters.count > 0) {
            fetcher.query(text) { [weak self] in
                self?.results = $0
            }
        } else {
            reset()
        }
    }

    func searchTextFieldViewWillClearText(searchTextFieldView: SearchTextFieldView) {
        reset()
    }
}


extension SearchViewController: UITableViewDataSource {

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(TableViewCell.reuseIdentifier, forIndexPath: indexPath)
        let emoji = self.results[indexPath.row]
        cell.textLabel?.text = emoji.character
        cell.detailTextLabel?.text = emoji.name
        return cell
    }
}


extension SearchViewController: UITableViewDelegate {

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)

        let emoji = self.results[indexPath.row]

        UIPasteboard.generalPasteboard().string = emoji.character

        SVProgressHUD.showSuccessWithStatus("Copied \(emoji.character)")

        let properties = [
            "Emoji Character": emoji.character,
            "Search Text": searchTextFieldView.text ?? "",
            "Search Text Count": String(searchTextFieldView.text?.characters.count ?? 0)
        ]
        Analytics.sharedInstance.track("Emoji Selected", properties: properties)

        RateReminder.sharedInstance.logEvent()

        var currentRecents = recents
        if let index = currentRecents.indexOf(emoji) {
            currentRecents.removeAtIndex(index)
        }
        currentRecents.insert(emoji, atIndex: 0)

        recents = Array(currentRecents.prefix(10))

        self.searchTextFieldView.text = nil
        reset()
    }
}
