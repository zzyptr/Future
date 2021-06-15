@dynamicMemberLookup
public final class Future<T, E: Error> {

    @usableFromInline
    var _lock: Lock?

    @usableFromInline
    var _callbacks: [Callback]?

    @usableFromInline
    var _result: Result<T, E>?

    @inlinable
    init() {
        _lock = Lock()
        _callbacks = []
    }

    @inlinable
    init(result: Result<T, E>) {
        _result = result
    }

    @usableFromInline
    typealias Callback = (Result<T, E>) -> Void
}

extension Future where E == Never {

    @inlinable
    public convenience init(_ value: T) {
        self.init(result: .success(value))
    }
}

extension Future where T == Never {

    @inlinable
    public convenience init(error: E) {
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
    func complete(with result: Result<T, E>) {
        _lock?.lock()
        guard _result == nil else { return }
        _result = result
        _callbacks?.forEach { $0(result) }
        _callbacks = nil
        _lock?.unlock()
        _lock = nil
    }

    @inlinable
    func succeeded(_ value: T) {
        complete(with: .success(value))
    }

    @inlinable
    func failed(_ error: E) {
        complete(with: .failure(error))
    }

    @inlinable
    func and_<U>(_ futureU: Future<U, E>) -> Future<(T, U), E> {
        var tOrU: Any?
        let lock = Lock()
        let futureTU = Future<(T, U), E>()
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
    func and_<U, F>(_ futureU: Future<U, F>) -> Future<(T, U), Error> {
        var tOrU: Any?
        let lock = Lock()
        let futureTU = Future<(T, U), Error>()
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
    func and_<U>(_ futureU: Future<U, Never>) -> Future<(T, U), E> {
        var tOrU: Any?
        let lock = Lock()
        let futureTU = Future<(T, U), E>()
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
            }
        }
        return futureTU
    }
}

extension Future {

