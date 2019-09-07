//
//  ViewController.swift
//  PDFInvoiceScanner
//
//  Created by Filip Tronnberg on 2019-09-05.
//  Copyright © 2019 Filip Tronnberg. All rights reserved.
//

import UIKit
import AVFoundation
import Vision
import VisionKit
import Accelerate
import CoreImage

class ViewController: UIViewController {

    let pdfScannerUtility = PDFScannerUtility()

    var pickerController: UIImagePickerController?
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var processImageButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        pdfScannerUtility.delegate = self
   }
    
    @IBAction func pickImageTapped(_ sender: Any) {
        let pickerController = UIImagePickerController()
        pickerController.delegate = self
        pickerController.allowsEditing = false
        pickerController.mediaTypes = ["public.image"]
        pickerController.sourceType = .photoLibrary
        present(pickerController, animated: true, completion: nil)
        self.pickerController = pickerController
    }

    @IBAction func scanDocumentTapped(_ sender: Any) {
        guard VNDocumentCameraViewController.isSupported else {
            showAlert(title: "No support", message: "This device doesn't support document scanning")
            return
        }
        let scannerViewController = VNDocumentCameraViewController()
        scannerViewController.delegate = self
        present(scannerViewController, animated: true)
    }

    @IBAction func processImageTapped(_ sender: Any) {
        guard let image = imageView.image else {
            return
        }
        pdfScannerUtility.extractInvoiceInformation(image: image)
    }
}

extension ViewController: PDFScannerUtilityDelegate {

    func pdfScannerUtilityDidBeginProcessing(_ pdfScannerUtility: PDFScannerUtility) {
        print("began processing")
    }

    func pdfScannerUtility(_ pdfScannerUtility: PDFScannerUtility, didFinishProcessing result: Result<PdfValidatedObservations, Error>) {
        switch result {
        case .failure(let error):
            showAlert(title: "error", message: error.localizedDescription)
        case .success(let validatedObservations):
            showAlert(title: "Finished", message: validatedObservations.debugDescription)
        }
    }

    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }

}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let pickedImage = info[.originalImage] as? UIImage else {
            return
        }
        imageView.image = pickedImage
        picker.dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

extension ViewController: VNDocumentCameraViewControllerDelegate {
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        // Process the scanned pages
        guard scan.pageCount > 0 else {
            showAlert(title: "Missing image", message: "Failed to find scanned image")
            return
        }
        let scannedImage = scan.imageOfPage(at: 0)
        imageView.image = scannedImage

        // You are responsible for dismissing the controller.
        controller.dismiss(animated: true)
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true)
    }

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        // You should handle errors appropriately in your app.
        showAlert(title: "Scanning error", message: error.localizedDescription)

        // You are responsible for dismissing the controller.
        controller.dismiss(animated: true)
    }
}
