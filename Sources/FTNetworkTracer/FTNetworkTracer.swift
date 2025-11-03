import Foundation
#if canImport(os.log)
import os.log
#endif

public class FTNetworkTracer {
    private let logger: LoggerConfiguration?
    private let analytics: AnalyticsProtocol?

    public init(logger: LoggerConfiguration?, analytics: AnalyticsProtocol?) {
        self.logger = logger
        self.analytics = analytics
    }

    // MARK: - Public API

    public func logAndTrackRequest(
        request: URLRequest,
        requestId: String
    ) {
        logAndTrack(
            type: "request",
            request: request,
            requestId: requestId
        )
    }

    public func logAndTrackResponse(
        request: URLRequest,
        response: URLResponse?,
        data: Data?,
        requestId: String,
        startTime: Date
    ) {
        guard let httpResponse = response as? HTTPURLResponse else { return }

        logAndTrack(
            type: "response",
            request: request,
            response: httpResponse,
            data: data,
            requestId: requestId,
            startTime: startTime
        )
    }

    public func logAndTrackError(
        request: URLRequest,
        error: Error,
        requestId: String
    ) {
        logAndTrack(
            type: "error",
            request: request,
            error: error,
            requestId: requestId
        )
    }
    
    // MARK: - Private Helpers

    private func logAndTrack(
        type: String,
        request: URLRequest,
        response: HTTPURLResponse? = nil,
        data: Data? = nil,
        error: Error? = nil,
        requestId: String,
        startTime: Date? = nil
    ) {
        let method = request.httpMethod ?? "UNKNOWN"
        let url = request.url?.absoluteString ?? "UNKNOWN"
        let headers = response?.allHeaderFields as? [String: String] ?? request.allHTTPHeaderFields
        let body = data ?? request.httpBody
        let statusCode = response?.statusCode
        let duration = startTime.map { Date().timeIntervalSince($0) }
        let errorString = error.map { String(describing: $0) }

        // Log if logger is available
        if let logger = logger {
            let logEntryType: EntryType
            switch type {
            case "request":
                logEntryType = .request(method: method, url: url)
            case "response":
                logEntryType = .response(method: method, url: url, statusCode: statusCode ?? 0)
            case "error":
                logEntryType = .error(method: method, url: url, error: errorString ?? "Unknown error")
            default:
                logEntryType = .request(method: method, url: url)
            }

            let logEntry = LogEntry(
                type: logEntryType,
                headers: headers,
                body: body,
                duration: duration,
                requestId: requestId
            )

            #if canImport(os.log)
            // Log to OSLog with proper privacy
            let level: OSLogType = {
                switch logEntry.type {
                case .error:
                    .error
                case let .response(_, _, statusCode):
                    (statusCode ?? 200) >= 400 ? .error : .info
                case .request:
                    .info
                }
            }()

            let message = logEntry.buildMessage(configuration: logger)
            switch logger.privacy {
            case .none:
                logger.logger.log(level: level, "\(message, privacy: .public)")
            case .auto:
                logger.logger.log(level: level, "\(message, privacy: .auto)")
            case .private:
                logger.logger.log(level: level, "\(message, privacy: .private)")
            case .sensitive:
                logger.logger.log(level: level, "\(message, privacy: .sensitive)")
            }
            #endif
        }

        // Track analytics if available
        if let analytics = analytics {
            let analyticEntryType: EntryType
            switch type {
            case "request":
                analyticEntryType = .request(method: method, url: url)
            case "response":
                analyticEntryType = .response(method: method, url: url, statusCode: statusCode ?? 0)
            case "error":
                analyticEntryType = .error(method: method, url: url, error: errorString ?? "Unknown error")
            default:
                analyticEntryType = .request(method: method, url: url)
            }

            let analyticEntry = AnalyticEntry(
                type: analyticEntryType,
                headers: headers,
                body: body,
                duration: duration,
                requestId: requestId,
                configuration: analytics.configuration
            )
            analytics.track(analyticEntry)
        }
    }
}