    @inlinable
    public subscript<U>(dynamicMember keyPath: KeyPath<T, U>) -> Future<U, E> {
        let futureU = Future<U, E>()
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
    public func map<U>(_ transform: @escaping (T) -> U) -> Future<U, E> {
        let futureU = Future<U, E>()
        appendCallback { result in
            switch result {
            case let .success(t):
                let u = transform(t)
                futureU.succeeded(u)
            case let .failure(e):
                futureU.failed(e)
            }
        }
        return futureU
    }

    @inlinable
    public func map<U>(_ transform: @escaping (T) throws -> U) -> Future<U, Error> {
        let futureU = Future<U, Error>()
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
    public func flatMap<U>(_ transform: @escaping (T) -> Future<U, E>) -> Future<U, E> {
        let futureU = Future<U, E>()
        appendCallback { result in
            switch result {
            case let .success(t):
                let future = transform(t)
                future.appendCallback(futureU.complete)
            case let .failure(e):
                futureU.failed(e)
            }
        }
        return futureU
    }

    @inlinable
    public func flatMap<U, F>(_ transform: @escaping (T) -> Future<U, F>) -> Future<U, Error> {
        let futureU = Future<U, Error>()
        appendCallback { result in
            switch result {
            case let .success(t):
                let future = transform(t)
                future.appendCallback { result in
                    switch result {
                    case let .success(u):
                        futureU.succeeded(u)
                    case let .failure(e):
                        futureU.failed(e)
                    }
                }
            case let .failure(e):
                futureU.failed(e)
            }
        }
        return futureU
    }

    @inlinable
    public func flatMap<U>(_ transform: @escaping (T) -> Future<U, Never>) -> Future<U, E> {
        let futureU = Future<U, E>()
        appendCallback { result in
            switch result {
            case let .success(t):
                let future = transform(t)
                future.appendCallback { result in
                    switch result {
                    case let .success(u):
                        futureU.succeeded(u)
                    }
                }
            case let .failure(e):
                futureU.failed(e)
            }
        }
        return futureU
    }

    @inlinable
    public func `do`(_ callback: @escaping (T) -> Void) -> Future {
        appendCallback { result in
            guard case let .success(t) = result else { return }
            callback(t)
        }
        return self
    }

    @inlinable
    public func then(_ callback: @escaping (Result<T, E>) -> Void) -> Future {
        appendCallback(callback)
        return self
    }

    @inlinable
    public func then(_ callback: @escaping () -> Void) -> Future {
        appendCallback { _ in callback() }
        return self
    }

    @inlinable
    public func mapError<F>(_ transform: @escaping (E) -> F) -> Future<T, F> {
        let future = Future<T, F>()
        appendCallback { result in
            switch result {
            case let .success(t):
                future.succeeded(t)
            case let .failure(e):
                let f = transform(e)
                future.failed(f)
            }
        }
        return future
    }

    @inlinable
    public func flatMapError<F>(_ transform: @escaping (E) -> Future<T, F>) -> Future<T, F> {
        let futureT = Future<T, F>()
        appendCallback { result in
            switch result {
            case let .success(t):
                futureT.succeeded(t)
            case let .failure(e):
                let future = transform(e)
                future.appendCallback(futureT.complete)
            }
        }
        return futureT
    }

    @inlinable
    @discardableResult
    public func `catch`(_ callback: @escaping (E) -> Void) -> Future<T, Never> {
        let futureT = Future<T, Never>()
        appendCallback { result in
            switch result {
            case let .success(t):
                futureT.succeeded(t)
            case let .failure(e):
                callback(e)
                futureT.failed()
            }
        }
        return futureT
    }

    @inlinable
    public func recover(_ callback: @escaping (E) -> T) -> Future<T, Never> {
        let futureT = Future<T, Never>()
        appendCallback { result in
            switch result {
            case let .success(t):
                futureT.succeeded(t)
            case let .failure(e):
                let t = callback(e)
                futureT.succeeded(t)
            }
        }
        return futureT
    }

    @inlinable
    public func and<U>(_ u: U) -> Future<(T, U), E> {
        return map { t in (t, u) }
    }

    @inlinable
    public func and<A, B, U>(_ u: U) -> Future<(A, B, U), E> where T == (A, B) {
        return map { t in (t.0, t.1, u) }
    }

    @inlinable
    public func and<A, B, C, U>(_ u: U) -> Future<(A, B, C, U), E> where T == (A, B, C) {
        return map { t in (t.0, t.1, t.2, u) }
    }

    @inlinable
    public func and<U>(_ futureU: Future<U, E>) -> Future<(T, U), E> {
        return and_(futureU)
    }

    @inlinable
    public func and<A, B, U>(_ futureU: Future<U, E>) -> Future<(A, B, U), E> where T == (A, B) {
        return and_(futureU).map { t, u in (t.0, t.1, u) }
    }

    @inlinable
    public func and<A, B, C, U>(_ futureU: Future<U, E>) -> Future<(A, B, C, U), E> where T == (A, B, C) {
        return and_(futureU).map { t, u in (t.0, t.1, t.2, u) }
    }

    @inlinable
    public func and<U, F>(_ futureU: Future<U, F>) -> Future<(T, U), Error> {
        return and_(futureU)
    }

    @inlinable
    public func and<A, B, U, F>(_ futureU: Future<U, F>) -> Future<(A, B, U), Error> where T == (A, B) {
        return and_(futureU).map { t, u in (t.0, t.1, u) }
    }

    @inlinable
    public func and<A, B, C, U, F>(_ futureU: Future<U, F>) -> Future<(A, B, C, U), Error> where T == (A, B, C) {
        return and_(futureU).map { t, u in (t.0, t.1, t.2, u) }
    }

    @inlinable
    public func and<U>(_ futureU: Future<U, Never>) -> Future<(T, U), E> {
        return and_(futureU)
    }

    @inlinable
    public func and<A, B, U>(_ futureU: Future<U, Never>) -> Future<(A, B, U), E> where T == (A, B) {
        return and_(futureU).map { t, u in (t.0, t.1, u) }
    }

    @inlinable
    public func and<A, B, C, U>(_ futureU: Future<U, Never>) -> Future<(A, B, C, U), E> where T == (A, B, C) {
        return and_(futureU).map { t, u in (t.0, t.1, t.2, u) }
    }
}

extension Future where E == Never {

    @inlinable
    func failed() {
        _lock?.lock()
        _callbacks = nil
        _lock?.unlock()
        _lock = nil
    }

    @inlinable
    public func flatMap<U, F>(_ transform: @escaping (T) -> Future<U, F>) -> Future<U, F> {
        let futureU = Future<U, F>()
        appendCallback { result in
            switch result {
            case let .success(t):
                let future = transform(t)
                future.appendCallback(futureU.complete)
            }
        }
        return futureU
    }

    @inlinable
    public func flatMap<U>(_ transform: @escaping (T) -> Future<U, Never>) -> Future<U, Never> {
        let futureU = Future<U, Never>()
        appendCallback { result in
            switch result {
            case let .success(t):
                let future = transform(t)
                future.appendCallback(futureU.complete)
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
    public func then(_ callback: @escaping (Result<T, E>) -> Void) -> Future {
        appendCallback(callback)
        return self
    }

    @inlinable
    @discardableResult
    public func then(_ callback: @escaping () -> Void) -> Future {
        appendCallback { _ in callback() }
        return self
    }

    @available(*, deprecated, message: "There are no errors to map")
    public func mapError<F>(_ transform: @escaping (E) -> F) -> Future<T, F> {
        fatalError("There are no errors to map")
    }

    @available(*, deprecated, message: "There are no errors to map")
    public func flatMapError<F>(_ transform: @escaping (E) -> Future<T, F>) -> Future<T, F> {
        fatalError("There are no errors to map")
    }

    @available(*, deprecated, message: "There are no errors to catch")
    public func `catch`(_ callback: @escaping (E) -> Void) -> Future<T, Never> {
        fatalError("There are no errors to catch")
    }

    @available(*, deprecated, message: "There are no errors to recover")
    public func recover(_ callback: @escaping (E) -> T) -> Future<T, Never> {
        fatalError("There are no errors to recover")
    }
    
    @inlinable
    public func and<U, F>(_ futureU: Future<U, F>) -> Future<(T, U), F> {
        return futureU.and_(self).map { u, t in (t, u) }
    }

    @inlinable
    public func and<A, B, U, F>(_ futureU: Future<U, F>) -> Future<(A, B, U), F> where T == (A, B) {
        return futureU.and_(self).map { u, t in (t.0, t.1, u) }
    }

    @inlinable
    public func and<A, B, C, U, F>(_ futureU: Future<U, F>) -> Future<(A, B, C, U), F> where T == (A, B, C) {
        return futureU.and_(self).map { u, t in (t.0, t.1, t.2, u) }
    }
}
