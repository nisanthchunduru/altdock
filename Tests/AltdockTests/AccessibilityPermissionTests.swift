import Testing
@testable import Altdock

@Suite("Accessibility checks never prompt without an explicit request")
@MainActor
struct AccessibilityPermissionTests {
    @Test("Already granted access never produces another permission prompt")
    func grantedAccess() {
        var prompts = 0
        let permission = AccessibilityPermission(check: { true }, prompt: { prompts += 1 })
        #expect(permission.isGranted)
        #expect(!permission.requestIfNeeded())
        #expect(!permission.requestIfNeeded())
        #expect(prompts == 0)
    }

    @Test("Checking missing access at startup does not request it")
    func passiveCheck() {
        var prompts = 0
        let permission = AccessibilityPermission(check: { false }, prompt: { prompts += 1 })
        #expect(!permission.isGranted)
        #expect(prompts == 0)
    }

    @Test("An explicit request checks the live grant instead of relying on stale cached state")
    func permissionChanges() {
        var granted = false
        var prompts = 0
        let permission = AccessibilityPermission(check: { granted }, prompt: { prompts += 1 })
        #expect(permission.requestIfNeeded())
        granted = true
        #expect(!permission.requestIfNeeded())
        #expect(prompts == 1)
        granted = false
        #expect(!permission.isGranted)
    }
}
