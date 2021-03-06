//
//  Copyright (c) 2015 The WebM project authors. All Rights Reserved.
//
//  Use of this source code is governed by a BSD-style license
//  that can be found in the LICENSE file in the root of the source
//  tree. An additional intellectual property rights grant can be found
//  in the file PATENTS.  All contributing project authors may
//  be found in the AUTHORS file in the root of the source tree.
//

typedef struct {
  SUM_SSE sum_sse[EIGHTTAP_SMOOTH + 1][64];
}GPU_SCRATCH;

//=====   GLOBAL DEFINITIONS   =====
//--------------------------------------
__constant BLOCK_SIZE txsize_to_bsize[TX_SIZES] = {
    BLOCK_4X4,  // TX_4X4
    BLOCK_8X8,  // TX_8X8
    BLOCK_16X16,  // TX_16X16
    BLOCK_32X32,  // TX_32X32
};

__constant int b_width_log2_lookup[BLOCK_SIZES] =
  {0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4};
__constant int b_height_log2_lookup[BLOCK_SIZES] =
  {0, 1, 0, 1, 2, 1, 2, 3, 2, 3, 4, 3, 4};

__constant int num_pels_log2_lookup[BLOCK_SIZES] =
  {4, 5, 5, 6, 7, 7, 8, 9, 9, 10, 11, 11, 12};

__constant TX_SIZE max_txsize_lookup[BLOCK_SIZES] = {
  TX_4X4,   TX_4X4,   TX_4X4,
  TX_8X8,   TX_8X8,   TX_8X8,
  TX_16X16, TX_16X16, TX_16X16,
  TX_32X32, TX_32X32, TX_32X32, TX_32X32
};

// NOTE: The tables below must be of the same size.

// The functions described below are sampled at the four most significant
// bits of x^2 + 8 / 256.

// Normalized rate:
// This table models the rate for a Laplacian source with given variance
// when quantized with a uniform quantizer with given stepsize. The
// closed form expression is:
// Rn(x) = H(sqrt(r)) + sqrt(r)*[1 + H(r)/(1 - r)],
// where r = exp(-sqrt(2) * x) and x = qpstep / sqrt(variance),
// and H(x) is the binary entropy function.
__constant int rate_tab_q10[] = {
  65536,  6086,  5574,  5275,  5063,  4899,  4764,  4651,
   4553,  4389,  4255,  4142,  4044,  3958,  3881,  3811,
   3748,  3635,  3538,  3453,  3376,  3307,  3244,  3186,
   3133,  3037,  2952,  2877,  2809,  2747,  2690,  2638,
   2589,  2501,  2423,  2353,  2290,  2232,  2179,  2130,
   2084,  2001,  1928,  1862,  1802,  1748,  1698,  1651,
   1608,  1530,  1460,  1398,  1342,  1290,  1243,  1199,
   1159,  1086,  1021,   963,   911,   864,   821,   781,
    745,   680,   623,   574,   530,   490,   455,   424,
    395,   345,   304,   269,   239,   213,   190,   171,
    154,   126,   104,    87,    73,    61,    52,    44,
     38,    28,    21,    16,    12,    10,     8,     6,
      5,     3,     2,     1,     1,     1,     0,     0,
};

// Normalized distortion:
// This table models the normalized distortion for a Laplacian source
// with given variance when quantized with a uniform quantizer
// with given stepsize. The closed form expression is:
// Dn(x) = 1 - 1/sqrt(2) * x / sinh(x/sqrt(2))
// where x = qpstep / sqrt(variance).
// Note the actual distortion is Dn * variance.
__constant int dist_tab_q10[] = {
     0,     0,     1,     1,     1,     2,     2,     2,
     3,     3,     4,     5,     5,     6,     7,     7,
     8,     9,    11,    12,    13,    15,    16,    17,
    18,    21,    24,    26,    29,    31,    34,    36,
    39,    44,    49,    54,    59,    64,    69,    73,
    78,    88,    97,   106,   115,   124,   133,   142,
   151,   167,   184,   200,   215,   231,   245,   260,
   274,   301,   327,   351,   375,   397,   418,   439,
   458,   495,   528,   559,   587,   613,   637,   659,
   680,   717,   749,   777,   801,   823,   842,   859,
   874,   899,   919,   936,   949,   960,   969,   977,
   983,   994,  1001,  1006,  1010,  1013,  1015,  1017,
  1018,  1020,  1022,  1022,  1023,  1023,  1023,  1024,
};

__constant int xsq_iq_q10[] = {
       0,      4,      8,     12,     16,     20,     24,     28,
      32,     40,     48,     56,     64,     72,     80,     88,
      96,    112,    128,    144,    160,    176,    192,    208,
     224,    256,    288,    320,    352,    384,    416,    448,
     480,    544,    608,    672,    736,    800,    864,    928,
     992,   1120,   1248,   1376,   1504,   1632,   1760,   1888,
    2016,   2272,   2528,   2784,   3040,   3296,   3552,   3808,
    4064,   4576,   5088,   5600,   6112,   6624,   7136,   7648,
    8160,   9184,  10208,  11232,  12256,  13280,  14304,  15328,
   16352,  18400,  20448,  22496,  24544,  26592,  28640,  30688,
   32736,  36832,  40928,  45024,  49120,  53216,  57312,  61408,
   65504,  73696,  81888,  90080,  98272, 106464, 114656, 122848,
  131040, 147424, 163808, 180192, 196576, 212960, 229344, 245728,
};

