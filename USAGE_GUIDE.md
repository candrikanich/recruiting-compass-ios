# LoginViewModel Feature Usage Guide

Complete examples for using all new features in your view layer.

---

## Quick Reference

| Feature | Property | Method | Init Parameter |
|---|---|---|---|
| Timeout Banner | `showTimeoutBanner` | `dismissTimeoutBanner()` | `timeoutReason` |
| Validating State | `isValidating` | — | — |
| Return Key | — | — | Works via `onSubmit` |
| Email Caching | `rememberMe`, `email` | — | Automatic on init |
| Error Messages | `errorMessage` | `mapError()` | Automatic in login |

---

## Feature 1: Timeout Banner

### Display Timeout Banner in View

```swift
struct LoginView: View {
  @StateObject private var viewModel: LoginViewModel
  @Environment(\.dismiss) var dismiss

  var body: some View {
    VStack {
      // Show timeout banner if session expired
      if viewModel.showTimeoutBanner {
        TimeoutBanner()
          .transition(.opacity)
          .padding()
      }

      // Rest of form...
    }
  }
}
```

### Initialize with Timeout Reason

**Option 1: From URL Query Parameter**
```swift
// In NavigationStack or route handler
let queryParams = URL(string: "app://login?reason=timeout")!
let components = URLComponents(url: queryParams, resolvingAgainstBaseURL: false)
let timeoutReason = components?.queryItems?.first(where: { $0.name == "reason" })?.value

LoginView(timeoutReason: timeoutReason)
```

**Option 2: Direct Initialization**
```swift
// When user was logged out due to inactivity
let viewModel = LoginViewModel(timeoutReason: "timeout")
```

**Option 3: From Navigation Parameter**
```swift
NavigationStack(path: $navigationPath) {
  LoginView(timeoutReason: navigationReason)
}
```

### Dismiss Banner

```swift
// User taps X button or banner auto-dismisses after time
viewModel.dismissTimeoutBanner()

// Or after delay
DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
  viewModel.dismissTimeoutBanner()
}
```

### Complete Example
```swift
struct LoginView: View {
  @StateObject private var viewModel: LoginViewModel
  let timeoutReason: String?

  init(timeoutReason: String? = nil) {
    _viewModel = StateObject(wrappedValue: LoginViewModel(timeoutReason: timeoutReason))
  }

  var body: some View {
    VStack {
      if viewModel.showTimeoutBanner {
        HStack {
          Image(systemName: "hourglass")
            .foregroundColor(.orange)

          Text("You were logged out due to inactivity. Please log in again.")
            .font(.system(size: 14))

          Spacer()

          Button(action: { viewModel.dismissTimeoutBanner() }) {
            Image(systemName: "xmark")
          }
        }
        .padding(12)
        .background(Color(red: 1, green: 0.984, blue: 0.92))
        .cornerRadius(8)
        .transition(.opacity)
      }

      // Form continues below...
    }
  }
}
```

---

## Feature 2: Validating State

### Show Loading Spinner During Validation

```swift
TextField("Email", text: $viewModel.email)
  .overlay(alignment: .trailing) {
    if viewModel.isValidating {
      ProgressView()
        .frame(width: 20, height: 20)
        .padding(.trailing, 8)
    }
  }
```

### Disable Input While Validating

```swift
HStack {
  TextField("Email", text: $viewModel.email)
    .disabled(viewModel.isValidating)

  if viewModel.isValidating {
    ProgressView()
      .tint(.gray)
  }
}
```

### Show Different Text Based on Validation State

```swift
Button(action: { viewModel.validateEmail() }) {
  Text(viewModel.isValidating ? "Validating..." : "Check Email")
}
.disabled(viewModel.isValidating)
```

### Complete Form Field with Validation Feedback

```swift
struct ValidatingEmailField: View {
  @ObservedObject var viewModel: LoginViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Email")
        .font(.system(size: 14, weight: .semibold))

      HStack(spacing: 8) {
        Image(systemName: "envelope")
          .foregroundColor(.gray)
          .frame(width: 20)

        TextField("your.email@example.com", text: $viewModel.email)
          .keyboardType(.emailAddress)
          .textInputAutocapitalization(.never)
          .disabled(viewModel.isValidating)
          .onSubmit {
            viewModel.validateEmail()
          }

        if viewModel.isValidating {
          ProgressView()
            .tint(.gray)
        }
      }
      .padding(12)
      .background(Color.white)
      .border(
        viewModel.fieldErrors["email"] != nil ? Color.red : Color.gray.opacity(0.2)
      )
      .cornerRadius(8)

      if let error = viewModel.fieldErrors["email"] {
        Text(error)
          .font(.system(size: 12))
          .foregroundColor(.red)
      }
    }
  }
}
```

