# iOS Setup & Installation Guide

Because you are using Windows, building an iOS app natively is not possible without a Mac. Therefore, I have prepared a cloud-based build pipeline and a sideloading strategy.

## Step 1: Upload to GitHub to Build the IPA
1. Create a **new, empty repository** on your GitHub account.
2. Upload the entire `ios_app_flutter` folder (the one containing this README) into the repository. **Make sure the `.github/workflows/ios.yml` file is strictly included.**
3. Once the files are pushed, go to the **Actions** tab on your GitHub repository.
4. You will see a workflow running named "Build iOS App". Wait for it to complete (usually takes 3-5 minutes).
5. Once completed, scroll to the bottom of the summary page, and download the artifact named **IOS_App**.
6. This artifact is a `.zip` containing your `Runner.ipa` file!

## Step 2: Install and Sign on iPhone
Since you do not have an Apple Developer account, you must sideload the app. The easiest offline tool for Windows is **Sideloadly**.

1. Download and install [Sideloadly](https://sideloadly.io/) and iTunes for Windows (from Apple's website, not the Microsoft Store version).
2. Connect your iPhone to your PC using a USB cable. Make sure to "Trust this computer" if prompted.
3. Open Sideloadly.
4. Drag and drop the `Runner.ipa` file you downloaded into the IPA icon box in Sideloadly.
5. Enter your Apple ID email in the field.
6. Click **Start**. Sideloadly will ask for your Apple ID password (this is sent directly to Apple to generate a free 7-day developer certificate).
7. Once Sideloadly says "Done", the app will be on your iPhone's home screen!

## Step 3: Trust the App on iPhone
Before opening the app on your phone:
1. Go to **Settings** > **General** > **VPN & Device Management**.
2. Tap on your Apple ID email under "Developer App".
3. Tap **Trust "your_email@apple.com"**.
4. You may now launch the DECODERS app!

> Note: Free Apple ID offline certificates expire every 7 days. You will need to plug your phone back into your PC and hit "Start" on Sideloadly again every 7 days to refresh the app if you are using it continuously.
