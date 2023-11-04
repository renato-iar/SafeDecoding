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

# Versions

## Version 1.4.0

- Add `@SafeDecoding(decodingStrategy:)` and `@SafeDecoding(decodingStrategy:reporter:)` for `enum`s
- Add `EnumCaseDecodingStrategy` to describe decoding strategy for `enum`s

## Version 1.3.0

- Add `@RetryDecoding`, allowing individual properties to have associated retries
- Add `@FallbackDecoding`, allowing individual properties to provide a last-resort value 

## Version 1.2.1

- Bug: uses `decodeIfPresent` for optionals when using error reporting

## Version 1.2.0

- Accounts for access modifiers

## Version 1.1.0

- Add error reporting to `@SafeDecoding` macro
- Remove sample client product

## Version 1.0.0

- Add `@SafeDecoding` and `@IgnoreSafeDecoding` macros


# Example Usage

## Structs & Classes

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

The `@FallbackDecoding` macro can be used to grant fallback semantics to properties.
`@FallbackDecoding` must be used with `@SafeDecoding`, and means decoding will never fail properties it is applied to (even if the type is not otherwise "safe-decodable"):

```swift
@SafeDecoding
struct Book {
    @FallbackDecoding(false)
    var isFavourite: Bool
}
```

The `RetryDecoding` macro can in turn be used to provide alternative decoding of a property; an alternative decoding type and a "mapper" between types must be provided.
An example could be a backend that sometimes returns integers as strings, or booleans as integers:

```swift
@SafeDecoding
struct Book {
    @RetryDecoding(String.self, map: { $0.lowercased() == "true" })
    @RetryDecoding(Int.self, map: { $0 != 0 })
    var isFavourite: Bool
}
```

Retries will be performed in the same order as they are declared in the property.
If `@FallbackDecoding` is used alongside retries, all retries will be attempted before the value specified for fallback is used.

## Enums

Decoding of `enum`s uses the same `@SafeDecoding` macro, but requires the `decodingStrategy` to be specified.
The strategy is itself an enumeration (`EnumCaseDecodingStrategy`) which holds two cases:

### `caseByObjectProperty(String)`
A property name must be specified; this will be itself decoded as a string matching the cases of the `enum`.
E.g. for the following `enum`:

```swift
@SafeDecoding(decodingStrategy: .caseByObjectProperty("type")
enum MediaAsset {
    case vod(...)
    case series(...)
    case episode(...)
    ...
}
```

A property `type` will be decoded, and matched with a case in the `MediaAsset` type:

```json
{
    "type": "vod",
    "title": "...",
    ...
}
```

This will result in a `.vod` being decoded.
The specified property may or may not be part of the final model.
 
### `caseByNestedObject`

The standard strategy used when auto-decoding is used, will attempt to decode a root property for each of the `enum`s cases, then decoding the case's parameters.
For the same example specified above, decoding a `vod` case would require a payload like the one below:

```json
{
    "vod": {
        "title": "...",
        ...
    }
}
```

The literal name used for an `enum` case will be the case itself by default, but may be overriden using the `@CaseNameDecoding` macro:

```swift
@SafeDecoding(decodingStrategy: .caseByObjectProperty("type"))
enum MediaAssetKeyed {
    @CaseNameDecoding("ASSET/PROGRAMME")
    case vod(String?, String)
    @CaseNameDecoding("ASSET/SERIES")
    case series(id: String, Set<String>)
    @CaseNameDecoding("ASSET/EPISODE")
    case episode(id: String, title: String, arguments: [String: Double])
}
```

This will try to match `case`s by decoding a `type` property, with the property's type itself matching the specified names:

```swift
{
    "type": "ASSET/EPISODE",
    "id": "...",
    ...
}
```

## Error Reporting

Finally, `@SafeDecoding` can report errors that occur (and are recovered from) during the decoding process.
This is done by passing the `reporter:` parameter to the macro:

```swift
@SafeDecoding(reporter: ...)
struct Book {
    ....
}
```

The same applies to `enum` decoding:

```swift
@SafeDecoding(decodingStrategy: ..., reporter: ...)
```
enum MediaAsset {
    ...
}

The reporter must conform the `SafeDecodingReporter` protocol.
Upon recovery of decoding errors, the reporter will be called with information about said error.
Remember that a reporter is local to its type, i.e. although the same type may be used everywhere **each @SafeDecoding usage must be given its reporter expression**.

# Installation

## Swift Package Manager

You can use the Swift Package Manager to install your package by adding it as a dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/renato-iar/SafeDecoding.git", from: "1.0.0")
]
```
