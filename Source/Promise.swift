public struct Promise<T, E: Error> {

    public let future = Future<T, E>()

    @inlinable
    public init() {}

    @inlinable
    public func complete(with result: Result<T, E>) {
        future.complete(with: result)
    }

    @inlinable
    public func succeed(with t: T) {
        future.succeed(with: t)
    }

    @inlinable
    public func fail(with e: E) {
        future.fail(with: e)
    }
}
