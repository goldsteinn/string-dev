
#include <immintrin.h>
__m128i do_x(__m128i a, __m128i b) {
    return _mm_alignr_epi8(a, b, 1);

}
