# SafeDecoding

Swift Macro enabling safe decoding of `struct`s and `class`es.

## Features

- Allow decoding to recover from partial failures:
    - `Optional` properties to recover from invalid structure (e.g. and `Int?` property receiving a `String`)
    - `Array`, `Set` and `Dictionary` properties to recover from invalid items (`Dictionary` is limited to recovering from invalid `Value`s)
    - per-property opt-out using `@IgnoreSafeDecoding` macro in properties
    - plays well with (actually, ignores) computed and initialized properties
- Automatic conformance to `Decodable` (if needed)

## Requirements

- Requires Swift 5.9

## Example Usage

A common problem is when an otherwise non-mandatory part of a model contains invalid/missing data, causing an entire payload to fail.
In the following example we have a `Book` model, for which we'll retrieve an array from some backend.

```
struct Tag: Decodable {
    let name: String
}

struct Book: Decodable {
    let title: String
    let author: String
    let synopsis: String?
    let tags: [Tag]
}
```

Receiving a corrupted tag would cause the entire payload to fail when fetching a list of `Book`s.
In the following JSON, note that the tag name is missing from the book *My Sweet Swift Book*:

```
[
    {
        "title": "Dune",
        "author": "Frank Herbert",
        "tags": [
            {
                "name": "Sky-Fi"
            }
        ]
    },
    ...
    {
        "title": "My Sweet Swift Book",
        "author": "Me",
        "tags": [
            {
                "name": "Tech"
            },
            {
            }
        ]
    }
]
``` 

With the current declaration of `Book` and `Tag`, this would cause the entire payload decoding to fail.
In order to allow a `class`/`struct` to gain resilience to partial decoding failure, simply add use the `@SafeDecoding` macro:

```
@SafeDecoding
struct Book {
    ...
}
```

This will implement custom decoding for `Book`, allowing the single invalid tag to fail, while correctly decoding everything else.
Safe decoding is achieved by attaching a type `extension` implementing a custom `init(from:)` (and declaring conformance to `Decodable`, if necessary).
Within the initializer, safe decoding will be applied to all fitting properties (of type `Optional`, `Array`, `Set` and `Dictionary`).  
`@SafeDecoding` may be used in any `struct` or `class`.

In order to opt-out of safe decoding for a property, simply tag it with `@IgnoreSafeDecoding` macro.
Let's say an invalid `synopsis` is enough to invalidate the entire `Book`:

```
@SafeDecoding
struct Book {
    ...
    @IgnoreSafeDecoding
    let synopsis: String?
    ...
}
```

This will cause `synopsis` to not be safely decoded in the initializer.

## Installation

### Swift Package Manager

You can use the Swift Package Manager to install your package by adding it as a dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/renato-iar/SafeDecoding.git", from: "1.0.0")
]
