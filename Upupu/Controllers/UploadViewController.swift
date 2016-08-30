//
//  UploadViewController.swift
//  Upupu
//
//  Created by Toshiki Takeuchi on 8/29/16.
//  Copyright © 2016 Xcoo, Inc. All rights reserved.
//  See LISENCE for Upupu's licensing information.
//

import UIKit

import MBProgressHUD

protocol UploadViewControllerDelegate: class {

    func uploadViewControllerDidReturn(uploadViewController: UploadViewController)
    func uploadViewControllerDidFinished(uploadViewController: UploadViewController)
    func uploadViewControllerDidSetup(uploadViewController: UploadViewController)

}

class UploadViewController: UIViewController, MBProgressHUDDelegate, UITextFieldDelegate {

    weak var delegate: UploadViewControllerDelegate?

    @IBOutlet private weak var nameField: UITextField!
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var retakeButton: UIBarItem!
    @IBOutlet private weak var uploadButton: UIBarItem!
    @IBOutlet private weak var settingsButton: UIBarItem!

    var image: UIImage?
    var shouldSavePhotoAlbum = true

    private var hud: MBProgressHUD?

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewWillAppear(animated: Bool) {
        imageView.image = image

        nameField.enabled = image != nil
        uploadButton.enabled = image != nil

        if let text = nameField.text {
            if text.isEmpty {
                nameField.text = makeFilename()
            }
        } else {
            nameField.text = makeFilename()
        }

        super.viewWillAppear(animated)
    }

    override func shouldAutorotate() -> Bool {
        return UIDevice.currentDevice().orientation == .Portrait
    }

    private func makeFilename() -> String {
        let date = NSDate()
        let formatter = NSDateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.stringFromDate(date)
    }

    // MARK: - Action

    @IBAction private func retakeButtonTapped(sender: UIBarItem) {
        nameField.text = ""
        delegate?.uploadViewControllerDidReturn(self)
    }

    @IBAction private func uploadButtonTapped(sender: UIBarItem) {
        if !Settings.isWebDAVEnabled() && !Settings.isDropboxEnabled() {
            AlertUtil.showWithTitle("Error", andMessage: "Setup server configuration before uploading")
            return
        }

        if Settings.isWebDAVEnabled() &&
            (Settings.webDAVURL() == nil || Settings.webDAVURL().isEmpty) {
            AlertUtil.showWithTitle("Error", andMessage: "Invalid WebDAV server URL")
            return
        }

        hud = HUDUtil.showWithText("Uploading",
                                   forView: navigationController?.view,
                                   whileExecuting:#selector(launchUpload),
                                   onTarget: self)
    }

    @IBAction private func settingsButtonTapped(sender: UIBarItem) {
        delegate?.uploadViewControllerDidSetup(self)
    }

    // MARK: - Picture processing

    private func showFailed() {
        if let hud = hud {
            hud.customView = UIImageView(image: UIImage(named: "failure_icon"))
            hud.mode = .CustomView
            hud.labelText = "Failed"
            hud.detailsLabelText = ""
        }
    }

    private func showSucceeded() {
        if let hud = hud {
            hud.customView = UIImageView(image: UIImage(named: "success_icon"))
            hud.mode = .CustomView
            hud.labelText = "Succeeded"
            hud.detailsLabelText = ""
        }
    }

    func launchUpload() {
        var image: UIImage?
        switch Settings.photoResolution() {
        case 0: image = self.image
        case 1: image = ImageUtil.scaleImage(self.image, withSize: CGSizeMake(1600, 2000))
        case 2: image = ImageUtil.scaleImage(self.image, withSize: CGSizeMake(800, 600))
        default: break
        }

        var quality = 1.0
        switch Settings.photoQuality() {
        case 0: quality = 1.0 // High
        case 1: quality = 0.6 // Medium
        case 2: quality = 0.2 // Low
        default: break
        }

        if let image = image {
            if shouldSavePhotoAlbum && Settings.photoSaveToAlbum() {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            }

            if let imageData = UIImageJPEGRepresentation(image, CGFloat(quality)),
                filename = nameField.text {
                // WebDAV
                if Settings.isWebDAVEnabled() {
                    hud?.detailsLabelText = "WebDAV"
                    let uploader = WebDAVUploader(name: filename, imageData: imageData)
                    uploader.upload()
                    if !uploader.success {
                        dispatch_sync(dispatch_get_main_queue(), {[weak self] in
                            self?.showFailed()
                            })
                        sleep(1)
                        return
                    }
                }

                // Dropbox
                if Settings.isDropboxEnabled() {
                    hud?.detailsLabelText = "Dropbox"
                    let uploader = DropboxUploader.sharedInstance()
                    uploader.uploadWithName(filename, imageData: imageData)
                    if !uploader.success {
                        dispatch_sync(dispatch_get_main_queue(), {[weak self] in
                            self?.showFailed()
                            })
                        sleep(1)
                        return
                    }
                }

                dispatch_sync(dispatch_get_main_queue(), {[weak self] in
                    self?.showSucceeded()
                    })
                sleep(1)

                nameField.text = ""
                delegate?.uploadViewControllerDidFinished(self)
            }
        }
    }

    // MARK: - TextFieldDelegate

    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

}