// Eight tap and Eight tap smooth filter weights table
__constant char8 filter[2][16] =
{
  {
    { 0,  0,   0,  64,   0,   0,   0,  0},
    { 0,  1,  -5, 126,   8,  -3,   1,  0},
    {-1,  3, -10, 122,  18,  -6,   2,  0},
    {-1,  4, -13, 118,  27,  -9,   3, -1},
    {-1,  4, -16, 112,  37, -11,   4, -1},
    {-1,  5, -18, 105,  48, -14,   4, -1},
    {-1,  5, -19,  97,  58, -16,   5, -1},
    {-1,  6, -19,  88,  68, -18,   5, -1},
    {-1,  6, -19,  78,  78, -19,   6, -1},
    {-1,  5, -18,  68,  88, -19,   6, -1},
    {-1,  5, -16,  58,  97, -19,   5, -1},
    {-1,  4, -14,  48, 105, -18,   5, -1},
    {-1,  4, -11,  37, 112, -16,   4, -1},
    {-1,  3,  -9,  27, 118, -13,   4, -1},
    { 0,  2,  -6,  18, 122, -10,   3, -1},
    { 0,  1,  -3,   8, 126,  -5,   1,  0}
  },

  {
    { 0,  0,  0,  64,  0,  0,  0,  0},
    {-3, -1, 32,  64, 38,  1, -3,  0},
    {-2, -2, 29,  63, 41,  2, -3,  0},
    {-2, -2, 26,  63, 43,  4, -4,  0},
    {-2, -3, 24,  62, 46,  5, -4,  0},
    {-2, -3, 21,  60, 49,  7, -4,  0},
    {-1, -4, 18,  59, 51,  9, -4,  0},
    {-1, -4, 16,  57, 53, 12, -4, -1},
    {-1, -4, 14,  55, 55, 14, -4, -1},
    {-1, -4, 12,  53, 57, 16, -4, -1},
    { 0, -4,  9,  51, 59, 18, -4, -1},
    { 0, -4,  7,  49, 60, 21, -3, -2},
    { 0, -4,  5,  46, 62, 24, -3, -2},
    { 0, -4,  4,  43, 63, 26, -2, -2},
    { 0, -3,  2,  41, 63, 29, -2, -2},
    { 0, -3,  1,  38, 64, 32, -1, -3}
  },
};

//=====   FUNCTION MACROS   =====
//--------------------------------------
#define ACCUMULATE_SUM_SSE_INTER_PRED(sum, sse)                         \
    sum.s0123 = sum.s0123 + sum.s4567;                                  \
    sum.s01   = sum.s01   + sum.s23;                                    \
    sum.s0    = sum.s0    + sum.s1;                                     \
    *psum = sum.s0;                                                     \
    sse.s01   = sse.s01   + sse.s23;                                    \
    sse.s0    = sse.s0    + sse.s1;                                     \
    *psse = sse.s0;

#define MODEL_RD_FOR_SB_Y_LARGE                                             \
  skip_txfm = SKIP_TXFM_NONE;                                               \
  for (k = 0; k < num; k++) {                                               \
    if (!(var_tx[k] < ac_thr || var == 0)) {                                \
      ac_test = 0;                                                          \
      break;                                                                \
    }                                                                       \
  }                                                                         \
  for (k = 0; k < num; k++) {                                               \
    if (!(sse_tx[k] - var_tx[k] < dc_thr || sse == var)) {                  \
      dc_test = 0;                                                          \
      break;                                                                \
    }                                                                       \
  }                                                                         \
  if (ac_test) {                                                            \
    skip_txfm = SKIP_TXFM_AC_ONLY;                                          \
    if (dc_test) {                                                          \
      skip_txfm = SKIP_TXFM_AC_DC;                                          \
    }                                                                       \
  } else if (dc_test) {                                                     \
    skip_dc = 1;                                                            \
  }                                                                         \
  if (skip_txfm == SKIP_TXFM_AC_DC) {                                       \
    actual_rate = 0;                                                        \
    actual_dist = sse << 4;                                                 \
  } else {                                                                  \
    if (!skip_dc) {                                                         \
      vp9_model_rd_from_var_lapndz(sse - var, num_pels_log2_lookup[bsize],  \
                                   dc_quant >> 3, &rate, &dist);            \
    }                                                                       \
    if (!skip_dc) {                                                         \
      actual_rate = rate >> 1;                                              \
      actual_dist = dist << 3;                                              \
    } else {                                                                \
      actual_rate = 0;                                                      \
      actual_dist = (sse - var) << 4;                                       \
    }                                                                       \
    vp9_model_rd_from_var_lapndz(var, num_pels_log2_lookup[bsize],          \
                                 ac_quant >> 3, &rate, &dist);              \
    actual_rate += rate;                                                    \
    actual_dist += dist << 4;                                               \
  }


//=====   FUNCTION DEFINITIONS   =====
//-------------------------------------------
inline int get_msb(unsigned int n) {
  return 31 ^ clz(n);
}

void model_rd_norm(int xsq_q10, int *r_q10, int *d_q10) {
  const int tmp = (xsq_q10 >> 2) + 8;
  const int k = get_msb(tmp) - 3;
  const int xq = (k << 3) + ((tmp >> k) & 0x7);
  const int one_q10 = 1 << 10;
  const int a_q10 = ((xsq_q10 - xsq_iq_q10[xq]) << 10) >> (2 + k);
  const int b_q10 = one_q10 - a_q10;
  *r_q10 = (rate_tab_q10[xq] * b_q10 + rate_tab_q10[xq + 1] * a_q10) >> 10;
  *d_q10 = (dist_tab_q10[xq] * b_q10 + dist_tab_q10[xq + 1] * a_q10) >> 10;
}