---

## Feature 3: Return Key Submission

### Connect Return Key to Validation

```swift
TextField("Email", text: $viewModel.email)
  .onSubmit {
    viewModel.validateEmail()
  }

SecureField("Password", text: $viewModel.password)
  .onSubmit {
    viewModel.validatePassword()
  }
```

### Chain Validations on Return

```swift
TextField("Email", text: $viewModel.email)
  .onSubmit {
    viewModel.validateEmail()
    // Move focus to password field
    DispatchQueue.main.async {
      UIApplication.shared.sendAction(#selector(UIResponder.becomeFirstResponder), to: nil, from: nil)
    }
  }

SecureField("Password", text: $viewModel.password)
  .onSubmit {
    viewModel.validatePassword()
    // Try login if form valid
    if viewModel.isFormValid {
      Task {
        await viewModel.login()
      }
    }
  }
```

### Complete Login Form with Return Key Handling

```swift
struct LoginFormView: View {
  @ObservedObject var viewModel: LoginViewModel
  @FocusState private var focusedField: Field?

  enum Field {
    case email, password
  }

  var body: some View {
    VStack(spacing: 16) {
      // Email field
      TextField("Email", text: $viewModel.email)
        .keyboardType(.emailAddress)
        .textInputAutocapitalization(.never)
        .focused($focusedField, equals: .email)
        .onSubmit {
          viewModel.validateEmail()
          focusedField = .password
        }
        .padding(12)
        .border(Color.gray.opacity(0.2))
        .cornerRadius(8)

      if let error = viewModel.fieldErrors["email"] {
        Text(error).foregroundColor(.red).font(.caption)
      }

      // Password field
      SecureField("Password", text: $viewModel.password)
        .focused($focusedField, equals: .password)
        .onSubmit {
          viewModel.validatePassword()
          if viewModel.isFormValid {
            Task {
              await viewModel.login()
            }
          }
        }
        .padding(12)
        .border(Color.gray.opacity(0.2))
        .cornerRadius(8)

      if let error = viewModel.fieldErrors["password"] {
        Text(error).foregroundColor(.red).font(.caption)
      }

      // Login button
      Button(action: {
        Task {
          await viewModel.login()
        }
      }) {
        Text("Sign In")
          .frame(maxWidth: .infinity)
          .padding(12)
          .background(Color.blue)
          .foregroundColor(.white)
          .cornerRadius(8)
      }
      .disabled(viewModel.isButtonDisabled)
    }
  }
}
```

---

## Feature 4: Remember Me Email Caching

### Display Remember Me Checkbox

```swift
HStack(spacing: 8) {
  Image(systemName: viewModel.rememberMe ? "checkmark.square.fill" : "square")
    .foregroundColor(.blue)
    .onTapGesture { viewModel.rememberMe.toggle() }

  Text("Remember me")
    .onTapGesture { viewModel.rememberMe.toggle() }

  Spacer()
}
```

### Cached Email Pre-fills Form

```swift
// This happens automatically on LoginViewModel init:
// - Loads cached email from UserDefaults
// - Sets rememberMe = true if found
// - User sees email pre-filled in form

struct LoginView: View {
  @StateObject private var viewModel = LoginViewModel()

  var body: some View {
    TextField("Email", text: $viewModel.email)
    // If user previously selected "Remember me", email is already filled
  }
}
```

### Cache Email on Login

```swift
// This happens automatically in viewModel.login():
// if rememberMe {
//   cacheEmail(email)
// } else {
//   clearCachedEmail()
// }

Button("Sign In") {
  Task {
    await viewModel.login()
    // Email now cached if rememberMe was true
  }
}
```

### Complete Remember Me Section

```swift
struct RememberMeSection: View {
  @ObservedObject var viewModel: LoginViewModel

  var body: some View {
    HStack(spacing: 12) {
      // Checkbox
      Button(action: { viewModel.rememberMe.toggle() }) {
        HStack(spacing: 6) {
          Image(systemName: viewModel.rememberMe ? "checkmark.square.fill" : "square")
            .foregroundColor(viewModel.rememberMe ? .blue : .gray)

          Text("Remember me")
            .foregroundColor(.black)
        }
      }

      Spacer()

      // Forgot password link
      NavigationLink(value: "forgot-password") {
        Text("Forgot password?")
          .font(.system(size: 14))
          .foregroundColor(.blue)
      }
    }
    .frame(height: 44)
  }
}
```

