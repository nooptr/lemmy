#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <stdbool.h>
#include <unistd.h>
#include <string.h>
#include <AppKit/AppKit.h>
#include <CoreFoundation/CoreFoundation.h>
#include "audio.h"

#include "transcription.h"

// Forward declarations for keylogger functionality
extern int start_keylogger(void);
extern void stop_keylogger(void);

// Global state
static volatile bool running = true;
static AudioRecorder* recorder = NULL;
static bool whisper_initialized = false;

// Copy text to clipboard
void copy_to_clipboard(const char* text) {
    NSString* nsText = [NSString stringWithUTF8String:text];
    NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard setString:nsText forType:NSPasteboardTypeString];
}

// Paste text by simulating Cmd+V
void paste_text() {
    // Create key events for Cmd+V
    CGEventRef cmdVDown = CGEventCreateKeyboardEvent(NULL, 9, true); // V key down
    CGEventRef cmdVUp = CGEventCreateKeyboardEvent(NULL, 9, false);   // V key up
    
    // Set Command modifier
    CGEventSetFlags(cmdVDown, kCGEventFlagMaskCommand);
    CGEventSetFlags(cmdVUp, kCGEventFlagMaskCommand);
    
    // Post the events
    CGEventPost(kCGHIDEventTap, cmdVDown);
    CGEventPost(kCGHIDEventTap, cmdVUp);
    
    // Clean up
    CFRelease(cmdVDown);
    CFRelease(cmdVUp);
}

// Handle FN key press - start recording
void fn_key_pressed() {
    if (!recorder) return;
    
    if (!audio_recorder_is_recording(recorder)) {
        printf("🔴 Recording...\n");
        if (audio_recorder_start_buffer(recorder) != 0) {
            printf("❌ Failed to start recording\n");
        }
    }
}

// Handle FN key release - stop recording and transcribe
void fn_key_released() {
    if (!recorder || !audio_recorder_is_recording(recorder)) return;
    
    printf("⏹️  Stopping recording...\n");
    if (audio_recorder_stop(recorder) != 0) {
        printf("❌ Failed to stop recording\n");
        return;
    }
    
    // Get the recorded audio data
    size_t data_size;
    const float* audio_data = audio_recorder_get_data(recorder, &data_size);
    double duration = audio_recorder_get_duration(recorder);
    
    printf("🎵 Recorded %.2f seconds (%zu samples)\n", duration, data_size);
    
    if (data_size == 0) {
        printf("❌ No audio data recorded\n");
        return;
    }
    
    if (!whisper_initialized) {
        printf("❌ Whisper not initialized\n");
        return;
    }
    
    // Transcribe the audio
    char result[1024];
    printf("🧠 Transcribing...\n");
    
    if (transcribe_audio(audio_data, (int)data_size, result, sizeof(result)) == 0) {
        if (strlen(result) > 0) {
            // Trim leading/trailing whitespace
            char* start = result;
            while (*start == ' ' || *start == '\t' || *start == '\n') start++;
            
            char* end = start + strlen(start) - 1;
            while (end > start && (*end == ' ' || *end == '\t' || *end == '\n')) end--;
            *(end + 1) = '\0';
            
            if (strlen(start) > 0) {
                printf("📝 \"%s\"\n", start);
                
                // Copy to clipboard and paste
                copy_to_clipboard(start);
                
                // Small delay then paste
                usleep(100000); // 100ms
                paste_text();
                
                printf("✅ Text pasted!\n");
            } else {
                printf("⚠️  Empty transcription\n");
            }
        } else {
            printf("⚠️  No speech detected\n");
        }
    } else {
        printf("❌ Transcription failed\n");
    }
}

// Signal handler for graceful shutdown
void signal_handler(int sig) {
    if (sig == SIGINT || sig == SIGTERM) {
        printf("\n🛑 Shutting down Whisperer...\n");
        running = false;
        stop_keylogger();
        
        if (recorder) {
            audio_recorder_destroy(recorder);
            recorder = NULL;
        }
        
        if (whisper_initialized) {
            transcription_cleanup();
            whisper_initialized = false;
        }
        
        CFRunLoopStop(CFRunLoopGetCurrent());
    }
}

int main(int argc, char *argv[]) {
    printf("🎤 Starting Whisperer...\n");
    
    // Set up signal handlers
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    // Request audio permissions
    printf("🔐 Requesting microphone permissions...\n");
    if (audio_request_permissions() != 0) {
        fprintf(stderr, "❌ Microphone permission denied. Please grant permission in System Preferences.\n");
        return 1;
    }
    printf("✅ Microphone permission granted\n");
    
    // Create audio recorder with Whisper-compatible settings
    recorder = audio_recorder_create(&WHISPER_AUDIO_CONFIG);
    if (!recorder) {
        fprintf(stderr, "❌ Failed to create audio recorder\n");
        return 1;
    }
    printf("✅ Audio recorder initialized\n");
    
    // Initialize Whisper
    printf("🧠 Initializing Whisper model...\n");
    if (transcription_init("whisper.cpp/models/ggml-base.en.bin") == 0) {
        whisper_initialized = true;
        printf("✅ Whisper model loaded\n");
    } else {
        fprintf(stderr, "❌ Failed to load Whisper model\n");
        fprintf(stderr, "   Make sure to run ./build.sh first to download the model\n");
        audio_recorder_destroy(recorder);
        return 1;
    }
    
    // Start the keylogger
    if (start_keylogger() != 0) {
        fprintf(stderr, "❌ Failed to start keylogger\n");
        audio_recorder_destroy(recorder);
        return 1;
    }
    printf("✅ Keylogger started\n");
    
    printf("\n🎤 Whisperer ready! Press and hold FN key to record.\n");
    printf("   Hold FN → speak → release FN → text appears!\n\n");
    
    // Run the Core Foundation event loop to process key events
    CFRunLoopRun();
    
    printf("👋 Whisperer stopped.\n");
    return 0;
}