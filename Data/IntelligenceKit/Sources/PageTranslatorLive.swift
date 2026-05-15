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
        let boxes: [TextLineBox]
        do {
            boxes = try await ocr.recognize(imageData: imageData)
        } catch {
            Self.log.error("OCR failed: \(error.localizedDescription, privacy: .public)")
            throw PageTranslatorError.silentFailure
        }
        if boxes.isEmpty {
            return TranslatedPage(
                comicId: comicId, pageIndex: pageIndex,
                sourceLanguage: "und", targetLanguage: targetLanguage,
                lines: [], createdAt: Date()
            )
        }

        // 2) Pick dominant language by total character count per language, across lines.
        //    Each line is detected independently; weight by line.text.count.
        //    "und" lines count toward Japanese — matches §6 fallback.
        var charCounts: [String: Int] = [:]
        for box in boxes {
            let raw = detector.detect(box.text)
            let lang = (raw == "und") ? "ja" : raw
            charCounts[lang, default: 0] += box.text.count
        }
        let source = charCounts.max(by: { $0.value < $1.value })?.key ?? "ja"

        if source == targetLanguage {
            return TranslatedPage(
                comicId: comicId, pageIndex: pageIndex,
                sourceLanguage: source, targetLanguage: targetLanguage,
                lines: [], createdAt: Date()
            )
        }

        // 3) LLM
        let inputs = boxes.map(\.text)
        let translated: [String]
        do {
            translated = try await llm.translateLines(inputs, from: source, to: targetLanguage)
        } catch {
            Self.log.error("LLM failure: \(error.localizedDescription, privacy: .public)")
            throw PageTranslatorError.silentFailure
        }
        guard translated.count == boxes.count else {
            throw PageTranslatorError.silentFailure
        }

        // 4) Background sample + assemble
        let lines: [TranslatedLine] = zip(boxes, translated).map { box, t in
            let argb = sampler.sample(imageData: imageData, normalizedBox: box.boundingBox)
            return TranslatedLine(original: box, translated: t, backgroundColorARGB: argb)
        }
        return TranslatedPage(
            comicId: comicId, pageIndex: pageIndex,
            sourceLanguage: source, targetLanguage: targetLanguage,
            lines: lines, createdAt: Date()
        )
    }
}
