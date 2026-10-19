import Testing
@testable import Altdock

@Suite("Unavailable private APIs fail safely")
struct DynamicLibraryTests {
    @Test("A missing framework produces nil instead of crashing at launch")
    func missingLibrary() {
        #expect(DynamicLibrary(path: "/nonexistent/Altdock.framework/Altdock") == nil)
    }

    @Test("A missing symbol produces nil instead of calling an invalid function pointer")
    func missingSymbol() throws {
        typealias Function = @convention(c) () -> Int32
        let library = try #require(DynamicLibrary(path: "/usr/lib/libSystem.B.dylib"))
        #expect(library.symbol("AltdockNonexistentSymbol", as: Function.self) == nil)
    }
}
