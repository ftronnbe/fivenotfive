//
//  PDFScannerUtility.swift
//  PDFInvoiceScanner
//
//  Created by Filip Tronnberg on 2019-09-06.
//  Copyright © 2019 Filip Tronnberg. All rights reserved.
//

import UIKit
import Foundation
import AVFoundation
import Vision
import Accelerate
import CoreImage

enum SomeError: Error {
    case invalidInputImage
    case somethingHappened
}

struct PdfValidatedObservations: CustomDebugStringConvertible {
    let validatedReceiverObservations: [ValidatedObservation]
    let validatedOcrObservations: [ValidatedObservation]
    let validatedDueDateObservations: [ValidatedObservation]
    let validatedInvoiceNumberObservations: [ValidatedObservation]
    let validatedPaymentObservations: [ValidatedObservation]

    var debugDescription: String {
        return "Possible receiver: \(validatedReceiverObservations)\nPossible ocr: \(validatedOcrObservations)\nPossible due date: \(validatedDueDateObservations)\nPossible invoice number: \(validatedInvoiceNumberObservations)\nPossible amount: \(validatedPaymentObservations)"
    }
}

struct ValidatedObservation: CustomDebugStringConvertible {
    enum FieldType {

        case receiver
        case ocr
        case dueDate
        case invoiceNumber
        case payment

        var displayName: String {
            switch self {
            case .receiver:
                return "Receiver"
            case .ocr:
                return "OCR"
            case .dueDate:
                return "Due Date"
            case .invoiceNumber:
                return "Invoice Number"
            case .payment:
                return "Amount"
            }
        }
    }

    let observation: VNRecognizedTextObservation
    let text: String
    let type: FieldType

    var debugDescription: String {
        return "\(text)"
    }
}

protocol PDFScannerUtilityDelegate: AnyObject {
    func pdfScannerUtilityDidBeginProcessing(_ pdfScannerUtility: PDFScannerUtility)
    func pdfScannerUtility(_ pdfScannerUtility: PDFScannerUtility, didFinishProcessing result: Result<PdfValidatedObservations, Error>)
}

class PDFScannerUtility {

    weak var delegate: PDFScannerUtilityDelegate?
    
    let receiverKeywords = ["bankgiro", "postgiro", "mottagare", "bg", "pg"]
    let ocrKeywords = ["ocr"]
    let dueDateKeywords = ["forfallo", "förfallo", "betalningsdag", "tillhanda"]
    let invoiceNumberKeywords = ["fakturanummer", "fakturanr"]
    let paymentKeywords = ["att betala", "belopp att betala", "totalt", "belopp"]

    let receiverRegex = #"\b^([0-9,-]{8,})\b"#
    let ocrRegex = #"\b^([0-9]{8,})\b"#
    let dueDateRegex = #"\b^([12]\d{3}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01]))\b"#
    let invoiceNumberRegex = #"\b^([0-9]{1,15})\b"#
    let paymentRegex = #"\b[\d,. ]+\b"#

    func extractInvoiceInformation(image: UIImage) {
        guard let cgImage = image.cgImage else {
            delegate?.pdfScannerUtility(self, didFinishProcessing: .failure(SomeError.invalidInputImage))
            return
        }

        let invoiceCIImage = CIImage(cgImage: cgImage)
        let imageRequestHandler = VNImageRequestHandler(ciImage: invoiceCIImage,
                                                        options: [:])
        do {
            delegate?.pdfScannerUtilityDidBeginProcessing(self)
            try imageRequestHandler.perform([createTextRecognitionRequest()])
        } catch {
            delegate?.pdfScannerUtility(self, didFinishProcessing: .failure(error))
        }
    }

    func createTextRecognitionRequest() -> VNRecognizeTextRequest {
        let textRecognitionRequest = VNRecognizeTextRequest { (request, error) in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                self.delegate?.pdfScannerUtility(self, didFinishProcessing: .failure(error ?? SomeError.somethingHappened))
                return
            }

            // Filter out receiver observations
            let validatedReceiverObservations = self.validatedObservations(among: observations,
                                                                           matching: self.receiverKeywords,
                                                                           regexLiteral: self.receiverRegex,
                                                                           type: .receiver)

            // Filter out OCR
            let validatedOcrObservations = self.validatedObservations(among: observations,
                                                                      matching: self.ocrKeywords,
                                                                      regexLiteral: self.ocrRegex,
                                                                      type: .ocr)

            // Filter out due date
            let validatedDueDateObservations = self.validatedObservations(among: observations,
                                                                          matching: self.dueDateKeywords,
                                                                          regexLiteral: self.dueDateRegex,
                                                                          type: .dueDate)

            // Filter out invoice number
            let validatedInvoiceNumberObservations = self.validatedObservations(among: observations,
                                                                                matching: self.invoiceNumberKeywords,
                                                                                regexLiteral: self.invoiceNumberRegex,
                                                                                type: .invoiceNumber)

            // Filter out payments
            let validatedPaymentObservations = self.validatedObservations(among: observations,
                                                                          matching: self.paymentKeywords,
                                                                          regexLiteral: self.paymentRegex,
                                                                          type: .payment,
                                                                          shouldExtractExactMatch: true)

            let validatedObservations = PdfValidatedObservations(validatedReceiverObservations: validatedReceiverObservations,
                                                                 validatedOcrObservations: validatedOcrObservations,
                                                                 validatedDueDateObservations: validatedDueDateObservations,
                                                                 validatedInvoiceNumberObservations: validatedInvoiceNumberObservations,
                                                                 validatedPaymentObservations: validatedPaymentObservations)
            self.delegate?.pdfScannerUtility(self, didFinishProcessing: .success(validatedObservations))
        }

