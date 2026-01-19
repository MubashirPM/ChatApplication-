# Interview Quick Reference - Authentication System

## 🎯 30-Second Elevator Pitch

*"I implemented Firebase Authentication with Google and Facebook sign-in using MVVM architecture. The system includes real-time auth state monitoring, automatic user validation on app launch, and handles user deletion detection. Users are stored in both Firebase Auth (for authentication) and Firestore (for application data and querying)."*

---

## 📊 Architecture Overview

```
ChatAppDemoApp (Entry Point)
    └── AuthenticationViewModel (@StateObject)
        ├── Firebase Auth (Authentication)
        ├── Firestore "Users" Collection (Application Data)
        ├── Google Sign-In SDK (Native iOS)
        └── OAuthProvider (Facebook Web Flow)
```

**MVVM Pattern:**
- **Model**: `UserModel.swift` - User data structure
- **View**: `AutheticationView.swift` - UI layer
- **ViewModel**: `AuthenticationViewModel.swift` - Business logic

---

## 🔄 Authentication Flow (30 seconds)

1. **App Launch** → Initialize Firebase & Google Sign-In
2. **ViewModel Init** → Setup auth state listener + validate existing session
3. **Check Auth State** → Read UserDefaults + Check Firebase Auth cache
4. **If Not Authenticated** → Show login screen (`AuthenticationView`)
5. **User Taps "Continue With Google"** → Native iOS Google sign-in UI
6. **Exchange Credentials** → Google ID Token → Firebase Credential
7. **Sign In with Firebase** → `Auth.auth().signIn(with: credential)`
8. **Save to Firestore** → Create/Update user document in `Users/{uid}`
9. **Load Current User** → Fetch from Firestore
10. **Save Auth State** → UserDefaults + `isAuthenticated = true`
11. **Auth State Listener** → Automatically triggers, validates user
12. **UI Updates** → Reactive binding shows `TabBarView`

---

## 💾 User Storage Strategy (Key Point!)

### **Dual Storage Approach**

**Firebase Auth (Primary Auth):**
- Purpose: Authentication & Authorization
- Stores: UID, email, display name, photo URL, tokens
- Access: `Auth.auth().currentUser`

**Firestore "Users" Collection (Application Data):**
- Purpose: Application-specific data & querying
- Stores: id, name, email, photoURL, createdAt
- Access: `db.collection("Users").document(userId)`
- Why: Can query all users for chat list (Auth doesn't support queries)

---

## 🔐 Key Features

### **1. Real-Time Auth State Monitoring**
```swift
Auth.auth().addStateDidChangeListener { _, user in
    // Fires on: sign in, sign out, token refresh, user deletion
    // Automatically validates user.reload()
}
```

### **2. Multi-Layer User Validation**
- **On App Launch**: `validateAndCheckAuthenticationState()`
- **Auth State Listener**: Real-time monitoring
- **On App Foreground**: `validateUserOnAppAppear()`
- **Methods**: `user.reload()` + `getIDToken(forcingRefresh: true)`

### **3. User Deletion Detection**
```swift
catch let error as NSError {
    if error.domain == "FIRAuthErrorDomain",
       let authErrorCode = AuthErrorCode(rawValue: error.code) {
        
        switch authErrorCode {
        case .userNotFound, .userDisabled, .userTokenExpired:
            handleUserDeleted()  // Force sign out + cleanup
        }
    }
}
```

### **4. Automatic Cleanup**
- When user deleted → Remove Firestore document
- Clear local state (currentUser, UserDefaults)
- Sign out from Firebase Auth & Google Sign-In

---

## 🛡️ Error Handling

| Error Type | Action | Reason |
|------------|--------|--------|
| User Cancellation | Silent (no error) | User intentionally cancelled |
| Network Error | Keep cached state | Don't force logout |
| User Not Found | Force logout | User deleted/disabled |
| Token Expired | Force logout | Security issue |
| Invalid Token | Force logout | Security issue |

---

## 🎯 Technical Decisions

| Decision | Why |
|----------|-----|
| **Async/Await** | Cleaner code, better error handling, native Swift concurrency |
| **@Published Properties** | Automatic UI updates, reactive binding, SwiftUI integration |
| **@MainActor on ViewModel** | UI updates on main thread, prevent race conditions |
| **Dual Storage (Auth + Firestore)** | Auth doesn't support queries, need Firestore for chat list |
| **Auth State Listener** | Real-time sync, detect deletions, handle token refresh |
| **UserDefaults Persistence** | Quick initial check, offline fallback (not authoritative) |

---

## 💬 Common Interview Questions & Answers

### **Q: How does authentication work?**
A: User taps "Continue With Google" → Native iOS Google sign-in UI → User selects account → Google ID Token exchanged for Firebase Credential → Firebase Auth signs in → User document saved/updated in Firestore → Auth state listener validates → UI updates reactively.

### **Q: Why store users in both Firebase Auth and Firestore?**
A: Firebase Auth handles authentication and stores minimal data. Firestore allows querying all users (needed for chat list) and storing application-specific profile data. The document ID matches the Firebase Auth UID for consistency.

### **Q: How do you handle user deletion from Firebase Console?**
A: Multi-layer validation: (1) On app launch, `user.reload()` fails if user deleted, (2) Auth state listener detects deletion in real-time, (3) On app foreground, re-validation catches missed cases. When detected, app signs out, clears state, and removes Firestore document.

### **Q: What happens if the network is unavailable?**
A: For validation errors, if it's a network error, we keep the cached state (don't force logout) and retry later. UserDefaults provides a quick initial check, but Firebase validation is authoritative when network is available.

