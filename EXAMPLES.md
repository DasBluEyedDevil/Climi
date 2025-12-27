# Real-World Examples: Gemini + Claude Code Workflows

This document provides concrete examples of using Gemini as a large-context companion to Claude Code across different scenarios.

## Example 1: Understanding a Complex Codebase

**Scenario**: You've inherited an app and need to understand how authentication works.

### Step 1: Query Gemini

```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/main/java/com/app/auth/" "
How is authentication implemented?

Show me:
1. Main classes and their responsibilities
2. Login state flow (logged out → authenticated)
3. How token refresh is handled
4. Error handling patterns
5. Key files with line numbers
"
```

### Gemini's Response

```
## SUMMARY
Authentication uses JWT tokens with StateFlow-based state management in AuthManager.kt.

## FILES
- AuthManager.kt:1-350 - Core authentication logic
- AuthState.kt:1-45 - State sealed class
- LoginViewModel.kt:1-200 - UI state management
- AuthRepository.kt - Data layer abstraction
- TokenStorage.kt - Secure token persistence

## ANALYSIS
**Login State Flow:**
- LoggedOut → Authenticating → Authenticated
- Implemented in AuthManager.kt:145-180
- Uses StateFlow for reactive updates

**Token Refresh:**
- Automatic refresh: AuthManager.kt:220-250
- Retry with exponential backoff
- Clears session on persistent failure

**Error Handling:**
- Network errors: AuthManager.kt:280-330
- Timeout handling: 30 second request timeout
- Session cleanup in onCleared()

## RECOMMENDATIONS
1. Review AuthManager.kt:145-180 for state transition logic
2. Check TokenStorage.kt for secure persistence patterns
3. Note error handling in AuthManager.kt:280-330
```

### Step 2: Claude Code Implements Enhancement

Based on Gemini's analysis, you now know exactly where to add a "session timeout" feature. Claude implements:

- Modify `AuthState.kt` to add `lastActivityTime: Long`
- Update `AuthManager.kt:145-180` to track activity
- Update `LoginViewModel.kt` to handle timeout UI

### Step 3: Verify with Gemini

```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/main/java/com/app/auth/" "
Changes made:
- AuthState.kt: Added lastActivityTime field
- AuthManager.kt:195: Added activity tracking
- LoginViewModel.kt:120: Added timeout handling

Verify:
1. Follows existing state management patterns
2. No regressions in auth flow
3. Proper StateFlow updates
"
```

**Result**: Feature implemented efficiently with minimal token usage.

---

## Example 2: Bug Tracing Across Multiple Files

**Scenario**: Users report that the app crashes when logging out during an active session.

### Step 1: Query Gemini to Trace the Bug

```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/main/java/" "
Bug: App crashes when logging out during active session
Error: NullPointerException in SessionManager.kt:245
Stack trace shows calls from: AuthManager → SessionRepository → SessionManager

Trace:
1. What triggers the logout?
2. How does it propagate to SessionManager?
3. What is null at line 245?
4. Why isn't it null-safe?
5. Show the complete call chain with file:line numbers
"
```

### Gemini's Response

```
## SUMMARY
NullPointerException at SessionManager.kt:245 caused by race condition during logout where userData is nullified before endSession() completes.

## FILES
- AuthManager.kt:320 - Logout trigger (onLogoutRequested callback)
- AuthRepository.kt:85 - Observes state, calls clearSession()
- SessionRepository.kt:140 - clearSession() calls SessionManager.endSession()
- SessionManager.kt:180 - Sets userData to null
- SessionManager.kt:245 - CRASH LOCATION

## ANALYSIS
**Call Chain:**
AuthManager.kt:320 → AuthRepository.kt:85 → SessionRepository.kt:140 → SessionManager.kt:245

**Root Cause:**
- `activeSession?.userData.saveMetrics()` at line 245
- `activeSession` is non-null BUT `userData` is null
- userData is set to null at line 180 before endSession() runs
- Race condition: no synchronization between nullify and usage

## RECOMMENDATIONS
1. Add null-safe check: `activeSession?.userData?.saveMetrics()` at line 245
2. Consider atomic state transition for logout sequence
3. Review similar patterns in SessionManager for other potential null issues
```

### Step 2: Claude Code Fixes the Bug

