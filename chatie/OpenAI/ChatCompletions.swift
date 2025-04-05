import Foundation

// MARK: - JSONNullOrAny

/// A helper type for decoding JSON values that might be null or any of a set of basic types.
public struct JSONNullOrAny: Codable {
    public let rawValue: Any?
    
    public init(rawValue: Any?) {
        self.rawValue = rawValue
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.rawValue = nil
            return
        }
        if let intVal = try? container.decode(Int.self) {
            self.rawValue = intVal
            return
        }
        if let doubleVal = try? container.decode(Double.self) {
            self.rawValue = doubleVal
            return
        }
        if let boolVal = try? container.decode(Bool.self) {
            self.rawValue = boolVal
            return
        }
        if let stringVal = try? container.decode(String.self) {
            self.rawValue = stringVal
            return
        }
        // Fallback: try to decode as a string.
        self.rawValue = try container.decode(String.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intVal = rawValue as? Int {
            try container.encode(intVal)
        } else if let doubleVal = rawValue as? Double {
            try container.encode(doubleVal)
        } else if let boolVal = rawValue as? Bool {
            try container.encode(boolVal)
        } else if let stringVal = rawValue as? String {
            try container.encode(stringVal)
        } else {
            try container.encodeNil()
        }
    }
}

// MARK: - Public API

/// A convenient wrapper for the OpenAI Chat Completions API.
public class OpenAIChat {
    
    // MARK: - Properties
    private let apiKey: String
    private let session: URLSession
    private let baseURL: URL
    
    // MARK: - Init
    /// Initializes the chat client with your OpenAI API key.
    /// - Parameters:
    ///   - apiKey: Your OpenAI API key.
    ///   - session: A custom URLSession, if desired. Defaults to `.shared`.
    ///   - baseURL: Custom base URL, if you are proxying or using a different domain.
    public init(apiKey: String,
                session: URLSession = .shared,
                baseURL: URL = URL(string: "https://api.openai.com")!) {
        self.apiKey = apiKey
        self.session = session
        self.baseURL = baseURL
    }
    
    // MARK: - Non-Streaming
    
    /// Creates a chat completion (non-streaming).
    /// - Parameter request: The request body containing all parameters.
    /// - Returns: A `ChatCompletionResponse` with the model’s response.
    public func createChatCompletion(
        request: ChatCompletionRequest
    ) async throws -> ChatCompletionResponse {
        let endpoint = baseURL.appendingPathComponent("/v1/chat/completions")
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let bodyData = try encoder.encode(request)
        urlRequest.httpBody = bodyData
        
        let (data, response) = try await session.data(for: urlRequest)
        try validateHTTP(response: response, data: data)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let chatResponse = try decoder.decode(ChatCompletionResponse.self, from: data)
        return chatResponse
    }
    
    // MARK: - Streaming
    
    /// Creates a chat completion in streaming mode using Server-Sent Events (SSE).
    /// Returns an `AsyncThrowingStream` of `ChatCompletionStreamChunk` objects,
    /// each representing a piece of data sent by the API.
    ///
    /// - Parameter request: The chat completion request (with `stream = true`).
    ///   You *must* set `stream = true` in the request for streaming to work.
    /// - Returns: An async stream of `ChatCompletionStreamChunk`.
    public func createChatCompletionStream(
        request: ChatCompletionRequest
    ) async throws -> AsyncThrowingStream<ChatCompletionStreamChunk, Error> {
        guard request.stream == true else {
            throw OpenAIChatError.streamingParameterMissing
        }
        
        let endpoint = baseURL.appendingPathComponent("/v1/chat/completions")
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let bodyData = try encoder.encode(request)
        urlRequest.httpBody = bodyData
        
        let (stream, task) = makeSSEStream(with: urlRequest)
        task.resume()
        return stream
    }
    
    // MARK: - Helpers
    
