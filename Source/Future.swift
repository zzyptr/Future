@dynamicMemberLookup
public final class Future<T, E: Error> {

    @usableFromInline
    typealias Callback = (Result<T, E>) -> Void

    @usableFromInline
    var _callbacks = [Callback]()

    @usableFromInline
    var _lock: Lock?

    @usableFromInline
    var _result: Result<T, E>?

    @inlinable
    public init(result: Result<T, E>) {
        _lock = nil
        _result = result
    }

    @inlinable
    public convenience init(_ value: T) {
        self.init(result: .success(value))
    }

    @inlinable
    public convenience init(error: E) {
        self.init(result: .failure(error))
    }

    @inlinable
    init() {
        _lock = Lock()
        _result = nil
    }

    @inlinable
    func complete(with result: Result<T, E>) {
        _lock?.lock()
        guard _result == nil else { return }
        _result = result
        _callbacks.forEach { $0(result) }
        _callbacks = []
        _lock?.unlock()
        _lock = nil
    }

    @inlinable
    func succeed(with value: T) {
        complete(with: .success(value))
    }

    @inlinable
    func fail(with error: E) {
        complete(with: .failure(error))
    }

    @inlinable
    func addCallback(_ callback: @escaping Callback) {
        _lock?.lock()
        defer { _lock?.unlock() }
        if let result = _result {
            callback(result)
        } else {
            _callbacks.append(callback)
        }
    }

    @inlinable
    func and_<U>(_ futureU: Future<U, E>) -> Future<(T, U), E> {
        var tOrU: Any?
        let lock = Lock()
        let futureTU = Future<(T, U), E>()
        addCallback { result in
            switch result {
            case .success(let t):
                lock.lock()
                defer { lock.unlock() }
                if let u = tOrU as? U {
                    futureTU.succeed(with: (t, u))
                } else {
                    tOrU = t
                }
            case .failure(let e):
                futureTU.fail(with: e)
            }
        }
        futureU.addCallback { result in
            switch result {
            case .success(let u):
                lock.lock()
                defer { lock.unlock() }
                if let t = tOrU as? T {
                    futureTU.succeed(with: (t, u))
                } else {
                    tOrU = u
                }
            case .failure(let e):
                futureTU.fail(with: e)
            }
        }
        return futureTU
    }

    @inlinable
    func and_<U, F>(_ futureU: Future<U, F>) -> Future<(T, U), Error> {
        var tOrU: Any?
        let lock = Lock()
        let futureTU = Future<(T, U), Error>()
        addCallback { result in
            switch result {
            case .success(let t):
                lock.lock()
                defer { lock.unlock() }
                if let u = tOrU as? U {
                    futureTU.succeed(with: (t, u))
                } else {
                    tOrU = t
                }
            case .failure(let e):
                futureTU.fail(with: e)
            }
        }
        futureU.addCallback { result in
            switch result {
            case .success(let u):
                lock.lock()
                defer { lock.unlock() }
                if let t = tOrU as? T {
                    futureTU.succeed(with: (t, u))
                } else {
                    tOrU = u
                }
            case .failure(let e):
                futureTU.fail(with: e)
            }
        }
        return futureTU
    }