void vp9_model_rd_from_var_lapndz(unsigned int var, unsigned int n_log2,
                                  unsigned int qstep, int *rate,
                                  int64_t *dist) {
  // This function models the rate and distortion for a Laplacian
  // source with given variance when quantized with a uniform quantizer
  // with given stepsize. The closed form expressions are in:
  // Hang and Chen, "Source Model for transform video coder and its
  // application - Part I: Fundamental Theory", IEEE Trans. Circ.
  // Sys. for Video Tech., April 1997.
  if (var == 0) {
    *rate = 0;
    *dist = 0;
  } else {
    int d_q10, r_q10;
    const uint32_t MAX_XSQ_Q10 = 245727;
    const uint64_t xsq_q10_64 =
        (((uint64_t)qstep * qstep << (n_log2 + 10)) + (var >> 1)) / var;
    const int xsq_q10 = (int)MIN(xsq_q10_64, MAX_XSQ_Q10);
    model_rd_norm(xsq_q10, &r_q10, &d_q10);
    *rate = ROUND_POWER_OF_TWO(r_q10 << n_log2, 10 - VP9_PROB_COST_SHIFT);
    *dist = (var * (int64_t)d_q10 + 512) >> 10;
  }
}

void calculate_variance(int bw, int bh, TX_SIZE tx_size,
                        uint32_t *sse_i, int *sum_i,
                        uint32_t *var_o, uint32_t *sse_o,
                        int *sum_o) {
  BLOCK_SIZE unit_size = txsize_to_bsize[tx_size];
  int nw = 1 << (bw - b_width_log2_lookup[unit_size]);
  int nh = 1 << (bh - b_height_log2_lookup[unit_size]);
  int i, j, k = 0;

  for (i = 0; i < nh; i += 2) {
    for (j = 0; j < nw; j += 2) {
      sse_o[k] = sse_i[i * nw + j] + sse_i[i * nw + j + 1] +
          sse_i[(i + 1) * nw + j] + sse_i[(i + 1) * nw + j + 1];
      sum_o[k] = sum_i[i * nw + j] + sum_i[i * nw + j + 1] +
          sum_i[(i + 1) * nw + j] + sum_i[(i + 1) * nw + j + 1];
      var_o[k] = sse_o[k] - (((uint32_t)sum_o[k] * sum_o[k]) >>
          (b_width_log2_lookup[unit_size] +
              b_height_log2_lookup[unit_size] + 6));
      k++;
    }
  }
}

inline void calculate_8x8_variance(__global uchar *ref_frame,
                                   __global uchar *cur_frame,
                                   unsigned int *sse,
                                   int *sum,
                                   int stride) {
  short8 vsum = 0;
  uint4 vsse = 0;
  short row;

  *sse = 0;
  *sum = 0;

  for(row = 0; row < 8; row++) {

    uchar8 output = vload8(0, ref_frame);
    ref_frame += stride;

    uchar8 cur = vload8(0, cur_frame);
    cur_frame += stride;

    short8 diff = convert_short8(output) - convert_short8(cur);
    vsum += diff;
    vsse += convert_uint4(convert_int4(diff.s0123) * convert_int4(diff.s0123));
    vsse += convert_uint4(convert_int4(diff.s4567) * convert_int4(diff.s4567));
  }
  vsum.s0123 = vsum.s0123 + vsum.s4567;
  vsum.s01 = vsum.s01 + vsum.s23;
  *sum = vsum.s0 + vsum.s1;

  vsse.s01 = vsse.s01 + vsse.s23;
  *sse = vsse.s0 + vsse.s1;
}

TX_SIZE get_uv_tx_size(tx_size, bsize) {
  BLOCK_SIZE plane_bsize = ss_size_lookup[bsize];

  return MIN(tx_size, max_txsize_lookup[plane_bsize]);
}

