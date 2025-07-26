# Google Drive Integration Setup Guide

## Overview
InstantRec now supports automatic Google Drive synchronization for recorded audio files. This document describes the implementation and setup process.

## Architecture

### Core Components

1. **GoogleDriveService.swift** - Main service for Google Drive operations
   - OAuth 2.0 authentication
   - File upload functionality 
   - Folder management (creates "InstantRec Recordings" folder)

2. **UploadQueue.swift** - Queue management for offline uploads
   - Handles network interruptions
   - Retry logic with exponential backoff
   - Concurrent upload limiting (max 2 simultaneous)

3. **CloudSyncStatus.swift** - Sync state management
   - Status: notSynced, pending, uploading, synced, error
   - UI display properties (icons, colors)

4. **Recording.swift** (extended) - Enhanced with cloud sync properties
   - Cloud sync status tracking
   - Google Drive file metadata storage
   - Error message handling

## Setup Instructions

### 1. Google Cloud Console Configuration

1. Create a new project in [Google Cloud Console](https://console.cloud.google.com/)
2. Enable the Google Drive API
3. Create OAuth 2.0 Client ID credentials:
   - Application type: iOS
   - Bundle ID: `com.yourcompany.instantrec` (replace with your actual bundle ID)
4. Download the configuration JSON file

### 2. Client Configuration

1. Extract the `client_id` from the downloaded JSON file
2. Update `/Sources/instantrec/Resources/GoogleSignInConfiguration.plist`:
   ```xml
   <key>CLIENT_ID</key>
   <string>YOUR_ACTUAL_CLIENT_ID_HERE</string>
   <key>REVERSED_CLIENT_ID</key>
   <string>com.googleusercontent.apps.YOUR_CLIENT_ID_HERE</string>
   ```

### 3. URL Scheme Setup

Add the reversed client ID as a URL scheme in your app's Info.plist:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>GoogleSignIn</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR_CLIENT_ID_HERE</string>
        </array>
    </dict>
</array>
```

## Features

### User Interface
- **Settings Screen**: Google Drive connection status and controls
- **Recording List**: Cloud sync status indicators for each recording
- **Upload Queue**: Real-time upload progress tracking

### Sync Behavior
- **Automatic Upload**: New recordings are automatically queued for upload
- **Offline Support**: Failed uploads are retried when network becomes available
- **Folder Organization**: All recordings are stored in "InstantRec Recordings" folder
- **Metadata Preservation**: Original filenames and creation dates are maintained

### Status Indicators
- 🌐 **Not Synced**: Gray cloud icon (awaiting sync)
- ⏰ **Pending**: Orange clock icon (queued for upload)
- ☁️⬆️ **Uploading**: Blue cloud with arrow (actively uploading)
- ✅☁️ **Synced**: Green cloud with checkmark (successfully synced)
- ❌☁️ **Error**: Red cloud with exclamation (sync failed)

## Security & Privacy

### Permissions
- **Minimal Scope**: Only requests `https://www.googleapis.com/auth/drive.file` scope
- **File Access**: Only accesses files created by the app
- **No Broad Access**: Cannot access other Google Drive files

### Data Handling
- **Local First**: Files are always stored locally first
- **Optional Sync**: Users can opt out of cloud sync entirely
- **Transparent Operations**: All sync operations are logged and visible to users

## Error Handling

### Common Issues
1. **Authentication Expired**: Automatic re-authentication on API calls
2. **Network Failures**: Automatic retry with exponential backoff
3. **Quota Exceeded**: Clear error messaging to user
4. **File Conflicts**: Overwrites with newest version

### Debug Information
- Console logging for all operations
- Error messages preserved in Recording model
- Upload queue status monitoring

## Performance Optimizations

### Upload Strategy
- **Concurrent Limiting**: Maximum 2 simultaneous uploads
- **Background Processing**: Uploads continue when app is backgrounded
- **Smart Queuing**: Failed uploads are retried with increasing delays

### Memory Management
- **Streaming Upload**: Files are uploaded directly from disk
- **Progress Tracking**: Real-time upload progress without memory overhead
- **Queue Persistence**: Upload queue survives app restarts

## Testing

### Test Scenarios
1. **Happy Path**: Normal upload with good network
2. **Network Interruption**: Upload during network loss
3. **Authentication Issues**: Expired tokens and re-auth
4. **Large Files**: Upload behavior with longer recordings
5. **Multiple Files**: Concurrent upload handling

### Debug Commands
```swift
// Check authentication status
GoogleDriveService.shared.checkAuthenticationStatus()

// Force queue processing
UploadQueue.shared.processQueue()

// Retry failed uploads
UploadQueue.shared.retryAll()
```

## Future Enhancements

### Planned Features
1. **Download Sync**: Restore recordings from Google Drive
2. **Selective Sync**: User control over which recordings to sync
3. **Bandwidth Control**: Upload speed limiting for mobile data
4. **Conflict Resolution**: Handle simultaneous edits from multiple devices

### Architecture Improvements
1. **Background App Refresh**: System-scheduled upload retries
2. **CloudKit Integration**: Alternative cloud storage option
3. **Delta Sync**: Only upload changes instead of full files
4. **Compression**: Optional audio compression before upload

## Migration Guide

### From Previous Versions
- Existing recordings will show as "Not Synced"
- Users can manually trigger sync for old recordings
- No data loss during migration

### Data Export
- All recordings remain accessible locally
- Google Drive files can be downloaded independently
- No vendor lock-in concerns