```kotlin
// SessionManager.kt:245 - Changed from:
activeSession?.userData.saveMetrics()

// To:
activeSession?.userData?.saveMetrics()
```

### Step 3: Verify Fix with Gemini

```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/main/java/" "
Fix applied: Made userData?.saveMetrics() null-safe at SessionManager.kt:245

Verify:
1. Are there other places where userData is accessed without null checks?
2. Should userData be nullable in the first place?
3. Any other race conditions in the logout flow?
"
```

**Gemini's Response**:
```
Verification:

1. Other unsafe accesses:
   - SessionManager.kt:260: userData.finalMetrics — NEEDS FIX
   - SessionManager.kt:280: userData.duration — NEEDS FIX

2. Design consideration:
   - userData should remain nullable (represents optional session data)
   - Current design is correct

3. Other race conditions:
   - None found in logout flow
   - All other accesses properly null-safe

Recommendation: Fix lines 260 and 280 with same pattern.
```

**Result**: Bug fixed comprehensively, no regressions, all related issues caught.

---

## Example 3: Implementing a New Feature

**Scenario**: Add user data export as CSV.

### Step 1: Analyze Existing Patterns

```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/main/java/" "
I need to implement user data export to CSV.

Analyze:
1. How is user data currently stored? (database schema)
2. Are there existing export or file-writing patterns?
3. Where should the export button go in the UI?
4. How do other features handle file permissions?
5. What format should the CSV use (show sample from existing data)?
"
```

### Gemini's Response

```
User Export Analysis:

1. Data Storage:
   - Room database: UserEntity (data/local/UserEntity.kt:1-30)
   - Fields: id, name, email, createdAt, preferences
   - DAO: UserDao.kt with getAll() and getByDateRange() queries

2. Existing File Patterns:
   - ProfileExport.kt:45-80: Exports user profile as JSON
   - Uses FileWriter with proper permissions handling
   - Saves to external storage: /Documents/AppName/

3. UI Location:
   - SettingsScreen.kt:120: Has "Export" section
   - Other screens add export to overflow menu
   - Follow pattern in ProfileScreen.kt:200-220

4. Permissions:
   - WRITE_EXTERNAL_STORAGE requested in ProfileExport.kt:50
   - Uses ActivityCompat.requestPermissions()
   - Includes fallback to internal storage on permission denial

5. CSV Format (based on UserEntity):
   Name,Email,Created,Preferences
   John Doe,john@example.com,2024-01-15,dark_mode
```

### Step 2: Claude Code Implements

Based on Gemini's analysis:
1. Create `UserExport.kt` following `ProfileExport.kt` pattern
2. Add export menu item to `SettingsScreen.kt:120`
3. Request permissions using same approach
4. Generate CSV with schema: Name, Email, Created, Preferences

### Step 3: Verify Implementation

```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/main/java/" "
Implemented user CSV export:
- UserExport.kt: New class with exportToCsv() method
- SettingsScreen.kt:125: Added 'Export Data' menu item
- Uses same permission pattern as ProfileExport.kt

Verify:
1. Follows existing file export patterns
2. Permission handling is correct
3. CSV format is appropriate
4. No resource leaks (FileWriter properly closed)
"
```

**Result**: Feature implemented following best practices, caught resource leak before it shipped.

---

## Example 4: Security Audit

**Scenario**: Prepare for release by auditing authentication security.

### Query Gemini for Security Review

```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/" "
Security audit for authentication system.

Check for:
1. Password storage - is it hashed/salted?
2. JWT token handling - stored securely?
3. API authentication - any hardcoded keys?
4. Input validation - SQL injection risks?
5. Session timeout - is there one?
6. HTTPS enforcement - verified?

Provide file:line references for any issues.
"
```

### Gemini's Response

```
Security Audit Results:

1. ✅ Password Storage:
   - auth/PasswordManager.kt:45: Uses bcrypt with salt
   - Secure implementation

2. ⚠️  JWT Token Storage:
   - auth/TokenManager.kt:30: Stored in SharedPreferences (PLAINTEXT)
   - RISK: Should use EncryptedSharedPreferences
   - File: auth/TokenManager.kt, Line: 30

3. ❌ API Keys:
   - api/ApiClient.kt:15: Hardcoded API key in source
   - CRITICAL: Move to BuildConfig or secure storage
   - Key: "sk_live_abc123..." (EXPOSED)

4. ✅ Input Validation:
   - auth/LoginRepository.kt:60: Parameterized queries
   - No SQL injection risk found

5. ⚠️  Session Timeout:
   - No automatic session timeout implemented
   - Tokens never expire

6. ✅ HTTPS Enforcement:
   - api/ApiClient.kt:25: HTTPS enforced
   - Certificate pinning enabled

CRITICAL ISSUES:
- Line api/ApiClient.kt:15: Remove hardcoded API key
- Line auth/TokenManager.kt:30: Use EncryptedSharedPreferences

HIGH PRIORITY:
- Implement session timeout (recommend 30 min)
```

