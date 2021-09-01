public struct Promise<V, E: Error> {

    public let future = Future<V, E>()

    @inlinable
    public init() {}

    @inlinable
    public func fulfill(with value: V) {
        future.setValue(value)
    }

    @inlinable
    public func reject(with error: E) {
        future.setError(error)
    }
}

extension Promise where E == Never {

    @inlinable
    public func reject() {
        future.setError(nil)
    }
}