### **Q: Explain the auth state listener.**
A: `addStateDidChangeListener` fires whenever Firebase Auth state changes - sign in, sign out, token refresh, or user deletion. It validates the user with `user.reload()` and updates the app's auth state reactively, keeping UI in sync.

### **Q: How do you handle token expiration?**
A: On app launch and when state changes, we call `user.getIDToken(forcingRefresh: true)` which refreshes the token. If it fails (user deleted/disabled), the auth state listener detects it and signs the user out.

### **Q: What's the difference between Google and Facebook sign-in implementation?**
A: Google uses native iOS SDK (`GIDSignIn.sharedInstance`), while Facebook uses Firebase's `OAuthProvider` for web-based flow (no Facebook SDK needed). Both end up using Firebase Auth and saving to the same Firestore structure.

---

## 🔑 Key Code Snippets

### **1. Sign In with Google**
```swift
let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
let credential = GoogleAuthProvider.credential(
    withIDToken: result.user.idToken.tokenString,
    accessToken: result.user.accessToken.tokenString
)
let authResult = try await Auth.auth().signIn(with: credential)
```

### **2. Save User to Firestore**
```swift
let userRef = db.collection("Users").document(user.uid)
let userModel = UserModel(id: user.uid, name: user.displayName ?? "", ...)
try userRef.setData(from: userModel)
```

### **3. Auth State Listener**
```swift
authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
    Task { @MainActor [weak self] in
        if let user = user {
            try await user.reload()  // Validate user exists
            await self?.loadCurrentUserFromFirestore(userId: user.uid)
        }
    }
}
```

### **4. User Validation**
```swift
try await user.reload()  // Fetch from server
_ = try await user.getIDToken(forcingRefresh: true)  // Validate token
```

### **5. Sign Out**
```swift
try Auth.auth().signOut()
GIDSignIn.sharedInstance.signOut()
saveAuthenticationState(false)  // Clear UserDefaults
```

---

## ✅ Pre-Interview Checklist

- [x] Understand MVVM architecture
- [x] Know why dual storage (Auth + Firestore)
- [x] Explain auth state listener purpose
- [x] Understand user validation flow
- [x] Know error handling strategy
- [x] Understand token refresh mechanism
- [x] Explain user deletion detection
- [x] Understand reactive state management (@Published)
- [x] Know async/await benefits
- [x] Explain UserDefaults vs Firebase Auth state

---

## 🎤 Opening Statement Template

*"I implemented a robust authentication system for a chat app using Firebase Auth with Google and Facebook sign-in. The system follows MVVM architecture with reactive state management using SwiftUI's @Published and @StateObject. Key features include real-time auth state monitoring, multi-layer user validation, and automatic detection of user deletion from Firebase Console. Users are stored in both Firebase Auth for authentication and Firestore for application data, allowing querying for features like the chat list."*

---

**Good luck! 🚀**
