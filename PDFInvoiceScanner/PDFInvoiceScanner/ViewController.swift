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
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var processImageButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        pdfScannerUtility.delegate = self
   }
    
    @IBAction func pickImageTapped(_ sender: Any) {
        // TODO: Bring up image picker
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
            print("Error: \(error)")
        case .success(let validatedObservations):
            print(validatedObservations)
        }
    }

}

extension ViewController: UIImagePickerControllerDelegate {
    
}
