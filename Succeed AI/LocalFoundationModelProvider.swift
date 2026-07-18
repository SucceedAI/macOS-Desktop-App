import Foundation
import FoundationModels

final class LocalFoundationModelProvider: AIProvideable {
    private let model: SystemLanguageModel
    private let runner: LocalModelRunner

    init() {
        let model = SystemLanguageModel(
            useCase: .general,
            guardrails: .permissiveContentTransformations
        )
        self.model = model
        self.runner = LocalModelRunner(model: model)
    }

    var availability: AIAvailabilityStatus {
        switch model.availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceDisabled
        case .unavailable(.modelNotReady):
            return .modelPreparing
        case .unavailable:
            return .modelPreparing
        }
    }

    func prepare() {
        guard availability.isAvailable else { return }
        Task { await runner.prepare() }
    }

    func releasePreparedResources() {
        Task { await runner.releasePreparedResources() }
    }

    @discardableResult
    func query(
        _ query: String,
        completion: @escaping (Result<String, AIProviderError>) -> Void
    ) -> Task<Void, Never> {
        let request = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !request.isEmpty else {
            completion(.failure(AIProviderError(userMessage: "Type a writing request first.")))
            return Task {}
        }

        guard availability.isAvailable else {
            completion(.failure(AIProviderError(userMessage: availability.detail)))
            return Task {}
        }

        return Task {
            do {
                try Task.checkCancellation()
                let content = try await runner.respond(to: request)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                try Task.checkCancellation()
                guard !content.isEmpty else {
                    completion(.failure(AIProviderError(userMessage: "The on-device model returned an empty response.")))
                    return
                }
                completion(.success(content))
            } catch is CancellationError {
                completion(.failure(.cancelled))
            } catch let error as AIProviderError {
                completion(.failure(error))
            } catch let error as LanguageModelSession.GenerationError {
                completion(.failure(AIProviderError(userMessage: Self.userMessage(for: error))))
            } catch {
                completion(.failure(AIProviderError(userMessage: "Local generation could not finish. Try a shorter request.")))
            }
        }
    }

    func getAiInstructions(_ query: String) -> String {
        """
        Complete the following writing request and return only the finished text:
        \(query.trimmingCharacters(in: .whitespacesAndNewlines))
        """
    }

    private static func userMessage(for error: LanguageModelSession.GenerationError) -> String {
        switch error {
        case .exceededContextWindowSize:
            return "That request is too long for the on-device model. Shorten it and try again."
        case .assetsUnavailable:
            #if os(macOS)
            return "The on-device model is not ready yet. Check Apple Intelligence in System Settings."
            #else
            return "The on-device model is not ready yet. Check Apple Intelligence in Settings."
            #endif
        case .unsupportedLanguageOrLocale:
            return "The on-device model does not currently support the language in this request."
        case .rateLimited, .concurrentRequests:
            return "The on-device model is busy. Wait a moment and try again."
        case .guardrailViolation, .refusal:
            return "The on-device model could not complete that request. Try rephrasing it."
        case .unsupportedGuide, .decodingFailure:
            return "Local generation could not format a response. Try again."
        @unknown default:
            return "Local generation could not finish. Try again."
        }
    }
}

private actor LocalModelRunner {
    private let model: SystemLanguageModel
    private var preparedSession: LanguageModelSession?
    private let generationGate = LocalGenerationGate.shared

    init(model: SystemLanguageModel) {
        self.model = model
    }

    func prepare() {
        guard preparedSession == nil else { return }
        let session = makeSession()
        session.prewarm()
        preparedSession = session
    }

    func releasePreparedResources() {
        preparedSession = nil
    }

    func respond(to request: String) async throws -> String {
        guard await generationGate.acquire() else { throw CancellationError() }
        defer { Task { await generationGate.release() } }

        let firstSession = preparedSession ?? makeSession()
        preparedSession = nil
        defer { prepare() }

        for attempt in 0..<3 {
            try Task.checkCancellation()
            let session = attempt == 0 ? firstSession : makeSession()
            do {
                let response = try await session.respond(
                    to: request,
                    options: GenerationOptions(
                        sampling: .random(probabilityThreshold: 0.9),
                        temperature: 0.2,
                        maximumResponseTokens: 800
                    )
                )
                return response.content
            } catch let error as LanguageModelSession.GenerationError {
                switch error {
                case .concurrentRequests, .rateLimited:
                    guard attempt < 2 else { throw error }
                    try await Task.sleep(for: .milliseconds(350 * (attempt + 1)))
                default:
                    throw error
                }
            }
        }

        throw AIProviderError(userMessage: "The on-device model is busy. Wait a moment and try again.")
    }

    private func makeSession() -> LanguageModelSession {
        LanguageModelSession(model: model, instructions: """
        You are SucceedAI, a precise writing assistant embedded on an Apple device.
        Follow the user's writing instruction directly.
        Return only the requested finished text, with no preface, commentary, quotation marks, or markdown fence unless the user explicitly asks for them.
        Preserve facts, names, intent, language, and useful formatting from source text.
        Prefer concise, natural language and never invent missing factual details.
        """)
    }
}

actor LocalGenerationGate {
    static let shared = LocalGenerationGate()

    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Bool, Never>
    }

    private var isOccupied = false
    private var waiters: [Waiter] = []

    func acquire() async -> Bool {
        guard !Task.isCancelled else { return false }
        guard isOccupied else {
            isOccupied = true
            return true
        }

        let waiterID = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume(returning: false)
                } else {
                    waiters.append(Waiter(id: waiterID, continuation: continuation))
                }
            }
        } onCancel: {
            Task { await self.cancel(waiterID: waiterID) }
        }
    }

    func release() {
        guard !waiters.isEmpty else {
            isOccupied = false
            return
        }
        let waiter = waiters.removeFirst()
        waiter.continuation.resume(returning: true)
    }

    private func cancel(waiterID: UUID) {
        if let index = waiters.firstIndex(where: { $0.id == waiterID }) {
            let waiter = waiters.remove(at: index)
            waiter.continuation.resume(returning: false)
        }
    }
}
