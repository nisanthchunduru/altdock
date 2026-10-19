import Darwin

final class DynamicLibrary {
    private let handle: UnsafeMutableRawPointer

    init?(path: String) {
        guard let handle = dlopen(path, RTLD_LAZY | RTLD_LOCAL) else { return nil }
        self.handle = handle
    }

    deinit { dlclose(handle) }

    func symbol<Function>(_ name: String, as type: Function.Type) -> Function? {
        guard let address = dlsym(handle, name) else { return nil }
        return unsafeBitCast(address, to: type)
    }
}
