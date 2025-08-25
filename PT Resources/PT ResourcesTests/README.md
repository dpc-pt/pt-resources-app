# PT Resources Unit Tests

This document describes the comprehensive unit test suite for the PT Resources iOS app.

## Test Coverage

The test suite covers the following areas:

### 1. Image Cache Service Tests (`ImageCacheServiceTests.swift`)
- ✅ Cache key generation
- ✅ Image processing and resizing
- ✅ Memory cache functionality
- ✅ Error handling for invalid data
- ✅ Performance testing

### 2. Privacy Service Tests (`PrivacyServiceTests.swift`)
- ✅ Data export functionality (full, talks, history)
- ✅ Data deletion (downloaded content, history, all data)
- ✅ Data usage statistics
- ✅ GDPR compliance features
- ✅ Export data models

### 3. Accessibility Tests (`AccessibilityTests.swift`)
- ✅ VoiceOver support
- ✅ Dynamic Type fonts
- ✅ Haptic feedback
- ✅ Accessibility preferences
- ✅ Color contrast compliance
- ✅ View extensions

### 4. Logger Tests (`PTLoggerTests.swift`)
- ✅ All logging categories
- ✅ Performance logging
- ✅ Error logging with metadata
- ✅ Concurrent logging
- ✅ Special character handling

### 5. Model Tests (`ModelTests.swift`)
- ✅ All data models (Talk, ESVPassage, Transcription, etc.)
- ✅ Codable compliance
- ✅ Mock data validation
- ✅ Edge cases and extreme values
- ✅ Performance testing

## Running Tests

### Xcode

```bash
# Run all tests
xcodebuild test -project "PT Resources/PT Resources.xcodeproj" -scheme "PT Resources" -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test -project "PT Resources/PT Resources.xcodeproj" -scheme "PT Resources" -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:PT_ResourcesTests/ImageCacheServiceTests

# Run with code coverage
xcodebuild test -project "PT Resources/PT Resources.xcodeproj" -scheme "PT Resources" -destination 'platform=iOS Simulator,name=iPhone 15' -enableCodeCoverage YES
```

### Command Line

```bash
# From the PT Resources directory
xcodebuild test -scheme "PT Resources" -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Test Configuration

### Test Environment
- **iOS Deployment Target**: iOS 17.0+
- **Swift Version**: 5.9+
- **Xcode Version**: 15.0+

### Test Data
- Mock data is used throughout tests
- Tests are designed to run without network access
- All tests are self-contained and don't modify production data

## Code Coverage Goals

| Component | Target Coverage |
|-----------|----------------|
| Models | 95% |
| Services | 85% |
| ViewModels | 80% |
| Views | 70% |
| Overall | 80% |

## Test Categories

### Unit Tests
- Test individual functions and methods
- Mock external dependencies
- Fast execution (< 0.1s per test)

### Integration Tests
- Test interactions between components
- Use real dependencies where appropriate
- Medium execution time (0.1-1s per test)

### Performance Tests
- Measure execution time
- Memory usage testing
- Large dataset handling

## Best Practices

### Test Organization
- ✅ Tests are organized by component/feature
- ✅ Test methods follow naming convention: `test[Feature][Condition][ExpectedResult]`
- ✅ Test classes have descriptive names ending with `Tests`

### Test Structure
- ✅ `setUpWithError()` and `tearDownWithError()` for test lifecycle
- ✅ Proper error handling in tests
- ✅ Clear assertions with descriptive messages

### Mock Data
- ✅ Comprehensive mock data for all models
- ✅ Consistent test data across tests
- ✅ Edge cases and boundary conditions covered

### Performance
- ✅ Performance tests for critical paths
- ✅ Memory leak detection
- ✅ Large dataset handling

## Continuous Integration

The test suite is designed to run in CI environments:

```yaml
# Example GitHub Actions workflow
- name: Run Tests
  run: |
    xcodebuild test \
      -project "PT Resources/PT Resources.xcodeproj" \
      -scheme "PT Resources" \
      -destination 'platform=iOS Simulator,name=iPhone 15' \
      -resultBundlePath TestResults \
      -enableCodeCoverage YES
```

## Troubleshooting

### Common Issues

1. **Simulator not available**
   - Ensure iOS Simulator is installed
   - Check available simulators: `xcrun simctl list`

2. **Code signing errors**
   - Tests should use automatic code signing
   - Check team settings in Xcode

3. **Missing dependencies**
   - All dependencies are included in the project
   - Check CocoaPods or Swift Package Manager setup

### Debug Mode

```bash
# Run tests with verbose output
xcodebuild test -project "PT Resources/PT Resources.xcodeproj" -scheme "PT Resources" -destination 'platform=iOS Simulator,name=iPhone 15' -verbose
```

## Future Enhancements

- [ ] UI Tests with XCUITest
- [ ] Snapshot testing for SwiftUI views
- [ ] Integration tests with real API endpoints
- [ ] Performance regression testing
- [ ] Memory leak detection tests