    /// Validates an HTTP response by checking status code and throwing if it’s an error.
    private func validateHTTP(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw OpenAIChatError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? "<no body>"
            throw OpenAIChatError.apiError(statusCode: http.statusCode, body: bodyText)
        }
    }
    
    /// Creates an `AsyncThrowingStream` that parses Server-Sent Events (SSE) from the API response.
    private func makeSSEStream(with request: URLRequest) ->
        (AsyncThrowingStream<ChatCompletionStreamChunk, Error>, URLSessionDataTask) {
        // Capture the continuation so the delegate can yield events.
        var continuation: AsyncThrowingStream<ChatCompletionStreamChunk, Error>.Continuation!
        let stream = AsyncThrowingStream<ChatCompletionStreamChunk, Error> { cont in
            continuation = cont
        }
        
        let delegate = SSEStreamDelegate { result in
            switch result {
            case .failure(let error):
                continuation.finish(throwing: error)
            case .success(let chunk):
                continuation.yield(chunk)
            }
        }
        
        let config = URLSessionConfiguration.default
        let ephemeralSession = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        let task = ephemeralSession.dataTask(with: request)
        
        return (stream, task)
    }
}

// MARK: - SSE Parsing Delegate

fileprivate class SSEStreamDelegate: NSObject, URLSessionDataDelegate {
    private let onEvent: (Result<ChatCompletionStreamChunk, Error>) -> Void
    private var buffer = Data()
    
    init(onEvent: @escaping (Result<ChatCompletionStreamChunk, Error>) -> Void) {
        self.onEvent = onEvent
    }
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data) {
        buffer.append(data)
        let separator1 = "\n\n".data(using: .utf8)!
        let separator2 = "\r\n\r\n".data(using: .utf8)!
        
        while true {
            if let range = buffer.range(of: separator1) ?? buffer.range(of: separator2) {
                let chunkData = buffer.subdata(in: 0..<range.lowerBound)
                buffer.removeSubrange(0..<range.upperBound)
                
                let sseString = String(data: chunkData, encoding: .utf8) ?? ""
                if sseString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continue
                }
                
                let lines = sseString.components(separatedBy: .newlines)
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard trimmed.hasPrefix("data:") else { continue }
                    
                    let jsonString = trimmed.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
                    if jsonString == "[DONE]" {
                        return
                    } else if !jsonString.isEmpty {
                        do {
                            let decoder = JSONDecoder()
                            decoder.keyDecodingStrategy = .convertFromSnakeCase
                            let chunk = try decoder.decode(ChatCompletionStreamChunk.self,
                                                           from: Data(jsonString.utf8))
                            onEvent(.success(chunk))
                        } catch {
                            onEvent(.failure(error))
                        }
                    }
                }
            } else {
                break
            }
        }
    }
    
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        if let error = error {
            onEvent(.failure(error))
        }
    }
}

// MARK: - ChatCompletionRequest (Body Parameters)

public struct ChatCompletionRequest: Encodable {
    public var model: String
    public var messages: [ChatMessage]
    
    public var audio: AudioOutputParameters?
    public var frequencyPenalty: Double?
    public var presencePenalty: Double?
    public var reasoningEffort: String?
    public var responseFormat: ResponseFormat?
    public var logitBias: [String: Int]?
    public var logprobs: Bool?
    public var maxCompletionTokens: Int?
    public var maxTokens: Int?
    public var metadata: [String: String]?
    public var modalities: [String]?
    public var n: Int?
    public var parallelToolCalls: Bool?
    public var prediction: PredictionConfig?
    public var serviceTier: String?
    public var stop: StopSequence?
    public var store: Bool?
    public var stream: Bool?
    public var streamOptions: StreamOptions?
    public var temperature: Double?
    public var toolChoice: ToolChoice?
    public var tools: [ToolDefinition]?
    public var topLogprobs: Int?
    public var topP: Double?
    public var user: String?
    public var webSearchOptions: WebSearchOptions?
    public var functionCall: FunctionCallSetting?
    public var functions: [DeprecatedFunctionDefinition]?
    