void inter_prediction(__global uchar *ref_data,
                      __global uchar *cur_frame,
                      int stride,
                      int horz_subpel,
                      int vert_subpel,
                      int filter_type,
                      __local uchar8 *intermediate,
                      int *psum,
                      uint32_t *psse) {
  __local uchar8 *intermediate_uchar8;
  __local int *intermediate_int = (__local int *)intermediate;
  uchar8 curr_data = vload8(0, cur_frame);

  uchar16 ref;
  uchar8 ref_u8;

  short8 inter;
  int4 inter_out1;
  short8 sum = (short8)(0, 0, 0, 0, 0, 0, 0, 0);
  uint4 sse = (uint4)(0, 0, 0, 0);
  short8 c;

  int local_col = get_local_id(0);
  int local_row = get_local_id(1);
  int inter_offset = (local_row * LOCAL_STRIDE * PIXEL_ROWS_PER_WORKITEM) + local_col;

  short8 tmp;
  int4 shift_val = (int4)(1 << 14);
  int4 tmp1;
  uchar8 temp_out;
  uchar8 out_uni;
  uchar8 out_bi;
  int i;

  if (!vert_subpel) {
    // L0 only x_frac
    char8 filt = filter[filter_type][horz_subpel];

    for (i = 0; i < PIXEL_ROWS_PER_WORKITEM; i++) {
      ref = vload16(0, ref_data - 3);

      inter = (short8)(-1 << 14);

      tmp = filt.s0;
      inter += convert_short8(ref.s01234567) * tmp;
      tmp = filt.s1;
      inter += convert_short8(ref.s12345678) * tmp;
      tmp = filt.s2;
      inter += convert_short8(ref.s23456789) * tmp;
      tmp = filt.s3;
      inter += convert_short8(ref.s3456789a) * tmp;
      tmp = filt.s4;
      inter += convert_short8(ref.s456789ab) * tmp;
      tmp = filt.s5;
      inter += convert_short8(ref.s56789abc) * tmp;
      tmp = filt.s6;
      inter += convert_short8(ref.s6789abcd) * tmp;
      tmp = filt.s7;
      inter += convert_short8(ref.s789abcde) * tmp;

      if (horz_subpel == 0) {
        tmp1 = (1 << 5) + shift_val;
        inter_out1 = convert_int4(inter.s0123);

        out_uni.s0123 = convert_uchar4_sat((inter_out1 + tmp1) >> 6);
        inter_out1 = convert_int4(inter.s4567);

        out_uni.s4567 = convert_uchar4_sat((inter_out1 + tmp1) >> 6);
      } else {
        tmp1 = (1 << 6) + shift_val;
        inter_out1 = convert_int4(inter.s0123);

        out_uni.s0123 = convert_uchar4_sat((inter_out1 + tmp1) >> 7);
        inter_out1 =convert_int4(inter.s4567);

        out_uni.s4567 = convert_uchar4_sat((inter_out1 + tmp1) >> 7);
      }

      curr_data = vload8(0, cur_frame);
      short8 diff = convert_short8(curr_data) - convert_short8(out_uni);
      sum += diff;
      sse += convert_uint4(convert_int4(diff.s0123) * convert_int4(diff.s0123));
      sse += convert_uint4(convert_int4(diff.s4567) * convert_int4(diff.s4567));

      ref_data += stride;
      cur_frame += stride;
    }
    ACCUMULATE_SUM_SSE_INTER_PRED(sum, sse)
  } else if(!horz_subpel) {
    // L0 only y_frac
    char8 filt = filter[filter_type][vert_subpel];
    ref_data -= (3 * stride);
    for(i = 0; i < PIXEL_ROWS_PER_WORKITEM; i++) {

      inter = (short8)(-1 << 14);
      ref_u8 = vload8(0, ref_data);
      tmp = filt.s0;
      inter += convert_short8(ref_u8) * tmp;

      ref_data += stride;
      ref_u8 = vload8(0, ref_data);
      tmp = filt.s1;
      inter += convert_short8(ref_u8) * tmp;

      ref_data += stride;
      ref_u8 = vload8(0, ref_data);
      tmp = filt.s2;
      inter += convert_short8(ref_u8) * tmp;

      ref_data += stride;
      ref_u8 = vload8(0, ref_data);
      tmp = filt.s3;
      inter += convert_short8(ref_u8) * tmp;

      ref_data += stride;
      ref_u8 = vload8(0, ref_data);
      tmp = filt.s4;
      inter += convert_short8(ref_u8) * tmp;

      ref_data += stride;
      ref_u8 = vload8(0, ref_data);
      tmp = filt.s5;
      inter += convert_short8(ref_u8) * tmp;

      ref_data += stride;
      ref_u8 = vload8(0, ref_data);
      tmp = filt.s6;
      inter += convert_short8(ref_u8) * tmp;

      ref_data += stride;
      ref_u8 = vload8(0, ref_data);
      tmp = filt.s7;
      inter += convert_short8(ref_u8) * tmp;

      tmp1 = (1 << 6) + shift_val;
      inter_out1 = convert_int4(inter.s0123);

      out_uni.s0123 = convert_uchar4_sat((inter_out1 + tmp1) >> 7);
      inter_out1 = convert_int4(inter.s4567);

      out_uni.s4567 = convert_uchar4_sat((inter_out1 + tmp1) >> 7);

      curr_data = vload8(0, cur_frame);
      short8 diff = convert_short8(curr_data) - convert_short8(out_uni);
      sum += diff;
      sse += convert_uint4(convert_int4(diff.s0123) * convert_int4(diff.s0123));
      sse += convert_uint4(convert_int4(diff.s4567) * convert_int4(diff.s4567));

      ref_data  -= 6 * stride;
      cur_frame += stride;
    }
    ACCUMULATE_SUM_SSE_INTER_PRED(sum, sse)
  } else {
    char8 filt = filter[filter_type][horz_subpel];
    ref_data -= (3 * stride);

    for(i = 0; i < PIXEL_ROWS_PER_WORKITEM; i++) {
      inter = (short8)(-1 << 14);
      ref = vload16(0, ref_data - 3);

      tmp = filt.s0;
      inter += convert_short8(ref.s01234567) * tmp;
      tmp = filt.s1;
      inter += convert_short8(ref.s12345678) * tmp;
      tmp = filt.s2;
      inter += convert_short8(ref.s23456789) * tmp;
      tmp = filt.s3;
      inter += convert_short8(ref.s3456789a) * tmp;
      tmp = filt.s4;
      inter += convert_short8(ref.s456789ab) * tmp;
      tmp = filt.s5;
      inter += convert_short8(ref.s56789abc) * tmp;
      tmp = filt.s6;
      inter += convert_short8(ref.s6789abcd) * tmp;
      tmp = filt.s7;
      inter += convert_short8(ref.s789abcde) * tmp;
      tmp1 = (1 << 6) + shift_val;
      inter_out1 = convert_int4(inter.s0123);
      temp_out.s0123 = convert_uchar4_sat((inter_out1 + tmp1) >> 7);
      inter_out1 = convert_int4(inter.s4567);
      temp_out.s4567 = convert_uchar4_sat((inter_out1 + tmp1) >> 7);
      intermediate[inter_offset] = temp_out;

      ref_data += stride;
      inter_offset += LOCAL_STRIDE;
    }

    if (local_row < 8 / PIXEL_ROWS_PER_WORKITEM) {
      ref_data += (BLOCK_SIZE_IN_PIXELS - PIXEL_ROWS_PER_WORKITEM) * stride;
      inter_offset += (BLOCK_SIZE_IN_PIXELS - PIXEL_ROWS_PER_WORKITEM) * LOCAL_STRIDE;

      for(i = 0; i < PIXEL_ROWS_PER_WORKITEM; i++) {
        ref = vload16(0, ref_data - 3);
        inter = (short8)(-1 << 14);
        tmp = filt.s0;
        inter += convert_short8(ref.s01234567) * tmp;
        tmp = filt.s1;
        inter += convert_short8(ref.s12345678) * tmp;
        tmp = filt.s2;
        inter += convert_short8(ref.s23456789) * tmp;
        tmp = filt.s3;
        inter += convert_short8(ref.s3456789a) * tmp;
        tmp = filt.s4;
        inter += convert_short8(ref.s456789ab) * tmp;
        tmp = filt.s5;
        inter += convert_short8(ref.s56789abc) * tmp;
        tmp = filt.s6;
        inter += convert_short8(ref.s6789abcd) * tmp;
        tmp = filt.s7;
        inter += convert_short8(ref.s789abcde) * tmp;
        tmp1 = (1 << 6) + shift_val;
        inter_out1 = convert_int4(inter.s0123);
        temp_out.s0123 = convert_uchar4_sat((inter_out1 + tmp1) >> 7);
        inter_out1 = convert_int4(inter.s4567);
        temp_out.s4567 = convert_uchar4_sat((inter_out1 + tmp1) >> 7);
        intermediate[inter_offset] = temp_out;

        ref_data += stride;
        inter_offset += LOCAL_STRIDE;
      }
      inter_offset -= BLOCK_SIZE_IN_PIXELS * LOCAL_STRIDE;
    }

    inter_offset -= (PIXEL_ROWS_PER_WORKITEM) * LOCAL_STRIDE;
    intermediate_uchar8 = intermediate + inter_offset + (3 * LOCAL_STRIDE);
    filt = filter[filter_type][vert_subpel];
    barrier(CLK_LOCAL_MEM_FENCE);
    for(i = 0; i < PIXEL_ROWS_PER_WORKITEM; i++) {
      inter = (short8)(-1 << 14);
      ref_u8 = intermediate_uchar8[-3 * LOCAL_STRIDE];
      tmp = filt.s0;
      inter += convert_short8(ref_u8) * tmp;
      ref_u8 = intermediate_uchar8[-2 * LOCAL_STRIDE];
      tmp = filt.s1;
      inter += convert_short8(ref_u8) * tmp;
      ref_u8 = intermediate_uchar8[-1 * LOCAL_STRIDE];
      tmp = filt.s2;
      inter += convert_short8(ref_u8) * tmp;
      ref_u8 = intermediate_uchar8[0 * LOCAL_STRIDE];
      tmp = filt.s3;
      inter += convert_short8(ref_u8) * tmp;
      ref_u8 = intermediate_uchar8[1 * LOCAL_STRIDE];
      tmp = filt.s4;
      inter += convert_short8(ref_u8) * tmp;
      ref_u8 = intermediate_uchar8[2 * LOCAL_STRIDE];
      tmp = filt.s5;
      inter += convert_short8(ref_u8) * tmp;
      ref_u8 = intermediate_uchar8[3 * LOCAL_STRIDE];
      tmp = filt.s6;
      inter += convert_short8(ref_u8) * tmp;
      ref_u8 = intermediate_uchar8[4 * LOCAL_STRIDE];
      tmp = filt.s7;
      inter += convert_short8(ref_u8) * tmp;

      tmp1 = (1 << 6) + shift_val;
      inter_out1 = convert_int4(inter.s0123);

      out_uni.s0123 = convert_uchar4_sat((inter_out1 + tmp1) >> 7);
      inter_out1 = convert_int4(inter.s4567);

      out_uni.s4567 = convert_uchar4_sat((inter_out1 + tmp1) >> 7);

      curr_data = vload8(0, cur_frame);
      short8 diff = convert_short8(curr_data) - convert_short8(out_uni);
      sum += diff;
      sse += convert_uint4(convert_int4(diff.s0123) * convert_int4(diff.s0123));
      sse += convert_uint4(convert_int4(diff.s4567) * convert_int4(diff.s4567));

      intermediate_uchar8 += LOCAL_STRIDE;
      cur_frame += stride;
    }
    ACCUMULATE_SUM_SSE_INTER_PRED(sum, sse)
  }
}

