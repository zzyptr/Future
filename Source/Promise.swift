public struct Promise<T> {

    public let future = Future<T>()

    @inlinable
    public init() {}

    @inlinable
    public func complete(with result: Result<T, Error>) {
        future.complete(with: result)
    }

    @inlinable
    public func succeeded(_ t: T) {
        future.succeeded(t)
    }

    @inlinable
    public func failed(_ e: Error) {
        future.failed(e)
    }
}
