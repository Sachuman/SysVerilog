
#include <cmath>
#include <cstdint>
#include <cstring>
#include <random>
#include <limits>

typedef int float_pkg_float_t;

float round_float32_to_float64(double in) {
    return static_cast<float>(in); // round ties to even
}

extern "C" {

double float2real(float_pkg_float_t in) {
    float f;
    std::memcpy(&f, &in, sizeof(f));
    return static_cast<double>(f);
}

float_pkg_float_t real2float(double in) {
    float f = round_float32_to_float64(in);
    float_pkg_float_t out;
    std::memcpy(&out, &f, sizeof(out));
    return out;
}

}
