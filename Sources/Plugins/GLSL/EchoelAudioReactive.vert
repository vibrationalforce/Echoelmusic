/*
 *  EchoelAudioReactive.vert
 *  Echoelmusic — GLSL Vertex Shader
 *
 *  Created: February 2026
 *  Fullscreen quad vertex shader for audio-reactive visual effects.
 *  Compatible: OpenGL 3.3+ / OpenGL ES 3.0+ / WebGL 2.0
 */

#version 330 core

layout(location = 0) in vec2 a_position;   /* -1 to 1 quad vertices */
layout(location = 1) in vec2 a_texCoord;   /* 0 to 1 texture coordinates */

out vec2 v_texCoord;

/* Audio-reactive vertex displacement (optional) */
uniform float u_audioRMS;
uniform float u_audioBass;
uniform float u_time;
uniform bool  u_enableDisplacement;

void main() {
    v_texCoord = a_texCoord;

    vec2 pos = a_position;

    /* Optional: audio-reactive vertex wobble for psychedelic effect */
    if (u_enableDisplacement) {
        float wobble = sin(pos.x * 3.14159 * 4.0 + u_time * 2.0) * u_audioBass * 0.02;
        pos.y += wobble;
        float swell = u_audioRMS * 0.01;
        pos *= 1.0 + swell;
    }

    gl_Position = vec4(pos, 0.0, 1.0);
}
