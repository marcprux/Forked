import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(ForkedModelMacros)
import ForkedModelMacros

final class ForkedModelMacrosSuite: XCTestCase {

    static let testMacros: [String: Macro.Type] = [
        "ForkedModel": ForkedModelMacro.self,
        "Merged": MergablePropertyMacro.self,
        "Backed": BackedPropertyMacro.self,
    ]
    
    func testDefault() {
        assertMacroExpansion(
            """
            @ForkedModel
            struct TestModel {
                @Merged var text: String
            }
            """,
            expandedSource:
            """
            struct TestModel {
                var text: String
            }

            extension TestModel: ForkedModel.Mergable {
                public func merged(withOlderConflicting other: Self, commonAncestor: Self?) throws -> Self {
                    var merged = self
                    merged.text = try self.text.merged(withOlderConflicting: other.text, commonAncestor: commonAncestor?.text)
                    return merged
                }
            }
            """,
            macros: Self.testMacros
        )
    }
    
    func testArrayPropertyMerge() {
        assertMacroExpansion(
            """
            @ForkedModel
            struct TestModel {
                @Merged(using: .arrayMerge) var text: [String.Element]
            }
            """,
            expandedSource:
            """
            struct TestModel {
                var text: [String.Element]
            }

            extension TestModel: ForkedModel.Mergable {
                public func merged(withOlderConflicting other: Self, commonAncestor: Self?) throws -> Self {
                    var merged = self
                    do {
                let merger = ValueArrayMerger<String.Element>()
                merged.text = try merger.merge(self.text, withOlderConflicting: other.text, commonAncestor: commonAncestor?.text)
                    }
                    return merged
                }
            }
            """,
            macros: Self.testMacros
        )
    }
    
    func testStringPropertyMerge() {
        assertMacroExpansion(
            """
            @ForkedModel
            struct TestModel {
                @Merged(using: .textMerge) var text: String
            }
            """,
            expandedSource:
            """
            struct TestModel {
                var text: String
            }

            extension TestModel: ForkedModel.Mergable {
                public func merged(withOlderConflicting other: Self, commonAncestor: Self?) throws -> Self {
                    var merged = self
                    do {
                let merger = TextMerger()
                merged.text = try merger.merge(self.text, withOlderConflicting: other.text, commonAncestor: commonAncestor?.text)
                    }
                    return merged
                }
            }
            """,
            macros: Self.testMacros
        )
    }
    
    func testMostRecentWinsPropertyMerge() {
        assertMacroExpansion(
            """
            @ForkedModel
            struct TestModel {
                @Backed var text: String
            }
            """,
            expandedSource:
            """
            struct TestModel {
                var text: String {
                    get {
                        return _forked_backedproperty_text.value
                    }
                    set {
                        _forked_backedproperty_text.value = newValue
                    }
                }

                private var _forked_backedproperty_text = Register<String>(.init())
            }

            extension TestModel: ForkedModel.Mergable {
                public func merged(withOlderConflicting other: Self, commonAncestor: Self?) throws -> Self {
                    var merged = self
                    merged._forked_backedproperty_text = try self._forked_backedproperty_text.merged(withOlderConflicting: other._forked_backedproperty_text, commonAncestor: commonAncestor?._forked_backedproperty_text)
                    return merged
                }
            }
            """,
            macros: Self.testMacros
        )
    }
    
    func testBackedAndMergedTogether() {
        assertMacroExpansion(
            """
            @ForkedModel
            private struct User {
                var name: String
                var age: Int
            }
            
            @ForkedModel
            private struct Note {
                @Backed(by: .register) var title: String
                @Merged(using: .textMerge) var text: String
            }
            """,
            expandedSource:
            """
            private struct User {
                var name: String
                var age: Int
            }
            private struct Note {
                var title: String {
                    get {
                        return _forked_backedproperty_title.value
                    }
                    set {
                        _forked_backedproperty_title.value = newValue
                    }
                }

                private var _forked_backedproperty_title = Register<String>(.init())
                var text: String
            }

            extension User: ForkedModel.Mergable {
                public func merged(withOlderConflicting other: Self, commonAncestor: Self?) throws -> Self {
                    return self
                }
            }

            extension Note: ForkedModel.Mergable {
                public func merged(withOlderConflicting other: Self, commonAncestor: Self?) throws -> Self {
                    var merged = self
                    do {
                let merger = TextMerger()
                merged.text = try merger.merge(self.text, withOlderConflicting: other.text, commonAncestor: commonAncestor?.text)
                    }
                    merged._forked_backedproperty_title = try self._forked_backedproperty_title.merged(withOlderConflicting: other._forked_backedproperty_title, commonAncestor: commonAncestor?._forked_backedproperty_title)
                    return merged
                }
            }
            """,
            macros: Self.testMacros
        )
    }
}
#endif
