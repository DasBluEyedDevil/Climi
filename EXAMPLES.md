# Real-World Examples: Gemini + Claude Code Workflows

This document provides concrete examples of using Gemini as a large-context companion to Claude Code across different scenarios.

## Example 1: Understanding a Complex Codebase

**Scenario**: You've inherited an Android app and need to understand how BLE connection management works.

### Step 1: Query Gemini

```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/main/java/com/app/ble/" "
How is BLE connection management implemented?

Show me:
1. Main classes and their responsibilities
2. Connection state flow (disconnected → connected)
3. How reconnection is handled
4. Error handling patterns
5. Key files with line numbers
"
```

### Gemini's Response

```
BLE Connection Management Analysis:

1. Main Classes:
   - BleConnectionManager.kt (lines 1-350): Core connection logic
   - BleState.kt (lines 1-45): State sealed class
   - ConnectionViewModel.kt (lines 1-200): UI state management

2. Connection State Flow:
   - Disconnected → Connecting → Connected
   - Implemented in BleConnectionManager.kt:145-180
   - Uses StateFlow for reactive updates

3. Reconnection:
   - Exponential backoff: BleConnectionManager.kt:220-250
   - Max 5 attempts with delays: 1s, 2s, 4s, 8s, 16s
   - Cancels on manual disconnect

4. Error Handling:
   - BluetoothGatt callbacks: BleConnectionManager.kt:280-330
   - Timeout handling: 30 second connection timeout
   - Resource cleanup in onCleared()

5. Key Files:
   - BleConnectionManager.kt: Primary connection logic
   - BleRepository.kt: Data layer abstraction
   - BleService.kt: Foreground service for background connections
```

### Step 2: Claude Code Implements Enhancement

Based on Gemini's analysis, you now know exactly where to add a "connection quality indicator" feature. Claude implements:

- Modify `BleState.kt` to add `connectionQuality: Int`
- Update `BleConnectionManager.kt:145-180` to calculate quality
- Update `ConnectionViewModel.kt` to expose quality to UI

### Step 3: Verify with Gemini

```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/main/java/com/app/ble/" "
Changes made:
- BleState.kt: Added connectionQuality field
- BleConnectionManager.kt:195: Added quality calculation
- ConnectionViewModel.kt:120: Exposed quality to UI

Verify:
1. Follows existing state management patterns
2. No regressions in connection flow
3. Proper StateFlow updates
"
```

**Result**: Feature implemented efficiently with minimal token usage.

---

## Example 2: Bug Tracing Across Multiple Files

**Scenario**: Users report that the app crashes when disconnecting from BLE device during an active workout.

### Step 1: Query Gemini to Trace the Bug

```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/main/java/" "
Bug: App crashes when disconnecting BLE during active workout
Error: NullPointerException in WorkoutManager.kt:245
Stack trace shows calls from: BleConnectionManager → WorkoutRepository → WorkoutManager

Trace:
1. What triggers the disconnect?
2. How does it propagate to WorkoutManager?
3. What is null at line 245?
4. Why isn't it null-safe?
5. Show the complete call chain with file:line numbers
"
```

### Gemini's Response

```
Bug Trace Analysis:

1. Disconnect Trigger:
   - BleConnectionManager.kt:320: onConnectionStateChange callback
   - Emits Disconnected state via StateFlow

2. Propagation Chain:
   - BleConnectionManager.kt:320 → StateFlow update
   - BleRepository.kt:85: Observes state, calls stopWorkout()
   - WorkoutRepository.kt:140: stopWorkout() calls WorkoutManager.endWorkout()
   - WorkoutManager.kt:245: CRASHES HERE

3. Null Value:
   - WorkoutManager.kt:245: `activeWorkout?.bleData.recordFinalSample()`
   - `activeWorkout` is non-null BUT `bleData` is null
   - bleData is initialized in startWorkout() from BLE connection
   - When BLE disconnects, bleData is set to null (line 180)
   - BUT endWorkout() assumes bleData exists

4. Root Cause:
   - Race condition: BLE disconnect sets bleData=null before endWorkout() runs
   - No null check at line 245

5. Call Chain:
   BleConnectionManager.kt:320 (onConnectionStateChange)
     ↓
   BleRepository.kt:85 (observeConnectionState)
     ↓
   WorkoutRepository.kt:140 (stopWorkout)
     ↓
   WorkoutManager.kt:245 (endWorkout — CRASH)

Recommended Fix:
Add null-safe check: `activeWorkout?.bleData?.recordFinalSample()` (line 245)
```

### Step 2: Claude Code Fixes the Bug

```kotlin
// WorkoutManager.kt:245 - Changed from:
activeWorkout?.bleData.recordFinalSample()

// To:
activeWorkout?.bleData?.recordFinalSample()
```

### Step 3: Verify Fix with Gemini

```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/main/java/" "
Fix applied: Made bleData?.recordFinalSample() null-safe at WorkoutManager.kt:245

Verify:
1. Are there other places where bleData is accessed without null checks?
2. Should bleData be nullable in the first place?
3. Any other race conditions in the disconnect flow?
"
```