### Disable Remember Me on Error

```swift
// Best practice: Clear cache if user has wrong password too many times
Task {
  await viewModel.login()
  if viewModel.errorMessage?.contains("Invalid") == true {
    viewModel.rememberMe = false
    // Consider clearing cache after security event
  }
}
```

---

## Feature 5: Comprehensive Error Messages

### Display Error Banner

```swift
if let error = viewModel.errorMessage {
  HStack(spacing: 12) {
    Image(systemName: "exclamationmark.circle.fill")
      .foregroundColor(.red)

    Text(error)
      .font(.system(size: 14))

    Spacer()

    Button(action: { viewModel.dismissError() }) {
      Image(systemName: "xmark")
        .foregroundColor(.red)
    }
  }
  .padding(12)
  .background(Color(red: 0.996, green: 0.886, blue: 0.886))
  .cornerRadius(8)
  .transition(.opacity)
}
```

### Handle Specific Errors

```swift
Task {
  await viewModel.login()

  // Error handling is automatic via mapError()
  // But you can also respond to specific messages
  if viewModel.errorMessage?.contains("sign up") == true {
    // Offer to navigate to signup
  } else if viewModel.errorMessage?.contains("verify") == true {
    // Show resend verification button
  }
}
```

### Error-to-Action Mapping

```swift
struct ErrorRecoveryView: View {
  @ObservedObject var viewModel: LoginViewModel
  @State var showSignup = false

  var body: some View {
    VStack {
      if let error = viewModel.errorMessage {
        VStack(spacing: 12) {
          Text(error)
            .font(.system(size: 14))

          // Show recovery action based on error
          if error.contains("sign up") {
            NavigationLink(value: "signup") {
              Text("Create an account")
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(4)
            }
          }

          if error.contains("verify") {
            Button(action: { /* resend verification */ }) {
              Text("Resend verification email")
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(4)
            }
          }

          if error.contains("try again later") {
            Button(action: { viewModel.dismissError() }) {
              Text("OK")
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(4)
            }
          }
        }
        .padding(12)
        .background(Color(red: 0.996, green: 0.886, blue: 0.886))
        .cornerRadius(8)
      }
    }
  }
}
```

---

## Complete Login Form Example

Combining all features together:

