// SPDX-License-Identifier: Apache-2.0

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <msi.h>
#include <msiquery.h>
#include <objbase.h>
#include <shellapi.h>
#include <winhttp.h>

#include <algorithm>
#include <cstring>
#include <string>
#include <vector>

#pragma comment(lib, "msi.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "winhttp.lib")

#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:FetchAdvert=_FetchAdvert@4")
#pragma comment(linker, "/EXPORT:OpenAdvertLink=_OpenAdvertLink@4")
#else
#pragma comment(linker, "/EXPORT:FetchAdvert")
#pragma comment(linker, "/EXPORT:OpenAdvertLink")
#endif

namespace
{
constexpr DWORD kMaxAdvertBytes = 1024U * 1024U;
constexpr DWORD kMaxApiResponseBytes = 64U * 1024U;
constexpr DWORD kDownloadBufferBytes = 64U * 1024U;
constexpr DWORD kImageHeaderBytes = 64U * 1024U;
constexpr DWORD kMaxAdvertUrlCharacters = 2048U;
constexpr wchar_t kRemoteAdvertBinaryId[] = L"AdvertRemote";
constexpr wchar_t kAdvertClickUrlProperty[] = L"AdvertClickUrl";
constexpr int kAdvertControlAttributes = 0x00000007; // visible, enabled, sunken
constexpr int kAdvertButtonAttributes = 0x00040003; // visible, enabled, bitmap
constexpr int kProgressDialogWidth = 370;
constexpr int kAdvertAreaY = 130;
constexpr int kAdvertAreaWidth = 330;
constexpr int kAdvertAreaHeight = 90;

enum class JsonAdvertResult
{
    found,
    empty,
    invalid
};

class InternetHandle
{
public:
    explicit InternetHandle(HINTERNET handle = nullptr) noexcept : handle_(handle) {}
    ~InternetHandle()
    {
        if (handle_ != nullptr)
        {
            WinHttpCloseHandle(handle_);
        }
    }

    InternetHandle(const InternetHandle&) = delete;
    InternetHandle& operator=(const InternetHandle&) = delete;

    HINTERNET Get() const noexcept { return handle_; }

private:
    HINTERNET handle_;
};

class InstallerHandle
{
public:
    explicit InstallerHandle(MSIHANDLE handle = 0) noexcept : handle_(handle) {}
    ~InstallerHandle()
    {
        if (handle_ != 0)
        {
            MsiCloseHandle(handle_);
        }
    }

    InstallerHandle(const InstallerHandle&) = delete;
    InstallerHandle& operator=(const InstallerHandle&) = delete;

    MSIHANDLE Get() const noexcept { return handle_; }

private:
    MSIHANDLE handle_;
};

class FileHandle
{
public:
    explicit FileHandle(HANDLE handle = INVALID_HANDLE_VALUE) noexcept : handle_(handle) {}
    ~FileHandle() { Close(); }

    FileHandle(const FileHandle&) = delete;
    FileHandle& operator=(const FileHandle&) = delete;

    HANDLE Get() const noexcept { return handle_; }

    void Close() noexcept
    {
        if (handle_ != INVALID_HANDLE_VALUE)
        {
            CloseHandle(handle_);
            handle_ = INVALID_HANDLE_VALUE;
        }
    }

private:
    HANDLE handle_;
};

void LogMessage(MSIHANDLE install, const wchar_t* message) noexcept
{
    InstallerHandle record(MsiCreateRecord(1));
    if (record.Get() == 0)
    {
        return;
    }

    MsiRecordSetStringW(record.Get(), 0, L"Remote advert: [1]");
    MsiRecordSetStringW(record.Get(), 1, message);
    MsiProcessMessage(install, INSTALLMESSAGE_INFO, record.Get());
}

void LogFailure(MSIHANDLE install, const wchar_t* message, DWORD error) noexcept
{
    InstallerHandle record(MsiCreateRecord(2));
    if (record.Get() == 0)
    {
        return;
    }

    MsiRecordSetStringW(record.Get(), 0, L"Remote advert: [1] (error [2]).");
    MsiRecordSetStringW(record.Get(), 1, message);
    MsiRecordSetInteger(record.Get(), 2, static_cast<int>(error));
    MsiProcessMessage(install, INSTALLMESSAGE_INFO, record.Get());
}

bool GetProperty(MSIHANDLE install, const wchar_t* name, std::wstring& value) noexcept
{
    wchar_t emptyBuffer = L'\0';
    DWORD characterCount = 0;
    UINT result = MsiGetPropertyW(install, name, &emptyBuffer, &characterCount);
    if (result != ERROR_SUCCESS && result != ERROR_MORE_DATA)
    {
        return false;
    }

    if (characterCount == 0)
    {
        value.clear();
        return true;
    }

    try
    {
        std::vector<wchar_t> buffer(static_cast<size_t>(characterCount) + 1U, L'\0');
        DWORD bufferCharacters = characterCount + 1U;
        result = MsiGetPropertyW(install, name, buffer.data(), &bufferCharacters);
        if (result != ERROR_SUCCESS)
        {
            return false;
        }

        value.assign(buffer.data(), bufferCharacters);
        return true;
    }
    catch (...)
    {
        return false;
    }
}

bool WideToUtf8(const std::wstring& value, std::string& utf8) noexcept
{
    if (value.empty())
    {
        utf8.clear();
        return true;
    }

    const int byteCount = WideCharToMultiByte(
        CP_UTF8, WC_ERR_INVALID_CHARS, value.data(), static_cast<int>(value.size()),
        nullptr, 0, nullptr, nullptr);
    if (byteCount <= 0)
    {
        return false;
    }

    try
    {
        utf8.resize(static_cast<size_t>(byteCount));
    }
    catch (...)
    {
        return false;
    }

    return WideCharToMultiByte(
        CP_UTF8, WC_ERR_INVALID_CHARS, value.data(), static_cast<int>(value.size()),
        &utf8[0], byteCount, nullptr, nullptr) == byteCount;
}

bool Utf8ToWide(const std::string& utf8, std::wstring& value) noexcept
{
    if (utf8.empty())
    {
        value.clear();
        return true;
    }

    const int characterCount = MultiByteToWideChar(
        CP_UTF8, MB_ERR_INVALID_CHARS, utf8.data(), static_cast<int>(utf8.size()), nullptr, 0);
    if (characterCount <= 0)
    {
        return false;
    }

    try
    {
        value.resize(static_cast<size_t>(characterCount));
    }
    catch (...)
    {
        return false;
    }

    return MultiByteToWideChar(
        CP_UTF8, MB_ERR_INVALID_CHARS, utf8.data(), static_cast<int>(utf8.size()),
        &value[0], characterCount) == characterCount;
}

void AppendJsonEscaped(const std::string& value, std::string& output)
{
    constexpr char hexadecimal[] = "0123456789abcdef";
    for (const unsigned char character : value)
    {
        switch (character)
        {
        case '"': output.append("\\\""); break;
        case '\\': output.append("\\\\"); break;
        case '\b': output.append("\\b"); break;
        case '\f': output.append("\\f"); break;
        case '\n': output.append("\\n"); break;
        case '\r': output.append("\\r"); break;
        case '\t': output.append("\\t"); break;
        default:
            if (character < 0x20)
            {
                output.append("\\u00");
                output.push_back(hexadecimal[character >> 4]);
                output.push_back(hexadecimal[character & 0x0f]);
            }
            else
            {
                output.push_back(static_cast<char>(character));
            }
            break;
        }
    }
}

bool AppendJsonPropertyValue(
    MSIHANDLE install,
    const wchar_t* property,
    std::string& payload) noexcept
{
    std::wstring value;
    std::string utf8;
    if (!GetProperty(install, property, value) || value.empty() || !WideToUtf8(value, utf8))
    {
        return false;
    }

    try
    {
        AppendJsonEscaped(utf8, payload);
        return true;
    }
    catch (...)
    {
        return false;
    }
}

class JsonReader
{
public:
    JsonReader(const char* bytes, size_t byteCount) noexcept
        : current_(bytes), end_(bytes + byteCount)
    {
    }

