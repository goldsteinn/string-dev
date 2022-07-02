	add
	/* Amount to shift __x86_shared_non_temporal_threshold by for
	   bound for memcpy_large_4x. This is essentially use to to
	   indicate that the copy is far beyond the scope of L3
	   (assuming no user config x86_non_temporal_threshold) and to
	   use a more aggressively unrolled loop.  NB: before
	   increasing the value also update initialization of
	   x86_non_temporal_threshold.  */
	/* r11 has __x86_shared_non_temporal_threshold.  Shift it left
	   by LOG_4X_MEMCPY_THRESH to get L(large_memcpy_4x) threshold.
	 */