    public init(
        model: String,
        messages: [ChatMessage],
        audio: AudioOutputParameters? = nil,
        frequencyPenalty: Double? = nil,
        presencePenalty: Double? = nil,
        reasoningEffort: String? = nil,
        responseFormat: ResponseFormat? = nil,
        logitBias: [String: Int]? = nil,
        logprobs: Bool? = nil,
        maxCompletionTokens: Int? = nil,
        maxTokens: Int? = nil,
        metadata: [String: String]? = nil,
        modalities: [String]? = nil,
        n: Int? = nil,
        parallelToolCalls: Bool? = nil,
        prediction: PredictionConfig? = nil,
        serviceTier: String? = nil,
        stop: StopSequence? = nil,
        store: Bool? = nil,
        stream: Bool? = nil,
        streamOptions: StreamOptions? = nil,
        temperature: Double? = nil,
        toolChoice: ToolChoice? = nil,
        tools: [ToolDefinition]? = nil,
        topLogprobs: Int? = nil,
        topP: Double? = nil,
        user: String? = nil,
        webSearchOptions: WebSearchOptions? = nil,
        functionCall: FunctionCallSetting? = nil,
        functions: [DeprecatedFunctionDefinition]? = nil
    ) {
        self.model = model
        self.messages = messages
        self.audio = audio
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.reasoningEffort = reasoningEffort
        self.responseFormat = responseFormat
        self.logitBias = logitBias
        self.logprobs = logprobs
        self.maxCompletionTokens = maxCompletionTokens
        self.maxTokens = maxTokens
        self.metadata = metadata
        self.modalities = modalities
        self.n = n
        self.parallelToolCalls = parallelToolCalls
        self.prediction = prediction
        self.serviceTier = serviceTier
        self.stop = stop
        self.store = store
        self.stream = stream
        self.streamOptions = streamOptions
        self.temperature = temperature
        self.toolChoice = toolChoice
        self.tools = tools
        self.topLogprobs = topLogprobs
        self.topP = topP
        self.user = user
        self.webSearchOptions = webSearchOptions
        self.functionCall = functionCall
        self.functions = functions
    }
}

// MARK: - Supporting Types

public struct ChatMessage: Codable {
    public var role: String
    public var content: ContentUnion?
    public var name: String?
    
    public var audio: AudioData?
    public var refusal: String?
    
    public var functionCall: DeprecatedFunctionCall?
    public var toolCalls: [ToolCall]?
    
    public var toolCallId: String?
    public var functionName: String?
    
    public init(role: String,
                content: ContentUnion? = nil,
                name: String? = nil,
                audio: AudioData? = nil,
                refusal: String? = nil,
                functionCall: DeprecatedFunctionCall? = nil,
                toolCalls: [ToolCall]? = nil,
                toolCallId: String? = nil,
                functionName: String? = nil) {
        self.role = role
        self.content = content
        self.name = name
        self.audio = audio
        self.refusal = refusal
        self.functionCall = functionCall
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
        self.functionName = functionName
    }
}

/// The content of a message can be either a string or an array of content parts.
public enum ContentUnion: Codable {
    case text(String)
    case parts([ContentPart])
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .text(str)
        } else if let parts = try? container.decode([ContentPart].self) {
            self = .parts(parts)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode ContentUnion")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let string):
            try container.encode(string)
        case .parts(let parts):
            try container.encode(parts)
        }
    }
}

/// A piece of content in array form.
public enum ContentPart: Codable {
    case text(TextContentPart)
    case image(ImageContentPart)
    case audio(AudioContentPart)
    case file(FileContentPart)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let textPart = try? container.decode(TextContentPart.self) {
            self = .text(textPart)
        } else if let imagePart = try? container.decode(ImageContentPart.self) {
            self = .image(imagePart)
        } else if let audioPart = try? container.decode(AudioContentPart.self) {
            self = .audio(audioPart)
        } else if let filePart = try? container.decode(FileContentPart.self) {
            self = .file(filePart)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode ContentPart")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let textPart):
            try textPart.encode(to: encoder)
        case .image(let imagePart):
            try imagePart.encode(to: encoder)
        case .audio(let audioPart):
            try audioPart.encode(to: encoder)
        case .file(let filePart):
            try filePart.encode(to: encoder)
        }
    }
}