    @inlinable
    func and_<U>(_ futureU: Future<U, Never>) -> Future<(T, U), E> {
        var tOrU: Any?
        let lock = Lock()
        let futureTU = Future<(T, U), E>()
        addCallback { result in
            switch result {
            case .success(let t):
                lock.lock()
                defer { lock.unlock() }
                if let u = tOrU as? U {
                    futureTU.succeed(with: (t, u))
                } else {
                    tOrU = t
                }
            case .failure(let e):
                futureTU.fail(with: e)
            }
        }
        futureU.addCallback { result in
            guard case .success(let u) = result else { return }
            lock.lock()
            defer { lock.unlock() }
            if let t = tOrU as? T {
                futureTU.succeed(with: (t, u))
            } else {
                tOrU = u
            }
        }
        return futureTU
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
    public subscript<U>(dynamicMember keyPath: KeyPath<T, U>) -> Future<U, E> {
        let futureU = Future<U, E>()
        addCallback { result in
            switch result {
            case .success(let t):
                let u = t[keyPath: keyPath]
                futureU.succeed(with: u)
            case .failure(let e):
                futureU.fail(with: e)
            }
        }
        return futureU
    }

    @inlinable
    public func map<U>(_ transform: @escaping (T) -> U) -> Future<U, E> {
        let futureU = Future<U, E>()
        addCallback { result in
            switch result {
            case .success(let t):
                let u = transform(t)
                futureU.succeed(with: u)
            case .failure(let e):
                futureU.fail(with: e)
            }
        }
        return futureU
    }

    @inlinable
    public func map<U>(_ transform: @escaping (T) throws -> U) -> Future<U, Error> {
        let futureU = Future<U, Error>()
        addCallback { result in
            switch result {
            case .success(let t):
                do {
                    let u = try transform(t)
                    futureU.succeed(with: u)
                } catch {
                    futureU.fail(with: error)
                }
            case .failure(let e):
                futureU.fail(with: e)
            }
        }
        return futureU
    }

    @inlinable
    public func mapError<F>(_ transform: @escaping (E) -> F) -> Future<T, F> {
        let futureT = Future<T, F>()
        addCallback { result in
            switch result {
            case .success(let t):
                futureT.succeed(with: t)
            case .failure(let e):
                let f = transform(e)
                futureT.fail(with: f)
            }
        }
        return futureT
    }

    @inlinable
    public func flatMap<U>(_ transform: @escaping (T) -> Future<U, E>) -> Future<U, E> {
        let futureU = Future<U, E>()
        addCallback { result in
            switch result {
            case .success(let t):
                let fut = transform(t)
                fut.addCallback(futureU.complete)
            case .failure(let e):
                futureU.fail(with: e)
            }
        }
        return futureU
    }

    @inlinable
    public func flatMap<U, F>(_ transform: @escaping (T) -> Future<U, F>) -> Future<U, Error> {
        let futureU = Future<U, Error>()
        addCallback { result in
            switch result {
            case .success(let t):
                let fut = transform(t)
                fut.addCallback { res in
                    switch res {
                    case .success(let u):
                        futureU.succeed(with: u)
                    case .failure(let e):
                        futureU.fail(with: e)
                    }
                }
            case .failure(let e):
                futureU.fail(with: e)
            }
        }
        return futureU
    }

    @inlinable
    public func flatMap<U>(_ transform: @escaping (T) -> Future<U, Never>) -> Future<U, E> {
        let futureU = Future<U, E>()
        addCallback { result in
            switch result {
            case .success(let t):
                let fut = transform(t)
                fut.addCallback { res in
                    guard case .success(let u) = res else { return }
                    futureU.succeed(with: u)
                }
            case .failure(let e):
                futureU.fail(with: e)
            }
        }
        return futureU
    }

    @inlinable
    public func flatMapError<F>(_ transform: @escaping (E) -> Future<T, F>) -> Future<T, F> {
        let futureT = Future<T, F>()
        addCallback { result in
            switch result {
            case .success(let t):
                futureT.succeed(with: t)
            case .failure(let e):
                let fut = transform(e)
                fut.addCallback(futureT.complete)
            }
        }
        return futureT
    }

    @inlinable
    public func recover(_ callback: @escaping (E) -> T) -> Future<T, Never> {
        let futureT = Future<T, Never>()
        addCallback { result in
            switch result {
            case .success(let t):
                futureT.succeed(with: t)
            case .failure(let e):
                let t = callback(e)
                futureT.succeed(with: t)
            }
        }
        return futureT
    }

    @inlinable
    public func then(_ callback: @escaping (Result<T, E>) -> Void) -> Future {
        addCallback(callback)
        return self
    }

    @inlinable
    public func then(_ callback: @escaping () -> Void) -> Future {
        addCallback { _ in callback() }
        return self
    }

    @inlinable
    public func `do`(_ callback: @escaping (T) -> Void) -> Future {
        addCallback { result in
            guard case .success(let t) = result else { return }
            callback(t)
        }
        return self
    }

    @inlinable
    @discardableResult
    public func `catch`(_ callback: @escaping (E) -> Void) -> Future<T, Never> {
        let futureT = Future<T, Never>()
        addCallback { result in
            switch result {
            case .success(let t):
                futureT.succeed(with: t)
            case .failure(let e):
                callback(e)
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
    public convenience init(_ value: T) {
        self.init(result: .success(value))
    }

    @inlinable
    public func flatMap<U, F>(_ transform: @escaping (T) -> Future<U, F>) -> Future<U, F> {
        let futureU = Future<U, F>()
        addCallback { result in
            guard case .success(let t) = result else { return }
            let fut = transform(t)
            fut.addCallback(futureU.complete)
        }
        return futureU
    }

    @inlinable
    @discardableResult
    public func then(_ callback: @escaping (Result<T, E>) -> Void) -> Future {
        addCallback(callback)
        return self
    }

    @inlinable
    @discardableResult
    public func then(_ callback: @escaping () -> Void) -> Future {
        addCallback { _ in callback() }
        return self
    }

    @inlinable
    @discardableResult
    public func `do`(_ callback: @escaping (T) -> Void) -> Future {
        addCallback { result in
            guard case .success(let t) = result else { return }
            callback(t)
        }
        return self
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