### Claude Code Fixes Issues

1. Moves API key to BuildConfig
2. Switches to EncryptedSharedPreferences
3. Implements 30-minute session timeout

**Result**: Security issues caught and fixed before release.

---

## Example 5: Refactoring Planning

**Scenario**: Codebase has grown; need to refactor the API module.

### Step 1: Analyze Current Architecture

```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/main/java/com/app/api/" "
Analyze API module for refactoring.

Identify:
1. Code duplication
2. Classes with too many responsibilities
3. Tight coupling between components
4. Missing abstractions
5. Suggested refactoring approach

Show file:line for specific issues.
"
```

### Gemini's Response

```
Refactoring Analysis:

1. Code Duplication:
   - ApiClient.kt:100-130 & NetworkService.kt:80-110
   - Same retry logic duplicated
   - Extract to RetryStrategy class

2. God Class:
   - ApiClient.kt (450 lines)
   - Responsibilities: requests, caching, error handling, logging
   - SPLIT INTO: ApiRequester, CacheManager, ErrorHandler

3. Tight Coupling:
   - Repository.kt:40 directly instantiates ApiClient
   - Hard to test, no dependency injection
   - Use constructor injection

4. Missing Abstraction:
   - Multiple files parse JSON responses: lines 120, 200, 340
   - No shared ResponseParser interface
   - Create ResponseParser with implementations

5. Suggested Refactoring:
   Phase 1: Extract RetryStrategy (low risk)
   Phase 2: Add ApiClient interface for DI
   Phase 3: Split into smaller classes (high effort)
   Phase 4: Create ResponseParser abstraction

Recommended order: Low risk → High value
Start with Phase 1 and Phase 4 (quick wins).
```

### Step 2: Claude Code Implements Phase 1

Creates `RetryStrategy` class and refactors duplicate code.

### Step 3: Verify with Gemini

```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/main/java/com/app/api/" "
Refactoring Phase 1 complete:
- Created RetryStrategy.kt
- Removed duplication from ApiClient.kt:100-130
- Removed duplication from NetworkService.kt:80-110

Verify:
1. No functionality changed (behavior preserved)
2. All call sites updated correctly
3. No new coupling introduced
"
```

**Result**: Incremental refactoring with verification at each step, no regressions.

---

## Token Savings Comparison

| Example | Without Gemini | With Gemini | Savings |
|---------|---------------|-------------|---------|
| Example 1 (Understanding) | ~8k tokens | ~400 tokens | 95% |
| Example 2 (Bug Tracing) | ~12k tokens | ~500 tokens | 96% |
| Example 3 (New Feature) | ~10k tokens | ~450 tokens | 95% |
| Example 4 (Security Audit) | ~15k tokens | ~600 tokens | 96% |
| Example 5 (Refactoring) | ~20k tokens | ~700 tokens | 96% |
| **Total** | **~65k tokens** | **~2,650 tokens** | **~96%** |

## Key Takeaways

1. **Query Gemini first** - Always analyze before implementing
2. **Be specific** - Detailed queries get detailed responses
3. **Verify after** - Catch issues before they ship
4. **Follow patterns** - Use templates for consistent results
5. **Iterate** - Complex features benefit from multiple analyze → implement → verify cycles

## Common Patterns Summary

### Pattern 1: Bug Investigation
Gemini traces → Claude fixes → Gemini verifies comprehensive coverage

### Pattern 2: New Feature
Gemini analyzes patterns → Claude implements → Gemini checks consistency

### Pattern 3: Security Review
Gemini audits → Claude fixes → Gemini re-audits

### Pattern 4: Refactoring
Gemini identifies issues → Claude refactors incrementally → Gemini verifies behavior preserved

All patterns conserve Claude's tokens while maintaining quality and catching issues early.
