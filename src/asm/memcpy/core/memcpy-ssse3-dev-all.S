// abf-off
/**********************************************************************
 *	lower-bound                     :0
 *	upper-bound                     :64
 *	unbounded                       :1
 *
 *	kstore_mult                     :1.1
 *	kub_num_align_movs              :1.0
 *	kwith_hoisted_movs              :1.0
 *	kwith_splitting                 :0.0
 *	kwith_branch_history            :0.0
 *	kwith_evex                      :1.0
 *	kbranch_miss_cost               :250.0
 *	kbaclear_cost                   :100.0
 *	kearly_clear_cost               :31.2
 *	kbht_interference_mul           :0.1
 *	kbtb_interference_mul           :0.1
 *	kbtb_packed_interference_mul    :0.8
 *	khoist_before_branch_mul        :0.5
 **********************************************************************/
// abf-on

#include "../libc-asm-common.h"


	// Range       : [0, 18446744073709551615]
	// % Of Calls  : 100.0
	// branch      : T = 24.2, NT = 75.8
	cmpq	$32, %rdx
	ja	L(LB33_UBinf)

	// Range       : [0, 32]
	// % Of Calls  : 75.8
	// branch      : T = 22.75, NT = 77.25
	cmpl	$16, %edx
	ja	L(LB17_UB32)

	// Range       : [0, 16]
	// % Of Calls  : 58.56
	// branch      : T = 28.53, NT = 71.47
	cmpl	$8, %edx
	jb	L(LB0_UB7)

	// Range       : [8, 16]
	// % Of Calls  : 41.85
	// copy        :
	movq	0(%rsi), %rcx
	movq	-8(%rsi, %rdx), %rsi
	movq	%rcx, 0(%rdi)
	movq	%rsi, -8(%rdi, %rdx)
	ret

	// Range       : [17, 32]
	// % Of Calls  : 17.24
	// copy        :
	.p2align 4
L(LB17_UB32):
	movups	0(%rsi), %xmm0
	movups	-16(%rsi, %rdx), %xmm1
	movups	%xmm0, 0(%rdi)
	movups	%xmm1, -16(%rdi, %rdx)
	ret


	// Range       : [0, 7]
	// % Of Calls  : 16.7
	// branch      : T = 35.95, NT = 64.05
	.p2align 4
L(LB0_UB7):
	cmpl	$4, %edx
	jae	L(LB4_UB7)

	// Range       : [0, 3]
	// % Of Calls  : 10.7
	// branch      : T = 26.51, NT = 73.49
	cmpl	$0, %edx
	jbe	L(LB0_UB0)

	// Range       : [1, 3]
	// % Of Calls  : 7.86
	// branch      : T = 11.85, NT = 88.15
	movzbl	0(%rsi), %ecx
	cmpl	$2, %edx
	ja	L(LB3_UB3_H1_1)

	// Range       : [1, 2]
	// % Of Calls  : 6.93
	// copy        :
	movzbl	-1(%rsi, %rdx), %esi
	movb	%cl, 0(%rdi)
	movb	%sil, -1(%rdi, %rdx)

	// Range       : [0, 0]
	// % Of Calls  : 2.84
	// copy        :
L(LB0_UB0):
	ret



	// Range       : [33, 64]
	// % Of Calls  : 9.48
	// copy        :
	.p2align 4
L(LB33_UB64_H1_16):
	movups	-64(%rsi, %rdx), %xmm1
	movups	-32(%rsi, %rdx), %xmm2
	movups	%xmm0, 0(%rdi)
	movups	%xmm1, -64(%rdi, %rdx)
	movups	%xmm2, -32(%rdi, %rdx)
	VZEROUPPER_RETURN



	// Range       : [4, 7]
	// % Of Calls  : 6.01
	// copy        :
	.p2align 4
L(LB4_UB7):
	movl	0(%rsi), %ecx
	movl	-4(%rsi, %rdx), %esi
	movl	%ecx, 0(%rdi)
	movl	%esi, -4(%rdi, %rdx)
	ret



	// Range       : [3, 3]
	// % Of Calls  : 0.93
	// copy        :
	.p2align 4
L(LB3_UB3_H1_1):
	movzwl	1(%rsi), %esi
	movb	%cl, 0(%rdi)
	movw	%si, 1(%rdi)
	ret



	// Range       : [33, 18446744073709551615]
	// % Of Calls  : 24.2
	// branch      : T = 39.16, NT = 60.84
	.p2align 4
L(LB33_UBinf):
	movups	0(%rsi), %xmm0
	cmpq	$65, %rdx
	jb	L(LB33_UB64_H1_16)