**Gemini's Response**:
```
Verification:

1. Other unsafe accesses:
   - WorkoutManager.kt:260: bleData.finalMetrics — NEEDS FIX
   - WorkoutManager.kt:280: bleData.duration — NEEDS FIX

2. Design consideration:
   - bleData should remain nullable (represents optional BLE connection)
   - Current design is correct

3. Other race conditions:
   - None found in disconnect flow
   - All other accesses properly null-safe

Recommendation: Fix lines 260 and 280 with same pattern.
```

### Step 4: Claude Code Applies Additional Fixes

Updates lines 260 and 280 to be null-safe.

**Result**: Bug fixed comprehensively, no regressions, all related issues caught.

---

## Example 3: Implementing a New Feature

**Scenario**: Add workout history export as CSV.

### Step 1: Analyze Existing Patterns

```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/main/java/" "
I need to implement workout history export to CSV.

Analyze:
1. How is workout data currently stored? (database schema)
2. Are there existing export or file-writing patterns?
3. Where should the export button go in the UI?
4. How do other features handle file permissions?
5. What format should the CSV use (show sample from existing data)?
"
```

### Gemini's Response

```
Workout Export Analysis:

1. Data Storage:
   - Room database: WorkoutEntity (data/local/WorkoutEntity.kt:1-30)
   - Fields: id, userId, date, exerciseType, repCount, weight, duration
   - DAO: WorkoutDao.kt with getAll() and getByDateRange() queries

2. Existing File Patterns:
   - ProfileExport.kt:45-80: Exports user profile as JSON
   - Uses FileWriter with proper permissions handling
   - Saves to external storage: /Documents/AppName/

3. UI Location:
   - HistoryScreen.kt:120: TopAppBar has "..." menu
   - Other screens add export to overflow menu
   - Follow pattern in ProfileScreen.kt:200-220

4. Permissions:
   - WRITE_EXTERNAL_STORAGE requested in ProfileExport.kt:50
   - Uses ActivityCompat.requestPermissions()
   - Includes fallback to internal storage on permission denial

5. CSV Format (based on WorkoutEntity):
   Date,Exercise,Reps,Weight (lbs),Duration (sec)
   2024-01-15,Chest Press,10,150,45
   2024-01-15,Squats,12,200,60
```

### Step 2: Claude Code Implements

Based on Gemini's analysis:

1. Create `WorkoutExport.kt` following `ProfileExport.kt` pattern
2. Add export menu item to `HistoryScreen.kt:120`
3. Request permissions using same approach
4. Generate CSV with schema: Date, Exercise, Reps, Weight, Duration

### Step 3: Verify Implementation

```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/main/java/" "
Implemented workout CSV export:
- WorkoutExport.kt: New class with exportToCsv() method
- HistoryScreen.kt:125: Added 'Export CSV' menu item
- Uses same permission pattern as ProfileExport.kt

Verify:
1. Follows existing file export patterns
2. Permission handling is correct
3. CSV format is appropriate
4. No resource leaks (FileWriter properly closed)
"
```

**Gemini's Response**:
```
Verification:

1. ✅ Follows ProfileExport.kt pattern correctly
2. ✅ Permission handling matches existing approach
3. ✅ CSV format is clear and matches data schema
4. ⚠️  ISSUE: WorkoutExport.kt:65 - FileWriter not in try-with-resources
   - Should use: `FileWriter(...).use { writer -> ... }`
   - Current code risks file handle leak on exception

Recommendation: Wrap FileWriter in .use {} block for automatic closing.
```

### Step 4: Claude Code Fixes Issue

Update `WorkoutExport.kt:65` to use `.use {}` block.

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

**Scenario**: Codebase has grown; need to refactor BLE module.

### Step 1: Analyze Current Architecture

```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/main/java/com/app/ble/" "
Analyze BLE module for refactoring.

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
   - BleConnectionManager.kt:100-130 & BleService.kt:80-110
   - Same connection retry logic duplicated
   - Extract to BleRetryStrategy class

2. God Class:
   - BleConnectionManager.kt (450 lines)
   - Responsibilities: connection, characteristic reading, error handling, state management
   - SPLIT INTO: BleConnection, BleCharacteristicReader, BleErrorHandler

3. Tight Coupling:
   - BleRepository.kt:40 directly instantiates BleConnectionManager
   - Hard to test, no dependency injection
   - Use constructor injection

4. Missing Abstraction:
   - Multiple files parse characteristic bytes: lines 120, 200, 340
   - No shared CharacteristicParser interface
   - Create BleCharacteristicParser with implementations

5. Suggested Refactoring:
   Phase 1: Extract BleRetryStrategy (low risk)
   Phase 2: Add BleConnectionManager interface for DI
   Phase 3: Split into smaller classes (high effort)
   Phase 4: Create CharacteristicParser abstraction

Recommended order: Low risk → High value
Start with Phase 1 and Phase 4 (quick wins).
```

### Step 2: Claude Code Implements Phase 1

Creates `BleRetryStrategy` class and refactors duplicate code.

### Step 3: Verify with Gemini

```bash
./skills/gemini.agent.wrapper.sh -d "@app/src/main/java/com/app/ble/" "
Refactoring Phase 1 complete:
- Created BleRetryStrategy.kt
- Removed duplication from BleConnectionManager.kt:100-130
- Removed duplication from BleService.kt:80-110

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
