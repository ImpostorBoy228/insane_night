#pragma once
#include <cstdint>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint32_t codepoint;
    float    adv_x;
    float    br_x;
    float    br_y;
    int      bm_width;
    int      bm_rows;
    int      bm_pitch;
    int      bm_offset;
    float    ker_x;
    float    ker_y;
} GlyphInfo;

void* font_load(const unsigned char *data, unsigned long len, float pixel_size);
void  font_free(void *font);
float cock_measure(void *font, const char *utf8, unsigned long len);
int   font_fill_glyphs(void *font, const char *utf8, unsigned long len,
                       GlyphInfo *out_infos, int max_glyphs,
                       unsigned char **out_bitmap, unsigned long *out_bitmap_size);
void  free_bitmap_buffer(unsigned char *ptr);

#ifdef __cplusplus
}
#endif
