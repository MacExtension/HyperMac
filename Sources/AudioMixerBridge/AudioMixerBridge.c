#include "AudioMixerBridge.h"
#include <stdatomic.h>
#include <math.h>
#include <stdlib.h>

struct HyperMacMixerState {
    _Atomic float gain;
};

HyperMacMixerState *HyperMacMixerCreate(void) {
    HyperMacMixerState *state = calloc(1, sizeof(HyperMacMixerState));
    if (state) atomic_store(&state->gain, 1.0f);
    return state;
}

void HyperMacMixerSetGain(HyperMacMixerState *state, float gain) {
    if (state) atomic_store(&state->gain, fmaxf(0.0f, fminf(2.0f, gain)));
}

static inline float scaled(float sample, float gain) {
    if (!isfinite(sample)) return 0.0f;
    if (gain <= 1.0f) return sample * gain;
    // Match unity at full scale, with a smooth ceiling for boosted peaks.
    return fmaxf(-1.0f, fminf(1.0f, tanhf(sample * gain) / tanhf(gain)));
}

void HyperMacMixerProcess(HyperMacMixerState *state,
                          const AudioBufferList *input,
                          AudioBufferList *output) {
    if (!state || !input || !output || !input->mNumberBuffers || !output->mNumberBuffers) return;
    float gain = atomic_load(&state->gain);

    // CoreAudio process taps provide stereo Float32. The output may use
    // interleaved or separate channel buffers; unused surround channels stay silent.
    UInt32 inputChannels = input->mNumberBuffers == 1 ? input->mBuffers[0].mNumberChannels : 1;
    if (!inputChannels) return;
    for (UInt32 outIndex = 0; outIndex < output->mNumberBuffers; outIndex++) {
        AudioBuffer *out = &output->mBuffers[outIndex];
        if (!out->mData || !out->mNumberChannels) continue;
        UInt32 frames = out->mDataByteSize / (sizeof(float) * out->mNumberChannels);
        float *dest = (float *)out->mData;
        for (UInt32 frame = 0; frame < frames; frame++) {
            for (UInt32 channel = 0; channel < out->mNumberChannels; channel++) {
                UInt32 sourceChannel = output->mNumberBuffers == 1
                    ? channel : outIndex * out->mNumberChannels + channel;
                float value = 0.0f;
                if (sourceChannel < 2) {
                    UInt32 sourceBuffer = input->mNumberBuffers == 1 ? 0 : sourceChannel;
                    if (sourceBuffer < input->mNumberBuffers) {
                        const AudioBuffer *in = &input->mBuffers[sourceBuffer];
                        UInt32 inChannels = input->mNumberBuffers == 1 ? inputChannels : in->mNumberChannels;
                        UInt32 inFrames = inChannels ? in->mDataByteSize / (sizeof(float) * inChannels) : 0;
                        if (in->mData && frame < inFrames && inChannels) {
                            UInt32 inChannel = input->mNumberBuffers == 1 ? (sourceChannel < inChannels ? sourceChannel : 0) : 0;
                            value = ((const float *)in->mData)[frame * inChannels + inChannel];
                        }
                    }
                }
                dest[frame * out->mNumberChannels + channel] = scaled(value, gain);
            }
        }
    }
}

void HyperMacMixerDestroy(HyperMacMixerState *state) {
    free(state);
}
