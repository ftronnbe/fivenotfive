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
        pickerController.allowsEditing = true
        pickerController.mediaTypes = ["public.image"]
        pickerController.sourceType = .photoLibrary
        present(pickerController, animated: true, completion: nil)
        self.pickerController = pickerController
    }

    @IBAction func scanDocumentTapped(_ sender: Any) {
        // TODO: Bring up document scanner
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
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in

        }))
        present(alert, animated: true, completion: nil)
    }

}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[.editedImage] as? UIImage else {
            return
        }
        self.imageView.image = image
    }
}
