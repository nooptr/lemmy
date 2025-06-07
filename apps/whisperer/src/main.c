#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <stdbool.h>
#include <unistd.h>
#include <CoreFoundation/CoreFoundation.h>

// Forward declarations for keylogger functionality
extern int start_keylogger(void);
extern void stop_keylogger(void);

// Global state
static volatile bool running = true;

// Signal handler for graceful shutdown
void signal_handler(int sig) {
    if (sig == SIGINT || sig == SIGTERM) {
        printf("\n🛑 Shutting down Whisperer...\n");
        running = false;
        stop_keylogger();
        CFRunLoopStop(CFRunLoopGetCurrent());
    }
}

int main(int argc, char *argv[]) {
    printf("🎤 Starting Whisperer...\n");
    
    // Set up signal handlers
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    // Start the keylogger
    if (start_keylogger() != 0) {
        fprintf(stderr, "ERROR: Failed to start keylogger\n");
        return 1;
    }
    
    printf("✅ Whisperer ready! Press and hold FN key to record.\n");
    
    // Run the Core Foundation event loop to process key events
    CFRunLoopRun();
    
    printf("👋 Whisperer stopped.\n");
    return 0;
}