# Ouro - Publishing Guide for Google Play Store

## ✅ Changes Completed

- [x] App name changed to "Ouro" in AndroidManifest.xml
- [x] Application ID updated to `com.antigravity.ouro`
- [x] Launcher icon configured with `logo-with-bg.png`
- [x] Home screen logo updated to `logo-no-bg.png`
- [x] Signing configuration added to build.gradle.kts
- [x] .gitignore updated to protect keystore files

---

## 📋 Step-by-Step Commands to Sign and Build Your App

### **Step 1: Generate the Launcher Icons**

First, generate your app icons using the new logo:

```powershell
flutter pub get
flutter pub run flutter_launcher_icons
```

This will create all the necessary launcher icons for Android using `logo-with-bg.png`.

---

### **Step 2: Create Your Keystore File** ⚠️ CRITICAL STEP

Run this command to generate your keystore (this is a ONE-TIME setup):

**Note:** Since `keytool` is not in your PATH, use the full path:

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v -keystore upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

If the above path doesn't work, keytool is located in your Java installation that comes with Android Studio.

**You will be asked to enter:**
1. **Keystore password** - CREATE A STRONG PASSWORD AND SAVE IT! You'll need this forever.
2. **Re-enter keystore password** - Confirm it
3. **Your name** - Your full name or company name
4. **Organizational unit** - Can be your app name or leave blank
5. **Organization** - Your company/studio name or leave blank
6. **City** - Your city
7. **State/Province** - Your state
8. **Country code** - Two-letter country code (e.g., US, IN, GB)
9. **Confirm** - Type "yes"
10. **Key password** - Press ENTER to use the same password as keystore, OR create a different one

**⚠️ CRITICAL WARNINGS:**
- **NEVER lose this keystore file or forget the passwords!**
- If you lose it, you can NEVER update your app on Play Store (you'd have to publish a completely new app)
- Keep a secure backup of `upload-keystore.jks` and the passwords
- NEVER commit this file to git (already protected in .gitignore)

---

### **Step 3: Create key.properties File**

Create a file at `android/key.properties` with the following content:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=../upload-keystore.jks
```

**Replace:**
- `YOUR_KEYSTORE_PASSWORD` - The keystore password you created in Step 2
- `YOUR_KEY_PASSWORD` - The key password (usually the same as keystore password)

**Example:**
```properties
storePassword=MySecurePass123!
keyPassword=MySecurePass123!
keyAlias=upload
storeFile=../upload-keystore.jks
```

⚠️ This file is already protected by .gitignore - never commit it!

---

### **Step 4: Build the Release AAB**

Now you're ready to build the signed app bundle:

```powershell
flutter clean
flutter pub get
flutter build appbundle --release
```

**What this does:**
- `flutter clean` - Removes old build artifacts
- `flutter pub get` - Gets all dependencies
- `flutter build appbundle --release` - Builds a signed AAB file

**Build time:** This may take 5-10 minutes depending on your computer.

---

### **Step 5: Locate Your AAB File**

After the build completes, your signed AAB file will be at:

```
build\app\outputs\bundle\release\app-release.aab
```

**This is the file you'll upload to Google Play Store!**

---

### **Step 6 (Optional): Build a Signed APK for Testing**

If you want to test the release version before uploading:

```powershell
flutter build apk --release
```

The APK will be at: `build\app\outputs\flutter-apk\app-release.apk`

You can install this on your Android device to test:

```powershell
flutter install --release
```

Or manually transfer the APK to your phone and install it.

---

## 🎮 Upload to Google Play Store

### **Before You Upload - Checklist:**

- [ ] AAB file built successfully
- [ ] Tested the release APK on a real device
- [ ] Keystore file backed up securely
- [ ] key.properties NOT committed to git
- [ ] Screenshots ready (minimum 2 phone screenshots)
- [ ] App icon looks good
- [ ] Privacy policy URL ready (required since app uses INTERNET permission)

### **Upload Steps:**

1. Go to [Google Play Console](https://play.google.com/console)
2. Click **"Create app"**
3. Fill in:
   - **App name:** Ouro
   - **Default language:** Your language
   - **App or game:** Game
   - **Free or paid:** Free (or Paid)
4. Accept declarations and click **"Create app"**

### **Set Up Your App:**

1. **App content:**
   - Privacy policy (required)
   - App access (if any restrictions)
   - Ads (does your app contain ads?)
   - Content rating (complete questionnaire)
   - Target audience (age groups)
   - News app (No)
   - COVID-19 contact tracing (No)
   - Data safety (what data you collect)

2. **Store listing:**
   - **App name:** Ouro
   - **Short description:** (80 characters max) - e.g., "Classic snake game with modern design"
   - **Full description:** (4000 characters max) - Describe your game, features, gameplay
   - **App icon:** 512x512 PNG (you can export from your logo)
   - **Feature graphic:** 1024x500 PNG banner
   - **Screenshots:** At least 2 phone screenshots (JPEG or PNG)
   - **Category:** Games > Casual or Puzzle
   - **Contact details:** Email, website (optional), phone (optional)

3. **Production release:**
   - Click **"Create new release"**
   - Upload your `app-release.aab` file
   - **Release name:** 1.0.0 (or your version)
   - **Release notes:** Describe what's new (e.g., "Initial release")
   - Click **"Review release"**
   - Click **"Start rollout to Production"**

### **Review Process:**

- Google will review your app (usually takes 1-3 days)
- You'll get an email when it's approved or if there are issues
- Once approved, your app will be live on the Play Store!

---

## 🔄 Future Updates

When you want to release an update:

### **1. Update Version Number**

Edit `pubspec.yaml`:

```yaml
version: 1.0.1+2  # Increment version name and build number
```

Format: `versionName+buildNumber`
- `1.0.1` - User-facing version (increment for updates)
- `+2` - Build number (must always increase)

### **2. Rebuild and Upload**

```powershell
flutter clean
flutter build appbundle --release
```

Upload the new AAB to Google Play Console under **"Production"** > **"Create new release"**.

---

## 🆘 Troubleshooting

### **Build fails with signing error:**
- Check that `key.properties` exists at `android/key.properties`
- Verify the passwords are correct
- Make sure `upload-keystore.jks` exists in project root

### **"Key alias not found" error:**
- Make sure `keyAlias=upload` in key.properties
- Verify you used `-alias upload` when creating the keystore

### **App crashes on release but works in debug:**
- Test with `flutter run --release` before building AAB
- Check for any debug-only code or assets

### **Upload rejected:**
- Make sure you've completed all Play Console requirements
- Check that content rating is complete
- Verify privacy policy is provided
- Ensure target SDK is up to date

---

## 📱 App Details

- **App Name:** Ouro
- **Package Name:** com.antigravity.ouro
- **Version:** 1.0.0+1
- **Launcher Icon:** logo-with-bg.png
- **Home Screen Logo:** logo-no-bg.png

---

## 🔐 Security Reminders

**Files to NEVER commit to git:**
- ✅ `upload-keystore.jks` (protected by .gitignore)
- ✅ `android/key.properties` (protected by .gitignore)
- ✅ Any `.keystore` or `.jks` files (protected by .gitignore)

**Files you MUST backup securely:**
- 💾 `upload-keystore.jks`
- 💾 Your keystore passwords (use a password manager!)

---

Good luck with your Play Store launch! 🚀
