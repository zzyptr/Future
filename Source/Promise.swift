public struct Promise<T, E: Error> {

    public let future = Future<T, E>()

    @inlinable
    public init() {}

    @inlinable
    public func complete(with result: Result<T, E>) {
        future.complete(with: result)
    }

    @inlinable
    public func succeeded(_ t: T) {
        future.succeeded(t)
    }

    @inlinable
    public func failed(_ e: E) {
        future.failed(e)
    }
}
