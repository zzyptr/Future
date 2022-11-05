# Future

An async functional container



### Constructions

- #### asynchronously

```swift
// 1st: Init a promise
let promise = Promise<Data, Error>()
// 2nd: Get future from the promise
let future: Future<Data, Error> = promise.future


URLSession.shared.dataTask(with: request) { data, response, error in
    if let error = error {
      	// 3rd: Reject the promise with an error
        promise.reject(with: error)
    } else {
        // 3rd: Or fulfill the promise with a value
        promise.fulfill(with: data ?? Data())
    }
}
```

- #### synchronously

```swift
let data = Data()
let boxedData = Future<Data, Error>(data)

let error: Error = ...
let boxedError = Future<Data, Error>(error: error)
```



### Transformations

- #### Mapping

```swift
let boxedString: Future<String, Error> = boxedData.map { data in
    return String(data: data, encoding: .utf8) ?? ""
}

let boxedNSError: Future<Data, NSError> = boxedError.mapError { error in
    return NSError(domain: "Future", code: -1)
}
```

- #### Flatten mapping

```swift
let boxedURL = boxedData.flatMap { data -> Future<URL, Error> in
    let promise = Promise<URL, Error>()
    do {
        let url = try JSONDecoder().decode(URL.self, from: data)
        promise.fulfill(with: url)
    } catch {
        promise.reject(with: error)
    }
    return promise.future
}

```

- #### Composing

```swift
let composed: Future<(String, URL), Error> = boxedString.and(boxedURL)
```