// MARK: Content Part Subtypes

public struct TextContentPart: Codable {
    public let text: String
    public let type: String // e.g. "text"
}

public struct ImageContentPart: Codable {
    public let imageUrl: ImageURL
    public let detail: String?
    public let type: String // e.g. "image"
}

/// The image URL may be a direct URL or base64 data.
public struct ImageURL: Codable {
    public let url: String
}

public struct AudioContentPart: Codable {
    public let inputAudio: AudioInput
    public let type: String // e.g. "input_audio"
}

public struct AudioInput: Codable {
    public let data: String  // base64
    public let format: String // "wav" or "mp3"
}

public struct FileContentPart: Codable {
    public let file: FileData
    public let type: String // "file"
}

public struct FileData: Codable {
    public let fileData: String? // base64 data
    public let fileId: String?   // The ID of an uploaded file
    public let filename: String?
}

// MARK: - Audio Output

public struct AudioOutputParameters: Codable {
    public let format: String // "wav", "mp3", "flac", "opus", or "pcm16"
    public let voice: String  // e.g. "alloy", "ash", ...
    
    public init(format: String, voice: String) {
        self.format = format
        self.voice = voice
    }
}

/// For assistant messages that include audio data.
public struct AudioData: Codable {
    public let format: String
    public let voice: String
    
    public init(format: String, voice: String) {
        self.format = format
        self.voice = voice
    }
}

// MARK: - Stopping sequences

/// The stop parameter can be a string, array, or null.
public enum StopSequence: Codable {
    case none
    case single(String)
    case multiple([String])
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .none
        } else if let str = try? container.decode(String.self) {
            self = .single(str)
        } else if let arr = try? container.decode([String].self) {
            self = .multiple(arr)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode StopSequence")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .none:
            try container.encodeNil()
        case .single(let str):
            try container.encode(str)
        case .multiple(let arr):
            try container.encode(arr)
        }
    }
}

// MARK: - Streaming Options

/// Options for streaming response.
public struct StreamOptions: Codable {
    public let includeUsage: Bool?
    
    public init(includeUsage: Bool? = nil) {
        self.includeUsage = includeUsage
    }
}

// MARK: - Predictions

/// Configuration for predicted output content to speed generation.
public struct PredictionConfig: Codable {
    public let content: PredictionContent
    public let type: String // must be "content"
    
    public init(content: PredictionContent) {
        self.content = content
        self.type = "content"
    }
}

/// The predicted content.
public enum PredictionContent: Codable {
    case text(String)
    case parts([TextContentPart])
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else if let parts = try? container.decode([TextContentPart].self) {
            self = .parts(parts)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode PredictionContent")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let text):
            try container.encode(text)
        case .parts(let parts):
            try container.encode(parts)
        }
    }
}

// MARK: - ResponseFormat

public enum ResponseFormat: Codable {
    case text(TextResponseFormat)
    case jsonSchema(JSONSchemaResponseFormat)
    case jsonObject(JSONObjResponseFormat)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let txt = try? container.decode(TextResponseFormat.self) {
            self = .text(txt)
        } else if let jsc = try? container.decode(JSONSchemaResponseFormat.self) {
            self = .jsonSchema(jsc)
        } else if let jobj = try? container.decode(JSONObjResponseFormat.self) {
            self = .jsonObject(jobj)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode ResponseFormat")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let txt):
            try txt.encode(to: encoder)
        case .jsonSchema(let jsc):
            try jsc.encode(to: encoder)
        case .jsonObject(let jobj):
            try jobj.encode(to: encoder)
        }
    }
}

/// Default text response format.
public struct TextResponseFormat: Codable {
    public var type = "text"
}

