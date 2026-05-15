// Data/IntelligenceKit/Sources/PageTranslatorLive.swift
import Foundation
import os
import Domain

public struct PageTranslatorLive: PageTranslator {
    private let ocr: VisionTextRecognizer
    private let detector: LanguageDetector
    private let llm: any LLMTranslator
    private let sampler: BackgroundColorSampler
    private static let log = Logger(subsystem: "com.coby.mana", category: "translation")

    public init(
        ocr: VisionTextRecognizer = VisionTextRecognizer(),
        detector: LanguageDetector = LanguageDetector(),
        sampler: BackgroundColorSampler = BackgroundColorSampler(),
        llm: any LLMTranslator
    ) {
        self.ocr = ocr
        self.detector = detector
        self.sampler = sampler
        self.llm = llm
    }

    public func translate(
        imageData: Data,
        comicId: UUID,
        pageIndex: Int,
        targetLanguage: String
    ) async throws -> TranslatedPage {
        // 1) OCR
        let allBoxes: [TextLineBox]
        do {
            allBoxes = try await ocr.recognize(imageData: imageData)
        } catch {
            Self.log.error("OCR failed: \(error.localizedDescription, privacy: .public)")
            throw PageTranslatorError.silentFailure
        }
        if allBoxes.isEmpty {
            return TranslatedPage(
                comicId: comicId, pageIndex: pageIndex,
                sourceLanguage: "und", targetLanguage: targetLanguage,
                lines: [], createdAt: Date()
            )
        }

        // 2) Sample backgrounds and keep only lines that look like they sit on a
        //    paper-like speech-bubble background. SFX, signage, and artwork text
        //    are dropped here.
        let sampled: [(box: TextLineBox, argb: UInt32)] = allBoxes.map { box in
            (box, sampler.sample(imageData: imageData, normalizedBox: box.boundingBox))
        }
        let bubbleBoxes = sampled.filter {
            BackgroundColorSampler.isLikelyBubbleBackground($0.argb)
        }
        if bubbleBoxes.isEmpty {
            return TranslatedPage(
                comicId: comicId, pageIndex: pageIndex,
                sourceLanguage: "und", targetLanguage: targetLanguage,
                lines: [], createdAt: Date()
            )
        }

        // 3) Per-line language detection + char-count weighting over bubble lines only.
        //    Spec §6: "und" treated as Japanese.
        var charCounts: [String: Int] = [:]
        for entry in bubbleBoxes {
            let raw = detector.detect(entry.box.text)
            let lang = (raw == "und") ? "ja" : raw
            charCounts[lang, default: 0] += entry.box.text.count
        }
        let source = charCounts.max(by: { $0.value < $1.value })?.key ?? "ja"
        if source == targetLanguage {
            return TranslatedPage(
                comicId: comicId, pageIndex: pageIndex,
                sourceLanguage: source, targetLanguage: targetLanguage,
                lines: [], createdAt: Date()
            )
        }

        // 4) LLM
        let inputs = bubbleBoxes.map { $0.box.text }
        let translated: [String]
        do {
            translated = try await llm.translateLines(inputs, from: source, to: targetLanguage)
        } catch {
            Self.log.error("LLM failure: \(error.localizedDescription, privacy: .public)")
            throw PageTranslatorError.silentFailure
        }
        guard translated.count == bubbleBoxes.count else {
            throw PageTranslatorError.silentFailure
        }

        // 5) Assemble using the already-sampled backgrounds.
        let lines: [TranslatedLine] = zip(bubbleBoxes, translated).map { entry, t in
            TranslatedLine(
                original: entry.box,
                translated: t,
                backgroundColorARGB: entry.argb
            )
        }
        return TranslatedPage(
            comicId: comicId, pageIndex: pageIndex,
            sourceLanguage: source, targetLanguage: targetLanguage,
            lines: lines, createdAt: Date()
        )
    }
}