//=====   KERNELS   =====
//------------------------------
__kernel
// PIXEL_ROWS_PER_WORKITEM should be exactly 16. Otherwise this kernel will fail
__attribute__((reqd_work_group_size(BLOCK_SIZE_IN_PIXELS / NUM_PIXELS_PER_WORKITEM,
                                    BLOCK_SIZE_IN_PIXELS / 16,
                                    1)))
void vp9_zero_motion_search(__global uchar *ref,
                            __global uchar *cur,
                            int stride,
                            __global GPU_INPUT *gpu_input,
                            __global GPU_OUTPUT_ME *gpu_output_me,
                            __global GPU_RD_PARAMS_DYNAMIC *rd_params_dyn,
                            int64_t yplane_size, int64_t uvplane_size,
                            int padding_offset) {
  __global uchar *ref_frame = ref;
  __global uchar *cur_frame = cur;
  uint sse_tmp;
  int sum_tmp;
  short bw;
  int group_col = get_group_id(0);
  int global_row = get_global_id(1);
  int group_stride = get_num_groups(0);
  BLOCK_SIZE bsize;
  __local uint sse8x8[(BLOCK_SIZE_IN_PIXELS * BLOCK_SIZE_IN_PIXELS) / 64];
  __local uint var8x8[(BLOCK_SIZE_IN_PIXELS * BLOCK_SIZE_IN_PIXELS) / 64];
  __local int sum16x16[(BLOCK_SIZE_IN_PIXELS * BLOCK_SIZE_IN_PIXELS) / 256];
  __local uint sse16x16[(BLOCK_SIZE_IN_PIXELS * BLOCK_SIZE_IN_PIXELS) / 256];
  __local uint var16x16[(BLOCK_SIZE_IN_PIXELS * BLOCK_SIZE_IN_PIXELS) / 256];
  __local uint sse_uv[2];
  __local int sum_uv[2];
  __local uint sse;
  __local int sum;

#if BLOCK_SIZE_IN_PIXELS == 64
  GPU_BLOCK_SIZE gpu_bsize = GPU_BLOCK_64X64;
  int group_offset = (global_row / (BLOCK_SIZE_IN_PIXELS / PIXEL_ROWS_PER_WORKITEM) *
      group_stride * 4 + group_col * 2);
#else
  GPU_BLOCK_SIZE gpu_bsize = GPU_BLOCK_32X32;
  int group_offset = (global_row / (BLOCK_SIZE_IN_PIXELS / PIXEL_ROWS_PER_WORKITEM) *
      group_stride + group_col);
#endif

  gpu_input += group_offset;
  gpu_output_me += group_offset;

  if (gpu_input->do_compute != gpu_bsize)
    goto exit;

  __global GPU_RD_SEG_PARAMETERS *seg_rd_params =
      &rd_params_dyn->seg_rd_param[gpu_input->seg_id];

  int local_col = get_local_id(0);
  int local_row = get_local_id(1);

  int global_offset = (global_row * PIXEL_ROWS_PER_WORKITEM * stride) +
                      (group_col * BLOCK_SIZE_IN_PIXELS) +
                      (local_col * NUM_PIXELS_PER_WORKITEM);
  global_offset += padding_offset;

  cur += global_offset;
  ref += global_offset;

#if BLOCK_SIZE_IN_PIXELS == 64
  bsize = BLOCK_64X64;
#elif BLOCK_SIZE_IN_PIXELS == 32
  bsize = BLOCK_32X32;
#endif

  bw = b_width_log2_lookup[bsize];

  int offset_8x8 =
      local_row * (BLOCK_SIZE_IN_PIXELS / NUM_PIXELS_PER_WORKITEM) * (PIXEL_ROWS_PER_WORKITEM / 8) + local_col;
  int offset_16x16 =
      local_row * (BLOCK_SIZE_IN_PIXELS / 16) * (PIXEL_ROWS_PER_WORKITEM / 16) + (local_col / 2);

  sum = 0;
  sse = 0;
  sum16x16[offset_16x16] = 0;
  sse16x16[offset_16x16] = 0;
  barrier(CLK_LOCAL_MEM_FENCE);

  int i;
  // Calculate the 8x8 and 16x16 variances for Y
  for(i = 0; i < PIXEL_ROWS_PER_WORKITEM / 8; i++) {
    calculate_8x8_variance(ref, cur, &sse_tmp, &sum_tmp, stride);
    var8x8[offset_8x8] = sse_tmp - (((unsigned int)sum_tmp * sum_tmp) >> 6);
    sse8x8[offset_8x8] = sse_tmp;
    atomic_add(&sum, sum_tmp);
    atomic_add(&sse, sse_tmp);
    atomic_add(sum16x16 + offset_16x16, sum_tmp);
    atomic_add(sse16x16 + offset_16x16, sse_tmp);
    ref += 8 * stride;
    cur += 8 * stride;
    offset_8x8 += (BLOCK_SIZE_IN_PIXELS / NUM_PIXELS_PER_WORKITEM);
  }
  barrier(CLK_LOCAL_MEM_FENCE);
  uint var = sse - (((int64_t)sum * sum) >> (bw * 2 + 4));

  // Calculate the Txfm size
  TX_SIZE tx_size;
  int skip_txfm;

  if (sse > (var << 2)) {
    tx_size = TX_16X16;
    var16x16[offset_16x16] = sse16x16[offset_16x16] -
        (((int64_t)sum16x16[offset_16x16] * sum16x16[offset_16x16]) >> 8);
    barrier(CLK_LOCAL_MEM_FENCE);
  } else {
    tx_size = TX_8X8;
  }

  // Calculate RD and fill the GPU_OUTPUT_ME structure vraiables
  if (local_row == 0 && local_col == 0) {
    int dc_quant = seg_rd_params->dc_dequant;
    int ac_quant = seg_rd_params->ac_dequant;
    int64_t dc_thr = dc_quant * dc_quant >> 6;
    int64_t ac_thr = ac_quant * ac_quant >> 6;
    int skip_dc = 0;

    int rate, actual_rate;
    int64_t dist, actual_dist;
    int num8x8 = 1 << (bw * 2 - 2);
    int num16x16 = num8x8 >> 2;

    int ac_test = 1;
    int dc_test = 1;
    int k;
    int num = (tx_size == TX_8X8) ? num8x8 : num16x16;
    __local uint *sse_tx = (tx_size == TX_8X8) ? sse8x8 : sse16x16;
    __local uint *var_tx = (tx_size == TX_8X8) ? var8x8 : var16x16;

    MODEL_RD_FOR_SB_Y_LARGE

    gpu_output_me->rate[GPU_INTER_OFFSET(ZEROMV)] = actual_rate;
    gpu_output_me->dist[GPU_INTER_OFFSET(ZEROMV)] = actual_dist;
    gpu_output_me->sse_y[GPU_INTER_OFFSET(ZEROMV)] = sse;
    gpu_output_me->var_y[GPU_INTER_OFFSET(ZEROMV)] = var;
    gpu_output_me->interp_filter[GPU_INTER_OFFSET(ZEROMV)] = EIGHTTAP;
    gpu_output_me->tx_size[GPU_INTER_OFFSET(ZEROMV)] = tx_size;
    gpu_output_me->skip_txfm[GPU_INTER_OFFSET(ZEROMV)] = skip_txfm;
    gpu_output_me->this_early_term[GPU_INTER_OFFSET(ZEROMV)] = 0;
    if (skip_txfm == SKIP_TXFM_AC_DC) {
      vstore2(0, 0, sum_uv);
      vstore2(0, 0, sse_uv);
    }
  }
  barrier(CLK_LOCAL_MEM_FENCE);

  // Check for this_early_term from UV variances
  skip_txfm = gpu_output_me->skip_txfm[GPU_INTER_OFFSET(ZEROMV)];
  if (skip_txfm == SKIP_TXFM_AC_DC) {
    global_offset = (global_row * (PIXEL_ROWS_PER_WORKITEM >> 1) * (stride >> 1)) +
                    (group_col * (BLOCK_SIZE_IN_PIXELS >> 1)) +
                    ((local_col >> 1) * NUM_PIXELS_PER_WORKITEM);
    global_offset += padding_offset;

    short uv_idx = (local_col & 1);
    global_offset += yplane_size + uv_idx * uvplane_size;

    __global uchar *ref_uv = ref_frame + global_offset;
    __global uchar *cur_uv = cur_frame + global_offset;

    calculate_8x8_variance(ref_uv, cur_uv, &sse_tmp, &sum_tmp, stride >> 1);

    atomic_add(sum_uv + uv_idx, sum_tmp);
    atomic_add(sse_uv + uv_idx, sse_tmp);
    barrier(CLK_LOCAL_MEM_FENCE);


    if (local_row == 0 && local_col == 0) {
      int uv_bw = bw - 1;
      // Assumes value of TX_16X16 as 2
      int sf = (uv_bw - tx_size) * 2;
      int dc_quant = seg_rd_params->dc_dequant;
      int ac_quant = seg_rd_params->ac_dequant;
      uint32_t uv_dc_thr = dc_quant * dc_quant >> (6 - sf);
      uint32_t uv_ac_thr = ac_quant * ac_quant >> (6 - sf);
      int this_early_term = 1;
      var = sse_uv[0] - (((int64_t)sum_uv[0] * sum_uv[0]) >> (uv_bw * 2 + 4));
      if (!((var < uv_ac_thr || var == 0) &&
            (sse_uv[0] - var < uv_dc_thr || sse_uv[0] == var))) {
        this_early_term = 0;
      }
      var = sse_uv[1] - (((int64_t)sum_uv[1] * sum_uv[1]) >> (uv_bw * 2 + 4));
      if (!((var < uv_ac_thr || var == 0) &&
            (sse_uv[1] - var < uv_dc_thr || sse_uv[1] == var))) {
        this_early_term = 0;
      }
      gpu_output_me->this_early_term[GPU_INTER_OFFSET(ZEROMV)] = this_early_term;

      if (this_early_term) {
        gpu_input->do_compute = GPU_BLOCK_INVALID;
        gpu_output_me->rv = 1;
#if BLOCK_SIZE_IN_PIXELS == 64
        group_stride = get_num_groups(0);
        (gpu_input + 1)->do_compute = GPU_BLOCK_INVALID;
        (gpu_input + (group_stride * 2))->do_compute = GPU_BLOCK_INVALID;
        (gpu_input + (group_stride * 2) + 1)->do_compute = GPU_BLOCK_INVALID;
#endif
      }
    }
  }

exit:
  return;
}

