// C ABI over Windows.Media.Ocr for Dart FFI. Every call runs on its own
// multi-threaded-apartment thread, so callers in any COM apartment (the
// Flutter UI thread is single-threaded) may block on the async OCR APIs.
// Results are UTF-8 JSON strings released with cts_wocr_free.

#include <combaseapi.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Globalization.h>
#include <winrt/Windows.Graphics.Imaging.h>
#include <winrt/Windows.Media.Ocr.h>
#include <winrt/Windows.Storage.Streams.h>

#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <functional>
#include <string>
#include <thread>

using namespace winrt;
using namespace winrt::Windows::Globalization;
using namespace winrt::Windows::Graphics::Imaging;
using namespace winrt::Windows::Media::Ocr;
using namespace winrt::Windows::Storage::Streams;

namespace {

std::string escape(const std::string& s) {
  std::string out;
  out.reserve(s.size() + 2);
  for (unsigned char c : s) {
    // JSON string escaping; character codes keep the source free of
    // backslash sequences.
    constexpr char kBackslash = 92;
    switch (c) {
      case 34:  // quote
      case 92:  // backslash
        out.push_back(kBackslash);
        out.push_back(static_cast<char>(c));
        break;
      case 10:
        out.push_back(kBackslash);
        out.push_back('n');
        break;
      case 13:
        out.push_back(kBackslash);
        out.push_back('r');
        break;
      case 9:
        out.push_back(kBackslash);
        out.push_back('t');
        break;
      default:
        if (c < 0x20) {
          char buf[8];
          snprintf(buf, sizeof buf, "%cu%04x", kBackslash, c);
          out += buf;
        } else {
          out.push_back(static_cast<char>(c));
        }
    }
  }
  return out;
}

std::string str(const hstring& h) { return "\"" + escape(to_string(h)) + "\""; }

std::string num(double v) {
  char buf[32];
  snprintf(buf, sizeof buf, "%.3f", v);
  return buf;
}

char* dup(const std::string& s) {
  char* p = static_cast<char*>(std::malloc(s.size() + 1));
  if (p) std::memcpy(p, s.c_str(), s.size() + 1);
  return p;
}

// Runs [work] on a fresh MTA thread and returns its JSON (or an error JSON).
char* run_mta(const std::function<std::string()>& work) {
  // C++/WinRT caches activation factories process-wide; they die with the
  // multi-threaded apartment, which COM tears down when its last thread
  // leaves. Keep the MTA alive for the life of the process.
  static const bool mta_pinned = [] {
    CO_MTA_USAGE_COOKIE cookie{};
    return SUCCEEDED(CoIncrementMTAUsage(&cookie));
  }();
  (void)mta_pinned;

  std::string out;
  std::thread worker([&] {
    try {
      init_apartment(apartment_type::multi_threaded);
      out = work();
    } catch (const hresult_error& e) {
      char code[16];
      snprintf(code, sizeof code, "0x%08x", static_cast<uint32_t>(e.code()));
      out = std::string("{\"error\":") + str(e.message()) + ",\"hresult\":\"" + code + "\"}";
    } catch (const std::exception& e) {
      out = std::string("{\"error\":\"") + escape(e.what()) + "\"}";
    } catch (...) {
      out = "{\"error\":\"unknown error\"}";
    }
    uninit_apartment();
  });
  worker.join();
  return dup(out);
}

}  // namespace

extern "C" {

// {"languages":["en-US",...],"max_dimension":N}
__declspec(dllexport) char* cts_wocr_info() {
  return run_mta([] {
    std::string out = "{\"languages\":[";
    bool first = true;
    for (const auto& lang : OcrEngine::AvailableRecognizerLanguages()) {
      if (!first) out += ",";
      first = false;
      out += str(lang.LanguageTag());
    }
    out += "],\"max_dimension\":" + std::to_string(OcrEngine::MaxImageDimension()) + "}";
    return out;
  });
}

// Recognizes an RGB image. [language_tag] is a BCP-47 tag such as "en-US";
// empty uses the user's profile languages.
// {"language":"en-US","angle":null,"lines":[{"text":"...","words":[{"text","x","y","w","h"}]}]}
__declspec(dllexport) char* cts_wocr_recognize(const uint8_t* rgb, int32_t width, int32_t height,
                                               const char* language_tag) {
  const std::string tag = language_tag ? language_tag : "";
  return run_mta([=] {
    OcrEngine engine{nullptr};
    if (tag.empty()) {
      engine = OcrEngine::TryCreateFromUserProfileLanguages();
    } else {
      Language lang{to_hstring(tag)};
      if (!OcrEngine::IsLanguageSupported(lang)) {
        return std::string("{\"error\":\"language not installed\",\"language\":\"") + escape(tag) + "\"}";
      }
      engine = OcrEngine::TryCreateFromLanguage(lang);
    }
    if (!engine) return std::string("{\"error\":\"no OCR engine available\"}");

    SoftwareBitmap bitmap(BitmapPixelFormat::Bgra8, width, height, BitmapAlphaMode::Premultiplied);
    const uint32_t size = static_cast<uint32_t>(width) * static_cast<uint32_t>(height) * 4;
    Buffer buffer(size);
    buffer.Length(size);
    uint8_t* dst = buffer.data();
    const size_t pixels = static_cast<size_t>(width) * height;
    for (size_t i = 0; i < pixels; i++) {
      dst[i * 4 + 0] = rgb[i * 3 + 2];
      dst[i * 4 + 1] = rgb[i * 3 + 1];
      dst[i * 4 + 2] = rgb[i * 3 + 0];
      dst[i * 4 + 3] = 255;
    }
    bitmap.CopyFromBuffer(buffer);

    const OcrResult result = engine.RecognizeAsync(bitmap).get();
    std::string out = "{\"language\":" + str(engine.RecognizerLanguage().LanguageTag()) + ",\"angle\":";
    const auto angle = result.TextAngle();
    out += angle ? num(angle.Value()) : "null";
    out += ",\"lines\":[";
    bool firstLine = true;
    for (const auto& line : result.Lines()) {
      if (!firstLine) out += ",";
      firstLine = false;
      out += "{\"text\":" + str(line.Text()) + ",\"words\":[";
      bool firstWord = true;
      for (const auto& word : line.Words()) {
        if (!firstWord) out += ",";
        firstWord = false;
        const auto r = word.BoundingRect();
        out += "{\"text\":" + str(word.Text()) + ",\"x\":" + num(r.X) + ",\"y\":" + num(r.Y) + ",\"w\":" +
               num(r.Width) + ",\"h\":" + num(r.Height) + "}";
      }
      out += "]}";
    }
    out += "]}";
    return out;
  });
}

__declspec(dllexport) void cts_wocr_free(char* p) { std::free(p); }

}  // extern "C"