    JsonAdvertResult ReadFirstAdvert(std::string& image, std::string& clickUrl)
    {
        if (!Consume('['))
        {
            return JsonAdvertResult::invalid;
        }

        SkipWhitespace();
        if (Consume(']'))
        {
            SkipWhitespace();
            return current_ == end_ ? JsonAdvertResult::empty : JsonAdvertResult::invalid;
        }

        if (!Consume('{'))
        {
            return JsonAdvertResult::invalid;
        }

        bool foundImage = false;
        bool foundClickUrl = false;
        SkipWhitespace();
        if (!Consume('}'))
        {
            for (;;)
            {
                std::string name;
                if (!ReadString(name) || !Consume(':'))
                {
                    return JsonAdvertResult::invalid;
                }

                if (name == "image")
                {
                    if (foundImage || !ReadString(image) || image.empty())
                    {
                        return JsonAdvertResult::invalid;
                    }
                    foundImage = true;
                }
                else if (name == "url")
                {
                    if (foundClickUrl)
                    {
                        return JsonAdvertResult::invalid;
                    }
                    // A missing, null, or non-string click URL leaves the banner
                    // displayed without a link.
                    SkipWhitespace();
                    if (current_ != end_ && *current_ == '"')
                    {
                        if (!ReadString(clickUrl))
                        {
                            return JsonAdvertResult::invalid;
                        }
                    }
                    else if (!SkipValue(0))
                    {
                        return JsonAdvertResult::invalid;
                    }
                    foundClickUrl = true;
                }
                else if (!SkipValue(0))
                {
                    return JsonAdvertResult::invalid;
                }

                if (Consume('}'))
                {
                    break;
                }
                if (!Consume(','))
                {
                    return JsonAdvertResult::invalid;
                }
            }
        }

        while (Consume(','))
        {
            if (!SkipValue(0))
            {
                return JsonAdvertResult::invalid;
            }
        }

        if (!Consume(']'))
        {
            return JsonAdvertResult::invalid;
        }
        SkipWhitespace();
        return current_ == end_ && foundImage ? JsonAdvertResult::found : JsonAdvertResult::invalid;
    }

private:
    void SkipWhitespace() noexcept
    {
        while (current_ != end_ &&
            (*current_ == ' ' || *current_ == '\t' || *current_ == '\r' || *current_ == '\n'))
        {
            ++current_;
        }
    }

    bool Consume(char expected) noexcept
    {
        SkipWhitespace();
        if (current_ == end_ || *current_ != expected)
        {
            return false;
        }
        ++current_;
        return true;
    }

    static bool IsHexadecimal(char character) noexcept
    {
        return (character >= '0' && character <= '9') ||
            (character >= 'a' && character <= 'f') ||
            (character >= 'A' && character <= 'F');
    }

    static unsigned int HexadecimalValue(char character) noexcept
    {
        if (character >= '0' && character <= '9')
        {
            return static_cast<unsigned int>(character - '0');
        }
        if (character >= 'a' && character <= 'f')
        {
            return static_cast<unsigned int>(character - 'a' + 10);
        }
        return static_cast<unsigned int>(character - 'A' + 10);
    }

    bool ReadCodeUnit(unsigned int& codeUnit) noexcept
    {
        if (static_cast<size_t>(end_ - current_) < 4)
        {
            return false;
        }

        codeUnit = 0;
        for (int index = 0; index < 4; ++index)
        {
            if (!IsHexadecimal(current_[index]))
            {
                return false;
            }
            codeUnit = (codeUnit << 4) | HexadecimalValue(current_[index]);
        }
        current_ += 4;
        return true;
    }

    static bool AppendCodePoint(unsigned int codePoint, std::string& value)
    {
        if (codePoint <= 0x7f)
        {
            value.push_back(static_cast<char>(codePoint));
        }
        else if (codePoint <= 0x7ff)
        {
            value.push_back(static_cast<char>(0xc0 | (codePoint >> 6)));
            value.push_back(static_cast<char>(0x80 | (codePoint & 0x3f)));
        }
        else if (codePoint <= 0xffff)
        {
            value.push_back(static_cast<char>(0xe0 | (codePoint >> 12)));
            value.push_back(static_cast<char>(0x80 | ((codePoint >> 6) & 0x3f)));
            value.push_back(static_cast<char>(0x80 | (codePoint & 0x3f)));
        }
        else if (codePoint <= 0x10ffff)
        {
            value.push_back(static_cast<char>(0xf0 | (codePoint >> 18)));
            value.push_back(static_cast<char>(0x80 | ((codePoint >> 12) & 0x3f)));
            value.push_back(static_cast<char>(0x80 | ((codePoint >> 6) & 0x3f)));
            value.push_back(static_cast<char>(0x80 | (codePoint & 0x3f)));
        }
        else
        {
            return false;
        }
        return true;
    }