__kernel
__attribute__((reqd_work_group_size(BLOCK_SIZE_IN_PIXELS / NUM_PIXELS_PER_WORKITEM,
                                    BLOCK_SIZE_IN_PIXELS / PIXEL_ROWS_PER_WORKITEM,
                                    1)))
void vp9_inter_prediction_and_sse(__global uchar *ref_frame,
                                  __global uchar *cur_frame,
                                  int stride,
                                  __global GPU_INPUT *gpu_input,
                                  __global GPU_OUTPUT_ME *gpu_output_me,
                                  __global GPU_SCRATCH *gpu_scratch,
                                  int padding_offset) {
  __local uchar8 intermediate_uchar8[(BLOCK_SIZE_IN_PIXELS * (BLOCK_SIZE_IN_PIXELS + 8)) / NUM_PIXELS_PER_WORKITEM];
  __local int *intermediate_int = (__local int *)intermediate_uchar8;
  int global_row = get_global_id(1);
  int group_col = get_group_id(0);
  int group_stride = (get_num_groups(0) >> 1);
  int sum;
  uint32_t sse;
  int filter_type;
  int group_row = global_row / (BLOCK_SIZE_IN_PIXELS / PIXEL_ROWS_PER_WORKITEM);
#if BLOCK_SIZE_IN_PIXELS == 64
  int group_offset = group_row * group_stride * 4 + (group_col >> 1) * 2;
#else
  int group_offset = group_row * group_stride + (group_col >> 1);
#endif

  gpu_input += group_offset;
  GPU_BLOCK_SIZE gpu_bsize = gpu_input->do_compute;
  if (gpu_bsize == GPU_BLOCK_INVALID)
    goto exit;

  // Assuming a values for enum GPU_BLOCK_64X64 as 1 and GPU_BLOCK_32X32 as 0
  int row_offset = group_row & gpu_bsize;
  int col_offset = (group_col >> 1) & gpu_bsize;
  group_offset -= row_offset * group_stride;
  group_offset -= col_offset;

  gpu_output_me += group_offset;
  gpu_scratch += group_offset;

  if (group_col % 2 == 0) {
    filter_type = EIGHTTAP;
  } else {
    filter_type = EIGHTTAP_SMOOTH;
  }

  MV out_mv = gpu_output_me->mv.as_mv;
  int mv_row = out_mv.row;
  int mv_col = out_mv.col;
  int mv_offset = ((mv_row >> SUBPEL_BITS) * stride) + (mv_col >> SUBPEL_BITS);
  int horz_subpel = (mv_col & SUBPEL_MASK) << 1;
  int vert_subpel = (mv_row & SUBPEL_MASK) << 1;
  int local_col = get_local_id(0);
  int local_row = get_local_id(1);
  int global_offset = (global_row * stride * PIXEL_ROWS_PER_WORKITEM) +
      ((group_col >> 1) * BLOCK_SIZE_IN_PIXELS) + (local_col * NUM_PIXELS_PER_WORKITEM);

  global_offset += padding_offset;

  if (filter_type != EIGHTTAP && !horz_subpel && !vert_subpel)
    goto exit;

  cur_frame += global_offset;
  ref_frame += global_offset + mv_offset;

  // Assuming a values for enum GPU_BLOCK_64X64 as 1 and GPU_BLOCK_32X32 as 0
  short local_offset = (local_row + row_offset * 4) * (4 << gpu_bsize) +
      local_col + (col_offset * 4);

  inter_prediction(ref_frame, cur_frame, stride, horz_subpel, vert_subpel,
                   filter_type, intermediate_uchar8,
                   &sum, &sse);

  gpu_scratch->sum_sse[filter_type][local_offset].sse = sse;
  gpu_scratch->sum_sse[filter_type][local_offset].sum = sum;

exit:
  return;
}

