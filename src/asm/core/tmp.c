int do_x(int a, int b, int c, int * d) {
    if(a) {
        b = a;
    }

    for(; c; --c) {
        *d += b;
    }
    return __builtin_ctz(b);
}
