// Pure-logic tests for the C++ engine (no window/bgfx init).
// Exercises header-inline helpers from src/heck.hpp + micro-benchmarks.
#include "heck.hpp"

#include <chrono>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <sstream>
#include <string>

struct ConcreteSkibidi : Skibidi {
  ConcreteSkibidi(int32_t z) : Skibidi(z) {}
  void collect(JohnPork &) override {}
};

static int g_failures = 0;
static int g_checks = 0;

#define CHECK(cond)                                                          \
  do {                                                                       \
    ++g_checks;                                                              \
    if (!(cond)) {                                                           \
      ++g_failures;                                                          \
      std::printf("  [FAIL] %s:%d: %s\n", __FILE__, __LINE__, #cond);        \
    }                                                                        \
  } while (0)

// ── benchmarking helpers ──────────────────────────────────────
static long rss_kb() {
  std::ifstream f("/proc/self/status");
  std::string line;
  while (std::getline(f, line)) {
    if (line.rfind("VmRSS:", 0) == 0) {
      long kb = 0;
      std::sscanf(line.c_str() + 6, "%ld", &kb);
      return kb;
    }
  }
  return -1;
}

static void bench_report(const char *name, double ns_per_op, int iters) {
  std::printf("  %-28s %12.1f ns/op  (%d iters)\n", name, ns_per_op, iters);
}

template <typename F>
static double bench_ns(F fn, int iters, int warmup) {
  for (int i = 0; i < warmup; ++i) fn();
  auto t0 = std::chrono::steady_clock::now();
  for (int i = 0; i < iters; ++i) fn();
  auto t1 = std::chrono::steady_clock::now();
  auto ns = std::chrono::duration_cast<std::chrono::nanoseconds>(t1 - t0).count();
  return static_cast<double>(ns) / iters;
}

static volatile uint64_t g_sink = 0; // prevent dead-code elimination

static void bench_hitbox() {
  ConcreteSkibidi s(0);
  s.setHitbox(10, 20, 30, 40);
  const int iters = 2000000;
  double t = bench_ns([&]() { g_sink += s.hitTest(25.f, 35.f) ? 1 : 0; }, iters, 10000);
  bench_report("Skibidi::hitTest", t, iters);
}

static void bench_utf8_decode() {
  const char s[] = "hello \xE0\xA4\xA4 world \xF0\x9F\x98\x80 \xC2\xA2";
  const size_t len = sizeof(s) - 1;
  const int iters = 1000000;
  double t = bench_ns([&]() {
    const char *p = s;
    const char *end = s + len;
    uint32_t acc = 0;
    while (p < end) acc += decodeUtf8Codepoint(p, end);
    g_sink += acc;
  }, iters, 10000);
  bench_report("decodeUtf8Codepoint (mixed)", t, iters);
}

static void bench_utf8_encode() {
  const int iters = 2000000;
  double t = bench_ns([&]() {
    std::string out;
    out.reserve(16);
    appendUtf8Codepoint(out, 0x1F600);
    g_sink += out.size();
  }, iters, 10000);
  bench_report("appendUtf8Codepoint (emoji)", t, iters);
}

static void bench_utf8_ascii_decode() {
  const char s[] = "the quick brown fox jumps over the lazy dog";
  const size_t len = sizeof(s) - 1;
  const int iters = 3000000;
  double t = bench_ns([&]() {
    const char *p = s;
    const char *end = s + len;
    uint32_t acc = 0;
    while (p < end) acc += decodeUtf8Codepoint(p, end);
    g_sink += acc;
  }, iters, 10000);
  bench_report("decodeUtf8Codepoint (ascii)", t, iters);
}


static void test_utf8_ascii() {
  const char *s = "abc";
  const char *p = s;
  const char *end = s + 3;
  CHECK(decodeUtf8Codepoint(p, end) == 'a');
  CHECK(p == s + 1);
  CHECK(decodeUtf8Codepoint(p, end) == 'b');
  CHECK(decodeUtf8Codepoint(p, end) == 'c');
  CHECK(p == end);
  CHECK(decodeUtf8Codepoint(p, end) == 0);
}

static void test_utf8_two_byte() {
  const char s[] = "\xC2\xA2"; // ¢ U+00A2
  const char *p = s;
  const char *end = s + 2;
  CHECK(decodeUtf8Codepoint(p, end) == 0x00A2);
  CHECK(p == end);
}

static void test_utf8_three_byte() {
  const char s[] = "\xE0\xA4\xA4"; // त U+0924
  const char *p = s;
  const char *end = s + 3;
  CHECK(decodeUtf8Codepoint(p, end) == 0x0924);
  CHECK(p == end);
}

static void test_utf8_four_byte() {
  const char s[] = "\xF0\x9F\x98\x80"; // 😀 U+1F600
  const char *p = s;
  const char *end = s + 4;
  CHECK(decodeUtf8Codepoint(p, end) == 0x1F600);
  CHECK(p == end);
}

static void test_utf8_truncated() {
  const char s[] = "\xE0\xA4"; // truncated 3-byte seq
  const char *p = s;
  const char *end = s + 2;
  CHECK(decodeUtf8Codepoint(p, end) == 0xFFFD);
  CHECK(p == s + 1);
}

static void test_utf8_overlong() {
  const char s[] = "\xC0\x80"; // overlong encoding of NUL
  const char *p = s;
  const char *end = s + 2;
  // lenient decoder: masks bits without rejecting overlongs -> NUL
  CHECK(decodeUtf8Codepoint(p, end) == 0x00);
  CHECK(p == s + 2);
}

static void test_utf8_bad_continuation() {
  // 0xE0 0x41 0x42: continuation bytes are not validated, bits are just masked
  const char s[] = "\xE0\x41\x42";
  const char *p = s;
  const char *end = s + 3;
  CHECK(decodeUtf8Codepoint(p, end) == 0x42);
  CHECK(p == s + 3);
}

static void test_utf8_bad_lead() {
  const char s[] = "\x80"; // continuation byte used as a lead
  const char *p = s;
  const char *end = s + 1;
  CHECK(decodeUtf8Codepoint(p, end) == 0xFFFD);
  CHECK(p == s + 1);
}

static void test_utf8_five_byte_lead() {
  const char s[] = "\xF8\x80\x80\x80"; // 5-byte lead is unsupported
  const char *p = s;
  const char *end = s + 4;
  CHECK(decodeUtf8Codepoint(p, end) == 0xFFFD);
  CHECK(p == s + 1);
}

static void test_utf8_short_2byte() {
  const char s[] = "\xC2"; // truncated 2-byte seq
  const char *p = s;
  const char *end = s + 1;
  CHECK(decodeUtf8Codepoint(p, end) == 0xFFFD);
  CHECK(p == s + 1);
}

static void test_utf8_surrogate_not_rejected() {
  // U+D800 in UTF-8: lenient decoder accepts it (no surrogate check)
  const char s[] = "\xED\xA0\x80";
  const char *p = s;
  const char *end = s + 3;
  CHECK(decodeUtf8Codepoint(p, end) == 0xD800);
  CHECK(p == s + 3);
}

static void test_utf8_max_codepoint() {
  const char s[] = "\xF4\x8F\xBF\xBF"; // U+10FFFF
  const char *p = s;
  const char *end = s + 4;
  CHECK(decodeUtf8Codepoint(p, end) == 0x10FFFF);
  CHECK(p == s + 4);
}

static void test_append_utf8_boundaries() {
  const uint32_t cps[] = { 0x7F, 0x80, 0x7FF, 0x800, 0xFFFF, 0x10000, 0x10FFFF };
  for (uint32_t cp : cps) {
    std::string out;
    appendUtf8Codepoint(out, cp);
    const char *p = out.data();
    const char *end = out.data() + out.size();
    CHECK(decodeUtf8Codepoint(p, end) == cp);
    CHECK(p == end);
  }
}

static void test_append_utf8_out_of_range() {
  // cp > U+10FFFF is not clamped; it round-trips (lenient)
  std::string out;
  appendUtf8Codepoint(out, 0x110000);
  const char *p = out.data();
  const char *end = out.data() + out.size();
  CHECK(decodeUtf8Codepoint(p, end) == 0x110000);
  CHECK(p == end);
}

static void test_append_utf8_byte_lengths() {
  std::string out;
  appendUtf8Codepoint(out, 0x41);    CHECK(out.size() == 1);
  out.clear(); appendUtf8Codepoint(out, 0xA2);   CHECK(out.size() == 2);
  out.clear(); appendUtf8Codepoint(out, 0x0924); CHECK(out.size() == 3);
  out.clear(); appendUtf8Codepoint(out, 0x1F600); CHECK(out.size() == 4);
}

static void test_append_utf8_roundtrip() {
  const uint32_t cps[] = { 0x41, 0x00A2, 0x0924, 0x1F600, 0x7F, 0x7FF, 0xFFFF };
  for (uint32_t cp : cps) {
    std::string out;
    appendUtf8Codepoint(out, cp);
    const char *p = out.data();
    const char *end = out.data() + out.size();
    CHECK(decodeUtf8Codepoint(p, end) == cp);
    CHECK(p == end);
  }
}

static void test_append_utf8_bytes() {
  std::string out;
  appendUtf8Codepoint(out, 0x41);
  CHECK(out == "A");
  out.clear();
  appendUtf8Codepoint(out, 0x00A2); // 2 bytes: 11000010 10100010
  CHECK(out.size() == 2);
  CHECK((unsigned char)out[0] == 0xC2);
  CHECK((unsigned char)out[1] == 0xA2);
}

static void test_hitbox() {
  ConcreteSkibidi s(5);
  CHECK(s.visible);
  CHECK(s.zindex == 5);

  s.setHitbox(10, 20, 30, 40);
  CHECK(s.hitX == 10 && s.hitY == 20 && s.hitW == 30 && s.hitH == 40);

  CHECK(s.hitTest(10, 20));
  CHECK(s.hitTest(39, 59));
  CHECK(!s.hitTest(9, 20));
  CHECK(!s.hitTest(40, 20));
  CHECK(!s.hitTest(10, 19));
  CHECK(!s.hitTest(10, 60));
}

static void test_hitbox_negative_size() {
  ConcreteSkibidi s(0);
  s.setHitbox(-10, -10, 20, 20);
  CHECK(s.hitTest(-10, -10));
  CHECK(s.hitTest(0, 0));
  CHECK(!s.hitTest(-11, 0));
  CHECK(!s.hitTest(10, 0));
}

static void test_frac() {
  ConcreteSkibidi s(1);
  CHECK(!s.hasFrac);
  s.setFrac(0.1f, 0.2f, 0.3f, 0.4f);
  CHECK(s.hasFrac);
  CHECK(s.frx == 0.1f && s.fry == 0.2f && s.frw == 0.3f && s.frh == 0.4f);
}

int main() {
  std::printf("== heck.hpp pure logic ==\n");
  test_utf8_ascii();
  test_utf8_two_byte();
  test_utf8_three_byte();
  test_utf8_four_byte();
  test_utf8_truncated();
  test_utf8_overlong();
  test_utf8_bad_continuation();
  test_utf8_bad_lead();
  test_utf8_five_byte_lead();
  test_utf8_short_2byte();
  test_utf8_surrogate_not_rejected();
  test_utf8_max_codepoint();
  test_append_utf8_roundtrip();
  test_append_utf8_bytes();
  test_append_utf8_boundaries();
  test_append_utf8_out_of_range();
  test_append_utf8_byte_lengths();
  test_hitbox();
  test_hitbox_negative_size();
  test_frac();

  std::printf("CPP TESTS: %d passed, %d failed (%d checks)\n",
              g_checks - g_failures, g_failures, g_checks);

  std::printf("\n== C++ micro-benchmarks ==\n");
  bench_hitbox();
  bench_utf8_decode();
  bench_utf8_ascii_decode();
  bench_utf8_encode();
  std::printf("  RSS: %ld KB\n", rss_kb());

  return g_failures == 0 ? 0 : 1;
}
