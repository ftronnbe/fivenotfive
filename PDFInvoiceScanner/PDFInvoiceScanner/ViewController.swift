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

    override func viewDidLoad() {
        super.viewDidLoad()
        pdfScannerUtility.delegate = self

        let image = UIImage(named: "sc.png")!
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