/// JSON Schema response format.
public struct JSONSchemaResponseFormat: Codable {
    public var type = "json_schema"
    public let jsonSchema: JSONSchemaObject
    
    public init(jsonSchema: JSONSchemaObject) {
        self.jsonSchema = jsonSchema
    }
}

/// For older JSON-object format.
public struct JSONObjResponseFormat: Codable {
    public var type = "json_object"
}

/// A JSON schema for structured outputs.
public struct JSONSchemaObject: Codable {
    public let name: String
    public let description: String?
    public let schema: [String: AnyCodable]?
    public let strict: Bool?
}

// MARK: - Tools & Function Calls

public enum ToolChoice: Codable {
    case none
    case auto
    case required
    case forced(FunctionTarget)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "none":
            self = .none
        case "auto":
            self = .auto
        case "required":
            self = .required
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ToolChoice")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .none:
            try container.encode("none")
        case .auto:
            try container.encode("auto")
        case .required:
            try container.encode("required")
        case .forced(let funcTarget):
            try container.encode(funcTarget)
        }
    }
}

/// Specifies a single function to force-call.
public struct FunctionTarget: Codable {
    public let type: String
    public let function: ForcedFunctionCall
    
    public init(functionName: String) {
        self.type = "function"
        self.function = ForcedFunctionCall(name: functionName)
    }
}

public struct ForcedFunctionCall: Codable {
    public let name: String
}

/// A list of tools the model may call.
public struct ToolDefinition: Codable {
    public let function: ToolFunction
    
    public init(function: ToolFunction) {
        self.function = function
    }
}

/// Actually the same shape as functions -> "function": {...}
public struct ToolFunction: Codable {
    public let name: String
    public let description: String?
    public let parameters: [String: AnyCodable]?
    public let strict: Bool?
    public var type = "function"
    
    public init(name: String,
                description: String? = nil,
                parameters: [String: AnyCodable]? = nil,
                strict: Bool? = nil) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.strict = strict
    }
}

// MARK: Deprecated fields

/// Deprecated in favor of `tool_choice`.
public enum FunctionCallSetting: Codable {
    case none
    case auto
    case forced(ForcedFunctionCall)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self), str == "none" {
            self = .none
        } else if let str = try? container.decode(String.self), str == "auto" {
            self = .auto
        } else {
            let fc = try ForcedFunctionCall(from: decoder)
            self = .forced(fc)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .none:
            try container.encode("none")
        case .auto:
            try container.encode("auto")
        case .forced(let fc):
            try fc.encode(to: encoder)
        }
    }
}

/// A single function definition for the old `functions` array.
public struct DeprecatedFunctionDefinition: Codable {
    public let name: String
    public let description: String?
    public let parameters: [String: AnyCodable]?
    
    public init(name: String,
                description: String? = nil,
                parameters: [String: AnyCodable]? = nil) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

/// A single function_call object in an assistant message.
public struct DeprecatedFunctionCall: Codable {
    public let name: String?
    public let arguments: [String: AnyCodable]?
    
    public init(name: String?, arguments: [String: AnyCodable]?) {
        self.name = name
        self.arguments = arguments
    }
}

// MARK: - Tool Calls

/// The model can respond with an array of tool calls.
public struct ToolCall: Codable {
    public let role: String  // always "tool"
    public let content: ContentUnion
    public let toolCallId: String
    
    public init(role: String = "tool",
                content: ContentUnion,
                toolCallId: String) {
        self.role = role
        self.content = content
        self.toolCallId = toolCallId
    }
}

// MARK: - Web Search

public struct WebSearchOptions: Codable {
    public let searchContextSize: String?
    public let userLocation: UserLocation?
    
    public init(searchContextSize: String? = nil,
                userLocation: UserLocation? = nil) {
        self.searchContextSize = searchContextSize
        self.userLocation = userLocation
    }
}

public struct UserLocation: Codable {
    public let approximate: ApproximateLocation
    public let type: String
    
