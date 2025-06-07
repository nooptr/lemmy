#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#include "audio.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Audio configurations
const AudioConfig WHISPER_AUDIO_CONFIG = {
    .sample_rate = 16000,
    .channels = 1,
    .bits_per_sample = 16
};

const AudioConfig HIGH_QUALITY_AUDIO_CONFIG = {
    .sample_rate = 44100,
    .channels = 2,
    .bits_per_sample = 16
};

// Internal AudioRecorder structure
struct AudioRecorder {
    AudioConfig config;
    AVAudioEngine* engine;
    AVAudioInputNode* inputNode;
    AVAudioFile* audioFile;
    NSURL* fileURL;
    
    // For buffer recording
    NSMutableData* audioBuffer;
    float* audioData;
    size_t audioDataSize;
    
    bool isRecording;
    NSDate* startTime;
};

AudioRecorder* audio_recorder_create(const AudioConfig* config) {
    AudioRecorder* recorder = calloc(1, sizeof(AudioRecorder));
    if (!recorder) return NULL;
    
    recorder->config = *config;
    recorder->engine = [[AVAudioEngine alloc] init];
    recorder->inputNode = [recorder->engine inputNode];
    recorder->audioBuffer = [[NSMutableData alloc] init];
    
    return recorder;
}

int audio_recorder_start_file(AudioRecorder* recorder, const char* filename) {
    if (!recorder || recorder->isRecording) return -1;
    
    @try {
        // Create file URL
        NSString* nsFilename = [NSString stringWithUTF8String:filename];
        recorder->fileURL = [NSURL fileURLWithPath:nsFilename];
        
        // Get the input format from the input node
        AVAudioFormat* inputFormat = [recorder->inputNode outputFormatForBus:0];
        
        // Use the input format for the file to avoid conversion issues
        NSError* error = nil;
        recorder->audioFile = [[AVAudioFile alloc] 
            initForWriting:recorder->fileURL
            settings:inputFormat.settings
            error:&error];
        
        if (error) {
            NSLog(@"Failed to create audio file: %@", error.localizedDescription);
            return -1;
        }
        
        // Install tap on input node using the input format
        [recorder->inputNode installTapOnBus:0 
            bufferSize:1024 
            format:inputFormat
            block:^(AVAudioPCMBuffer* buffer, AVAudioTime* when) {
                NSError* writeError = nil;
                [recorder->audioFile writeFromBuffer:buffer error:&writeError];
                if (writeError) {
                    NSLog(@"Error writing audio: %@", writeError.localizedDescription);
                }
            }];
        
        // Start the engine
        [recorder->engine startAndReturnError:&error];
        if (error) {
            NSLog(@"Failed to start audio engine: %@", error.localizedDescription);
            return -1;
        }
        
        recorder->isRecording = true;
        recorder->startTime = [NSDate now];
        
        return 0;
    }
    @catch (NSException* exception) {
        NSLog(@"Exception starting recording: %@", exception.reason);
        return -1;
    }
}

int audio_recorder_start_buffer(AudioRecorder* recorder) {
    if (!recorder || recorder->isRecording) return -1;
    
    @try {
        // Clear previous buffer data
        [recorder->audioBuffer setLength:0];
        if (recorder->audioData) {
            free(recorder->audioData);
            recorder->audioData = NULL;
            recorder->audioDataSize = 0;
        }
        
        // Set up audio format
        AVAudioFormat* format = [[AVAudioFormat alloc] 
            initWithCommonFormat:AVAudioPCMFormatFloat32
            sampleRate:recorder->config.sample_rate
            channels:recorder->config.channels
            interleaved:NO];
        
        if (!format) {
            NSLog(@"Failed to create audio format");
            return -1;
        }
        
        // Install tap on input node to capture to buffer
        [recorder->inputNode installTapOnBus:0 
            bufferSize:1024 
            format:format 
            block:^(AVAudioPCMBuffer* buffer, AVAudioTime* when) {
                // Convert to float data and append to buffer
                float* channelData = buffer.floatChannelData[0];
                NSUInteger frameCount = buffer.frameLength;
                [recorder->audioBuffer appendBytes:channelData 
                    length:frameCount * sizeof(float)];
            }];
        
        // Start the engine
        NSError* error = nil;
        [recorder->engine startAndReturnError:&error];
        if (error) {
            NSLog(@"Failed to start audio engine: %@", error.localizedDescription);
            return -1;
        }
        
        recorder->isRecording = true;
        recorder->startTime = [NSDate now];
        
        return 0;
    }
    @catch (NSException* exception) {
        NSLog(@"Exception starting buffer recording: %@", exception.reason);
        return -1;
    }
}

int audio_recorder_stop(AudioRecorder* recorder) {
    if (!recorder || !recorder->isRecording) return -1;
    
    @try {
        // Stop the engine
        [recorder->engine stop];
        
        // Remove tap
        [recorder->inputNode removeTapOnBus:0];
        
        // Close audio file if recording to file
        if (recorder->audioFile) {
            recorder->audioFile = nil;
        }
        
        // Convert buffer data to float array for easy access
        if (recorder->audioBuffer.length > 0) {
            recorder->audioDataSize = recorder->audioBuffer.length / sizeof(float);
            recorder->audioData = malloc(recorder->audioBuffer.length);
            if (recorder->audioData) {
                memcpy(recorder->audioData, recorder->audioBuffer.bytes, recorder->audioBuffer.length);
            }
        }
        
        recorder->isRecording = false;
        
        return 0;
    }
    @catch (NSException* exception) {
        NSLog(@"Exception stopping recording: %@", exception.reason);
        return -1;
    }
}

const float* audio_recorder_get_data(AudioRecorder* recorder, size_t* out_size) {
    if (!recorder || !out_size) return NULL;
    
    *out_size = recorder->audioDataSize;
    return recorder->audioData;
}

double audio_recorder_get_duration(AudioRecorder* recorder) {
    if (!recorder || !recorder->startTime) return 0.0;
    
    if (recorder->isRecording) {
        return [[NSDate now] timeIntervalSinceDate:recorder->startTime];
    } else {
        // Calculate duration from audio data
        if (recorder->audioDataSize > 0) {
            return (double)recorder->audioDataSize / recorder->config.sample_rate;
        }
    }
    
    return 0.0;
}

bool audio_recorder_is_recording(AudioRecorder* recorder) {
    return recorder ? recorder->isRecording : false;
}

void audio_recorder_destroy(AudioRecorder* recorder) {
    if (!recorder) return;
    
    if (recorder->isRecording) {
        audio_recorder_stop(recorder);
    }
    
    if (recorder->audioData) {
        free(recorder->audioData);
    }
    
    recorder->engine = nil;
    recorder->inputNode = nil;
    recorder->audioFile = nil;
    recorder->fileURL = nil;
    recorder->audioBuffer = nil;
    recorder->startTime = nil;
    
    free(recorder);
}

int audio_request_permissions(void) {
    @try {
        __block int result = -1;
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio 
            completionHandler:^(BOOL granted) {
                result = granted ? 0 : -1;
                dispatch_semaphore_signal(semaphore);
            }];
        
        // Wait for permission response (timeout after 5 seconds)
        dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC);
        if (dispatch_semaphore_wait(semaphore, timeout) != 0) {
            NSLog(@"Timeout waiting for audio permission");
            return -1;
        }
        
        return result;
    }
    @catch (NSException* exception) {
        NSLog(@"Exception requesting audio permissions: %@", exception.reason);
        return -1;
    }
}