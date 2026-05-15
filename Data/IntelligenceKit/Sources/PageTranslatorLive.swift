import Foundation
import os
import Domain

public struct PageTranslatorLive: PageTranslator {
    private let ocr: VisionTextRecognizer
    private let llm: any LLMTranslator
    private let sampler: BackgroundColorSampler
    private static let log = Logger(subsystem: "com.coby.mana", category: "translation")

    /// Hardcoded source language for the translation pipeline. The user reads
    /// Japanese manga; everything on the page is treated as Japanese before
    /// being handed to the LLM. If the user's app language is also Japanese,
    /// the pipeline short-circuits without calling the model.
    private static let sourceLanguage = "ja"

    public init(
        ocr: VisionTextRecognizer = VisionTextRecognizer(),
        sampler: BackgroundColorSampler = BackgroundColorSampler(),
        llm: any LLMTranslator
    ) {
        self.ocr = ocr
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
                sourceLanguage: Self.sourceLanguage, targetLanguage: targetLanguage,
                lines: [], createdAt: Date()
            )
        }

        // 2) Short-circuit when there's nothing to translate (e.g. user reads in
        //    Japanese already). Still cache the empty result so we don't re-OCR.
        if Self.sourceLanguage == targetLanguage {
            return TranslatedPage(
                comicId: comicId, pageIndex: pageIndex,
                sourceLanguage: Self.sourceLanguage, targetLanguage: targetLanguage,
                lines: [], createdAt: Date()
            )
        }

        // 3) Translate everything in one batch.
        let inputs = boxes.map(\.text)
        let translated: [String]
        do {
            translated = try await llm.translateLines(inputs, from: Self.sourceLanguage, to: targetLanguage)
        } catch {
            Self.log.error("LLM failure: \(error.localizedDescription, privacy: .public)")
            throw PageTranslatorError.silentFailure
        }
        guard translated.count == boxes.count else {
            throw PageTranslatorError.silentFailure
        }

        // 4) Sample a background color per line for the opaque overlay fill, then
        //    assemble.
        let lines: [TranslatedLine] = zip(boxes, translated).map { box, t in
            let argb = sampler.sample(imageData: imageData, normalizedBox: box.boundingBox)
            return TranslatedLine(original: box, translated: t, backgroundColorARGB: argb)
        }
        return TranslatedPage(
            comicId: comicId, pageIndex: pageIndex,
            sourceLanguage: Self.sourceLanguage, targetLanguage: targetLanguage,
            lines: lines, createdAt: Date()
        )
    }
}