    public init(approximate: ApproximateLocation) {
        self.approximate = approximate
        self.type = "approximate"
    }
}

public struct ApproximateLocation: Codable {
    public let city: String?
    public let country: String?
    public let region: String?
    public let timezone: String?
}

// MARK: - ChatCompletionResponse

public struct ChatCompletionResponse: Codable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [ChatCompletionChoice]
    public let usage: UsageInfo?
    public let serviceTier: String?
    
    public struct ChatCompletionChoice: Codable {
        public let index: Int
        public let message: AssistantMessage
        public let logprobs: JSONNullOrAny?
        public let finishReason: String?
    }
    
    public struct AssistantMessage: Codable {
        public let role: String
        public let content: ContentUnionOrNull?
        public let refusal: String?
        public let annotations: [String]?
    }
    
    public struct UsageInfo: Codable {
        public let promptTokens: Int
        public let completionTokens: Int
        public let totalTokens: Int
        public let promptTokensDetails: TokensDetails?
        public let completionTokensDetails: TokensDetails?
    }
    
    public struct TokensDetails: Codable {
        public let cachedTokens: Int?
        public let audioTokens: Int?
        public let reasoningTokens: Int?
        public let acceptedPredictionTokens: Int?
        public let rejectedPredictionTokens: Int?
    }
    
    /// Helper to parse `content` field which can be an array or string or null
    public enum ContentUnionOrNull: Codable {
        case text(String)
        case parts([AnyDecodablePart])
        case none
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                self = .none
                return
            }
            if let str = try? container.decode(String.self) {
                self = .text(str)
                return
            }
            if let arr = try? container.decode([AnyDecodablePart].self) {
                self = .parts(arr)
                return
            }
            self = .none
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .none:
                try container.encodeNil()
            case .text(let str):
                try container.encode(str)
            case .parts(let parts):
                try container.encode(parts)
            }
        }
    }
    
    public struct AnyDecodablePart: Codable {
        // Simplified placeholder.
        public init(from decoder: Decoder) throws {}
        public func encode(to encoder: Encoder) throws {}
    }
}

// MARK: - ChatCompletionStreamChunk

public struct ChatCompletionStreamChunk: Codable {
    public let id: String?
    public let object: String?
    public let created: Int?
    public let model: String?
    public let choices: [StreamChoice]?
    
    public struct StreamChoice: Codable {
        public let index: Int?
        public let delta: StreamDelta?
        public let finishReason: String?
    }
    
    public struct StreamDelta: Codable {
        public let role: String?
        public let content: String?
        public let toolCalls: [ToolCall]?
        public let functionCall: DeprecatedFunctionCall?
        public let refusal: String?
    }
}

// MARK: - Error Handling

public enum OpenAIChatError: Error {
    case invalidResponse
    case apiError(statusCode: Int, body: String)
    case streamingParameterMissing
}

/// A helper for encoding/decoding arbitrary values.
public struct AnyCodable: Codable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self.value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            self.value = doubleVal
        } else if let boolVal = try? container.decode(Bool.self) {
            self.value = boolVal
        } else if let strVal = try? container.decode(String.self) {
            self.value = strVal
        } else if let arrVal = try? container.decode([AnyCodable].self) {
            self.value = arrVal.map { $0.value }
        } else if let dictVal = try? container.decode([String: AnyCodable].self) {
            self.value = dictVal.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let intVal as Int:
            try container.encode(intVal)
        case let doubleVal as Double:
            try container.encode(doubleVal)
        case let boolVal as Bool:
            try container.encode(boolVal)
        case let strVal as String:
            try container.encode(strVal)
        case let arrVal as [Any]:
            let anyCodableArr = arrVal.map { AnyCodable($0) }
            try container.encode(anyCodableArr)
        case let dictVal as [String: Any]:
            let anyCodableDict = dictVal.mapValues { AnyCodable($0) }
            try container.encode(anyCodableDict)
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded")
            throw EncodingError.invalidValue(value, context)
        }
    }
}