__kernel
void vp9_rd_calculation(__global GPU_INPUT *gpu_input,
                        __global GPU_OUTPUT_ME *gpu_output_me,
                        __global GPU_RD_PARAMS_STATIC *rd_params_static,
                        __global GPU_RD_PARAMS_DYNAMIC *rd_params_dyn,
                        __global GPU_SCRATCH *gpu_scratch) {
  uint32_t sse8x8[64], var8x8[64];
  int sum8x8[64];
  uint32_t sse, var;
  int sum;
  int bw, bh;
  int global_col = get_global_id( 0 );
  int global_row = get_global_id( 1 );
  int global_stride = get_global_size( 0 );
  int i, j;
  int filter_type = EIGHTTAP_SMOOTH;
  int bsize;
  int this_early_term = 0;
  int group_offset = (global_row * global_stride + global_col);

  gpu_input += group_offset;
  gpu_output_me += group_offset;
  gpu_scratch += group_offset;

  if (gpu_input->do_compute == GPU_BLOCK_32X32)
    bsize = BLOCK_32X32;
  else if (gpu_input->do_compute == GPU_BLOCK_64X64)
    bsize = BLOCK_64X64;
  else
    goto exit;

  __global GPU_RD_SEG_PARAMETERS *seg_rd_params =
      &rd_params_dyn->seg_rd_param[gpu_input->seg_id];
  MV out_mv = gpu_output_me->mv.as_mv;
  int mv_row = out_mv.row;
  int mv_col = out_mv.col;
  int horz_subpel = (mv_col & SUBPEL_MASK) << 1;
  int vert_subpel = (mv_row & SUBPEL_MASK) << 1;

  if (!horz_subpel && !vert_subpel)
    filter_type = EIGHTTAP;

  // Only Square block sizes supported in GPU
  bw = bh = b_width_log2_lookup[bsize];

  int64_t cost, best_cost = INT64_MAX;
  for (j = 0; j <= filter_type; j++) {
    sse = 0;
    sum = 0;
    int num8x8 = 1 << (bw + bh - 2);
    for (i = 0; i < num8x8; i++) {
      sse8x8[i] = gpu_scratch->sum_sse[j][i].sse;
      sum8x8[i] = gpu_scratch->sum_sse[j][i].sum;

      var8x8[i] = sse8x8[i] - (((unsigned int)sum8x8[i] * sum8x8[i]) >> 6);

      sse += sse8x8[i];
      sum += sum8x8[i];
    }
    var = sse - (((int64_t)sum * sum) >> (bw + bh + 4));

    {
      TX_SIZE tx_size;

      int dc_quant = seg_rd_params->dc_dequant;
      int ac_quant = seg_rd_params->ac_dequant;
      int64_t dc_thr = dc_quant * dc_quant >> 6;
      int64_t ac_thr = ac_quant * ac_quant >> 6;
      int skip_txfm;
      int skip_dc = 0;

      int rate, actual_rate;
      int64_t dist, actual_dist;
      if (sse > (var << 2))
        tx_size = TX_16X16;
      else
        tx_size = TX_8X8;
      int num8x8 = 1 << (bw + bh - 2);
      uint32_t sse16x16[16];
      int sum16x16[16];
      uint32_t var16x16[16];
      int num16x16 = num8x8 >> 2;

      int ac_test = 1;
      int dc_test = 1;
      int k;
      int num = (tx_size == TX_8X8) ? num8x8 : num16x16;
      uint32_t *sse_tx = (tx_size == TX_8X8) ? sse8x8 : sse16x16;
      uint32_t *var_tx = (tx_size == TX_8X8) ? var8x8 : var16x16;
      if (tx_size >= TX_16X16) {
        calculate_variance(bw, bh, TX_8X8, sse8x8, sum8x8, var16x16, sse16x16,
                           sum16x16);
      }
      MODEL_RD_FOR_SB_Y_LARGE

      if (horz_subpel || vert_subpel)
        actual_rate += rd_params_static->switchable_interp_costs[j];
      cost = RDCOST(seg_rd_params->rd_mult, rd_params_static->rd_div,
                    actual_rate, actual_dist);
      if (cost < best_cost) {
        best_cost = cost;
        gpu_output_me->rate[GPU_INTER_OFFSET(NEWMV)] = actual_rate;
        gpu_output_me->dist[GPU_INTER_OFFSET(NEWMV)] = actual_dist;
        gpu_output_me->sse_y[GPU_INTER_OFFSET(NEWMV)] = sse;
        gpu_output_me->var_y[GPU_INTER_OFFSET(NEWMV)] = var;
        gpu_output_me->interp_filter[GPU_INTER_OFFSET(NEWMV)] = j;
        gpu_output_me->tx_size[GPU_INTER_OFFSET(NEWMV)] = tx_size;
        gpu_output_me->skip_txfm[GPU_INTER_OFFSET(NEWMV)] = skip_txfm;
        gpu_output_me->this_early_term[GPU_INTER_OFFSET(NEWMV)] = this_early_term;
      }
    }
  }

  exit:
  return;
}
