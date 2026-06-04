@echo off
set ANDROID_HOME=D:\Android\Sdk
set ANDROID_SDK_ROOT=D:\Android\Sdk
set ANDROID_USER_HOME=D:\Android\.android
set ANDROID_AVD_HOME=D:\Android\.android\avd
set GRADLE_USER_HOME=D:\Android\Gradle\.gradle

cd /d "%~dp0"
flutter run -d edge