        textRecognitionRequest.recognitionLevel = .accurate
        textRecognitionRequest.usesLanguageCorrection = false

        return textRecognitionRequest
    }
    
    // MARK: Extraction

    func extract(regexLiteral: StringLiteralType, from validatedObservations: [ValidatedObservation], type: ValidatedObservation.FieldType) -> [ValidatedObservation] {
        var observations: [ValidatedObservation] = []
        for observation in validatedObservations {
            guard let range = observation.text.range(of: regexLiteral, options: .regularExpression) else { continue }
            let text = String(observation.text[range])
            let validatedObservation = ValidatedObservation(observation: observation.observation, text: text, type: type)
            observations.append(validatedObservation)
        }

        return observations
    }

    // MARK: Validation

    func validatedObservations(among observations: [VNRecognizedTextObservation],
                               matching keywords: [String],
                               regexLiteral: StringLiteralType,
                               type: ValidatedObservation.FieldType,
                               shouldExtractExactMatch: Bool = false) -> [ValidatedObservation] {
        let keywordObservations = self.findObservations(matchingKeywords: keywords, among: observations)
        var validatedObservations: [ValidatedObservation] = []
        for keywordObservation in keywordObservations {
            let closestObservationToRight = self.findObservationClosestToTheRight(of: keywordObservation, among: observations)
            let closestObservationBelow = self.findObservationClosestBelow(of: keywordObservation, among: observations)
            let validObservations = self.validatedObservation(regularExpressionLiteral: regexLiteral,
                                                              among: [closestObservationToRight, closestObservationBelow],
                                                              type: type,
                                                              shouldExtractExactMatch: shouldExtractExactMatch)
            validatedObservations.append(contentsOf: validObservations)
        }
        return validatedObservations
    }

    func validatedObservation(regularExpressionLiteral: StringLiteralType,
                              among observations: [VNRecognizedTextObservation?],
                              type: ValidatedObservation.FieldType,
                              shouldExtractExactMatch: Bool = false) -> [ValidatedObservation] {
        var validatedObservations: [ValidatedObservation] = []
        for observation in observations {
            guard let observation = observation,
                var text = observation.topCandidates(1).first?.string else {
                    continue
            }

            if let regexRange = text.range(of: regularExpressionLiteral, options: .regularExpression) {
                if shouldExtractExactMatch {
                    text = String(text[regexRange])
                }

                let validatedObservation = ValidatedObservation(observation: observation, text: text, type: type)
                validatedObservations.append(validatedObservation)
            }
        }
        return validatedObservations
    }

    // MARK: General

    func findObservations(matchingKeywords keywords: [String], among observations: [VNRecognizedTextObservation]) -> [VNRecognizedTextObservation] {
        return observations.filter { (observation) -> Bool in
            guard let text = observation.topCandidates(1).first?.string else {
                return false
            }
            
            for keyword in keywords {
                if text.lowercased(with: Locale(identifier: "sv_SE")).contains(keyword) {
                    return true
                }
            }
            
            return false
        }
    }

    func findObservationClosestToTheRight(of rootObservation: VNRecognizedTextObservation, among observations: [VNRecognizedTextObservation]) -> VNRecognizedTextObservation? {

        let bottomRight = rootObservation.bottomRight

        var shortestDistanceToRight: CGFloat = .infinity
        var closestObservationToRight: VNRecognizedTextObservation? = nil

        for observation in observations {

            // Skip root observation
            if observation == rootObservation {
                continue
            }

            // Skip observations not on the same horizontal line
            if abs(observation.bottomLeft.y - bottomRight.y) > 0.01 {
                continue
            }

            // Skip observations to the left
            if observation.bottomLeft.x < bottomRight.x {
                continue
            }

            let distance = observation.bottomLeft.x - bottomRight.x
            if distance < shortestDistanceToRight {
                shortestDistanceToRight = distance
                closestObservationToRight = observation
            }
        }

        return closestObservationToRight
    }

    func findObservationClosestBelow(of rootObservation: VNRecognizedTextObservation, among observations: [VNRecognizedTextObservation]) -> VNRecognizedTextObservation? {

        let bottomLeft = rootObservation.bottomLeft


        var shortestDistanceBelow: CGFloat = .infinity
        var closestObservationBelow: VNRecognizedTextObservation? = nil

        for observation in observations {

            // Skip root observation
            if observation == rootObservation {
                continue
            }

            // Skip observations not on the same vertical line
            if abs(observation.bottomLeft.x - bottomLeft.x) > 0.01 {
                continue
            }

            // Skip observations above
            if observation.bottomLeft.y > bottomLeft.y {
                continue
            }

            let distance = bottomLeft.y - observation.bottomLeft.y
            if distance < shortestDistanceBelow {
                shortestDistanceBelow = distance
                closestObservationBelow = observation
            }
        }

        return closestObservationBelow
    }


}
