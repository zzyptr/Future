@dynamicMemberLookup
public final class Future<T> {

    @usableFromInline
    var _lock: Lock?

    @usableFromInline
    var _callbacks: [Callback]?

    @usableFromInline
    var _result: Result<T, Error>?

    @inlinable
    init() {
        _lock = Lock()
        _callbacks = []
    }

    @inlinable
    init(result: Result<T, Error>) {
        _result = result
    }

    @inlinable
    public convenience init(_ value: T) {
        self.init(result: .success(value))
    }

    @usableFromInline
    typealias Callback = (Result<T, Error>) -> Void
}

extension Future where T == Never {

    @inlinable
    public convenience init(error: Error) {
        self.init(result: .failure(error))
    }
}

extension Future {

    @inlinable
    func appendCallback(_ callback: @escaping Callback) {
        _lock?.lock()
        defer { _lock?.unlock() }
        if let result = _result {
            callback(result)
        } else {
            _callbacks?.append(callback)
        }
    }

    @inlinable
    func complete(with result: Result<T, Error>) {
        _lock?.lock()
        if _result == nil {
            _result = result
            _callbacks?.forEach { $0(result) }
        }
        _callbacks = nil
        _lock?.unlock()
        _lock = nil
    }

    @inlinable
    func succeeded(_ value: T) {
        complete(with: .success(value))
    }

    @inlinable
    func failed(_ error: Error) {
        complete(with: .failure(error))
    }
}

extension Future {

    @inlinable
    public subscript<U>(dynamicMember keyPath: KeyPath<T, U>) -> Future<U> {
        let futureU = Future<U>()
        appendCallback { result in
            switch result {
            case let .success(t):
                let u = t[keyPath: keyPath]
                futureU.succeeded(u)
            case let .failure(e):
                futureU.failed(e)
            }
        }
        return futureU
    }

    @inlinable
    public func map<U>(_ transform: @escaping (T) throws -> U) -> Future<U> {
        let futureU = Future<U>()
        appendCallback { result in
            switch result {
            case let .success(t):
                do {
                    let u = try transform(t)
                    futureU.succeeded(u)
                } catch {
                    futureU.failed(error)
                }
            case let .failure(e):
                futureU.failed(e)
            }
        }
        return futureU
    }

    @inlinable
    public func flatMap<U>(_ transform: @escaping (T) throws -> Future<U>) -> Future<U> {
        let futureU = Future<U>()
        appendCallback { result in
            switch result {
            case let .success(t):
                do {
                    let future = try transform(t)
                    future.appendCallback(futureU.complete)
                } catch {
                    futureU.failed(error)
                }
            case let .failure(e):
                futureU.failed(e)
            }
        }
        return futureU
    }

    @inlinable
    @discardableResult
    public func `do`(_ callback: @escaping (T) -> Void) -> Future {
        appendCallback { result in
            guard case let .success(t) = result else { return }
            callback(t)
        }
        return self
    }

    @inlinable
    @discardableResult
    public func `catch`(_ callback: @escaping (Error) -> Void) -> Future {
        appendCallback { result in
            guard case let .failure(e) = result else { return }
            callback(e)
        }
        return self
    }

    @inlinable
    @discardableResult
    public func then(_ callback: @escaping (Result<T, Error>) -> Void) -> Future {
        appendCallback(callback)
        return self
    }

    @inlinable
    @discardableResult
    public func then(_ callback: @escaping () -> Void) -> Future {
        appendCallback { _ in callback() }
        return self
    }

    @inlinable
    public func and<U>(_ u: U) -> Future<(T, U)> {
        return map { t in (t, u) }
    }

    @inlinable
    public func and<A, B, U>(_ u: U) -> Future<(A, B, U)> where T == (A, B) {
        return map { t in (t.0, t.1, u) }
    }

    @inlinable
    public func and<A, B, C, U>(_ u: U) -> Future<(A, B, C, U)> where T == (A, B, C) {
        return map { t in (t.0, t.1, t.2, u) }
    }

    @inlinable
    public func and<U>(_ futureU: Future<U>) -> Future<(T, U)> {
        var tOrU: Any?
        let lock = Lock()
        let futureTU = Future<(T, U)>()
        appendCallback { result in
            switch result {
            case let .success(t):
                lock.lock()
                defer { lock.unlock() }
                if let u = tOrU as? U {
                    futureTU.succeeded((t, u))
                } else {
                    tOrU = t
                }
            case let .failure(e):
                futureTU.failed(e)
            }
        }
        futureU.appendCallback { result in
            switch result {
            case let .success(u):
                lock.lock()
                defer { lock.unlock() }
                if let t = tOrU as? T {
                    futureTU.succeeded((t, u))
                } else {
                    tOrU = u
                }
            case let .failure(e):
                futureTU.failed(e)
            }
        }
        return futureTU
    }

    @inlinable
    public func and<A, B, U>(_ futureU: Future<U>) -> Future<(A, B, U)> where T == (A, B) {
        return and(futureU).map { t, u in (t.0, t.1, u) }
    }

    @inlinable
    public func and<A, B, C, U>(_ futureU: Future<U>) -> Future<(A, B, C, U)> where T == (A, B, C) {
        return and(futureU).map { t, u in (t.0, t.1, t.2, u) }
    }
}