// abf-off
/**********************************************************************
 *	{Range     : [   0,  inf]                    }
 *	{Calls %   : 100.00                          }
 *	{Path Cost : 0.00        -- (0.00)           }
 *	{BB Cost   : 182.69      -- (19.24)          }
 *	{Hoisted   : []          -- []               }
 *	{Branch    : size GT 32  -- (24.2 T/75.8 NT) }
 *	|
 *	|   {Range     : [   0,   32]                    }
 *	|   {Calls %   : 75.80                           }
 *	|   {Path Cost : 104.70      -- (11.02)          }
 *	|   {BB Cost   : 134.40      -- (14.15)          }
 *	|   {Hoisted   : []          -- []               }
 *	|   {Branch    : size GT 16  -- (22.7 T/77.3 NT) }
 *	|   |
 *	|   |   {Range     : [   0,   16]                    }
 *	|   |   {Calls %   : 58.56                           }
 *	|   |   {Path Cost : 182.92      -- (19.26)          }
 *	|   |   {BB Cost   : 115.54      -- (12.17)          }
 *	|   |   {Hoisted   : []          -- []               }
 *	|   |   {Branch    : size LT 8   -- (28.5 T/71.5 NT) }
 *	|   |   |
 *	|   |   |   {Range     : [   8,   16]                    }
 *	|   |   |   {Calls %   : 41.85                           }
 *	|   |   |   {Path Cost : 246.39      -- (25.94)          }
 *	|   |   |   {BB Cost   : 73.24       -- (7.71)           }
 *	|   |   |   {Hoisted   : []          -- []               }
 *	|   |   |   {Copy      : True                            }
 *	|   |   |
 *	|   |   |   {Range     : [   0,    7]                    }
 *	|   |   |   {Calls %   : 16.70                           }
 *	|   |   |   {Path Cost : 234.99      -- (24.74)          }
 *	|   |   |   {BB Cost   : 36.34       -- (3.83)           }
 *	|   |   |   {Hoisted   : []          -- []               }
 *	|   |   |   {Branch    : size GE 4   -- (36.0 T/64.0 NT) }
 *	|   |   |   |
 *	|   |   |   |   {Range     : [   0,    3]                    }
 *	|   |   |   |   {Calls %   : 10.70                           }
 *	|   |   |   |   {Path Cost : 253.70      -- (26.71)          }
 *	|   |   |   |   {BB Cost   : 20.41       -- (2.15)           }
 *	|   |   |   |   {Hoisted   : []          -- []               }
 *	|   |   |   |   {Branch    : size LE 0   -- (26.5 T/73.5 NT) }
 *	|   |   |   |   |
 *	|   |   |   |   |   {Range     : [   1,    3]                    }
 *	|   |   |   |   |   {Calls %   : 7.86                            }
 *	|   |   |   |   |   {Path Cost : 265.13      -- (27.92)          }
 *	|   |   |   |   |   {BB Cost   : 9.39        -- (0.99)           }
 *	|   |   |   |   |   {Hoisted   : []          -- [ 1(1) ]         }
 *	|   |   |   |   |   {Branch    : size GT 2   -- (11.8 T/88.2 NT) }
 *	|   |   |   |   |   |
 *	|   |   |   |   |   |   {Range     : [   1,    2]                    }
 *	|   |   |   |   |   |   {Calls %   : 6.93                            }
 *	|   |   |   |   |   |   {Path Cost : 271.33      -- (28.57)          }
 *	|   |   |   |   |   |   {BB Cost   : 6.45        -- (0.68)           }
 *	|   |   |   |   |   |   {Hoisted   : [ 1(1) ]    -- []               }
 *	|   |   |   |   |   |   {Copy      : True                            }
 *	|   |   |   |   |   |
 *	|   |   |   |   |   |   {Range     : [   3,    3]                    }
 *	|   |   |   |   |   |   {Calls %   : 0.93                            }
 *	|   |   |   |   |   |   {Path Cost : 268.32      -- (28.25)          }
 *	|   |   |   |   |   |   {BB Cost   : 0.91        -- (0.10)           }
 *	|   |   |   |   |   |   {Hoisted   : [ 1(1) ]    -- []               }
 *	|   |   |   |   |   |   {Copy      : True                            }
 *	|   |   |   |   |   |
 *	|   |   |   |   |   {Range     : [   0,    0]                    }
 *	|   |   |   |   |   {Calls %   : 2.84                            }
 *	|   |   |   |   |   {Path Cost : 262.68      -- (27.66)          }
 *	|   |   |   |   |   {BB Cost   : 0.00        -- (0.00)           }
 *	|   |   |   |   |   {Hoisted   : []          -- []               }
 *	|   |   |   |   |   {Copy      : True                            }
 *	|   |   |   |   |
 *	|   |   |   |   {Range     : [   4,    7]                    }
 *	|   |   |   |   {Calls %   : 6.01                            }
 *	|   |   |   |   {Path Cost : 252.63      -- (26.60)          }
 *	|   |   |   |   {BB Cost   : 7.15        -- (0.75)           }
 *	|   |   |   |   {Hoisted   : []          -- []               }
 *	|   |   |   |   {Copy      : True                            }
 *	|   |   |   |
 *	|   |   |
 *	|   |   {Range     : [  17,   32]                    }
 *	|   |   {Calls %   : 17.24                           }
 *	|   |   {Path Cost : 160.87      -- (16.94)          }
 *	|   |   {BB Cost   : 51.55       -- (5.43)           }
 *	|   |   {Hoisted   : []          -- []               }
 *	|   |   {Copy      : True                            }
 *	|   |
 *	|   {Range     : [  33,  inf]                    }
 *	|   {Calls %   : 24.20                           }
 *	|   {Path Cost : 77.99       -- (8.21)           }
 *	|   {BB Cost   : 49.26       -- (5.19)           }
 *	|   {Hoisted   : []          -- [ 1(16) ]        }
 *	|   {Branch    : size LT 65  -- (39.2 T/60.8 NT) }
 *	|   |
 *	|   |   {Range     : [  65,  inf]                    }
 *	|   |   {Calls %   : 14.72                           }
 *	|   |   {Path Cost : 102.14      -- (10.75)          }
 *	|   |   {BB Cost   : 189.04      -- (19.90)          }
 *	|   |   {Hoisted   : [ 1(16) ]   -- []               }
 *	|   |   {Copy      : True                            }
 *	|   |
 *	|   |   {Range     : [  33,   64]                    }
 *	|   |   {Calls %   : 9.48                            }
 *	|   |   {Path Cost : 103.10      -- (10.86)          }
 *	|   |   {BB Cost   : 73.36       -- (7.72)           }
 *	|   |   {Hoisted   : [ 1(16) ]   -- []               }
 *	|   |   {Copy      : True                            }
 *	|   |
 *	|
 **********************************************************************/
// abf-on
