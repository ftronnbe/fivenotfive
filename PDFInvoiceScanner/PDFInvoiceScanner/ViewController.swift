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

struct ValidatedObservation {
    let observation: VNRecognizedTextObservation
    let text: String
}

class ViewController: UIViewController {

    let receiverKeywords = ["bankgiro", "postgiro", "mottagare", "bankgiro:"]
    let ocrKeywords = ["ocr-nummer", "ocr", "ocr/fakturanummer"]
    let dueDateKeywords = ["förfallodatum", "förfallodatum:", "förfallodag", "förfallodag:",
                           "forfallodatum", "forfallodatum:", "forfallodag", "forfallodag:"]

    let receiverRegex = #"\b([0-9,-]{8,})\b"#
    let ocrRegex = #"\b([0-9]{8,})\b"#
    let dueDateRegex = #"\b([12]\d{3}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01]))\b"#

    override func viewDidLoad() {
        super.viewDidLoad()

        let textRecognitionRequest = VNRecognizeTextRequest { (request, error) in
            if let observations = request.results as? [VNRecognizedTextObservation] {

                // Filter out receiver observations
                let validatedReceiverObservations = self.validatedObservations(among: observations,
                                                                               matching: self.receiverKeywords,
                                                                               regexLiteral: self.receiverRegex)

                // Filter out OCR
                let validatedOcrObservations = self.validatedObservations(among: observations,
                                                                          matching: self.ocrKeywords,
                                                                          regexLiteral: self.ocrRegex)

                // Filter out due date
                let validatedDueDateObservations = self.validatedObservations(among: observations,
                                                                              matching: self.dueDateKeywords,
                                                                              regexLiteral: self.dueDateRegex)

                print("Possible receivers: \(validatedReceiverObservations.map { $0.text })")
                print("Possible ocr: \(validatedOcrObservations.map { $0.text })")
                print("Possible due dates: \(validatedDueDateObservations.map { $0.text })")

            }
        }
        textRecognitionRequest.recognitionLevel = .accurate
        textRecognitionRequest.usesLanguageCorrection = false

        guard let cgImage = UIImage(named: "sc.png")?.cgImage else {
            fatalError("Failed to create cgimage")
        }
        let invoiceCIImage = CIImage(cgImage: cgImage)
        let imageRequestHandler = VNImageRequestHandler(ciImage: invoiceCIImage,
                                                        options: [:])

        do {
            try imageRequestHandler.perform([textRecognitionRequest])
        } catch {
            print(error)
        }
    }

    // MARK: Validation

    func validatedObservations(among observations: [VNRecognizedTextObservation],
                               matching keywords: [String],
                               regexLiteral: StringLiteralType) -> [ValidatedObservation] {
        let keywordObservations = self.findObservations(matchingKeywords: keywords, among: observations)
        var validatedObservations: [ValidatedObservation] = []
        for keywordObservation in keywordObservations {
            let closestObservationToRight = self.findObservationClosestToTheRight(of: keywordObservation, among: observations)
            let closestObservationBelow = self.findObservationClosestBelow(of: keywordObservation, among: observations)
            let validObservations = self.validatedObservation(regularExpressionLiteral: regexLiteral,
                                                              among: [closestObservationToRight, closestObservationBelow])
            validatedObservations.append(contentsOf: validObservations)
        }
        return validatedObservations
    }

    func validatedObservation(regularExpressionLiteral: StringLiteralType, among observations: [VNRecognizedTextObservation?]) -> [ValidatedObservation] {
        var validatedObservations: [ValidatedObservation] = []
        for observation in observations {
            guard let observation = observation,
                let text = observation.topCandidates(1).first?.string else {
                    continue
            }

            if text.range(of: regularExpressionLiteral, options: .regularExpression) != nil {
                let validatedObservation = ValidatedObservation(observation: observation, text: text)
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
            return keywords.contains(text.lowercased())
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