    bool ReadString(std::string& value)
    {
        SkipWhitespace();
        if (current_ == end_ || *current_ != '"')
        {
            return false;
        }
        ++current_;
        value.clear();

        while (current_ != end_)
        {
            const unsigned char character = static_cast<unsigned char>(*current_++);
            if (character == '"')
            {
                return true;
            }
            if (character < 0x20)
            {
                return false;
            }
            if (character != '\\')
            {
                value.push_back(static_cast<char>(character));
                continue;
            }
            if (current_ == end_)
            {
                return false;
            }

            const char escaped = *current_++;
            switch (escaped)
            {
            case '"': value.push_back('"'); break;
            case '\\': value.push_back('\\'); break;
            case '/': value.push_back('/'); break;
            case 'b': value.push_back('\b'); break;
            case 'f': value.push_back('\f'); break;
            case 'n': value.push_back('\n'); break;
            case 'r': value.push_back('\r'); break;
            case 't': value.push_back('\t'); break;
            case 'u':
            {
                unsigned int codePoint = 0;
                if (!ReadCodeUnit(codePoint))
                {
                    return false;
                }
                if (codePoint >= 0xd800 && codePoint <= 0xdbff)
                {
                    if (static_cast<size_t>(end_ - current_) < 6 || current_[0] != '\\' || current_[1] != 'u')
                    {
                        return false;
                    }
                    current_ += 2;
                    unsigned int lowSurrogate = 0;
                    if (!ReadCodeUnit(lowSurrogate) || lowSurrogate < 0xdc00 || lowSurrogate > 0xdfff)
                    {
                        return false;
                    }
                    codePoint = 0x10000 + ((codePoint - 0xd800) << 10) + (lowSurrogate - 0xdc00);
                }
                else if (codePoint >= 0xdc00 && codePoint <= 0xdfff)
                {
                    return false;
                }
                if (!AppendCodePoint(codePoint, value))
                {
                    return false;
                }
                break;
            }
            default: return false;
            }
        }
        return false;
    }

    bool SkipValue(unsigned int depth)
    {
        if (depth > 32)
        {
            return false;
        }

        SkipWhitespace();
        if (current_ == end_)
        {
            return false;
        }
        if (*current_ == '"')
        {
            std::string discarded;
            return ReadString(discarded);
        }
        if (*current_ == '{')
        {
            ++current_;
            SkipWhitespace();
            if (Consume('}'))
            {
                return true;
            }
            for (;;)
            {
                std::string name;
                if (!ReadString(name) || !Consume(':') || !SkipValue(depth + 1))
                {
                    return false;
                }
                if (Consume('}'))
                {
                    return true;
                }
                if (!Consume(','))
                {
                    return false;
                }
            }
        }
        if (*current_ == '[')
        {
            ++current_;
            SkipWhitespace();
            if (Consume(']'))
            {
                return true;
            }
            for (;;)
            {
                if (!SkipValue(depth + 1))
                {
                    return false;
                }
                if (Consume(']'))
                {
                    return true;
                }
                if (!Consume(','))
                {
                    return false;
                }
            }
        }
        if (MatchLiteral("true") || MatchLiteral("false") || MatchLiteral("null"))
        {
            return true;
        }
        return SkipNumber();
    }

    bool MatchLiteral(const char* literal) noexcept
    {
        const size_t length = std::strlen(literal);
        if (static_cast<size_t>(end_ - current_) < length ||
            std::memcmp(current_, literal, length) != 0)
        {
            return false;
        }
        current_ += length;
        return true;
    }

    bool SkipNumber() noexcept
    {
        const char* start = current_;
        if (current_ != end_ && *current_ == '-')
        {
            ++current_;
        }
        if (current_ == end_)
        {
            current_ = start;
            return false;
        }
        if (*current_ == '0')
        {
            ++current_;
        }
        else if (*current_ >= '1' && *current_ <= '9')
        {
            while (current_ != end_ && *current_ >= '0' && *current_ <= '9')
            {
                ++current_;
            }
        }
        else
        {
            current_ = start;
            return false;
        }
        if (current_ != end_ && *current_ == '.')
        {
            ++current_;
            const char* fraction = current_;
            while (current_ != end_ && *current_ >= '0' && *current_ <= '9')
            {
                ++current_;
            }
            if (current_ == fraction)
            {
                current_ = start;
                return false;
            }
        }
        if (current_ != end_ && (*current_ == 'e' || *current_ == 'E'))
        {
            ++current_;
            if (current_ != end_ && (*current_ == '+' || *current_ == '-'))
            {
                ++current_;
            }
            const char* exponent = current_;
            while (current_ != end_ && *current_ >= '0' && *current_ <= '9')
            {
                ++current_;
            }
            if (current_ == exponent)
            {
                current_ = start;
                return false;
            }
        }
        return true;
    }

