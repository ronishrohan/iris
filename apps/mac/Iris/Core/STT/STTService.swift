import Foundation

protocol STTService: AnyObject, Sendable {
    func start(onPartial: @escaping @Sendable (String) -> Void,
               onFinal: @escaping @Sendable (String) -> Void,
               onError: @escaping @Sendable (Error) -> Void) async throws
    func stop()
}