```swift
struct CompleteLoginView: View {
  @StateObject private var viewModel: LoginViewModel
  @Environment(\.dismiss) var dismiss
  @FocusState private var focusedField: Field?

  enum Field {
    case email, password
  }

  let timeoutReason: String?

  init(timeoutReason: String? = nil) {
    self.timeoutReason = timeoutReason
    _viewModel = StateObject(wrappedValue: LoginViewModel(timeoutReason: timeoutReason))
  }

  var body: some View {
    ZStack {
      LinearGradient(
        gradient: Gradient(colors: [Color(red: 0.024, green: 0.588, blue: 0.412), Color(red: 0.016, green: 0.522, blue: 0.373)]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      VStack(spacing: 0) {
        // Navigation
        HStack {
          Button(action: { dismiss() }) {
            HStack(spacing: 4) {
              Image(systemName: "arrow.left")
              Text("Back")
            }
          }
          Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)

        ScrollView {
          VStack(spacing: 24) {
            // Timeout banner
            if viewModel.showTimeoutBanner {
              HStack(spacing: 12) {
                Image(systemName: "hourglass")
                  .foregroundColor(.orange)
                Text("You were logged out due to inactivity. Please log in again.")
                  .font(.system(size: 14))
                Spacer()
              }
              .padding(12)
              .background(Color(red: 1, green: 0.984, blue: 0.92))
              .cornerRadius(8)
              .transition(.opacity)
            }

            // Error banner
            if let error = viewModel.errorMessage {
              HStack(spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                  .foregroundColor(.red)
                Text(error)
                Spacer()
                Button(action: { viewModel.dismissError() }) {
                  Image(systemName: "xmark")
                    .foregroundColor(.red)
                }
              }
              .padding(12)
              .background(Color(red: 0.996, green: 0.886, blue: 0.886))
              .cornerRadius(8)
              .transition(.opacity)
            }

            // Email field
            VStack(alignment: .leading, spacing: 4) {
              Text("Email")
                .font(.system(size: 14, weight: .semibold))

              HStack(spacing: 8) {
                Image(systemName: "envelope")
                  .foregroundColor(.gray)

                TextField("your.email@example.com", text: $viewModel.email)
                  .keyboardType(.emailAddress)
                  .textInputAutocapitalization(.never)
                  .focused($focusedField, equals: .email)
                  .onSubmit {
                    viewModel.validateEmail()
                    focusedField = .password
                  }

                if viewModel.isValidating {
                  ProgressView()
                    .tint(.gray)
                }
              }
              .padding(12)
              .border(viewModel.fieldErrors["email"] != nil ? Color.red : Color.gray.opacity(0.2))
              .cornerRadius(8)

              if let error = viewModel.fieldErrors["email"] {
                Text(error)
                  .font(.system(size: 12))
                  .foregroundColor(.red)
              }
            }

            // Password field
            VStack(alignment: .leading, spacing: 4) {
              Text("Password")
                .font(.system(size: 14, weight: .semibold))

              HStack(spacing: 8) {
                Image(systemName: "lock")
                  .foregroundColor(.gray)

                SecureField("Enter your password", text: $viewModel.password)
                  .focused($focusedField, equals: .password)
                  .onSubmit {
                    viewModel.validatePassword()
                    if viewModel.isFormValid {
                      Task {
                        await viewModel.login()
                      }
                    }
                  }

                if viewModel.isValidating {
                  ProgressView()
                    .tint(.gray)
                }
              }
              .padding(12)
              .border(viewModel.fieldErrors["password"] != nil ? Color.red : Color.gray.opacity(0.2))
              .cornerRadius(8)

              if let error = viewModel.fieldErrors["password"] {
                Text(error)
                  .font(.system(size: 12))
                  .foregroundColor(.red)
              }
            }

            // Remember me
            HStack(spacing: 8) {
              Button(action: { viewModel.rememberMe.toggle() }) {
                HStack(spacing: 6) {
                  Image(systemName: viewModel.rememberMe ? "checkmark.square.fill" : "square")
                    .foregroundColor(.blue)
                  Text("Remember me")
                }
              }

              Spacer()

              NavigationLink(value: "forgot-password") {
                Text("Forgot password?")
                  .font(.system(size: 14))
                  .foregroundColor(.blue)
              }
            }
            .frame(height: 44)

            // Login button
            Button(action: {
              Task {
                await viewModel.login()
              }
            }) {
              HStack {
                Text(viewModel.isLoading ? "Signing in..." : "Sign In")
                  .font(.system(size: 16, weight: .semibold))

                if viewModel.isLoading {
                  ProgressView()
                    .tint(.white)
                }
              }
              .frame(maxWidth: .infinity)
              .frame(height: 48)
              .foregroundColor(.white)
              .background(
                LinearGradient(
                  gradient: Gradient(colors: [Color(red: 0, green: 0.4, blue: 1), Color(red: 0, green: 0.32, blue: 0.8)]),
                  startPoint: .leading,
                  endPoint: .trailing
                )
              )
              .cornerRadius(8)
              .opacity(viewModel.isButtonDisabled ? 0.5 : 1)
              .disabled(viewModel.isButtonDisabled)
            }

            // Signup link
            HStack(spacing: 4) {
              Text("Don't have an account?")
              NavigationLink(value: "signup") {
                HStack(spacing: 4) {
                  Text("Create one now")
                    .font(.system(size: 14, weight: .semibold))
                  Image(systemName: "arrow.right")
                }
                .foregroundColor(.blue)
              }
            }
          }
          .padding(32)
        }
        .background(Color.white.opacity(0.95))
        .cornerRadius(16)
        .padding(24)

        Spacer()
      }
    }
  }
}

#Preview {
  NavigationStack {
    CompleteLoginView()
  }
}
```

---

## Testing in Previews

```swift
#Preview("Normal Login") {
  NavigationStack {
    CompleteLoginView()
  }
}

#Preview("With Timeout") {
  NavigationStack {
    CompleteLoginView(timeoutReason: "timeout")
  }
}

#Preview("With Validation Error") {
  var viewModel = LoginViewModel()
  viewModel.email = "invalid"
  viewModel.validateEmail()

  return NavigationStack {
    CompleteLoginView()
  }
}

#Preview("With Network Error") {
  var viewModel = LoginViewModel()
  viewModel.errorMessage = "Network error. Please check your connection and try again."

  return NavigationStack {
    CompleteLoginView()
  }
}
```

---

## Summary

All five features work together seamlessly:
1. **Timeout Banner** - Notifies user of session expiration
2. **Validating State** - Provides visual feedback during validation
3. **Return Key** - Enables keyboard submission
4. **Email Caching** - Convenience for repeated logins
5. **Error Messages** - User-friendly error communication

Use the complete example above as a starting point and customize UI to match your design.