    const char* current_;
    const char* end_;
};

bool ParseAdvertUrl(
    const std::wstring& url,
    std::wstring& host,
    INTERNET_PORT& port,
    std::wstring& objectName,
    bool& secure,
    DWORD& error) noexcept
{
    if (url.empty() || url.size() > kMaxAdvertUrlCharacters || url.find(L'#') != std::wstring::npos)
    {
        error = ERROR_INVALID_PARAMETER;
        return false;
    }

    for (const wchar_t character : url)
    {
        if (character <= L' ')
        {
            error = ERROR_INVALID_PARAMETER;
            return false;
        }
    }

    URL_COMPONENTS components{};
    components.dwStructSize = sizeof(components);
    components.dwSchemeLength = static_cast<DWORD>(-1);
    components.dwHostNameLength = static_cast<DWORD>(-1);
    components.dwUserNameLength = static_cast<DWORD>(-1);
    components.dwPasswordLength = static_cast<DWORD>(-1);
    components.dwUrlPathLength = static_cast<DWORD>(-1);
    components.dwExtraInfoLength = static_cast<DWORD>(-1);

    if (!WinHttpCrackUrl(url.c_str(), static_cast<DWORD>(url.size()), 0, &components))
    {
        error = GetLastError();
        return false;
    }

    if ((components.nScheme != INTERNET_SCHEME_HTTPS && components.nScheme != INTERNET_SCHEME_HTTP) ||
        components.dwHostNameLength == 0 ||
        components.dwUserNameLength != 0 ||
        components.dwPasswordLength != 0)
    {
        error = ERROR_INVALID_PARAMETER;
        return false;
    }

    try
    {
        host.assign(components.lpszHostName, components.dwHostNameLength);
        if (components.dwUrlPathLength == 0)
        {
            objectName.assign(L"/");
        }
        else
        {
            objectName.assign(components.lpszUrlPath, components.dwUrlPathLength);
        }

        if (components.dwExtraInfoLength != 0)
        {
            objectName.append(components.lpszExtraInfo, components.dwExtraInfoLength);
        }
    }
    catch (...)
    {
        error = ERROR_NOT_ENOUGH_MEMORY;
        return false;
    }

    secure = components.nScheme == INTERNET_SCHEME_HTTPS;
    const bool loopbackHost =
        _wcsicmp(host.c_str(), L"localhost") == 0 ||
        _wcsicmp(host.c_str(), L"127.0.0.1") == 0 ||
        _wcsicmp(host.c_str(), L"::1") == 0;
    if (!secure && !loopbackHost)
    {
        error = ERROR_ACCESS_DENIED;
        return false;
    }

    port = components.nPort == 0
        ? (secure ? INTERNET_DEFAULT_HTTPS_PORT : INTERNET_DEFAULT_HTTP_PORT)
        : components.nPort;
    return true;
}

bool HasSupportedImageSignature(const BYTE* bytes, DWORD byteCount) noexcept
{
    const bool isJpeg = byteCount >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff;
    const bool isBitmap = byteCount >= 2 && bytes[0] == 'B' && bytes[1] == 'M';
    const BYTE pngSignature[] = {0x89, 'P', 'N', 'G', 0x0d, 0x0a, 0x1a, 0x0a};
    const bool isPng = byteCount >= sizeof(pngSignature) &&
        std::memcmp(bytes, pngSignature, sizeof(pngSignature)) == 0;
    return isJpeg || isBitmap || isPng;
}

DWORD ReadBigEndian32(const BYTE* bytes) noexcept
{
    return (static_cast<DWORD>(bytes[0]) << 24) |
        (static_cast<DWORD>(bytes[1]) << 16) |
        (static_cast<DWORD>(bytes[2]) << 8) |
        static_cast<DWORD>(bytes[3]);
}

DWORD ReadLittleEndian32(const BYTE* bytes) noexcept
{
    return static_cast<DWORD>(bytes[0]) |
        (static_cast<DWORD>(bytes[1]) << 8) |
        (static_cast<DWORD>(bytes[2]) << 16) |
        (static_cast<DWORD>(bytes[3]) << 24);
}

bool ReadImageDimensions(
    const std::wstring& imageFile,
    DWORD& width,
    DWORD& height) noexcept
{
    FileHandle file(CreateFileW(
        imageFile.c_str(),
        GENERIC_READ,
        FILE_SHARE_READ,
        nullptr,
        OPEN_EXISTING,
        FILE_FLAG_SEQUENTIAL_SCAN,
        nullptr));
    if (file.Get() == INVALID_HANDLE_VALUE)
    {
        return false;
    }

    std::vector<BYTE> header;
    try
    {
        header.resize(kImageHeaderBytes);
    }
    catch (...)
    {
        return false;
    }

    DWORD bytesRead = 0;
    if (!ReadFile(file.Get(), header.data(), static_cast<DWORD>(header.size()), &bytesRead, nullptr))
    {
        return false;
    }
    header.resize(bytesRead);

    const BYTE pngSignature[] = {0x89, 'P', 'N', 'G', 0x0d, 0x0a, 0x1a, 0x0a};
    if (header.size() >= 24 &&
        std::memcmp(header.data(), pngSignature, sizeof(pngSignature)) == 0)
    {
        width = ReadBigEndian32(header.data() + 16);
        height = ReadBigEndian32(header.data() + 20);
        return width != 0 && height != 0;
    }

    if (header.size() >= 26 && header[0] == 'B' && header[1] == 'M')
    {
        const LONG bitmapWidth = static_cast<LONG>(ReadLittleEndian32(header.data() + 18));
        const LONG bitmapHeight = static_cast<LONG>(ReadLittleEndian32(header.data() + 22));
        if (bitmapWidth <= 0 || bitmapHeight == 0 || bitmapHeight == LONG_MIN)
        {
            return false;
        }
        width = static_cast<DWORD>(bitmapWidth);
        height = static_cast<DWORD>(bitmapHeight < 0 ? -bitmapHeight : bitmapHeight);
        return true;
    }

    if (header.size() < 4 || header[0] != 0xff || header[1] != 0xd8)
    {
        return false;
    }

    size_t offset = 2;
    while (offset + 4 <= header.size())
    {
        if (header[offset] != 0xff)
        {
            ++offset;
            continue;
        }
        while (offset < header.size() && header[offset] == 0xff)
        {
            ++offset;
        }
        if (offset == header.size())
        {
            break;
        }

        const BYTE marker = header[offset++];
        if (marker == 0xd8 || marker == 0xd9 || marker == 0x01 ||
            (marker >= 0xd0 && marker <= 0xd7))
        {
            continue;
        }
        if (offset + 2 > header.size())
        {
            break;
        }

        const size_t segmentLength =
            (static_cast<size_t>(header[offset]) << 8) | header[offset + 1];
        if (segmentLength < 2 || segmentLength > header.size() - offset)
        {
            break;
        }

        const bool isStartOfFrame =
            (marker >= 0xc0 && marker <= 0xc3) ||
            (marker >= 0xc5 && marker <= 0xc7) ||
            (marker >= 0xc9 && marker <= 0xcb) ||
            (marker >= 0xcd && marker <= 0xcf);
        if (isStartOfFrame && segmentLength >= 7)
        {
            height = (static_cast<DWORD>(header[offset + 3]) << 8) | header[offset + 4];
            width = (static_cast<DWORD>(header[offset + 5]) << 8) | header[offset + 6];
            return width != 0 && height != 0;
        }
        offset += segmentLength;
    }

    return false;
}

bool RequestAdvertImageUrl(
    MSIHANDLE install,
    const std::wstring& apiUrl,
    std::wstring& imageUrl,
    std::wstring& clickUrl,
    bool& noAdvert,
    const wchar_t*& failureReason,
    DWORD& error) noexcept
{
    noAdvert = false;

    std::string payload;
    try
    {
        payload.assign("{\"host\":\"");
        if (!AppendJsonPropertyValue(install, L"AdvertApiHost", payload))
        {
            failureReason = L"the API host value is missing or invalid";
            error = ERROR_INVALID_DATA;
            return false;
        }
        payload.append("\",\"source\":\"");
        if (!AppendJsonPropertyValue(install, L"AdvertApiSource", payload))
        {
            failureReason = L"the API source value is missing or invalid";
            error = ERROR_INVALID_DATA;
            return false;
        }
        payload.append("\",\"publish_to\":\"");
        if (!AppendJsonPropertyValue(install, L"AdvertApiPublishTo", payload))
        {
            failureReason = L"the API publication target is missing or invalid";
            error = ERROR_INVALID_DATA;
            return false;
        }
        payload.append("\",\"format\":{\"");
        if (!AppendJsonPropertyValue(install, L"AdvertApiFormat", payload))
        {
            failureReason = L"the API advert format is missing or invalid";
            error = ERROR_INVALID_DATA;
            return false;
        }
        payload.append("\":1}}");
    }
    catch (...)
    {
        failureReason = L"the API request could not be created";
        error = ERROR_NOT_ENOUGH_MEMORY;
        return false;
    }

    std::wstring host;
    std::wstring objectName;
    INTERNET_PORT port = INTERNET_DEFAULT_HTTPS_PORT;
    bool secure = true;
    if (!ParseAdvertUrl(apiUrl, host, port, objectName, secure, error))
    {
        failureReason = L"the API URL must be credential-free HTTPS";
        return false;
    }
    if (!secure)
    {
        failureReason = L"the API URL must use HTTPS";
        error = ERROR_ACCESS_DENIED;
        return false;
    }

    InternetHandle session(WinHttpOpen(
        L"Eclipse-Adoptium-MSI-Advert/1.0",
        WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
        WINHTTP_NO_PROXY_NAME,
        WINHTTP_NO_PROXY_BYPASS,
        0));
    if (session.Get() == nullptr)
    {
        error = GetLastError();
        failureReason = L"WinHTTP initialization failed";
        return false;
    }

    if (!WinHttpSetTimeouts(session.Get(), 1500, 1500, 1500, 3000))
    {
        error = GetLastError();
        failureReason = L"WinHTTP timeout configuration failed";
        return false;
    }

    if (secure)
    {
        DWORD secureProtocols = WINHTTP_FLAG_SECURE_PROTOCOL_TLS1_2;
        if (!WinHttpSetOption(
                session.Get(), WINHTTP_OPTION_SECURE_PROTOCOLS, &secureProtocols, sizeof(secureProtocols)))
        {
            error = GetLastError();
            failureReason = L"TLS 1.2 is unavailable";
            return false;
        }
    }

    InternetHandle connection(WinHttpConnect(session.Get(), host.c_str(), port, 0));
    if (connection.Get() == nullptr)
    {
        error = GetLastError();
        failureReason = L"the API connection failed";
        return false;
    }

    const wchar_t* acceptedTypes[] = {L"application/json", nullptr};
    InternetHandle request(WinHttpOpenRequest(
        connection.Get(),
        L"POST",
        objectName.c_str(),
        nullptr,
        WINHTTP_NO_REFERER,
        acceptedTypes,
        (secure ? WINHTTP_FLAG_SECURE : 0) | WINHTTP_FLAG_REFRESH));
    if (request.Get() == nullptr)
    {
        error = GetLastError();
        failureReason = L"the API request could not be created";
        return false;
    }

    DWORD redirectPolicy = WINHTTP_OPTION_REDIRECT_POLICY_NEVER;
    if (!WinHttpSetOption(
            request.Get(), WINHTTP_OPTION_REDIRECT_POLICY, &redirectPolicy, sizeof(redirectPolicy)))
    {
        error = GetLastError();
        failureReason = L"API redirect protection could not be enabled";
        return false;
    }

    const wchar_t headers[] =
        L"Accept: application/json\r\n"
        L"Content-Type: application/json; charset=utf-8\r\n"
        L"Cache-Control: no-cache";
    if (!WinHttpSendRequest(
            request.Get(),
            headers,
            static_cast<DWORD>(-1),
            payload.empty() ? WINHTTP_NO_REQUEST_DATA : &payload[0],
            static_cast<DWORD>(payload.size()),
            static_cast<DWORD>(payload.size()),
            0) ||
        !WinHttpReceiveResponse(request.Get(), nullptr))
    {
        error = GetLastError();
        failureReason = L"the API request failed";
        return false;
    }

    DWORD statusCode = 0;
    DWORD statusCodeBytes = sizeof(statusCode);
    if (!WinHttpQueryHeaders(
            request.Get(),
            WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
            WINHTTP_HEADER_NAME_BY_INDEX,
            &statusCode,
            &statusCodeBytes,
            WINHTTP_NO_HEADER_INDEX))
    {
        error = GetLastError();
        failureReason = L"the API response status could not be read";
        return false;
    }
    if (statusCode == 406)
    {
        noAdvert = true;
        return true;
    }
    if (statusCode != 200)
    {
        error = statusCode;
        failureReason = L"the API did not return HTTP 200";
        return false;
    }

    DWORD contentLength = 0;
    DWORD contentLengthBytes = sizeof(contentLength);
    if (WinHttpQueryHeaders(
            request.Get(),
            WINHTTP_QUERY_CONTENT_LENGTH | WINHTTP_QUERY_FLAG_NUMBER,
            WINHTTP_HEADER_NAME_BY_INDEX,
            &contentLength,
            &contentLengthBytes,
            WINHTTP_NO_HEADER_INDEX) &&
        contentLength > kMaxApiResponseBytes)
    {
        error = ERROR_FILE_TOO_LARGE;
        failureReason = L"the API response exceeds the 64 KiB limit";
        return false;
    }

    std::vector<BYTE> buffer;
    std::string response;
    try
    {
        buffer.resize(kDownloadBufferBytes);
        if (contentLength != 0)
        {
            response.reserve(contentLength);
        }
    }
    catch (...)
    {
        error = ERROR_NOT_ENOUGH_MEMORY;
        failureReason = L"memory allocation failed";
        return false;
    }

    for (;;)
    {
        DWORD availableBytes = 0;
        if (!WinHttpQueryDataAvailable(request.Get(), &availableBytes))
        {
            error = GetLastError();
            failureReason = L"the API response could not be read";
            return false;
        }
        if (availableBytes == 0)
        {
            break;
        }
        if (availableBytes > kMaxApiResponseBytes - response.size())
        {
            error = ERROR_FILE_TOO_LARGE;
            failureReason = L"the API response exceeds the 64 KiB limit";
            return false;
        }

        while (availableBytes != 0)
        {
            const DWORD bytesToRead = (std::min)(availableBytes, kDownloadBufferBytes);
            DWORD bytesRead = 0;
            if (!WinHttpReadData(request.Get(), buffer.data(), bytesToRead, &bytesRead) || bytesRead == 0)
            {
                error = GetLastError();
                if (error == ERROR_SUCCESS)
                {
                    error = ERROR_INVALID_DATA;
                }
                failureReason = L"the API response ended unexpectedly";
                return false;
            }
            try
            {
                response.append(reinterpret_cast<const char*>(buffer.data()), bytesRead);
            }
            catch (...)
            {
                error = ERROR_NOT_ENOUGH_MEMORY;
                failureReason = L"memory allocation failed";
                return false;
            }
            availableBytes -= bytesRead;
        }
    }

    std::string imageUtf8;
    std::string clickUrlUtf8;
    const JsonAdvertResult parsed =
        JsonReader(response.data(), response.size()).ReadFirstAdvert(imageUtf8, clickUrlUtf8);
    if (parsed == JsonAdvertResult::empty)
    {
        noAdvert = true;
        return true;
    }
    if (parsed != JsonAdvertResult::found || !Utf8ToWide(imageUtf8, imageUrl))
    {
        error = ERROR_INVALID_DATA;
        failureReason = L"the API returned invalid advert JSON";
        return false;
    }
    if (!clickUrlUtf8.empty() && !Utf8ToWide(clickUrlUtf8, clickUrl))
    {
        clickUrl.clear();
    }

    return true;
}

bool IsAllowedClickUrl(const std::wstring& url) noexcept
{
    std::wstring host;
    std::wstring objectName;
    INTERNET_PORT port = INTERNET_DEFAULT_HTTPS_PORT;
    bool secure = true;
    DWORD error = ERROR_SUCCESS;
    try
    {
        return ParseAdvertUrl(url, host, port, objectName, secure, error);
    }
    catch (...)
    {
        return false;
    }
}

bool DownloadAdvert(
    const std::wstring& url,
    std::wstring& downloadedFile,
    const wchar_t*& failureReason,
    DWORD& error) noexcept
{
    std::wstring host;
    std::wstring objectName;
    INTERNET_PORT port = INTERNET_DEFAULT_HTTPS_PORT;
    bool secure = true;
    if (!ParseAdvertUrl(url, host, port, objectName, secure, error))
    {
        failureReason = L"the URL must be credential-free HTTPS or HTTP on a literal loopback host";
        return false;
    }

    InternetHandle session(WinHttpOpen(
        L"Eclipse-Adoptium-MSI-Advert/1.0",
        WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
        WINHTTP_NO_PROXY_NAME,
        WINHTTP_NO_PROXY_BYPASS,
        0));
    if (session.Get() == nullptr)
    {
        error = GetLastError();
        failureReason = L"WinHTTP initialization failed";
        return false;
    }

    if (!WinHttpSetTimeouts(session.Get(), 1500, 1500, 1500, 3000))
    {
        error = GetLastError();
        failureReason = L"WinHTTP timeout configuration failed";
        return false;
    }

    if (secure)
    {
        DWORD secureProtocols = WINHTTP_FLAG_SECURE_PROTOCOL_TLS1_2;
        if (!WinHttpSetOption(
                session.Get(), WINHTTP_OPTION_SECURE_PROTOCOLS, &secureProtocols, sizeof(secureProtocols)))
        {
            error = GetLastError();
            failureReason = L"TLS 1.2 is unavailable";
            return false;
        }
    }

    InternetHandle connection(WinHttpConnect(session.Get(), host.c_str(), port, 0));
    if (connection.Get() == nullptr)
    {
        error = GetLastError();
        failureReason = L"the HTTPS connection failed";
        return false;
    }

    const wchar_t* acceptedTypes[] = {L"image/jpeg", L"image/png", L"image/bmp", nullptr};
    InternetHandle request(WinHttpOpenRequest(
        connection.Get(),
        L"GET",
        objectName.c_str(),
        nullptr,
        WINHTTP_NO_REFERER,
        acceptedTypes,
        (secure ? WINHTTP_FLAG_SECURE : 0) | WINHTTP_FLAG_REFRESH));
    if (request.Get() == nullptr)
    {
        error = GetLastError();
        failureReason = L"the HTTPS request could not be created";
        return false;
    }

    DWORD redirectPolicy = WINHTTP_OPTION_REDIRECT_POLICY_NEVER;
    if (!WinHttpSetOption(
            request.Get(), WINHTTP_OPTION_REDIRECT_POLICY, &redirectPolicy, sizeof(redirectPolicy)))
    {
        error = GetLastError();
        failureReason = L"redirect protection could not be enabled";
        return false;
    }

    if (!WinHttpSendRequest(
            request.Get(),
            L"Cache-Control: no-cache\r\nPragma: no-cache",
            static_cast<DWORD>(-1),
            WINHTTP_NO_REQUEST_DATA,
            0,
            0,
            0) ||
        !WinHttpReceiveResponse(request.Get(), nullptr))
    {
        error = GetLastError();
        failureReason = L"the image request failed";
        return false;
    }

    DWORD statusCode = 0;
    DWORD statusCodeBytes = sizeof(statusCode);
    if (!WinHttpQueryHeaders(
            request.Get(),
            WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
            WINHTTP_HEADER_NAME_BY_INDEX,
            &statusCode,
            &statusCodeBytes,
            WINHTTP_NO_HEADER_INDEX) ||
        statusCode != 200)
    {
        error = statusCode == 0 ? GetLastError() : statusCode;
        failureReason = L"the image endpoint did not return HTTP 200";
        return false;
    }

    DWORD contentLength = 0;
    DWORD contentLengthBytes = sizeof(contentLength);
    if (WinHttpQueryHeaders(
            request.Get(),
            WINHTTP_QUERY_CONTENT_LENGTH | WINHTTP_QUERY_FLAG_NUMBER,
            WINHTTP_HEADER_NAME_BY_INDEX,
            &contentLength,
            &contentLengthBytes,
            WINHTTP_NO_HEADER_INDEX) &&
        contentLength > kMaxAdvertBytes)
    {
        error = ERROR_FILE_TOO_LARGE;
        failureReason = L"the image exceeds the one MiB limit";
        return false;
    }

    wchar_t temporaryDirectory[MAX_PATH + 1]{};
    const DWORD temporaryDirectoryLength = GetTempPathW(MAX_PATH, temporaryDirectory);
    if (temporaryDirectoryLength == 0 || temporaryDirectoryLength >= MAX_PATH)
    {
        error = GetLastError();
        failureReason = L"a temporary directory is unavailable";
        return false;
    }

    wchar_t temporaryFile[MAX_PATH + 1]{};
    if (GetTempFileNameW(temporaryDirectory, L"adp", 0, temporaryFile) == 0)
    {
        error = GetLastError();
        failureReason = L"a temporary image file could not be created";
        return false;
    }

    FileHandle file(CreateFileW(
        temporaryFile,
        GENERIC_WRITE,
        0,
        nullptr,
        CREATE_ALWAYS,
        FILE_ATTRIBUTE_TEMPORARY | FILE_FLAG_SEQUENTIAL_SCAN,
        nullptr));
    if (file.Get() == INVALID_HANDLE_VALUE)
    {
        error = GetLastError();
        failureReason = L"the temporary image file could not be opened";
        DeleteFileW(temporaryFile);
        return false;
    }

    std::vector<BYTE> buffer;
    try
    {
        buffer.resize(kDownloadBufferBytes);
    }
    catch (...)
    {
        error = ERROR_NOT_ENOUGH_MEMORY;
        failureReason = L"memory allocation failed";
        file.Close();
        DeleteFileW(temporaryFile);
        return false;
    }

    BYTE signature[8]{};
    DWORD signatureBytes = 0;
    DWORD totalBytes = 0;
    for (;;)
    {
        DWORD availableBytes = 0;
        if (!WinHttpQueryDataAvailable(request.Get(), &availableBytes))
        {
            error = GetLastError();
            failureReason = L"the image response could not be read";
            file.Close();
            DeleteFileW(temporaryFile);
            return false;
        }

        if (availableBytes == 0)
        {
            break;
        }

        if (availableBytes > kMaxAdvertBytes - totalBytes)
        {
            error = ERROR_FILE_TOO_LARGE;
            failureReason = L"the image exceeds the one MiB limit";
            file.Close();
            DeleteFileW(temporaryFile);
            return false;
        }

        while (availableBytes != 0)
        {
            const DWORD bytesToRead = (std::min)(availableBytes, kDownloadBufferBytes);
            DWORD bytesRead = 0;
            if (!WinHttpReadData(request.Get(), buffer.data(), bytesToRead, &bytesRead) || bytesRead == 0)
            {
                error = GetLastError();
                if (error == ERROR_SUCCESS)
                {
                    error = ERROR_INVALID_DATA;
                }
                failureReason = L"the image response ended unexpectedly";
                file.Close();
                DeleteFileW(temporaryFile);
                return false;
            }

            const DWORD signatureCopyBytes =
                (std::min)(bytesRead, static_cast<DWORD>(sizeof(signature)) - signatureBytes);
            if (signatureCopyBytes != 0)
            {
                std::memcpy(signature + signatureBytes, buffer.data(), signatureCopyBytes);
                signatureBytes += signatureCopyBytes;
            }

            DWORD bytesWritten = 0;
            if (!WriteFile(file.Get(), buffer.data(), bytesRead, &bytesWritten, nullptr) ||
                bytesWritten != bytesRead)
            {
                error = GetLastError();
                failureReason = L"the temporary image file could not be written";
                file.Close();
                DeleteFileW(temporaryFile);
                return false;
            }

            totalBytes += bytesRead;
            availableBytes -= bytesRead;
        }
    }

    file.Close();
    if (totalBytes == 0 || !HasSupportedImageSignature(signature, signatureBytes))
    {
        error = ERROR_INVALID_DATA;
        failureReason = L"the response is not a supported JPEG, PNG, or BMP image";
        DeleteFileW(temporaryFile);
        return false;
    }

    try
    {
        downloadedFile.assign(temporaryFile);
    }
    catch (...)
    {
        error = ERROR_NOT_ENOUGH_MEMORY;
        failureReason = L"memory allocation failed";
        DeleteFileW(temporaryFile);
        return false;
    }

    return true;
}

bool AddTemporaryAdvertUi(
    MSIHANDLE install,
    const std::wstring& imageFile,
    bool clickable,
    bool& linked,
    DWORD& error) noexcept
{
    linked = false;
    DWORD imageWidth = 0;
    DWORD imageHeight = 0;
    if (!ReadImageDimensions(imageFile, imageWidth, imageHeight))
    {
        error = ERROR_INVALID_DATA;
        return false;
    }

    int controlWidth = kAdvertAreaWidth;
    int controlHeight = static_cast<int>(
        (static_cast<unsigned long long>(kAdvertAreaWidth) * imageHeight + imageWidth / 2U) /
        imageWidth);
    if (controlHeight > kAdvertAreaHeight)
    {
        controlHeight = kAdvertAreaHeight;
        controlWidth = static_cast<int>(
            (static_cast<unsigned long long>(kAdvertAreaHeight) * imageWidth + imageHeight / 2U) /
            imageHeight);
    }
    controlWidth = (std::max)(1, controlWidth);
    controlHeight = (std::max)(1, controlHeight);
    const int controlX = (kProgressDialogWidth - controlWidth) / 2;
    const int controlY = kAdvertAreaY + (kAdvertAreaHeight - controlHeight) / 2;

    InstallerHandle database(MsiGetActiveDatabase(install));
    if (database.Get() == 0)
    {
        error = ERROR_INVALID_HANDLE;
        return false;
    }

    MSIHANDLE rawView = 0;
    UINT result = MsiDatabaseOpenViewW(
        database.Get(), L"SELECT `Name`, `Data` FROM `Binary`", &rawView);
    InstallerHandle view(rawView);
    if (result != ERROR_SUCCESS)
    {
        error = result;
        return false;
    }

    result = MsiViewExecute(view.Get(), 0);
    if (result != ERROR_SUCCESS)
    {
        error = result;
        return false;
    }

    InstallerHandle record(MsiCreateRecord(2));
    if (record.Get() == 0)
    {
        error = ERROR_NOT_ENOUGH_MEMORY;
        return false;
    }

    result = MsiRecordSetStringW(record.Get(), 1, kRemoteAdvertBinaryId);
    if (result == ERROR_SUCCESS)
    {
        result = MsiRecordSetStreamW(record.Get(), 2, imageFile.c_str());
    }
    if (result == ERROR_SUCCESS)
    {
        result = MsiViewModify(view.Get(), MSIMODIFY_INSERT_TEMPORARY, record.Get());
    }

    MsiViewClose(view.Get());
    if (result != ERROR_SUCCESS)
    {
        error = result;
        return false;
    }

    MSIHANDLE rawControlView = 0;
    result = MsiDatabaseOpenViewW(
        database.Get(),
        L"SELECT `Dialog_`, `Control`, `Type`, `X`, `Y`, `Width`, `Height`, "
        L"`Attributes`, `Property`, `Text`, `Control_Next`, `Help` FROM `Control`",
        &rawControlView);
    InstallerHandle controlView(rawControlView);
    if (result != ERROR_SUCCESS)
    {
        error = result;
        return false;
    }

    result = MsiViewExecute(controlView.Get(), 0);
    if (result != ERROR_SUCCESS)
    {
        error = result;
        return false;
    }

    InstallerHandle controlRecord(MsiCreateRecord(12));
    if (controlRecord.Get() == 0)
    {
        error = ERROR_NOT_ENOUGH_MEMORY;
        return false;
    }

    MsiRecordSetStringW(controlRecord.Get(), 1, L"ProgressDlg");
    MsiRecordSetStringW(controlRecord.Get(), 2, L"ProgressAdvertImage");
    // A bitmap push button is the only Windows Installer image control that can
    // publish a DoAction event while the modeless progress dialog is displayed.
    MsiRecordSetStringW(controlRecord.Get(), 3, clickable ? L"PushButton" : L"Bitmap");
    MsiRecordSetInteger(controlRecord.Get(), 4, controlX);
    MsiRecordSetInteger(controlRecord.Get(), 5, controlY);
    MsiRecordSetInteger(controlRecord.Get(), 6, controlWidth);
    MsiRecordSetInteger(controlRecord.Get(), 7, controlHeight);
    MsiRecordSetInteger(
        controlRecord.Get(), 8, clickable ? kAdvertButtonAttributes : kAdvertControlAttributes);
    MsiRecordSetStringW(controlRecord.Get(), 10, kRemoteAdvertBinaryId);
    if (clickable)
    {
        // The Help column is not formatted, so resolve the localized tooltip here.
        std::wstring tooltip;
        try
        {
            if (GetProperty(install, L"AdvertLinkTooltip", tooltip) && !tooltip.empty() &&
                tooltip.find(L'|') == std::wstring::npos)
            {
                tooltip.push_back(L'|');
                MsiRecordSetStringW(controlRecord.Get(), 12, tooltip.c_str());
            }
        }
        catch (...)
        {
        }
    }

    result = MsiViewModify(
        controlView.Get(), MSIMODIFY_INSERT_TEMPORARY, controlRecord.Get());
    if (result != ERROR_SUCCESS)
    {
        MsiViewClose(controlView.Get());
        error = result;
        return false;
    }

    InstallerHandle disclosureRecord(MsiCreateRecord(12));
    if (disclosureRecord.Get() != 0)
    {
        MsiRecordSetStringW(disclosureRecord.Get(), 1, L"ProgressDlg");
        MsiRecordSetStringW(disclosureRecord.Get(), 2, L"ProgressAdvertDisclosure");
        MsiRecordSetStringW(disclosureRecord.Get(), 3, L"Text");
        MsiRecordSetInteger(disclosureRecord.Get(), 4, 20);
        MsiRecordSetInteger(disclosureRecord.Get(), 5, 222);
        MsiRecordSetInteger(disclosureRecord.Get(), 6, 330);
        MsiRecordSetInteger(disclosureRecord.Get(), 7, 10);
        MsiRecordSetInteger(disclosureRecord.Get(), 8, 3); // visible and enabled
        MsiRecordSetStringW(disclosureRecord.Get(), 10, L"[AdvertDisclosureText]");
        MsiViewModify(
            controlView.Get(), MSIMODIFY_INSERT_TEMPORARY, disclosureRecord.Get());
    }

    MsiViewClose(controlView.Get());

    if (clickable)
    {
        MSIHANDLE rawEventView = 0;
        if (MsiDatabaseOpenViewW(
                database.Get(),
                L"SELECT `Dialog_`, `Control_`, `Event`, `Argument`, `Condition`, `Ordering` "
                L"FROM `ControlEvent`",
                &rawEventView) == ERROR_SUCCESS)
        {
            InstallerHandle eventView(rawEventView);
            InstallerHandle eventRecord(MsiCreateRecord(6));
            if (eventRecord.Get() != 0 && MsiViewExecute(eventView.Get(), 0) == ERROR_SUCCESS)
            {
                MsiRecordSetStringW(eventRecord.Get(), 1, L"ProgressDlg");
                MsiRecordSetStringW(eventRecord.Get(), 2, L"ProgressAdvertImage");
                MsiRecordSetStringW(eventRecord.Get(), 3, L"DoAction");
                MsiRecordSetStringW(eventRecord.Get(), 4, L"OpenAdvertLink");
                MsiRecordSetStringW(eventRecord.Get(), 5, L"1");
                MsiRecordSetInteger(eventRecord.Get(), 6, 1);
                linked = MsiViewModify(
                    eventView.Get(), MSIMODIFY_INSERT_TEMPORARY, eventRecord.Get()) == ERROR_SUCCESS;
            }
            MsiViewClose(eventView.Get());
        }
    }
    return true;
}
} // namespace

