#pragma once

#include <cmath>

/**
 * EchoelPoint3D - 3D Point for Spatial Positioning
 *
 * JUCE doesn't have a built-in Point3D template, so we create our own.
 * This is used throughout the Quantum architecture for spatial positioning.
 */
template<typename ValueType>
struct EchoelPoint3D
{
    ValueType x, y, z;

    // Constructors
    EchoelPoint3D() : x(0), y(0), z(0) {}
    EchoelPoint3D(ValueType x_, ValueType y_, ValueType z_) : x(x_), y(y_), z(z_) {}

    // Copy constructor
    EchoelPoint3D(const EchoelPoint3D& other) : x(other.x), y(other.y), z(other.z) {}

    // Assignment
    EchoelPoint3D& operator=(const EchoelPoint3D& other)
    {
        x = other.x;
        y = other.y;
        z = other.z;
        return *this;
    }

    // Arithmetic operators
    EchoelPoint3D operator+(const EchoelPoint3D& other) const
    {
        return EchoelPoint3D(x + other.x, y + other.y, z + other.z);
    }

    EchoelPoint3D operator-(const EchoelPoint3D& other) const
    {
        return EchoelPoint3D(x - other.x, y - other.y, z - other.z);
    }

    EchoelPoint3D operator*(ValueType scalar) const
    {
        return EchoelPoint3D(x * scalar, y * scalar, z * scalar);
    }

    EchoelPoint3D operator/(ValueType scalar) const
    {
        return EchoelPoint3D(x / scalar, y / scalar, z / scalar);
    }

    // Compound assignment
    EchoelPoint3D& operator+=(const EchoelPoint3D& other)
    {
        x += other.x;
        y += other.y;
        z += other.z;
        return *this;
    }

    EchoelPoint3D& operator-=(const EchoelPoint3D& other)
    {
        x -= other.x;
        y -= other.y;
        z -= other.z;
        return *this;
    }

    // Comparison
    bool operator==(const EchoelPoint3D& other) const
    {
        return x == other.x && y == other.y && z == other.z;
    }

    bool operator!=(const EchoelPoint3D& other) const
    {
        return !(*this == other);
    }

    // Distance calculations
    ValueType distanceTo(const EchoelPoint3D& other) const
    {
        ValueType dx = other.x - x;
        ValueType dy = other.y - y;
        ValueType dz = other.z - z;
        return std::sqrt(dx * dx + dy * dy + dz * dz);
    }

    ValueType distanceFromOrigin() const
    {
        return std::sqrt(x * x + y * y + z * z);
    }

    // Magnitude (length) of vector
    ValueType magnitude() const
    {
        return distanceFromOrigin();
    }

    // Normalize (unit vector)
    EchoelPoint3D normalized() const
    {
        ValueType mag = magnitude();
        if (mag > 0)
            return EchoelPoint3D(x / mag, y / mag, z / mag);
        return EchoelPoint3D();
    }

    // Dot product
    ValueType dot(const EchoelPoint3D& other) const
    {
        return x * other.x + y * other.y + z * other.z;
    }

    // Cross product
    EchoelPoint3D cross(const EchoelPoint3D& other) const
    {
        return EchoelPoint3D(
            y * other.z - z * other.y,
            z * other.x - x * other.z,
            x * other.y - y * other.x
        );
    }

    // Interpolation
    EchoelPoint3D interpolate(const EchoelPoint3D& other, ValueType amount) const
    {
        return EchoelPoint3D(
            x + (other.x - x) * amount,
            y + (other.y - y) * amount,
            z + (other.z - z) * amount
        );
    }

    // String representation
    juce::String toString() const
    {
        return juce::String("(") + juce::String(x) + ", " + juce::String(y) + ", " + juce::String(z) + ")";
    }
};

// Common type aliases
using EchoelPoint3Df = EchoelPoint3D<float>;
using EchoelPoint3Dd = EchoelPoint3D<double>;
using EchoelPoint3Di = EchoelPoint3D<int>;
