# Firebase Login Troubleshooting Guide

## Most Common Issue: Email/Password Not Enabled (Error 17026)

**This is the #1 reason Firebase login fails!**

### Fix: Enable Email/Password Authentication

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **faith-journal-d2a32**
3. Navigate to **Authentication** → **Sign-in method**
4. Find **Email/Password** in the list
5. Click on it
6. **Enable** the toggle
7. Click **Save**

**This is required for email/password login to work!**

---

## Other Common Issues

### 1. User Doesn't Exist (Error 17011)
**Error:** "No account found with this email"

**Fix:**
- Use **"Sign Up"** to create an account first
- The "Sign In" button only works for existing accounts

### 2. Wrong Password (Error 17009)
**Error:** "Incorrect password"

**Fix:**
- Check your password
- Use **"Forgot Password?"** to reset it

### 3. Network Error (Error 17020)
**Error:** "Network error"

**Fix:**
- Check your internet connection
- Try again in a few moments

### 4. Firebase Not Configured
**Error:** "Firebase not configured. Please check app setup."

**Fix:**
- Verify `GoogleService-Info.plist` exists in the project
- Check that Firebase is initializing (see logs)

---

## How to Check Error Details

1. **In Xcode:**
   - Open the Debug Console (⇧⌘Y)
   - Look for lines starting with "❌ [FIREBASE AUTH]"
   - The error code will tell you what's wrong

2. **Error Codes:**
   - **17008**: Invalid email format
   - **17009**: Wrong password
   - **17011**: User not found (sign up first!)
   - **17020**: Network error
   - **17026**: Email/Password not enabled ⚠️ **MOST COMMON**
   - **17007**: Email already in use (use sign in instead)

---

## Quick Checklist

- [ ] Email/Password authentication enabled in Firebase Console
- [ ] User account exists (or sign up first)
- [ ] Correct email and password
- [ ] Internet connection working
- [ ] Firebase properly configured

---

## Need Help?

1. Check the Xcode console for detailed error messages
2. Look for the error code in the logs
3. Enable Email/Password in Firebase Console (most likely fix)
4. Make sure you're using "Sign Up" if you don't have an account yet