extern "C" UINT __stdcall FetchAdvert(MSIHANDLE install)
{
    // Advertising is optional. Every failure is fail-open so it can never block installation.
    MsiSetPropertyW(install, L"ADVERT_FETCH_ATTEMPTED", L"1");
    MsiSetPropertyW(install, L"ADVERT_LOADED", L"");
    MsiSetPropertyW(install, kAdvertClickUrlProperty, L"");

    try
    {
        std::wstring url;
        std::wstring clickUrl;
        std::wstring apiUrl;
        if (GetProperty(install, L"AdvertApiUrl", apiUrl) && !apiUrl.empty())
        {
            bool noAdvert = false;
            const wchar_t* failureReason = L"the API request failed";
            DWORD error = ERROR_SUCCESS;
            if (!RequestAdvertImageUrl(
                    install, apiUrl, url, clickUrl, noAdvert, failureReason, error))
            {
                LogFailure(install, failureReason, error);
                return ERROR_SUCCESS;
            }
            if (noAdvert)
            {
                LogMessage(install, L"the API returned no eligible campaign; skipping");
                return ERROR_SUCCESS;
            }
        }
        else if (!GetProperty(install, L"AdvertImageUrl", url) || url.empty())
        {
            LogMessage(install, L"no endpoint is configured; skipping");
            return ERROR_SUCCESS;
        }

        std::wstring imageFile;
        const wchar_t* failureReason = L"the image could not be downloaded";
        DWORD error = ERROR_SUCCESS;
        if (!DownloadAdvert(url, imageFile, failureReason, error))
        {
            LogFailure(install, failureReason, error);
            return ERROR_SUCCESS;
        }

        bool clickable = false;
        if (!clickUrl.empty())
        {
            clickable = IsAllowedClickUrl(clickUrl) &&
                MsiSetPropertyW(install, kAdvertClickUrlProperty, clickUrl.c_str()) == ERROR_SUCCESS;
            if (!clickable)
            {
                LogMessage(install, L"the click URL is invalid; the banner will not be linked");
            }
        }

        bool linked = false;
        const bool inserted = AddTemporaryAdvertUi(install, imageFile, clickable, linked, error);
        DeleteFileW(imageFile.c_str());
        if (!inserted)
        {
            LogFailure(install, L"the image could not be added to the installer UI", error);
            return ERROR_SUCCESS;
        }

        const UINT propertyResult = MsiSetPropertyW(install, L"ADVERT_LOADED", L"1");
        if (propertyResult != ERROR_SUCCESS)
        {
            LogFailure(install, L"the advert UI could not be enabled", propertyResult);
            return ERROR_SUCCESS;
        }

        if (clickable && !linked)
        {
            LogMessage(install, L"the banner click action could not be registered");
        }
        LogMessage(install, L"image loaded successfully");
    }
    catch (...)
    {
        LogMessage(install, L"an unexpected error occurred; skipping");
    }

    return ERROR_SUCCESS;
}

extern "C" UINT __stdcall OpenAdvertLink(MSIHANDLE install)
{
    // Published by the banner button. Failures are logged and never affect installation.
    try
    {
        std::wstring url;
        if (!GetProperty(install, kAdvertClickUrlProperty, url) || url.empty() ||
            !IsAllowedClickUrl(url))
        {
            LogMessage(install, L"no valid click URL is available");
            return ERROR_SUCCESS;
        }

        const HRESULT comResult =
            CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);
        const HINSTANCE result =
            ShellExecuteW(nullptr, L"open", url.c_str(), nullptr, nullptr, SW_SHOWNORMAL);
        if (SUCCEEDED(comResult))
        {
            CoUninitialize();
        }
        if (reinterpret_cast<INT_PTR>(result) <= 32)
        {
            LogFailure(
                install,
                L"the click URL could not be opened",
                static_cast<DWORD>(reinterpret_cast<INT_PTR>(result)));
            return ERROR_SUCCESS;
        }
        LogMessage(install, L"opened the click URL");
    }
    catch (...)
    {
        LogMessage(install, L"an unexpected error occurred while opening the click URL");
    }

    return ERROR_SUCCESS;
}
