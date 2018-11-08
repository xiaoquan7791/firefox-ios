/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import XCTest

private let testingURL = "example.com"
private let userName = "iosmztest"
private let userPassword = "test15mz"
private let historyItemSavedOnDesktop = "http://www.example.com/"
private let loginEntry = "iosmztest, https://accounts.google.com"
private let tabOpenInDesktop = "http://example.com/"

class IntegrationTests: BaseTestCase {

    let testWithDB = ["testFxASyncHistory", "testFxASyncBookmark"]

    // This DB contains 1 entry example.com
    let historyDB = "exampleURLHistoryBookmark.db"

    override func setUp() {
     // Test name looks like: "[Class testFunc]", parse out the function name
     let parts = name.replacingOccurrences(of: "]", with: "").split(separator: " ")
     let key = String(parts[1])
     if testWithDB.contains(key) {
     // for the current test name, add the db fixture used
     launchArguments = [LaunchArguments.SkipIntro, LaunchArguments.StageServer, LaunchArguments.SkipWhatsNew, LaunchArguments.LoadDatabasePrefix + historyDB]
     }
     super.setUp()
     }

    func allowNotifications () {
        addUIInterruptionMonitor(withDescription: "notifications") { (alert) -> Bool in
            alert.buttons["Allow"].tap()
            return true
        }
        app.swipeDown()
    }

    private func signInFxAccounts() {
        navigator.goto(FxASigninScreen)
        waitForExistence(app.webViews.staticTexts["Sign in"], timeout: 10)
        userState.fxaUsername = ProcessInfo.processInfo.environment["FXA_EMAIL"]!
        userState.fxaPassword = ProcessInfo.processInfo.environment["FXA_PASSWORD"]!
        navigator.performAction(Action.FxATypeEmail)
        navigator.performAction(Action.FxATypePassword)
        navigator.performAction(Action.FxATapOnSignInButton)
        sleep(3)
        allowNotifications()
    }

    private func waitForInitialSyncComplete() {
        navigator.nowAt(BrowserTab)
        navigator.goto(SettingsScreen)
        waitForExistence(app.tables.staticTexts["Sync Now"], timeout: 10)
    }

    func testFxASyncHistory () {
        // History is generated using the DB so go directly to Sign in
        // Sign into Firefox Accounts
        navigator.goto(BrowserTabMenu)
        signInFxAccounts()

        // Wait for initial sync to complete
        waitForInitialSyncComplete()
    }

    func testFxASyncBookmark () {
        // Bookmark is added by the DB
        // Sign into Firefox Accounts
        signInFxAccounts()

        // Wait for initial sync to complete
        waitForInitialSyncComplete()
    }

    func testFxASyncBookmarkDesktop () {
        // Bookmark is added by the DB
        // Sign into Firefox Accounts
        signInFxAccounts()

        // Wait for initial sync to complete
        waitForInitialSyncComplete()
        navigator.goto(HomePanelsScreen)
        waitForTabsButton()
        navigator.goto(BrowserTabMenu)
        navigator.goto(HomePanel_Bookmarks)
        waitForExistence(app.tables["Bookmarks List"].cells.element(boundBy: 1).staticTexts["Example Domain"])
    }

    func testFxASyncTabs () {
        navigator.openURL(testingURL)
        waitUntilPageLoad()
        navigator.goto(BrowserTabMenu)
        signInFxAccounts()

        // Wait for initial sync to complete
        navigator.nowAt(BrowserTab)
        // This is only to check that the device's name changed
        navigator.goto(SettingsScreen)
        app.tables.cells.element(boundBy: 0).tap()
        waitForExistence(app.cells["DeviceNameSetting"].textFields["DeviceNameSettingTextField"])
        XCTAssertEqual(app.cells["DeviceNameSetting"].textFields["DeviceNameSettingTextField"].value! as! String, "Fennec on iOS")

        // Sync again just to make sure to sync after new name is shown
        app.buttons["Settings"].tap()
        app.tables.cells.element(boundBy: 1).tap()
        waitForExistence(app.tables.staticTexts["Sync Now"], timeout: 15)
    }

    func testFxASyncLogins () {
        navigator.openURL("gmail.com")
        waitUntilPageLoad()

        // Log in in order to save it
        waitForExistence(app.webViews.textFields["Email or phone"])
        app.webViews.textFields["Email or phone"].tap()
        app.webViews.textFields["Email or phone"].typeText(userName)
        app.webViews.buttons["Next"].tap()
        waitForExistence(app.webViews.secureTextFields["Password"])
        app.webViews.secureTextFields["Password"].tap()
        app.webViews.secureTextFields["Password"].typeText(userPassword)

        app.webViews.buttons["Sign in"].tap()

        // Save the login
        waitForExistence(app.buttons["SaveLoginPrompt.saveLoginButton"])
        app.buttons["SaveLoginPrompt.saveLoginButton"].tap()

        // Sign in with FxAccount
        signInFxAccounts()
        // Wait for initial sync to complete
        waitForInitialSyncComplete()
    }

    func testFxASyncHistoryDesktop () {
        // Sign into Firefox Accounts
        signInFxAccounts()

        // Wait for initial sync to complete
        waitForInitialSyncComplete()

        // Check synced History
        navigator.goto(HomePanelsScreen)
        waitForTabsButton()
        navigator.goto(BrowserTabMenu)
        navigator.goto(HomePanel_History)
        waitForExistence(app.tables.cells.staticTexts[historyItemSavedOnDesktop], timeout: 5)
    }

    func testFxASyncPasswordDesktop () {
        // Sign into Firefox Accounts
        signInFxAccounts()

        // Wait for initial sync to complete
        waitForInitialSyncComplete()

        // Check synced Logins
        navigator.nowAt(SettingsScreen)
        navigator.goto(LoginsSettings)
        waitForExistence(app.tables["Login List"], timeout: 5)
        XCTAssertTrue(app.tables.cells[loginEntry].exists, "The login saved on desktop is not synced")
    }

    func testFxASyncTabsDesktop () {
        // Sign into Firefox Accounts
        signInFxAccounts()

        // Wait for initial sync to complete
        waitForInitialSyncComplete()

        // Check synced Tabs
        navigator.goto(HomePanelsScreen)
        navigator.goto(HomePanel_History)
        waitForExistence(app.cells["HistoryPanel.syncedDevicesCell"], timeout: 5)
        app.cells["HistoryPanel.syncedDevicesCell"].tap()
        waitForExistence(app.tables.otherElements["profile1"], timeout: 5)
        XCTAssertTrue(app.tables.staticTexts[tabOpenInDesktop].exists, "The tab is not synced")
    }
}
