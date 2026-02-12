# Create Keystore for Ouro App

## Use This Command:

Since `keytool` is not in your PATH, use the full path to the keytool executable:

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v -keystore upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

## What You'll Be Asked:

1. **Enter keystore password:** Create a strong password (e.g., `MySecurePass123!`)
2. **Re-enter new password:** Confirm the password
3. **What is your first and last name?** Your name or company name
4. **What is the name of your organizational unit?** Can leave blank or enter "Development"
5. **What is the name of your organization?** Your company/studio name or leave blank
6. **What is the name of your City or Locality?** Your city
7. **What is the name of your State or Province?** Your state
8. **What is the two-letter country code for this unit?** e.g., US, IN, GB, etc.
9. **Is CN=..., OU=..., correct?** Type `yes`
10. **Enter key password for <upload>:** Press ENTER to use same password as keystore

## After Creating Keystore:

Create the file `android/key.properties` with this content:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=../upload-keystore.jks
```

Replace `YOUR_KEYSTORE_PASSWORD` and `YOUR_KEY_PASSWORD` with the passwords you just created.

## ⚠️ IMPORTANT:

- **NEVER lose the `upload-keystore.jks` file or forget the passwords!**
- Keep a secure backup
- These files are already protected in `.gitignore` - never commit them to git
- If you lose them, you can NEVER update your app on Play Store

## Alternative: Add keytool to PATH (Optional)

If you want to use `keytool` directly in the future, add this to your PATH:

```
C:\Program Files\Android\Android Studio\jbr\bin
```

But for now, just use the full path command above.
